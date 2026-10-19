import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

const maxReportImageBytes = 5 * 1024 * 1024;
const maxSourceImageBytes = 20 * 1024 * 1024;

Uint8List encodeReportImage(Uint8List bytes) {
  try {
    return _encodeReportImage(bytes);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Please choose a valid, single-frame photo.');
  }
}

Uint8List _encodeReportImage(Uint8List bytes) {
  if (bytes.length > maxSourceImageBytes) {
    throw const FormatException(
        'Image is too large. Please choose a smaller photo.');
  }
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width * info.height > 25000000 ||
      info.numFrames > 1) {
    throw const FormatException('Please choose a valid, single-frame photo.');
  }
  final decoded = decoder!.decodeFrame(0);
  if (decoded == null) throw const FormatException('Invalid image.');
  final resized = decoded.width > 1280 || decoded.height > 1280
      ? img.copyResize(decoded,
          width: decoded.width >= decoded.height ? 1280 : null,
          height: decoded.height > decoded.width ? 1280 : null)
      : decoded;
  final encoded = img.encodeWebP(resized);
  if (encoded.length > maxReportImageBytes) {
    throw const FormatException('Compressed image exceeds the upload limit.');
  }
  return encoded;
}

/// Delete only actual files under the app cache, never gallery originals or
/// symlinks that escape the cache. Missing files are already cleaned up.
Future<void> deleteCachedImages(Iterable<String> paths, Directory cache) async {
  if (!await cache.exists()) return;
  final root = await cache.resolveSymbolicLinks();
  for (final path in paths.toSet()) {
    final file = File(path);
    if (!await file.exists()) continue;
    final resolved = await file.resolveSymbolicLinks();
    if (p.isWithin(root, resolved)) await file.delete();
  }
}
