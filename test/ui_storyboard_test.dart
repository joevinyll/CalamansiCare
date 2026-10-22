import 'dart:io';
import 'dart:ui' as ui;

import 'package:calamansi_care/main.dart';
import 'package:calamansi_care/data/community_repository.dart';
import 'package:calamansi_care/disease_classifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'support/fake_community_repository.dart';

// Optional visual export; normal test runs do not write storyboard artifacts.
void main() {
  const output = String.fromEnvironment('STORYBOARD_OUTPUT');
  testWidgets('Render real screens for the UI storyboard', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/camera'),
            (call) async => call.method == 'availableCameras' ? [] : null);
    await tester.runAsync(() async {
      for (final entry in {
        'FlaticonProfile': 'FlaticonProfile.ttf',
        'LibreBaskerville': 'LibreBaskerville.ttf',
      }.entries) {
        final loader = FontLoader(entry.key)
          ..addFont(Future.value(ByteData.sublistView(
              await File('assets/fonts/${entry.value}').readAsBytes())));
        await loader.load();
      }
      final flutter = Platform.environment['FLUTTER_ROOT'] ?? 'D:/flutter';
      for (final name in ['regular', 'medium', 'bold', 'black']) {
        final file = File(
            '$flutter/bin/cache/artifacts/material_fonts/roboto-$name.ttf');
        final loader = FontLoader('Roboto')
          ..addFont(
              Future.value(ByteData.sublistView(await file.readAsBytes())));
        await loader.load();
      }
      for (final entry in {
        'MaterialIcons': 'materialicons-regular.otf',
        'Ahem': 'roboto-regular.ttf',
        'FlutterTest': 'roboto-regular.ttf',
        'Segoe UI': 'roboto-regular.ttf',
        'Arial': 'roboto-regular.ttf',
        'sans-serif': 'roboto-regular.ttf',
      }.entries) {
        final loader = FontLoader(entry.key)
          ..addFont(Future.value(ByteData.sublistView(await File(
                  '$flutter/bin/cache/artifacts/material_fonts/${entry.value}')
              .readAsBytes())));
        await loader.load();
      }
    });
    await tester.pumpWidget(const CalamansiCareApp(
        enableInitialStatsRefresh: false,
        enableSettingsPersistence: false,
        enableConnectivityMonitor: false));
    await tester.pumpAndSettle();
    final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
    final state = AppState(persistSettings: false)
      ..farmerName = 'Maria Santos'
      ..farmerLocation = 'Davao City'
      ..accountEmail = 'maria@example.com'
      ..officeEmail = 'agriculture@example.org'
      ..consentEnabled = true;
    addTearDown(state.dispose);
    const key = ValueKey('storyboard-frame');
    Future<void> show(Widget screen) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(AppScope(
          state: state,
          child: MaterialApp(
              navigatorKey: navigator,
              theme: theme,
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(state.fontScale)),
                  child: RepaintBoundary(key: key, child: child!)),
              home: screen is HomeScreen ? screen : const SizedBox())));
      await tester.pumpAndSettle();
      if (screen is! HomeScreen) {
        navigator.currentState!
            .push<void>(MaterialPageRoute(builder: (_) => screen));
      }
      await tester.pumpAndSettle();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(output).create(recursive: true);
        await File('$output/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final photo = File('assets/app_icon.png').absolute.path;
    final results = List<BatchScanResult>.generate(
        10,
        (i) => (
              file: XFile(photo),
              prediction: DiseasePrediction(
                  label: i == 0
                      ? 'Healthy Fruit'
                      : i < 4
                          ? 'Citrus Scab'
                          : 'Melanose',
                  confidence: .96 - i * .005),
              id: i + 1,
              error: null,
            ));
    final batch = ScanHistoryBatch(List.generate(
        10,
        (i) => <String, Object?>{
              'id': i + 24,
              'batch_id': 'storyboard',
              'batch_total_count': 10,
              'batch_image_index': i,
              'disease': results[i].prediction!.label,
              'confidence': results[i].prediction!.confidence,
              'image_path': photo,
              'created_at': '2026-10-22T01:41:00Z',
            }));
    await show(const HomeScreen());
    await capture('01-home');
    await show(const CaptureScreen());
    await capture('02-camera');
    await show(BatchResultsScreen(results: results));
    await capture('03-results');
    await tester.scrollUntilVisible(find.text('Recommendations'), 240,
        scrollable: find.byType(Scrollable).first);
    await capture('04-care');
    await show(BatchHistoryDetailsScreen(batch: batch));
    await capture('05-batch');
    await show(BatchReportSummaryScreen(batch: batch));
    await capture('06-report');
    state.tabIndex = 2;
    await show(const SettingsScreen());
    await capture('07-settings');
    await show(const EditProfileScreen());
    await capture('08-profile');
    state.fontScale = 1.3;
    state.farmerLocation =
        'Ramon Magsaysay Avenue, Magsaysay Park, Poblacion District, Davao City, Davao del Sur, Davao Region';
    await show(const SettingsScreen());
    await tester.scrollUntilVisible(find.text('Farm location'), 80,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Farm location'));
    await capture('09-large-text');
    state.accountEmail = '';
    state.authConfigured = true;
    state.fontScale = 1;
    await show(const AuthLandingScreen());
    await capture('10-account');
    final community = FakeCommunityRepository();
    addTearDown(community.close);
    state.tabIndex = 3;
    state.accountEmail = 'maria@example.com';
    await show(CommunityFeedScreen(repository: community));
    await capture('11-community');
    await tester.tap(find.byTooltip('Post options').first);
    await tester.pumpAndSettle();
    await capture('21-post-options');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View profile').first);
    await tester.pumpAndSettle();
    await capture('18-community-profile');
    await tester.tap(find.byTooltip('Close profile'));
    await tester.pumpAndSettle();
    await show(CreateCommunityPostScreen(repo: community));
    await capture('12-create-post');
    await tester.tap(find.byType(DropdownButton<CommunityAudience>));
    await tester.pumpAndSettle();
    await capture('20-visibility-menu');
    await tester.tap(find.text('Only Me').last);
    await tester.pumpAndSettle();
    await show(
        CommunityCommentsScreen(repo: community, post: community.rows.first));
    await capture('13-comments');
    await show(CommunityFeedScreen(repository: community, myPosts: true));
    await capture('14-my-posts');
    await show(
        EditCommunityPostScreen(repo: community, post: community.rows.first));
    await capture('15-edit-post');
    community.notificationRows = [
      {
        'id': 'sample-notification',
        'actor_name': 'Jose Reyes',
        'kind': 'comment',
        'post_id': 'post-1',
        'read_at': null,
        'created_at': '2026-10-23T01:00:00Z',
      }
    ];
    await show(CommunityActivityScreen(repo: community));
    await capture('16-community-activity');
    await tester.runAsync(() async {
      final provider = ResizeImage(FileImage(File(photo)), width: 900);
      await provider.evict();
      await precacheImage(
          provider, tester.element(find.byType(CommunityActivityScreen)));
    });
    await show(Scaffold(
        appBar: AppBar(title: const Text('Post images')),
        body: Padding(
            padding: const EdgeInsets.all(16),
            child: CommunityImageGallery(paths: List.filled(5, photo)))));
    await capture('17-community-gallery');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }, skip: output.isEmpty);
}
