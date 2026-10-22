import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_security.dart';

String communityErrorMessage(Object? error) {
  if (error is FormatException) return error.message;
  if (error is PostgrestException) {
    if ((error.code == '42703' || error.code == 'PGRST204') &&
        error.message.contains('visibility')) {
      return 'Community needs a database update. Apply the Community visibility migration in Supabase, then tap Retry.';
    }
    if (error.code == '42703' ||
        error.code == 'PGRST204' ||
        error.code == '42P01' ||
        error.code == 'PGRST205') {
      return 'Community database setup is incomplete. Apply the pending Community migrations in Supabase, then retry.';
    }
    if (error.code == '42501') {
      return 'Community access was denied. Sign in again; if this continues, check the Community database permissions.';
    }
    if (error.code == '42P17') {
      return 'Community database policies need attention. Check the Supabase policies before retrying.';
    }
    if (error.code == 'PGRST301' || error.code == 'PGRST303') {
      return 'Your session has expired. Sign in again to use Community.';
    }
    return 'The Community service could not complete this request. Please try again.';
  }
  if (error is SocketException) {
    return 'Could not reach Community. Check your internet connection and try again.';
  }
  if (error is TimeoutException) {
    return 'Community took too long to respond. Please try again.';
  }
  return 'Could not complete the Community request. Please try again.';
}

String communityDisplayName(String name) {
  final value = name.trim();
  if (value.isEmpty) return 'Farmer';
  return value.length > 80 ? value.substring(0, 80) : value;
}

const maxCommunityPhotos = 5;

enum CommunityAudience {
  community,
  onlyMe;

  String get value => this == onlyMe ? 'only_me' : 'community';
}

List<String> communityImagePaths(Map<String, dynamic> post) {
  final paths = (post['image_paths'] as List?)?.whereType<String>().toList();
  if (paths != null && paths.isNotEmpty) return paths;
  final legacy = post['image_path'] as String?;
  return legacy == null ? [] : [legacy];
}

class CommunityRepository {
  CommunityRepository(this.client);
  final SupabaseClient client;
  String get userId => client.auth.currentUser!.id;
  Stream<List<Map<String, dynamic>>> notifications() => client
      .from('community_notifications')
      .stream(primaryKey: ['id'])
      .eq('recipient_id', userId)
      .order('created_at', ascending: false);
  Future<void> readNotification(String id) async {
    await client
        .from('community_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('recipient_id', userId)
        .isFilter('read_at', null);
  }

  Future<Map<String, dynamic>?> notificationPost(String id) =>
      client.from('community_posts').select().eq('id', id).maybeSingle();
  Future<String?> memberSince(String memberId) async {
    if (memberId == client.auth.currentUser?.id) {
      return client.auth.currentUser?.createdAt;
    }
    final value = await client.rpc('community_member_since',
        params: {'member_id': memberId}).timeout(const Duration(seconds: 15));
    return value as String?;
  }

  Stream<List<Map<String, dynamic>>> posts() => client
      .from('community_posts')
      .stream(primaryKey: ['id'])
      .eq('visibility', 'community')
      .order('created_at', ascending: false)
      .limit(50);
  Stream<List<Map<String, dynamic>>> myPosts() => client
      .from('community_posts')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false);

  Future<void> editPost(String id, String text,
      {CommunityAudience audience = CommunityAudience.community}) async {
    if (text.trim().length > 3000) {
      throw const FormatException('Keep your message within 3,000 characters.');
    }
    final post = await client
        .from('community_posts')
        .select('image_path')
        .eq('id', id)
        .eq('user_id', userId)
        .maybeSingle();
    if (post == null) {
      throw const FormatException('This post is no longer available.');
    }
    if (text.trim().isEmpty && post['image_path'] == null) {
      throw const FormatException('Add a message to your post.');
    }
    await client
        .from('community_posts')
        .update({'body': text.trim(), 'visibility': audience.value})
        .eq('id', id)
        .eq('user_id', userId)
        .select('id')
        .single();
  }

  Stream<List<Map<String, dynamic>>> comments(String? postId) {
    final stream = client.from('community_comments').stream(primaryKey: ['id']);
    return postId == null
        ? stream.order('created_at', ascending: false).limit(300)
        : stream.eq('post_id', postId).order('created_at');
  }

