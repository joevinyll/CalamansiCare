import 'dart:async';
import 'dart:io';
import 'package:calamansi_care/data/community_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeCommunityRepository extends CommunityRepository {
  FakeCommunityRepository()
      : super(SupabaseClient('https://example.supabase.co', 'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false)));
  @override
  String get userId => 'user-1';
  @override
  Future<String?> memberSince(String memberId) async {
    if (memberSinceFails) {
      throw const FormatException('Membership lookup unavailable');
    }
    return '2026-01-02T12:00:00Z';
  }

  bool memberSinceFails = false;
  @override
  Future<String> photoUrl(String path) async =>
      throw const FormatException('Fixture photo unavailable');
  final changes = StreamController<List<Map<String, dynamic>>>.broadcast();
  List<Map<String, dynamic>> rows = [
    {
      'id': 'post-1',
      'user_id': 'user-1',
      'author_name': 'Maria Santos',
      'body': 'Our calamansi harvest this morning!',
      'image_path': null,
      'created_at': '2026-10-23T01:00:00Z',
      'like_count': 24,
      'comment_count': 2,
    }
  ];
  final replies = <Map<String, dynamic>>[
    {
      'id': 'comment-1',
      'post_id': 'post-1',
      'user_id': 'user-2',
      'author_name': 'Jose Reyes',
      'body': 'Beautiful harvest! How often do you water them?',
      'parent_id': null,
      'created_at': '2026-10-23T02:00:00Z',
      'like_count': 0,
    }
  ];
  String? published, sentComment, parent;
  List<File> publishedPhotos = [];
  CommunityAudience publishedAudience = CommunityAudience.community;
  CommunityAudience editedAudience = CommunityAudience.community;
  int toggleCalls = 0;
  int postSubscriptions = 0;
  Object? postsError;
  String? editedId, deletedId;
  bool editFails = false;
  @override
  Stream<List<Map<String, dynamic>>> myPosts() =>
      posts().map((rows) => rows.where((p) => p['user_id'] == userId).toList());
  @override
  Future<void> editPost(String id, String text,
      {CommunityAudience audience = CommunityAudience.community}) async {
    if (editFails) throw const FormatException('Could not save this post.');
    editedId = id;
    editedAudience = audience;
    rows = rows
        .map((p) => p['id'] == id
            ? {...p, 'body': text.trim(), 'visibility': audience.value}
            : p)
        .toList();
    changes.add(rows);
  }

  @override
  Future<void> deletePost(String id) async {
    deletedId = id;
    rows = rows.where((p) => p['id'] != id).toList();
    changes.add(rows);
  }

  @override
  Stream<List<Map<String, dynamic>>> posts() async* {
    postSubscriptions++;
    if (postsError != null) throw postsError!;
    yield rows;
    yield* changes.stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> comments(String? postId) =>
      Stream.value(replies);
  @override
  Stream<List<Map<String, dynamic>>> likes() => Stream.value([]);
  @override
  Future<void> publish(String text, String name, List<File> photos,
      {CommunityAudience audience = CommunityAudience.community}) async {
    published = text;
    publishedPhotos = List.of(photos);
    publishedAudience = audience;
  }

  @override
  Future<void> comment(
      String postId, String text, String name, String? parentId) async {
    sentComment = text;
    parent = parentId;
  }

  @override
  Future<void> toggleLike(String id, bool liked, {bool comment = false}) async {
    toggleCalls++;
  }

  Future<void> close() async {
    unawaited(changes.close());
    unawaited(client.dispose());
  }
}
