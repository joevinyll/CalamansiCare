import 'dart:async';
import 'dart:io';

import 'package:calamansi_care/main.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Camera extends CameraPlatform {
  final flashCalls = <FlashMode>[];
  int camerasCreated = 0;
  int picturesTaken = 0;
  bool stallFlash = false;

  @override
  Future<List<CameraDescription>> availableCameras() async => [
        const CameraDescription(
            name: 'back',
            lensDirection: CameraLensDirection.back,
            sensorOrientation: 90)
      ];
  @override
  Future<int> createCamera(
          CameraDescription description, ResolutionPreset? preset,
          {bool enableAudio = false}) async =>
      ++camerasCreated;
  @override
  Future<void> initializeCamera(int cameraId,
      {ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown}) async {}
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(CameraInitializedEvent(
          cameraId, 1280, 720, ExposureMode.auto, true, FocusMode.auto, true));
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) =>
      Stream<CameraErrorEvent>.multi((_) {});
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) {
    flashCalls.add(mode);
    return stallFlash && mode != FlashMode.off
        ? Completer<void>().future
        : Future.value();
  }

  @override
  Future<XFile> takePicture(int cameraId) async {
    picturesTaken++;
    return XFile(File('assets/app_icon.png').absolute.path);
  }

  @override
  Widget buildPreview(int cameraId) => const ColoredBox(color: Colors.black);
  @override
  Future<void> dispose(int cameraId) async {}
}

void main() {
  for (final stall in [false, true]) {
    testWidgets(
        stall
            ? 'Stalled flash recovers camera'
            : 'Rapid flash selection only applies hardware mode on capture',
        (tester) async {
      final original = CameraPlatform.instance;
      final camera = _Camera()..stallFlash = stall;
      CameraPlatform.instance = camera;
      final state = AppState(persistSettings: false);
      addTearDown(() {
        CameraPlatform.instance = original;
        state.dispose();
      });
      await tester.pumpWidget(MaterialApp(
          home: AppScope(state: state, child: const CaptureScreen())));
      await tester.pumpAndSettle();
      for (var i = 0; i < 31; i++) {
        await tester.tap(find.byWidgetPredicate(
            (w) => w is IconButton && (w.tooltip ?? '').startsWith('Flash ')));
        await tester.pump();
      }
      expect(find.byTooltip('Flash on'), findsOneWidget);
      expect(camera.flashCalls, [FlashMode.off]);
      await tester.tap(find.byTooltip('Capture image'));
      await tester.pump();
      if (stall) await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      if (stall) {
        expect(camera.camerasCreated, 2);
        expect(find.byTooltip('Flash off'), findsOneWidget);
        expect(camera.picturesTaken, 0);
      } else {
        expect(camera.flashCalls, [FlashMode.off, FlashMode.always]);
        expect(camera.picturesTaken, 1);
        expect(find.text('1 / 10'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
