import 'dart:typed_data';

import 'package:cached_network_image_web/src/is_static_bitmap_image.dart';
import 'package:flutter_test/flutter_test.dart';

const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

List<int> _pngChunk(String type, [int length = 0]) => [
      (length >> 24) & 0xFF,
      (length >> 16) & 0xFF,
      (length >> 8) & 0xFF,
      length & 0xFF,
      ...type.codeUnits,
      ...List.filled(length + 4, 0),
    ];

List<int> _webp(String chunk, {int flags = 0}) => [
      ...'RIFF'.codeUnits,
      0, 0, 0, 0,
      ...'WEBP'.codeUnits,
      ...chunk.codeUnits,
      0, 0, 0, 0,
      flags,
      0, 0, 0,
    ];

void main() {
  bool check(List<int> bytes) => isStaticBitmapImage(Uint8List.fromList(bytes));

  test('accepts JPEG and BMP', () {
    expect(check([0xFF, 0xD8, 0xFF, 0xE0]), isTrue);
    expect(check([0x42, 0x4D, 0, 0]), isTrue);
  });

  test('accepts a static PNG', () {
    expect(
      check([..._pngSignature, ..._pngChunk('IHDR', 13), ..._pngChunk('IDAT')]),
      isTrue,
    );
  });

  test('rejects an APNG', () {
    expect(
      check([
        ..._pngSignature,
        ..._pngChunk('IHDR', 13),
        ..._pngChunk('acTL', 8),
        ..._pngChunk('IDAT'),
      ]),
      isFalse,
    );
  });

  test('accepts static WebP and rejects animated WebP', () {
    expect(check(_webp('VP8 ')), isTrue);
    expect(check(_webp('VP8L')), isTrue);
    expect(check(_webp('VP8X')), isTrue);
    expect(check(_webp('VP8X', flags: 0x02)), isFalse);
  });

  test('rejects GIF, unknown and truncated input', () {
    expect(check('GIF89a'.codeUnits), isFalse);
    expect(check([0x00, 0x01, 0x02]), isFalse);
    expect(check([]), isFalse);
    expect(check([..._pngSignature, 0, 0, 0]), isTrue);
  });
}
