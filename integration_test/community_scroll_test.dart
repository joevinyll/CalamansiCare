import 'dart:io';
import 'dart:ui' as ui;

import 'package:calamansi_care/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/fake_community_repository.dart';

class _PhotoRepository extends FakeCommunityRepository {
  _PhotoRepository(this.port);
  final int port;
  @override
  Future<String> photoUrl(String path) async => 'http://127.0.0.1:$port/$path';
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Community scrolling with paged photo posts', (tester) async {
    // Synthetic media exercises real decoding without touching user data or Supabase.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var y = 0; y < 1200; y += 40) {
      for (var x = 0; x < 1600; x += 40) {
        canvas.drawRect(
            Rect.fromLTWH(x.toDouble(), y.toDouble(), 40, 40),
            Paint()
              ..color = Color.fromARGB(255, x % 256, y % 256, (x + y) % 256));
      }
    }
    final picture = recorder.endRecording();
    final photo = await picture.toImage(1600, 1200);
    final bytes = (await photo.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    photo.dispose();
    picture.dispose();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var photoRequests = 0;
    final requests = server.listen((request) {
      photoRequests++;
      request.response.headers.contentType = ContentType('image', 'png');
      request.response.add(bytes);
      request.response.close();
    });
    final repo = _PhotoRepository(server.port);
    final source = repo.rows.first;
    repo.rows = List.generate(
        200,
        (i) => {
              ...source,
              'id': 'post-${i.toString().padLeft(4, '0')}',
              'body': 'Field update $i',
              'image_path': 'photo-$i.png',
            });
    final state = AppState(persistSettings: false)..farmerName = 'Test farmer';
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      state.dispose();
      await repo.close();
      await requests.cancel();
      await server.close(force: true);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(home: CommunityFeedScreen(repository: repo))));
    await tester.pumpAndSettle();
    final cache = PaintingBinding.instance.imageCache;
    final initialCacheBytes = cache.currentSizeBytes;
    await binding.watchPerformance(() async {
      for (var i = 0; i < 25; i++) {
        await tester.fling(
            find.byType(ListView).last, const Offset(0, -900), 2000);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'photo_feed_scroll');
    binding.reportData!['feed_workload'] = {
      'fixture_posts': 200,
      'additional_pages': repo.pageCalls,
      'photo_requests': photoRequests,
      'initial_image_cache_bytes': initialCacheBytes,
      'final_image_cache_bytes': cache.currentSizeBytes,
      'image_cache_limit_bytes': cache.maximumSizeBytes,
      'live_image_count': cache.liveImageCount,
    };
    expect(repo.pageCalls, greaterThan(0));
    expect(photoRequests, greaterThan(0));
    expect(cache.currentSizeBytes, lessThanOrEqualTo(32 * 1024 * 1024));
    expect(tester.takeException(), isNull);
  });
}