  Stream<List<Map<String, dynamic>>> likes() => client
      .from('community_likes')
      .stream(primaryKey: ['id']).eq('user_id', userId);
  final _urls = <String, ({String url, DateTime expires})>{};
  Future<String> avatarUrl(String path) => _signedUrl('profile-avatars', path);
  Future<String> photoUrl(String path) => _signedUrl('community-images', path);
  Future<String> _signedUrl(String bucket, String path) async {
    final key = '$bucket/$path';
    final cached = _urls[key];
    if (cached != null && cached.expires.isAfter(DateTime.now())) {
      return cached.url;
    }
    final url = await client.storage.from(bucket).createSignedUrl(path, 3600);
    _urls[key] =
        (url: url, expires: DateTime.now().add(const Duration(minutes: 50)));
    return url;
  }

  Future<void> publish(String text, String name, List<File> photos,
      {CommunityAudience audience = CommunityAudience.community}) async {
    if (photos.length > maxCommunityPhotos) {
      throw const FormatException('Choose up to 5 photos per post.');
    }
    if (text.trim().length > 3000 || (text.trim().isEmpty && photos.isEmpty)) {
      throw const FormatException(
          'Add a message or photo (up to 3,000 characters).');
    }
    final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    for (final photo in photos) {
      if (await photo.length() > maxReportImageBytes) {
        throw const FormatException('Choose a photo of 5 MB or less.');
      }
    }
    final paths = <String>[];
    try {
      for (var i = 0; i < photos.length; i++) {
        final encoded =
            await compute(encodeReportImage, await photos[i].readAsBytes());
        final path = '$userId/$id${i == 0 ? '' : '-${i + 1}'}.webp';
        paths.add(path);
        await client.storage.from('community-images').uploadBinary(
            path, encoded,
            fileOptions: const FileOptions(contentType: 'image/webp'));
      }
    } catch (_) {
      // No post exists yet; remove attempted uploads when possible.
      if (paths.isNotEmpty) {
        try {
          await client.storage.from('community-images').remove(paths);
        } catch (_) {/* Orphan cleanup can be retried by the operator. */}
      }
      rethrow;
    }
    try {
      await client.from('community_posts').insert({
        'id': id,
        'user_id': userId,
        'author_name': communityDisplayName(name),
        'body': text.trim(),
        'image_path': paths.isEmpty ? null : paths.first,
        'image_paths': paths,
        'visibility': audience.value,
      });
    } catch (_) {
      // Do not delete after an ambiguous network response: the post may exist.
      rethrow;
    }
  }

  Future<void> comment(
      String postId, String text, String name, String? parentId) async {
    if (text.trim().isEmpty || text.trim().length > 2000) {
      throw const FormatException('Enter a comment of up to 2,000 characters.');
    }
    await client.from('community_comments').insert({
      'post_id': postId,
      'user_id': userId,
      'body': text.trim(),
      'author_name': communityDisplayName(name),
      'parent_id': parentId
    });
  }

  Future<void> toggleLike(String id, bool liked, {bool comment = false}) async {
    final field = comment ? 'comment_id' : 'post_id';
    if (liked) {
      await client
          .from('community_likes')
          .delete()
          .eq('user_id', userId)
          .eq(field, id);
    } else {
      await client.from('community_likes').upsert(
          {'user_id': userId, field: id},
          onConflict: 'user_id,$field', ignoreDuplicates: true);
    }
  }

  Future<void> deletePost(String id) async {
    final post = await client
        .from('community_posts')
        .select('image_path,image_paths')
        .eq('id', id)
        .eq('user_id', userId)
        .maybeSingle();
    if (post == null) return;
    await client
        .from('community_posts')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
    final paths = communityImagePaths(post);
    if (paths.isNotEmpty) {
      await client.storage.from('community-images').remove(paths);
    }
  }

  Future<void> deleteComment(String id) => client
      .from('community_comments')
      .delete()
      .eq('id', id)
      .eq('user_id', userId);
  Future<void> flag(String id) =>
      client.from('community_flags').insert({'user_id': userId, 'post_id': id});
}
