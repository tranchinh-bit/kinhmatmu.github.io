import 'package:speech_to_text/speech_to_text.dart' as stt;

typedef VoiceAction = Future<void> Function(String text);

class VoiceCommand {
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _ready=false; bool get isReady=>_ready;

  Future<bool> init() async {
    _ready = await _stt.initialize(onStatus: (_){}, onError: (_){});
    return _ready;
  }

  /// Chế độ C: hệ thống sẽ dùng STT của OS (online khi có mạng; offline nếu đã cài gói offline).
  /// Bạn có thể vào cài đặt hệ thống để tải "Tiếng Việt (Offline recognition)".
  Future<void> listenVI(VoiceAction onFinalText) async {
    if(!_ready) await init();
    await _stt.listen(
      localeId: 'vi_VN',
      listenMode: stt.ListenMode.search,   // ưu tiên độ chính xác câu ngắn
      partialResults: false,
      onResult: (res) async { if(res.finalResult){ await onFinalText(res.recognizedWords.toLowerCase().trim()); } }
    );
  }

  Future<void> stop() async => _stt.stop();
}
