import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:calamansi_care/data/community_feed_controller.dart';
import 'support/fake_community_repository.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

class DeferredPageRepository extends FakeCommunityRepository {
  final nextPage = Completer<List<Map<String, dynamic>>>();
  @override
  Future<List<Map<String, dynamic>>> postPage(
          {required bool own, Map<String, dynamic>? before}) =>
      before == null ? super.postPage(own: own) : nextPage.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Refresh discards an older page that finishes late', () async {
    final repo = DeferredPageRepository();
    addTearDown(repo.close);
    final row = repo.rows.first;
    repo.rows = List.generate(20, (i) => {...row, 'id': 'post-$i'});
    final feed = CommunityFeedController(repo);
    addTearDown(feed.dispose);
    await flush();
    final pending = feed.loadMore();
    repo.rows = [
      {...row, 'id': 'fresh', 'body': 'Fresh after refresh'}
    ];
    await feed.refresh();
    repo.nextPage.complete([
      {...row, 'id': 'stale'}
    ]);
    await pending;
    expect(feed.rows.single['id'], 'fresh');
    expect(feed.hasMore, isFalse);
  });
  FakeCommunityRepository fixture(int count) {
    final repo = FakeCommunityRepository();
    final row = repo.rows.first;
    repo.rows = List.generate(
        count,
        (i) => {
              ...row,
              'id': 'post-${i.toString().padLeft(3, '0')}',
              'body': 'Post $i',
            });
    return repo;
  }

  test('A live count update does not invalidate the feed list', () async {
    final repo = fixture(20);
    addTearDown(repo.close);
    final feed = CommunityFeedController(repo);
    addTearDown(feed.dispose);
    await flush();
    var listUpdates = 0;
    var changedCardUpdates = 0;
    var otherCardUpdates = 0;
    feed.post('post-000').addListener(() => changedCardUpdates++);
    feed.post('post-001').addListener(() => otherCardUpdates++);
    feed.addListener(() => listUpdates++);
    repo.rows = [
      {...repo.rows.first, 'like_count': 25},
      ...repo.rows.skip(1)
    ];
    repo.changes.add(repo.rows);
    await flush();
    expect(listUpdates, 0);
    expect(changedCardUpdates, 1);
    expect(otherCardUpdates, 0);
    expect(
        feed.rows.firstWhere((r) => r['id'] == 'post-000')['like_count'], 25);
  });

  test('Likes notify only the affected card and never the feed list', () async {
    final repo = fixture(20);
    addTearDown(repo.close);
    final feed = CommunityFeedController(repo);
    addTearDown(feed.dispose);
    await flush();
    var listUpdates = 0, changed = 0, other = 0;
    feed.addListener(() => listUpdates++);
    feed.liked('post-000').addListener(() => changed++);
    feed.liked('post-001').addListener(() => other++);
    repo.likeChanges.add([
      {'post_id': 'post-000', 'user_id': 'user-1'}
    ]);
    await flush();
    expect(feed.liked('post-000').value, isTrue);
    expect(changed, 1);
    expect(other, 0);
    expect(listUpdates, 0);
  });

  test('Live edits still update active search membership', () async {
    final repo = fixture(2);
    addTearDown(repo.close);
    final feed = CommunityFeedController(repo);
    addTearDown(feed.dispose);
    await flush();
    feed.setSearch('harvest');
    expect(feed.rows, isEmpty);
    repo.rows = [
      {...repo.rows.first, 'body': 'Harvest today'},
      ...repo.rows.skip(1)
    ];
    repo.changes.add(repo.rows);
    await flush();
    expect(feed.rows.single['body'], 'Harvest today');
    feed.setSearch('');
    expect(feed.rows.length, 2);
  });

  test('A queued post deleted before display is not resurrected', () async {
    final repo = fixture(2);
    addTearDown(repo.close);
    final feed = CommunityFeedController(repo);
    addTearDown(feed.dispose);
    await flush();
    final original = List<Map<String, dynamic>>.of(repo.rows);
    repo.rows = [
      {...original.first, 'id': 'new', 'created_at': '2026-10-27T00:00:00Z'},
      ...original
    ];
    repo.changes.add(repo.rows);
    await flush();
    expect(feed.newPostCount, 1);
    repo.rows = original;
    repo.changes.add(repo.rows);
    await flush();
    feed.showNewPosts();
    expect(feed.newPostCount, 0);
    expect(feed.rows.any((row) => row['id'] == 'new'), isFalse);
  });

  test('Incoming posts do not shift the current reading position', () async {
    final repo = fixture(20);
    addTearDown(repo.close);
    final feed = CommunityFeedController(repo);
    addTearDown(feed.dispose);
    await flush();
    final order = feed.rows.map((r) => r['id']).toList();
    var listUpdates = 0;
    feed.addListener(() => listUpdates++);
    repo.rows = [
      {...repo.rows.first, 'id': 'new', 'created_at': '2026-10-24T00:00:00Z'},
      ...repo.rows
    ];
    repo.changes.add(repo.rows);
    await flush();
    expect(feed.rows.map((r) => r['id']), order);
    expect(feed.newPostCount, 1);
    expect(listUpdates, 0);
    feed.showNewPosts();
    expect(feed.rows.first['id'], 'new');
    expect(feed.rows.skip(1).map((r) => r['id']), order);
    expect(feed.newPostCount, 0);
  });

  test(
      'Fetches 20 at a time, keeps order, and reaches the end without duplicate IDs',
      () async {
    final repo = fixture(45);
    addTearDown(repo.close);
    final feed = CommunityFeedController(repo);
    addTearDown(feed.dispose);
    await flush();
    expect(feed.rows.length, 20);
    expect(repo.pageCalls, 0);
    final first = feed.rows.map((r) => r['id']).toList();
    await Future.wait([feed.loadMore(), feed.loadMore()]);
    expect(repo.pageCalls, 1);
    expect(feed.rows.length, 40);
    expect(feed.rows.take(20).map((r) => r['id']), first);
    await feed.loadMore();
    expect(feed.rows.length, 45);
    expect(feed.rows.map((r) => r['id']).toSet().length, 45);
    expect(feed.hasMore, isFalse);
    await feed.loadMore();
    expect(repo.pageCalls, 2);
  });
  test(
      'New realtime posts do not move the cursor and older loaded rows stay live',
      () async {
    final repo = fixture(40);
    addTearDown(repo.close);
    final feed = CommunityFeedController(repo);
    addTearDown(feed.dispose);
    await flush();
    final first = feed.rows.map((r) => r['id']).toSet();
    repo.rows = [
      {...repo.rows.first, 'id': 'new', 'created_at': '2026-10-24T00:00:00Z'},
      ...repo.rows
    ];
    repo.changes.add(repo.rows);
    await flush();
    feed.showNewPosts();
    await feed.loadMore();
    expect(feed.rows.map((r) => r['id']).toSet().length, 41);
    expect(feed.rows.map((r) => r['id']).toSet(), containsAll(first));
    repo.rows = repo.rows.where((r) => r['id'] != 'post-001').toList();
    repo.changes.add(repo.rows);
    await flush();
    expect(feed.rows.any((r) => r['id'] == 'post-001'), isFalse);
  });
  test('A failed page retains visible posts and can be retried', () async {
    final repo = fixture(25);
    addTearDown(repo.close);
    final feed = CommunityFeedController(repo);
    addTearDown(feed.dispose);
    await flush();
    repo.pageError = Exception('offline');
    await feed.loadMore();
    expect(feed.rows.length, 20);
    expect(feed.pageError, isNotNull);
    expect(feed.hasMore, isTrue);
    repo.pageError = null;
    await feed.loadMore();
    expect(feed.rows.length, 25);
    expect(feed.pageError, isNull);
    await feed.refresh();
    expect(feed.rows.length, 20);
    expect(repo.postSubscriptions, 2);
  });
  test('My Posts stays newest first and excludes other authors', () async {
    final repo = fixture(25);
    repo.rows.add({...repo.rows.first, 'id': 'foreign', 'user_id': 'user-2'});
    addTearDown(repo.close);
    final feed = CommunityFeedController(repo, own: true);
    addTearDown(feed.dispose);
    await flush();
    await feed.loadMore();
    expect(feed.rows.length, 25);
    expect(feed.rows.first['id'], 'post-024');
    expect(feed.rows.last['id'], 'post-000');
    expect(feed.rows.any((r) => r['id'] == 'foreign'), isFalse);
  });
}
