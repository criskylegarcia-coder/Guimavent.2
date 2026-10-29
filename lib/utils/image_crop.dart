import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Center-crops [bytes] (any format package:image can decode — JPEG, PNG,
/// HEIC via platform decode, etc.) to a square using the shorter side, then
/// re-encodes as JPEG. Used for avatar uploads so every stored photo has a
/// consistent square aspect ratio regardless of what the user picked, with
/// no separate crop-UI screen.
Uint8List centerCropSquareJpeg(Uint8List bytes, {int quality = 85}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Could not decode the selected image.');
  }
  final side = decoded.width < decoded.height ? decoded.width : decoded.height;
  final x = (decoded.width - side) ~/ 2;
  final y = (decoded.height - side) ~/ 2;
  final cropped = img.copyCrop(decoded, x: x, y: y, width: side, height: side);
  return Uint8List.fromList(img.encodeJpg(cropped, quality: quality));
}
