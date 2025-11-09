import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'rtsp_bridge.dart';
import 'ocr_service.dart';
import 'detector_yolo.dart';
import 'tts_haptics.dart';
import 'config/context_manager.dart';
import 'risk_logic.dart';
import 'gps_service.dart';
import 'places_service.dart';
import 'number_extractor.dart';
import 'voice_command.dart';
// import 'face_service.dart'; // bật nếu dùng nhận diện

void main()=> runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override Widget build(BuildContext c)=> const MaterialApp(debugShowCheckedModeBanner:false, home: Home());
}

class Home extends StatefulWidget { const Home({super.key}); @override State<Home> createState()=>_HomeState(); }

class _HomeState extends State<Home>{
  final rtsp=RtspBridge(); final ocr=OcrService(); final ntf=Notifier();
  final battery=Battery(); final ctxMgr=ContextManager(); final gps=GpsService();
  final places=PlacesService(); final voice=VoiceCommand();
  // final face=FaceService();
  late YOLOv8n det;

  String activeProfile='scan_outdoor'; bool obstacleMode=true; bool busy=false; bool powerSave=false; bool sosMode=false;
  double kDistance=1400;

  @override void initState(){ super.initState(); rtsp.onFrame=_onFrame; _boot(); }

  Future<void> _boot() async {
    await ctxMgr.load(); await gps.init(); await places.init(); await voice.init(); // await face.init();
    _applyProfile('scan_outdoor');
    det = await YOLOv8n.create(modelAsset:'assets/models/detector.tflite', labelsAsset:'assets/models/labels.txt',
      inputSize:320, scoreThresh:0.55, nmsIou:0.5, topK:50);
    await rtsp.start('rtsp://192.168.50.1:8554/unicast');
    final lvl = await battery.batteryLevel; if(lvl<25) _setPowerSave(true);
  }

  void _applyProfile(String name){
    final p=ctxMgr.get(name); activeProfile=name; rtsp.setIntervalMs(p.snapshotMs);
    ntf.minGapSec=p.ttsGapSec; kDistance=p.kDistance; setState((){});
  }

  void _setPowerSave(bool on){ powerSave=on; _applyProfile(on?'power_save':'scan_outdoor'); }

  Future<void> _onFrame(ui.Image img) async {
    if(!obstacleMode || busy) return; busy=true;
    try{
      final dets=await det.detect(img); final p=ctxMgr.get(activeProfile);
      final filtered=dets.where((d)=> p.classes.contains(d.cls)).toList();
      if(filtered.isNotEmpty){
        filtered.sort((a,b)=> _dist(a).compareTo(_dist(b)));
        final top=filtered.first; final dist=_dist(top);
        final side=bearingOf(top.x1,top.x2,img.width.toDouble());
        final lvl=riskLevel(top.cls,dist,side,conf: top.score);
        if(lvl>0){
          await ntf.buzz(lvl);
          final name=viName(top.cls); final word=dist<1.2?'rất gần':(dist<2.5?'gần':'xa');
          final msg=(lvl>=3)?'Dừng lại! Phía $side rất gần $name.':'Phía $side có $name, $word.';
          await ntf.say(msg);
        }
      }
    } finally { busy=false; }
  }

  double _dist(d){ final h=max(1.0,d.y2-d.y1); return kDistance/h; }

  Future<void> _doOCR() async {
    obstacleMode=false;
    final shot = await _grabOne();
    final text = await ocr.recognize(shot);
    await ntf.say(text.isEmpty? 'Không thấy chữ rõ.' : 'Nội dung: $text');
    final meta=NumberExtractor.extractAll(text); await ntf.say(NumberExtractor.speak(meta));
    obstacleMode=true; setState((){});
  }

  Future<ui.Image> _grabOne() async {
    final c=Completer<ui.Image>(); final prev=rtsp.onFrame; rtsp.onFrame=(img){ rtsp.onFrame=prev; c.complete(img); };
    return c.future;
  }

  Future<void> _speakLocation() async {
    final pos=await gps.current(); if(pos==null){ await ntf.say('Không lấy được vị trí.'); return; }
    await ntf.say(GpsService.speakable(pos.latitude,pos.longitude));
    final addr=await gps.reverse(pos.latitude,pos.longitude); if(addr!=null&&addr.trim().isNotEmpty) await ntf.say('Gần: $addr');
  }

  Future<void> _toggleSOS() async {
    sosMode=!sosMode;
    if(sosMode){ await ntf.say('Kích hoạt S O S.'); await _speakLocation(); }
    else { await ntf.say('Tắt S O S.'); }
    setState((){});
  }

  Future<void> _saveCurrentPlace(String name) async {
    final pos=await gps.current(); if(pos==null){ await ntf.say('Không lấy được vị trí.'); return; }
    await places.savePlace(name.isEmpty?'Noi_${DateTime.now().millisecondsSinceEpoch}':name, pos.latitude,pos.longitude);
    await ntf.say('Đã lưu nơi $name.');
  }

  double _hav(double lat1,double lon1,double lat2,double lon2){
    const R=6371000.0; final dLat=(lat2-lat1)*pi/180, dLon=(lon2-lon1)*pi/180;
    final a=sin(dLat/2)*sin(dLat/2)+cos(lat1*pi/180)*cos(lat2*pi/180)*sin(dLon/2)*sin(dLon/2);
    return R*2*atan2(sqrt(a),sqrt(1-a));
  }
  double _bearing(double lat1,double lon1,double lat2,double lon2){
    final y=sin((lon2-lon1)*pi/180)*cos(lat2*pi/180);
    final x=cos(lat1*pi/180)*sin(lat2*pi/180)-sin(lat1*pi/180)*cos(lat2*pi/180)*cos((lon2-lon1)*pi/180);
    var b=atan2(y,x)*180/pi; if(b<0) b+=360; return b;
  }

