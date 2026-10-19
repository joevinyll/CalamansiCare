import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:calamansi_care/data/image_security.dart';

void main() {
  test('accepts a valid image and transcodes it to WebP', () {
    final png =
        Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 3)));
    final webp = encodeReportImage(png);
    expect(img.findDecoderForData(webp), isNotNull);
    expect(img.decodeImage(webp)!.width, 4);
    expect(webp.length, lessThanOrEqualTo(maxReportImageBytes));
  });

  test('rejects non-image, oversized, and decompression-heavy input', () {
    expect(() => encodeReportImage(Uint8List.fromList([1, 2, 3])),
        throwsFormatException);
    expect(() => encodeReportImage(Uint8List(maxSourceImageBytes + 1)),
        throwsFormatException);
    final huge =
        Uint8List.fromList(img.encodePng(img.Image(width: 6000, height: 5000)));
    expect(() => encodeReportImage(huge), throwsFormatException);
  });

  test('deletes cached images without touching files outside the cache',
      () async {
    final root = await Directory.systemTemp.createTemp('calamansi-cache-');
    final outside =
        await File('${root.parent.path}/calamansi-outside-$pid.webp')
            .writeAsString('gallery original');
    final inside =
        await File('${root.path}/report.webp').writeAsString('cached copy');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
      if (await outside.exists()) await outside.delete();
    });

    await deleteCachedImages([inside.path, outside.path], root);
    expect(await inside.exists(), isFalse);
    expect(await outside.exists(), isTrue);
  });
}
