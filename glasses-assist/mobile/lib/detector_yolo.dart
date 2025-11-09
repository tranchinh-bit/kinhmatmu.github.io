import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as im;
import 'package:flutter/services.dart' show rootBundle;

class Detection {
  final String cls; final double score; final double x1,y1,x2,y2;
  Detection(this.cls,this.score,this.x1,this.y1,this.x2,this.y2);
}

class YOLOv8n {
  final tfl.Interpreter _i; final List<String> labels;
  int inputSize; double scoreThresh; double nmsIou; int topK;
  YOLOv8n._(this._i,this.labels,this.inputSize,this.scoreThresh,this.nmsIou,this.topK);

  static Future<YOLOv8n> create({
    String modelAsset='assets/models/detector.tflite',
    String labelsAsset='assets/models/labels.txt',
    int inputSize=320, double scoreThresh=0.55, double nmsIou=0.5, int topK=50, int threads=2
  }) async {
    final i = await tfl.Interpreter.fromAsset(modelAsset, options: tfl.InterpreterOptions()..threads=threads);
    final lbl = (await rootBundle.loadString(labelsAsset)).trim().split('\n');
    return YOLOv8n._(i,lbl,inputSize,scoreThresh,nmsIou,topK);
  }

  Future<List<Detection>> detect(ui.Image img) async {
    final lb = await _letterbox(img);
    final input = Float32List(inputSize*inputSize*3);
    int idx=0;
    for(int y=0;y<inputSize;y++){
      for(int x=0;x<inputSize;x++){
        final p = lb.img.getPixel(x,y);
        input[idx++]=im.getRed(p)/255.0; input[idx++]=im.getGreen(p)/255.0; input[idx++]=im.getBlue(p)/255.0;
      }
    }
    final inputTensor = input.reshape([1,inputSize,inputSize,3]);
    final out0 = _i.getOutputTensor(0);
    final outputs = {0: out0.buffer};
    _i.runForMultipleInputs([inputTensor], outputs);
    final Float32List raw = out0.buffer as Float32List;
    final shape = out0.shape;

    final dets=<_RawDet>[];
    if(shape.length==3 && shape[1]==84){ // [1,84,8400]
      final n=shape[2];
      for(int i=0;i<n;i++){
        final bx=raw[0*shape[1]*n + 0*n + i], by=raw[1*n + i], bw=raw[2*n + i], bh=raw[3*n + i];
        double best=0; int bestCls=-1;
        for(int c=4;c<shape[1];c++){ final sc=raw[c*n+i]; if(sc>best){ best=sc; bestCls=c-4; } }
        if(best>=scoreThresh) dets.add(_RawDet(cx:bx,cy:by,w:bw,h:bh,score:best,cls:bestCls));
      }
    } else if(shape.length==3 && shape[2]==84){ // [1,8400,84]
      final n=shape[1];
      for(int i=0;i<n;i++){
        final bx=raw[i*84+0], by=raw[i*84+1], bw=raw[i*84+2], bh=raw[i*84+3];
        double best=0; int bestCls=-1; for(int c=4;c<84;c++){ final sc=raw[i*84+c]; if(sc>best){best=sc; bestCls=c-4;} }
        if(best>=scoreThresh) dets.add(_RawDet(cx:bx,cy:by,w:bw,h:bh,score:best,cls:bestCls));
      }
    } else { return <Detection>[]; }

    final boxes=<Detection>[];
    for(final r in dets){
      final x1=(r.cx-r.w/2.0 - lb.padLeft)/lb.scale, y1=(r.cy-r.h/2.0 - lb.padTop)/lb.scale;
      final x2=(r.cx+r.w/2.0 - lb.padLeft)/lb.scale, y2=(r.cy+r.h/2.0 - lb.padTop)/lb.scale;
      if(x2<=0||y2<=0||x1>=lb.W||y1>=lb.H) continue;
      final clsIdx=(r.cls>=0&&r.cls<labels.length)?r.cls:0;
      boxes.add(Detection(labels[clsIdx], r.score,
        x1.clamp(0,lb.W), y1.clamp(0,lb.H), x2.clamp(0,lb.W), y2.clamp(0,lb.H)));
    }
    boxes.sort((a,b)=> b.score.compareTo(a.score));
    final kept=<Detection>[];
    for(final d in boxes){
      bool ok=true; for(final k in kept){ if(_iou(d,k)>nmsIou){ ok=false; break; } }
      if(ok) kept.add(d); if(kept.length>=topK) break;
    }
    return kept;
  }

  double _iou(Detection a, Detection b){
    final xx1=math.max(a.x1,b.x1), yy1=math.max(a.y1,b.y1);
    final xx2=math.min(a.x2,b.x2), yy2=math.min(a.y2,b.y2);
    final w=math.max(0,xx2-xx1), h=math.max(0,yy2-yy1);
    final inter=w*h, areaA=(a.x2-a.x1)*(a.y2-a.y1), areaB=(b.x2-b.x1)*(b.y2-b.y1);
    return inter/(areaA+areaB-inter+1e-6);
  }

  Future<_Letterbox> _letterbox(ui.Image img) async {
    final W=img.width, H=img.height;
    final scale=math.min(inputSize/W, inputSize/H);
    final newW=(W*scale).round(), newH=(H*scale).round();
    final left=((inputSize-newW)/2).round(), top=((inputSize-newH)/2).round();
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = bd!.buffer.asUint8List();
    final rgb = im.Image.fromBytes(width: W, height: H, bytes: rgba, numChannels: 4).convert(numChannels:3);
    final resized = im.copyResize(rgb, width: newW, height: newH);
    final boxed = im.Image(width: inputSize, height: inputSize); im.fill(boxed, color: im.ColorUint8.rgb(114,114,114));
    im.copyInto(boxed, resized, dstX:left, dstY:top);
    return _Letterbox(img:boxed, scale:scale, padLeft:left, padTop:top, W:W.toDouble(), H:H.toDouble());
  }
}
class _RawDet{ final double cx,cy,w,h,score; final int cls; _RawDet({required this.cx,required this.cy,required this.w,required this.h,required this.score,required this.cls}); }
class _Letterbox{ final im.Image img; final double scale; final int padLeft,padTop; final double W,H;
  _Letterbox({required this.img,required this.scale,required this.padLeft,required this.padTop,required this.W,required this.H}); }