  Future<void> _gotoPlace(SavedPlace p) async {
    final pos=await gps.current(); if(pos==null){ await ntf.say('Không lấy được vị trí.'); return; }
    final d=_hav(pos.latitude,pos.longitude,p.lat,p.lon); final b=_bearing(pos.latitude,pos.longitude,p.lat,p.lon);
    final dir=(b<30||b>=330)?'Bắc': (b<60)?'Đông Bắc': (b<120)?'Đông': (b<150)?'Đông Nam': (b<210)?'Nam': (b<240)?'Tây Nam': (b<300)?'Tây':'Tây Bắc';
    await ntf.say('Nơi ${p.name}: cách khoảng ${d.round()} mét, hướng $dir.');
    final url=Uri.parse('https://maps.google.com/?q=${p.lat},${p.lon}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _handleVoiceCommand(String s) async {
    s=s.toLowerCase().replaceAll(RegExp(r'\s+'),' ').trim();
    if(s.contains('đọc chữ')||s.contains('ocr')) { await _doOCR(); return; }
    if(s.contains('yên lặng')) { _applyProfile('quiet_mode'); await ntf.say('Đã bật yên lặng'); return; }
    if(s.contains('tiết kiệm')||s.contains('power')) { _setPowerSave(true); await ntf.say('Đã bật tiết kiệm pin'); return; }
    if(s.contains('tắt tiết kiệm')) { _setPowerSave(false); await ntf.say('Đã tắt tiết kiệm pin'); return; }
    if(s.contains('ngoài trời')) { _applyProfile('scan_outdoor'); await ntf.say('Đã chuyển ngoài trời'); return; }
    if(s.contains('trong nhà')) { _applyProfile('scan_indoor'); await ntf.say('Đã chuyển trong nhà'); return; }
    if(s.contains('qua đường')) { _applyProfile('crosswalk'); await ntf.say('Đã chuyển qua đường'); return; }
    if(s.contains('s o s')||s.contains('khẩn cấp')) { await _toggleSOS(); return; }
    if(s.contains('vị trí của tôi')||s.contains('tôi đang ở đâu')) { await _speakLocation(); return; }
    if(s.startsWith('lưu nơi')) { final name=s.replaceFirst('lưu nơi','').trim(); await _saveCurrentPlace(name); return; }
    if(s.startsWith('đi tới')||s.startsWith('đi đến')){
      final name=s.replaceFirst(RegExp(r'đi (tới|đến)'),'').trim();
      final item = places.list().reversed.firstWhere((p)=> p.name.toLowerCase()==name.toLowerCase(), orElse: ()=> places.list().isEmpty? null: places.list().last);
      if(item==null){ await ntf.say('Chưa có nơi đã lưu.'); return; } await _gotoPlace(item); return;
    }
    await ntf.say('Bạn có thể nói: đọc chữ, yên lặng, tiết kiệm, ngoài trời, trong nhà, qua đường, vị trí của tôi, lưu nơi <tên>, đi tới <tên>, S O S.');
  }

  @override Widget build(BuildContext c){
    final profiles=ctxMgr.list();
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: Column(children:[
        const SizedBox(height:10),
        const Text('Kính trợ lực (Bluetooth mic/speaker) – YOLOv8n', style: TextStyle(color:Colors.white,fontSize:18)),
        const SizedBox(height:10),
        Wrap(spacing:8, runSpacing:8, alignment: WrapAlignment.center, children:[
          ElevatedButton(onPressed:_doOCR, child: const Text('Đọc chữ')),
          ElevatedButton(onPressed: ()=> setState(()=> obstacleMode=!obstacleMode), child: Text(obstacleMode?'Tạm dừng dò':'Tiếp tục dò')),
          ElevatedButton(onPressed: ()=> setState(()=> _setPowerSave(!powerSave)), child: Text(powerSave?'Tắt Power Save':'Bật Power Save')),
          ElevatedButton(onPressed: _speakLocation, child: const Text('Vị trí của tôi')),
          ElevatedButton(onPressed: _toggleSOS, child: Text(sosMode?'Tắt SOS':'Bật SOS')),
          ElevatedButton(onPressed: ()=> _saveCurrentPlace('Noi_${DateTime.now().millisecondsSinceEpoch}'), child: const Text('Lưu nơi này')),
          ElevatedButton(onPressed: () async { final items=places.list(); if(items.isEmpty){ await ntf.say('Chưa có nơi nào.'); return; } await _gotoPlace(items.last); }, child: const Text('Danh sách nơi')),
          ElevatedButton(onPressed: () async { await ntf.say('Đang nghe...'); await voice.listenVI(_handleVoiceCommand); }, child: const Text('🎤 Giọng nói')),
          DropdownButton<String>(
            dropdownColor: Colors.grey[900], value: activeProfile, style: const TextStyle(color:Colors.white),
            items: profiles.map((e)=> DropdownMenuItem(value:e, child: Text(e, style: const TextStyle(color:Colors.white)))).toList(),
            onChanged: (v){ if(v!=null) _applyProfile(v); })
        ])
      ]))
    );
  }
  final face = FaceService();

@override
Future<void> _boot() async {
   ...
   await face.init();
}

Future<void> _enrollFace(String name) async {
  final shot = await _grabOne();
  try {
    await face.enroll(name, shot);
    await ntf.say("Đã lưu mặt $name.");
  } catch (e) {
    await ntf.say("Không thể lưu mặt.");
  }
}

Future<void> _identifyFace() async {
  final shot = await _grabOne();
  final who = await face.identify(shot);
  if (who == null) await ntf.say("Không nhận ra ai.");
  else await ntf.say("Đây là $who.");
}
}
