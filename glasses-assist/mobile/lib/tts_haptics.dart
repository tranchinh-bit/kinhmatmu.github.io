import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

class Notifier {
  final _tts = FlutterTts();
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  double minGapSec = 1.0;
  Notifier(){
    _tts.setLanguage('vi-VN');
    _tts.setSpeechRate(0.48);
    _tts.setPitch(1.0);
    _tts.setVolume(1.0);
    // ưu tiên Bluetooth khi có
    // (OS sẽ tự route sang thiết bị đang kết nối)
  }
  Future<void> say(String s) async {
    final now=DateTime.now();
    if(now.difference(_last).inMilliseconds < (minGapSec*1000)) return;
    _last=now; await _tts.speak(s);
  }
  Future<void> buzz(int lvl) async {
    if(!(await Vibration.hasVibrator()??false)) return;
    if(lvl==1) Vibration.vibrate(duration:70);
    else if(lvl==2) Vibration.vibrate(duration:200);
    else Vibration.vibrate(pattern:[0,250,120,250]);
  }
}
