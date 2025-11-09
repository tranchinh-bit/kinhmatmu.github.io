import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as im;

class Detection {
  final String cls;
  final double score;
  final double x1, y1, x2, y2; // pixel
  Detection(this.cls, this.score, this.x1, this.y1, this.x2, this.y2);
}

class SSDDetector {
  final tfl.Interpreter _i;
  final List<String> labels;
  final int inputW, inputH;
  int topK = 20;
  double scoreThresh = 0.5;

  SSDDetector._(this._i, this.labels, this.inputW, this.inputH);

  static Future<SSDDetector> create({
    String modelAsset = 'assets/models/detector.tflite',
    String labelsAsset = 'assets/models/labels.txt',
    int inputW = 300, int inputH = 300,
    int threads = 2,
  }) async {
    final i = await tfl.Interpreter.fromAsset(
      modelAsset, options: tfl.InterpreterOptions()..threads = threads);
    final lbl = (await rootBundle.loadString(labelsAsset)).trim().split('\n');
    return SSDDetector._(i, lbl, inputW, inputH);
  }

  // Power Save: có thể giảm input xuống 256x256 khi bật tiết kiệm pin (set lại inputW/H trước khi detect)
  void setPowerSave(bool on) {
    if (on) { /* xử lý ở lớp gọi: giảm tần số khung; nếu dùng model 300x300 giữ nguyên để tránh load lại tensor */ }
  }

  Future<List<Detection>> detect(ui.Image img) async {
    final rgb = await _toRGB(img);
    final resized = im.copyResize(rgb, width: inputW, height: inputH);
    final input = Float32List(inputW * inputH * 3);
    int idx = 0;
    for (var y=0; y<inputH; y++) {
      for (var x=0; x<inputW; x++) {
        final p = resized.getPixel(x, y);
        input[idx++] = (im.getRed(p))/255.0;
        input[idx++] = (im.getGreen(p))/255.0;
        input[idx++] = (im.getBlue(p))/255.0;
      }
    }
    final inputTensor = input.reshape([1, inputH, inputW, 3]);

    final locations = List.generate(1, (_) => List.generate(1917, (_)=> List.filled(4, 0.0)));
    final classes   = List.generate(1, (_) => List.filled(1917, 0.0));
    final scores    = List.generate(1, (_) => List.filled(1917, 0.0));
    final numDet    = List.filled(1, 0.0);

    final outputs = { 0: locations, 1: classes, 2: scores, 3: numDet };
    _i.runForMultipleInputs([inputTensor], outputs);

    final W = img.width.toDouble(), H = img.height.toDouble();
    final dets = <Detection>[];
    for (int i=0; i<1917; i++) {
      final s = scores[0][i];
      if (s < scoreThresh) continue;
      final clsIdx = classes[0][i].toInt();
      final name = (clsIdx>=0 && clsIdx<labels.length) ? labels[clsIdx] : 'obj';
      final b = locations[0][i]; // ymin, xmin, ymax, xmax
      final y1 = (b[0] * H).clamp(0, H);
      final x1 = (b[1] * W).clamp(0, W);
      final y2 = (b[2] * H).clamp(0, H);
      final x2 = (b[3] * W).clamp(0, W);
      dets.add(Detection(name, s, x1, y1, x2, y2));
    }

    dets.sort((a,b)=> b.score.compareTo(a.score));
    final kept = <Detection>[];
    for (final d in dets) {
      bool ok = true;
      for (final k in kept) {
        if (_iou(d,k) > 0.5) { ok = false; break; }
      }
      if (ok) kept.add(d);
      if (kept.length >= topK) break;
    }
    return kept;
  }

  double _iou(Detection a, Detection b) {
    final xx1 = (a.x1>b.x1)?a.x1:b.x1;
    final yy1 = (a.y1>b.y1)?a.y1:b.y1;
    final xx2 = (a.x2<b.x2)?a.x2:b.x2;
    final yy2 = (a.y2<b.y2)?a.y2:b.y2;
    final w = (xx2-xx1).clamp(0, double.infinity);
    final h = (yy2-yy1).clamp(0, double.infinity);
    final inter = w*h;
    final areaA = (a.x2-a.x1)*(a.y2-a.y1);
    final areaB = (b.x2-b.x1)*(b.y2-b.y1);
    final uni = areaA+areaB-inter+1e-6;
    return inter/uni;
  }

  Future<im.Image> _toRGB(ui.Image img) async {
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = byteData!.buffer.asUint8List();
    return im.Image.fromBytes(
      width: img.width, height: img.height, bytes: rgba, numChannels: 4
    ).convert(numChannels: 3);
  }
}
