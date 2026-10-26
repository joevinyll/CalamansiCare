import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:calamansi_care/data/diagnosis_repository.dart';
import 'package:calamansi_care/data/image_security.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

// Already-completed reads isolate CPU work from filesystem scheduling in this test.
class _ReportFile extends Fake implements File {
  _ReportFile(this.bytes);
  final Uint8List bytes;
  @override
  Future<int> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
}

void main() {
  test('Report upload compression lets the UI event loop keep running',
      () async {
    final png =
        Uint8List.fromList(img.encodePng(img.Image(width: 64, height: 48)));
    var uiEventRan = false;
    final heartbeat = Timer(Duration.zero, () => uiEventRan = true);
    addTearDown(heartbeat.cancel);
    final output = await DiagnosisRepository.instance
        .compressReportImage(_ReportFile(png));
    expect(uiEventRan, isTrue,
        reason: 'Compression must yield to the UI isolate');
    expect(output, orderedEquals(encodeReportImage(png)));
  });

  test('Report compression retains invalid-image and size validation',
      () async {
    await expectLater(
        DiagnosisRepository.instance
            .compressReportImage(_ReportFile(Uint8List.fromList([1, 2, 3]))),
        throwsFormatException);
    await expectLater(
        DiagnosisRepository.instance.compressReportImage(
            _ReportFile(Uint8List(maxSourceImageBytes + 1))),
        throwsFormatException);
  });
}
