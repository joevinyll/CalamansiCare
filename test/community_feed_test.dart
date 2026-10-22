import 'dart:io';
import 'package:calamansi_care/main.dart';
import 'package:calamansi_care/data/community_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_community_repository.dart';

void disposeCommunityScreen(WidgetTester tester, AppState state) {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}

void main() {
  testWidgets(
      'Visibility menu fits narrow screens with enlarged text and clear selection',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeCommunityRepository();
    addTearDown(repo.close);
    final state = AppState(persistSettings: false)..farmerName = 'Maria Santos';
    disposeCommunityScreen(tester, state);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!),
            home: CreateCommunityPostScreen(repo: repo))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<CommunityAudience>));
    await tester.pumpAndSettle();
    expect(find.text('Signed-in members'), findsOneWidget);
    expect(find.text('Private to you'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Only Me').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Only Me').last);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DropdownButton<CommunityAudience>>(
                find.byType(DropdownButton<CommunityAudience>))
            .value,
        CommunityAudience.onlyMe);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Keyboard animation does not recreate visible post galleries each frame',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final repo = FakeCommunityRepository();
    addTearDown(repo.close);
    repo.rows = [
      {...repo.rows.first, 'image_path': 'fixture.webp'}
    ];
    final state = AppState(persistSettings: false)..farmerName = 'Maria Santos';
    disposeCommunityScreen(tester, state);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(home: CommunityFeedScreen(repository: repo))));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 20);
    await tester.pumpAndSettle();
    final gallery = tester
        .widget<CommunityImageGallery>(find.byType(CommunityImageGallery));
    for (var inset = 30; inset <= 300; inset += 15) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset.toDouble());
      await tester.pump(const Duration(milliseconds: 16));
      expect(
          identical(
              tester.widget<CommunityImageGallery>(
                  find.byType(CommunityImageGallery)),
              gallery),
          isTrue);
    }
    expect(repo.postSubscriptions, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Profile keeps working when membership date is unavailable',
      (tester) async {
    final repo = FakeCommunityRepository()..memberSinceFails = true;
    addTearDown(repo.close);
    final state = AppState(persistSettings: false)..farmerName = 'Maria Santos';
    disposeCommunityScreen(tester, state);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(home: CommunityFeedScreen(repository: repo))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View profile').first);
    await tester.pumpAndSettle();
    expect(find.text('Membership date unavailable'), findsOneWidget);
    expect(find.textContaining('Jan 2021'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close profile'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
  testWidgets('Database setup error is actionable and retry can recover',
      (tester) async {
    final repo = FakeCommunityRepository()
      ..postsError = const PostgrestException(
          message: 'column community_posts.visibility does not exist',
          code: '42703');
    addTearDown(repo.close);
    final state = AppState(persistSettings: false)..farmerName = 'Maria Santos';
    disposeCommunityScreen(tester, state);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(home: CommunityFeedScreen(repository: repo))));
    await tester.pumpAndSettle();
    expect(find.textContaining('visibility migration'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
    repo.postsError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Our calamansi harvest this morning!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Search keyboard leaves posts scrollable without navigation dead space',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final repo = FakeCommunityRepository();
    addTearDown(repo.close);
    repo.rows = [
      {...repo.rows.first, 'image_path': 'fixture.webp'}
    ];
    final state = AppState(persistSettings: false)..farmerName = 'Maria Santos';
    disposeCommunityScreen(tester, state);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(home: CommunityFeedScreen(repository: repo))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search posts'));
    expect(tester.getTopLeft(find.text('Community').first).dx, closeTo(24, 1));
    expect(
        tester
            .getRect(find.byWidgetPredicate((widget) =>
                widget is IconButton && widget.tooltip == 'My posts'))
            .right,
        closeTo(390 - 24, 1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'harvest');
    await tester.pumpAndSettle();
    final searchIcon = find.descendant(
        of: find.byType(TextField), matching: find.byIcon(Icons.search));
    expect(tester.getCenter(searchIcon).dy,
        closeTo(tester.getCenter(find.byType(EditableText)).dy, 2));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomNav), findsNothing);
    expect(find.text('Share an update...'), findsNothing);
    final list = find.byType(ListView).last;
    expect(tester.getRect(list).bottom, closeTo(844 - 300 - 16, 1));
    await tester.drag(list, const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse);
    await tester.ensureVisible(find.text('Comment'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Comment')).bottom, lessThan(544));
    expect(find.text('harvest'), findsOneWidget);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(find.text('Share an update...'), findsOneWidget);
    await tester.tap(find.byTooltip('My posts'));
    await tester.pumpAndSettle();
    expect(
        tester
            .getRect(find.byWidgetPredicate((widget) =>
                widget is IconButton && widget.tooltip == 'Search posts'))
            .right,
        closeTo(390 - 24, 1));
    expect(
        tester
            .getRect(find.byWidgetPredicate((widget) =>
                widget is IconButton && widget.tooltip == 'Back to Community'))
            .left,
        closeTo(24, 1));
    expect(tester.getCenter(find.byTooltip('Back to Community')).dx,
        lessThan(tester.getCenter(find.text('My posts')).dx));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Community avatars open the correct privacy-safe profile overlay',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeCommunityRepository();
    addTearDown(repo.close);
    final state = AppState(persistSettings: false)
      ..farmerName = 'Maria Santos'
      ..accountEmail = 'private@example.com'
      ..farmerLocation = 'Private farm address';
    disposeCommunityScreen(tester, state);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(home: CommunityFeedScreen(repository: repo))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View profile').first);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Community Member'), findsOneWidget);
    final profileDialog = tester.widget<Dialog>(find.byType(Dialog));
    expect((profileDialog.shape! as RoundedRectangleBorder).side.style,
        BorderStyle.none);
    expect(tester.widget<Text>(find.text('Community Member')).style?.fontFamily,
        isNull);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    expect(find.text('Member since: Jan 2026'), findsOneWidget);
    expect(find.byTooltip('Community member profile'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(Dialog), matching: find.text('Maria Santos')),
        findsOneWidget);
    expect(find.text('private@example.com'), findsNothing);
    expect(find.text('Private farm address'), findsNothing);
    await tester.tap(find.byTooltip('Close profile'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(
            key: UniqueKey(),
            home: CommunityCommentsScreen(repo: repo, post: repo.rows.first))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View profile').first);
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(Dialog), matching: find.text('Maria Santos')),
        findsOneWidget);
    await tester.tap(find.byTooltip('Close profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View profile').at(1));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(Dialog), matching: find.text('Jose Reyes')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Composer saves Only Me visibility', (tester) async {
    final repo = FakeCommunityRepository();
    addTearDown(repo.close);
    final state = AppState(persistSettings: false)..farmerName = 'Maria Santos';
    disposeCommunityScreen(tester, state);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(home: CreateCommunityPostScreen(repo: repo))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<CommunityAudience>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Only Me').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Private farm notes');
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    expect(repo.publishedAudience, CommunityAudience.onlyMe);
    expect(repo.published, 'Private farm notes');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Only Me posts stay in My posts and their visibility can be edited',
      (tester) async {
    final repo = FakeCommunityRepository();
    addTearDown(repo.close);
    repo.rows = [
      {
        ...repo.rows.first,
        'visibility': 'only_me',
        'body': 'Private farm notes'
      }
    ];
    final state = AppState(persistSettings: false)..farmerName = 'Maria Santos';
    disposeCommunityScreen(tester, state);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(home: CommunityFeedScreen(repository: repo))));
    await tester.pumpAndSettle();
    expect(find.text('Private farm notes'), findsNothing);
    await tester.tap(find.byTooltip('My posts'));
    await tester.pumpAndSettle();
    expect(find.text('Private farm notes'), findsOneWidget);
    expect(find.text('Only Me'), findsOneWidget);
    await tester.tap(find.byTooltip('Post options').last);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    await tester.tap(find.text('Edit post'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DropdownButton<CommunityAudience>>(
                find.byType(DropdownButton<CommunityAudience>))
            .value,
        CommunityAudience.onlyMe);
    await tester.tap(find.byType(DropdownButton<CommunityAudience>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Community').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.editedAudience, CommunityAudience.community);
    expect(find.text('Only Me'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test('Gallery paths preserve legacy posts and reject more than five uploads',
      () async {
    expect(communityImagePaths({'image_path': 'old.webp'}), ['old.webp']);
    expect(
        communityImagePaths({
          'image_paths': ['a.webp', 'b.webp'],
          'image_path': 'a.webp'
        }),
        ['a.webp', 'b.webp']);
    expect(communityImagePaths({}), isEmpty);
    final fake = FakeCommunityRepository();
    addTearDown(fake.close);
    await expectLater(
        CommunityRepository(fake.client)
            .publish('Post', 'Maria', List.filled(6, File('missing.jpg'))),
        throwsFormatException);
  });

  testWidgets(
      'Composer caps uploads at five and gallery supports next, previous and removal',
      (tester) async {
    final repo = FakeCommunityRepository();
    addTearDown(repo.close);
    final state = AppState(persistSettings: false)..farmerName = 'Maria Santos';
    disposeCommunityScreen(tester, state);
    var selected = 6;
    final channel =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    channel.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/image_picker'),
        (call) async => call.method == 'pickMultiImage'
            ? List.filled(selected, File('assets/app_icon.png').absolute.path)
            : null);
    addTearDown(() => channel.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/image_picker'), null));
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(home: CreateCommunityPostScreen(repo: repo))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    expect(find.text('Choose up to 5 photos per post.'), findsOneWidget);
    selected = 5;
    await tester.runAsync(() async {
      await tester.tap(find.text('Add photo'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('1 / 5'), findsOneWidget);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Add photo'))
            .onPressed,
        isNull);
    await tester.ensureVisible(find.byTooltip('Next image'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next image'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 5'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous image'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 5'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Remove image 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove image 1'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 4'), findsOneWidget);
    await tester.tap(find.text('Post').first);
    await tester.pumpAndSettle();
    expect(repo.publishedPhotos.length, 4);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Activity cards show posted time, live counts and open comments',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeCommunityRepository();
    addTearDown(repo.close);
    final state = AppState(persistSettings: false)..farmerName = 'Maria Santos';
    disposeCommunityScreen(tester, state);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!),
            home: CommunityActivityScreen(repo: repo))));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsOneWidget);
    expect(find.textContaining('Posted '), findsOneWidget);
    expect(find.textContaining('2026'), findsOneWidget);
    expect(find.text('24 likes'), findsOneWidget);
    expect(find.text('2 comments'), findsOneWidget);
    repo.rows = [
      {...repo.rows.first, 'like_count': 25}
    ];
    repo.changes.add(repo.rows);
    await tester.pumpAndSettle();
    expect(find.text('25 likes'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Our calamansi harvest this morning!'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityCommentsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Pull down reloads Community including an empty feed',
      (tester) async {
    final repo = FakeCommunityRepository();
    addTearDown(repo.close);
    final state = AppState(persistSettings: false)..farmerName = 'Maria Santos';
    disposeCommunityScreen(tester, state);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(home: CommunityFeedScreen(repository: repo))));
    await tester.pumpAndSettle();
    expect(repo.postSubscriptions, 1);
    repo.rows = [
      {...repo.rows.first, 'body': 'Refreshed post'}
    ];
    await tester.drag(find.byType(ListView).last, const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(repo.postSubscriptions, 2);
    expect(find.text('Refreshed post'), findsOneWidget);
    repo.rows = [];
    await tester.drag(find.byType(ListView).last, const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(find.text('No community posts yet.'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(repo.postSubscriptions, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Random feed order stays stable across live updates',
      (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeCommunityRepository();
    addTearDown(repo.close);
    final source = repo.rows.first;
    repo.rows = List.generate(
        3, (i) => {...source, 'id': 'post-$i', 'body': 'Sample post $i'});
    final state = AppState(persistSettings: false)..farmerName = 'Maria Santos';
    disposeCommunityScreen(tester, state);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(home: CommunityFeedScreen(repository: repo))));
    await tester.pumpAndSettle();
    List<String> order() => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.startsWith('Sample post'))
        .toList();
    final initial = order();
    expect(
        initial.toSet(), {'Sample post 0', 'Sample post 1', 'Sample post 2'});
    repo.changes.add(repo.rows.reversed.toList());
    await tester.pumpAndSettle();
    expect(order(), initial);
    expect(tester.takeException(), isNull);
  });
  testWidgets('My posts filters authors, saves edits and confirms deletion',
      (tester) async {
    final repo = FakeCommunityRepository();
    addTearDown(repo.close);
    repo.rows = [
      ...repo.rows,
      {
        ...repo.rows.first,
        'id': 'other-post',
        'user_id': 'user-2',
        'author_name': 'Jose Reyes',
        'body': 'Another farmer post',
      }
    ];
    final state = AppState(persistSettings: false)..farmerName = 'Maria Santos';
    disposeCommunityScreen(tester, state);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(home: CommunityFeedScreen(repository: repo))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('My posts'));
    await tester.pumpAndSettle();
    expect(find.text('My posts'), findsOneWidget);
    expect(find.text('Another farmer post'), findsNothing);
    await tester.tap(find.byTooltip('Post options').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit post'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Updated harvest');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.editedId, 'post-1');
    expect(find.text('Updated harvest'), findsOneWidget);
    await tester.tap(find.byTooltip('Post options').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete post'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.deletedId, isNull);
    await tester.tap(find.byTooltip('Post options').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete post'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repo.deletedId, 'post-1');
    expect(find.text('You have not shared any posts yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Failed edit keeps the draft and Community header fits a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeCommunityRepository()..editFails = true;
    addTearDown(repo.close);
    final state = AppState(persistSettings: false)..farmerName = 'Maria Santos';
    disposeCommunityScreen(tester, state);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!),
            home: CommunityFeedScreen(repository: repo))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('My posts'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Post options').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit post'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Keep my draft');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save this post.'), findsOneWidget);
    expect(find.text('Keep my draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Community uses the current Settings name and avatar on old posts',
      (tester) async {
    final repo = FakeCommunityRepository();
    addTearDown(repo.close);
    final state = AppState(persistSettings: false)
      ..farmerName = 'Updated farmer'
      ..avatarPath = File('assets/app_icon.png').absolute.path
      ..accountEmail = 'maria@example.com';
    disposeCommunityScreen(tester, state);
    await tester.pumpWidget(AnimatedBuilder(
        animation: state,
        builder: (_, __) => AppScope(
            state: state,
            child: MaterialApp(home: CommunityFeedScreen(repository: repo)))));
    await tester.pumpAndSettle();
    expect(find.text('Updated farmer'), findsOneWidget);
    expect(find.text('Maria Santos'), findsNothing);
    expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .where((image) =>
                image.image is ResizeImage &&
                (image.image as ResizeImage).imageProvider is FileImage)
            .length,
        2);
    await state.setFarmerName('New display name');
    await tester.pumpAndSettle();
    expect(find.text('New display name'), findsOneWidget);
    expect(find.text('Updated farmer'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test('Community author names have safe display defaults', () {
    expect(communityDisplayName(' '), 'Farmer');
    expect(communityDisplayName(' Maria '), 'Maria');
    expect(communityDisplayName('x' * 100).length, 80);
  });
  Future<void> mount(WidgetTester tester, Widget screen) async {
    final state = AppState(persistSettings: false)
      ..farmerName = 'Maria Santos'
      ..accountEmail = 'maria@example.com';
    disposeCommunityScreen(tester, state);
    await tester
        .pumpWidget(AppScope(state: state, child: MaterialApp(home: screen)));
    await tester.pumpAndSettle();
  }

  testWidgets('Feed receives stream updates, likes and opens composer',
      (tester) async {
    final repo = FakeCommunityRepository();
    addTearDown(repo.close);
    await mount(tester, CommunityFeedScreen(repository: repo));
    expect(find.text('Our calamansi harvest this morning!'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    await tester.tap(find.text('Like'));
    await tester.pumpAndSettle();
    expect(repo.toggleCalls, 1);
    repo.rows = [
      {
        ...repo.rows.first,
        'body': 'Fresh update from another phone',
        'like_count': 25
      }
    ];
    repo.changes.add(repo.rows);
    await tester.pumpAndSettle();
    expect(find.text('Fresh update from another phone'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    await tester.tap(find.text('Share an update...'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'New harvest');
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    expect(repo.published, 'New harvest');
    expect(tester.takeException(), isNull);
  });
  testWidgets('Comments reply to correct parent and submit', (tester) async {
    final repo = FakeCommunityRepository();
    addTearDown(repo.close);
    await mount(
        tester, CommunityCommentsScreen(repo: repo, post: repo.rows.first));
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    expect(find.text('Replying to Jose Reyes'), findsOneWidget);
    await tester.enterText(
        find.byType(TextField), 'I check the soil every morning.');
    await tester.tap(find.byTooltip('Send comment'));
    await tester.pumpAndSettle();
    expect(repo.parent, 'comment-1');
    expect(repo.sentComment, 'I check the soil every morning.');
    expect(tester.takeException(), isNull);
  });
  testWidgets('Community composer fits narrow screens and large text',
      (tester) async {
    final repo = FakeCommunityRepository();
    addTearDown(repo.close);
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(
        tester,
        MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: CreateCommunityPostScreen(repo: repo)));
    expect(find.text('Add photo'), findsOneWidget);
    expect(find.text('Maximum 5 images per post'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
