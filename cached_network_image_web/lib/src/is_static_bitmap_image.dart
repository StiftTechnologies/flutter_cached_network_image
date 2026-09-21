import 'dart:typed_data';

/// Whether [bytes] hold an image that `createImageBitmap` fully represents.
///
/// Animated formats are excluded because `createImageBitmap` only yields their
/// first frame.
bool isStaticBitmapImage(Uint8List bytes) {
  if (_startsWith(bytes, const [0xFF, 0xD8, 0xFF])) {
    return true;
  }
  if (_startsWith(bytes, const [0x42, 0x4D])) {
    return true;
  }
  if (_startsWith(
    bytes,
    const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
  )) {
    return !_isAnimatedPng(bytes);
  }
  if (_startsWith(bytes, const [0x52, 0x49, 0x46, 0x46]) &&
      _matchesAt(bytes, 8, const [0x57, 0x45, 0x42, 0x50])) {
    return !_isAnimatedWebp(bytes);
  }
  return false;
}

/// An APNG carries an `acTL` chunk before the first `IDAT` chunk.
bool _isAnimatedPng(Uint8List bytes) {
  var offset = 8;
  while (offset + 8 <= bytes.length) {
    if (_matchesAt(bytes, offset + 4, const [0x61, 0x63, 0x54, 0x4C])) {
      return true;
    }
    if (_matchesAt(bytes, offset + 4, const [0x49, 0x44, 0x41, 0x54])) {
      return false;
    }
    final length = (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    offset += length + 12;
  }
  return false;
}

/// An animated WebP is an extended (`VP8X`) file with the animation flag set.
bool _isAnimatedWebp(Uint8List bytes) {
  if (!_matchesAt(bytes, 12, const [0x56, 0x50, 0x38, 0x58])) {
    return false;
  }
  return bytes.length > 20 && bytes[20] & 0x02 != 0;
}

bool _startsWith(Uint8List bytes, List<int> prefix) =>
    _matchesAt(bytes, 0, prefix);

bool _matchesAt(Uint8List bytes, int offset, List<int> expected) {
  if (offset + expected.length > bytes.length) {
    return false;
  }
  for (var i = 0; i < expected.length; i++) {
    if (bytes[offset + i] != expected[i]) {
      return false;
    }
  }
  return true;
}
