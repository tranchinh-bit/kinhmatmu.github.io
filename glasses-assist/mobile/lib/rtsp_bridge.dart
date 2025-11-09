import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class RtspBridge {
  static const _ch = MethodChannel('rtsp_bridge');
  void Function(ui.Image img)? onFrame;

  RtspBridge(){
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onFrame') {
        final bytes = call.arguments as Uint8List;
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        onFrame?.call(frame.image);
      } else if (call.method == 'onFrameRaw') {
        final bytes = call.arguments as Uint8List;
        final img = await _rgbaToImage(bytes, 640, 360);
        onFrame?.call(img);
      }
    });
  }

  Future<void> start(String url) => _ch.invokeMethod('start', {'url': url});
  Future<void> stop() => _ch.invokeMethod('stop');
  Future<void> setIntervalMs(int ms)=> _ch.invokeMethod('setInterval', {'ms': ms});

  Future<ui.Image> _rgbaToImage(Uint8List rgba, int w, int h) async {
    final desc = ui.ImageDescriptor.raw(await ui.ImmutableBuffer.fromUint8List(rgba),
      width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
    final fi = await (await desc.instantiateCodec()).getNextFrame();
    return fi.image;
  }
}
