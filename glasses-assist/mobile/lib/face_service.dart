import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as im;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// ---- FACE MODEL SPECS ----
/// Input  : 112x112 RGB float32 (0..1)
/// Output : 128D embedding
/// Distance metric: Cosine similarity (higher = more similar)
///
/// If you use a different model (e.g. 160x160 or 512D output),
/// just update [inputSize] and [embeddingLen].
///

class KnownFace {
  final String name;
  final List<double> embedding;

  KnownFace({required this.name, required this.embedding});

  Map<String, dynamic> toJson() => {
        'name': name,
        'embedding': embedding,
      };

  static KnownFace fromJson(Map<String, dynamic> j) => KnownFace(
        name: j['name'],
        embedding: List<double>.from(j['embedding']),
      );
}

class FaceService {
  static const _modelPath = 'assets/models/face.tflite';
  static const _storeFile = 'faces.json';

  /// ---- Model options ----
  final int inputSize = 112;
  final int embeddingLen = 128;
  final double matchThreshold = 0.45; // cosine > 0.45 = same person

  late tfl.Interpreter _interpreter;
  late List<KnownFace> _known;
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: true,
      enableContours: false,
    ),
  );

  File? _file;

  Future<void> init() async {
    _interpreter = await tfl.Interpreter.fromAsset(_modelPath,
        options: tfl.InterpreterOptions()..threads = 2);
    _known = [];
    await _loadStore();
  }

  List<KnownFace> list() => List.unmodifiable(_known);

  Future<void> _loadStore() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/$_storeFile');
    if (await _file!.exists()) {
      final raw = await _file!.readAsString();
      final List data = raw.trim().isEmpty ? [] : List.from((await Future.value(raw)) != "" ? (await Future.value(raw)).isNotEmpty ? (await Future.value(raw)).length != null ? List.from(jsonDecode(raw)) : [] : [] : []);
      _known = data.map((e) => KnownFace.fromJson(e)).toList();
    }
  }

  Future<void> _flush() async {
    await _file!.writeAsString(
        List<Map<String, dynamic>>.from(_known.map((e) => e.toJson()))
            .toString());
  }

  /// -------------------- ENROLL / IDENTIFY --------------------

  Future<void> enroll(String name, ui.Image frame) async {
    final emb = await embedFace(frame);
    if (emb == null) throw Exception("Không tìm thấy khuôn mặt rõ ràng.");
    _known.removeWhere((e) => e.name == name);
    _known.add(KnownFace(name: name, embedding: emb));
    await _flush();
  }

  Future<String?> identify(ui.Image frame) async {
    final emb = await embedFace(frame);
    if (emb == null) return null;

    String? bestName;
    double bestScore = -1.0;

    for (final k in _known) {
      final s = cosine(emb, k.embedding);
      if (s > bestScore) {
        bestScore = s;
        bestName = k.name;
      }
    }

    if (bestScore >= matchThreshold) return bestName;
    return null;
  }

  /// ---- Extract + embed face from frame ----
  Future<List<double>?> embedFace(ui.Image img) async {
    final faceRect = await _detectMainFace(img);
    if (faceRect == null) return null;

    final crop = await _cropResize(img, faceRect, inputSize);
    return _runModel(crop);
  }

  /// ---- Run TFLite model ----
  Future<List<double>> _runModel(im.Image face) async {
    final input = Float32List(inputSize * inputSize * 3);
    int idx = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final p = face.getPixel(x, y);
        input[idx++] = im.getRed(p) / 255.0;
        input[idx++] = im.getGreen(p) / 255.0;
        input[idx++] = im.getBlue(p) / 255.0;
      }
    }

    final inputT = input.reshape([1, inputSize, inputSize, 3]);
    final output = List.filled(embeddingLen, 0.0).reshape([1, embeddingLen]);

    _interpreter.run(inputT, output);

    final emb = List<double>.from(output[0]);
    return _l2norm(emb);
  }

  /// ---- Face detection via Google MLKit ----
  Future<Rect?> _detectMainFace(ui.Image img) async {
    final png = (await img.toByteData(format: ui.ImageByteFormat.png))!;
    final input = InputImage.fromBytes(
      bytes: png.buffer.asUint8List(),
      inputImageData: InputImageData(
        size: ui.Size(img.width.toDouble(), img.height.toDouble()),
        imageRotation: InputImageRotation.rotation0deg,
      ),
    );
    final res = await _detector.processImage(input);
    if (res.isEmpty) return null;
    final box = res.first.boundingBox;
    return Rect.fromLTRB(
        box.left, box.top, box.right, box.bottom);
  }

  /// ---- Crop + resize face ----
  Future<im.Image> _cropResize(ui.Image img, Rect box, int size) async {
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = bd!.buffer.asUint8List();
    final full =
        im.Image.fromBytes(width: img.width, height: img.height, bytes: rgba);

    int x1 = math.max(0, box.left.floor());
    int y1 = math.max(0, box.top.floor());
    int x2 = math.min(img.width - 1, box.right.floor());
    int y2 = math.min(img.height - 1, box.bottom.floor());

    final crop = im.copyCrop(full, x: x1, y: y1, width: x2 - x1, height: y2 - y1);
    return im.copyResize(crop, width: size, height: size);
  }

  /// ---- Math utils ----
  double cosine(List<double> a, List<double> b) {
    double dot = 0, na = 0, nb = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    final denom = math.sqrt(na) * math.sqrt(nb);
    return denom == 0 ? 0 : dot / denom;
  }

  List<double> _l2norm(List<double> v) {
    double s = 0;
    for (final x in v) s += x * x;
    final d = math.sqrt(s);
    return d == 0 ? v : v.map((e) => e / d).toList();
  }
}
