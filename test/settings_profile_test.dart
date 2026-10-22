import 'dart:io';
import 'package:calamansi_care/main.dart';
import 'package:calamansi_care/data/diagnosis_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Future<void> showSettings(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(AnimatedBuilder(
      animation: state,
      builder: (_, __) => AppScope(
          state: state, child: const MaterialApp(home: SettingsScreen()))));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Avatar rejects files larger than 5 MB', () async {
    final root = await Directory.systemTemp.createTemp('avatar-limit-');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/oversized.jpg');
    final handle = await file.open(mode: FileMode.write);
    await handle.truncate(maxAvatarBytes + 1);
    await handle.close();
    await expectLater(DiagnosisRepository.instance.cacheProfileAvatar(file.path),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('5 MB'))));
  });
  testWidgets('Confirmed sign out resets navigation to language welcome', (tester) async {
    final state = AppState(persistSettings: false)
      ..accountEmail = 'farmer@example.com'
      ..farmerName = 'Maria'
      ..tabIndex = 2
      ..termsAccepted = true;
    addTearDown(state.dispose);
    await showSettings(tester, state);
    await tester.scrollUntilVisible(find.text('Sign out'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(LanguageChoice), findsWidgets);
    expect(state.isSignedIn, isFalse);
    expect(state.termsAccepted, isFalse);
    expect(state.tabIndex, 0);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
    expect(find.text('Could not finish signing out. Please try again.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test('Account profile retains private avatar object reference', () {
    final profile = FarmerProfile.fromMap({
      'farmer_name': 'Maria',
      'avatar_object_path': 'user-id/avatar-photo.webp',
    });
    expect(profile.avatarObjectPath, 'user-id/avatar-photo.webp');
    expect(FarmerProfile.fromMap({}).avatarObjectPath, isNull);
  });
  testWidgets('Profile card stays fixed while settings text scales',
      (tester) async {
    final state = AppState(persistSettings: false)
      ..farmerName = 'Joevinyll Jan Palabrica';
    addTearDown(state.dispose);
    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      Future<void> render(double scale) async {
        await tester.pumpWidget(AppScope(
            state: state,
            child: MaterialApp(
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: const SettingsScreen())));
        await tester.pumpAndSettle();
      }

      await render(1);
      final size =
          tester.getSize(find.byKey(const ValueKey('settings-profile-card')));
      await render(1.3);
      expect(
          tester.getSize(find.byKey(const ValueKey('settings-profile-card'))),
          size);
      expect(
          MediaQuery.textScalerOf(tester.element(find.text(state.farmerName)))
              .scale(19),
          19);
      expect(
          MediaQuery.textScalerOf(tester.element(find.text('Farm location')))
              .scale(14),
          closeTo(18.2, .01));
      expect(tester.takeException(), isNull);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets('Large font stacks contact details and account email is locked',
      (tester) async {
    final state = AppState(persistSettings: false)
      ..fontScale = 1.3
      ..farmerLocation = 'Davao City'
      ..officeEmail = 'agriculture@example.org'
      ..accountEmail = 'maria@example.com';
    addTearDown(state.dispose);
    await showSettings(tester, state);
    for (final pair in [
      ['Farm location', 'Davao City'],
      ['Barangay email', 'agriculture@example.org'],
      ['My email', 'maria@example.com'],
    ]) {
      await tester.scrollUntilVisible(find.text(pair[1]), 100,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text(pair[1])).dy,
          greaterThan(tester.getTopLeft(find.text(pair[0])).dy));
    }
    final row = find
        .ancestor(of: find.text('My email'), matching: find.byType(InkWell))
        .first;
    expect(tester.widget<InkWell>(row).onTap, isNull);
    expect(tester.takeException(), isNull);
  });
  test('Profile avatar path round-trips through local settings', () {
    final settings = AppSettings.fromMap(
        {'farmer_name': 'Maria', 'avatar_path': 'profile/photo.webp'});
    expect(
        AppSettings.fromMap(settings.toMap()).avatarPath, 'profile/photo.webp');
  });

  testWidgets('Profile saves edits and Back discards draft changes',
      (tester) async {
    final state = AppState(persistSettings: false)
      ..farmerName = 'Maria Santos'
      ..farmerLocation = 'Davao City';
    addTearDown(state.dispose);
    await showSettings(tester, state);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('profile-name')), 'Maria Reyes');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(state.farmerName, 'Maria Reyes');
    expect(find.text('Maria Reyes'), findsOneWidget);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('profile-name')), 'Unsaved name');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(state.farmerName, 'Maria Reyes');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Photo source actions and cancellation keep the saved avatar',
      (tester) async {
    final state = AppState(persistSettings: false)
      ..farmerName = 'Maria'
      ..farmerLocation = 'Davao City'
      ..avatarPath = 'missing-avatar.webp';
    addTearDown(state.dispose);
    await showSettings(tester, state);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change photo'));
    await tester.pumpAndSettle();
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();
    expect(state.avatarPath, 'missing-avatar.webp');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(state.avatarPath, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sign out is last and cancelling keeps the session',
      (tester) async {
    final state = AppState(persistSettings: false)
      ..farmerName = 'Maria'
      ..farmerLocation = 'Davao City'
      ..accountEmail = 'maria@example.com';
    addTearDown(state.dispose);
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showSettings(tester, state);
    await tester.scrollUntilVisible(find.text('Sign out'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Sign out')).dy,
        greaterThan(tester.getTopLeft(find.text('About & Terms')).dy));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Stay signed in'));
    await tester.pumpAndSettle();
    expect(state.isSignedIn, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('Avatar copies survive separately from gallery originals', () async {
    final root =
        await Directory.systemTemp.createTemp('calamansi-avatar-test-');
    addTearDown(() => root.delete(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => root.path);
    final original = await File('${root.path}/original.png')
        .writeAsBytes(img.encodePng(img.Image(width: 12, height: 12)));
    final repo = DiagnosisRepository.instance;
    final path = await repo.cacheProfileAvatar(original.path);
    expect(await File(path).exists(), isTrue);
    expect(path, contains('profile_avatars'));
    await repo.deleteProfileAvatar(path);
    expect(await File(path).exists(), isFalse);
    expect(await original.exists(), isTrue);
  });
}
