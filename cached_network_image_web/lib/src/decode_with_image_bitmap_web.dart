import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

import 'is_static_bitmap_image.dart';

/// Decodes [bytes] into a single-frame codec backed by an `ImageBitmap`, or
/// returns null when the engine's own decoder should be used instead.
///
/// On browsers without WebCodecs (Firefox, Safari) the Flutter engine decodes
/// images through a detached `<img>` element and hands CanvasKit a lazy texture
/// that is only uploaded at raster time. Firefox frequently has no pixel data
/// available at that point ("tex(Sub)Image: Resource has no data (yet?).
/// Uploading zeros.") and the image paints solid black. An `ImageBitmap` owns
/// its decoded pixels, so the upload always succeeds.
Future<ui.Codec?> decodeWithImageBitmap(Uint8List bytes) async {
  if (_engineDecodesWithWebCodecs || !isStaticBitmapImage(bytes)) {
    return null;
  }
  try {
    final blob = web.Blob(<JSAny>[bytes.toJS].toJS);
    final bitmap = await web.window.createImageBitmap(blob).toDart;
    return _ImageBitmapCodec(await ui_web.createImageFromImageBitmap(bitmap));
  } on Object catch (e) {
    web.console.warn(
      'ImageBitmap decoding failed, falling back to the engine decoder. '
              'Images may render black on Firefox. $e'
          .toJS,
    );
    return null;
  }
}

/// Whether the engine decodes images with the WebCodecs `ImageDecoder`, which
/// produces `VideoFrame`-backed images that do not hit the `<img>` path.
bool get _engineDecodesWithWebCodecs =>
    ui_web.browser.browserEngine == ui_web.BrowserEngine.blink &&
    globalContext.has('ImageDecoder');

/// A [ui.Codec] wrapping a single already-decoded image.
///
/// The image is handed to the first caller of [getNextFrame], which becomes
/// responsible for disposing it; [dispose] only releases an image that was
/// never handed out.
class _ImageBitmapCodec implements ui.Codec {
  _ImageBitmapCodec(this._image);

  final ui.Image _image;
  bool _handedOut = false;
  bool _disposed = false;

  @override
  int get frameCount => 1;

  @override
  int get repetitionCount => 0;

  @override
  Future<ui.FrameInfo> getNextFrame() async {
    if (_disposed) {
      throw StateError('Cannot decode a frame from a disposed codec.');
    }
    final frame = _handedOut ? _image.clone() : _image;
    _handedOut = true;
    return _SingleFrameInfo(frame);
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    if (!_handedOut) {
      _image.dispose();
    }
  }
}

class _SingleFrameInfo implements ui.FrameInfo {
  _SingleFrameInfo(this.image);

  @override
  Duration get duration => Duration.zero;

  @override
  final ui.Image image;
}
