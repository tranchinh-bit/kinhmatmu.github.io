import 'dart:ui' as ui;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final _recog = TextRecognizer(script: TextRecognitionScript.latin);
  Future<String> recognize(ui.Image img) async {
    final png=(await img.toByteData(format: ui.ImageByteFormat.png))!;
    final input = InputImage.fromBytes(bytes: png.buffer.asUint8List(),
      inputImageData: InputImageData(size: ui.Size(img.width.toDouble(),img.height.toDouble()),
      imageRotation: InputImageRotation.rotation0deg, inputImageFormat: InputImageFormat.bgra8888, planeData: []));
    final res = await _recog.processImage(input); return res.text.trim();
  }
  Future<void> close()=>_recog.close();
}
