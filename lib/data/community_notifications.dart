import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'community_repository.dart';

String communityNotificationText(Map<String, dynamic> row) {
  final actor = communityDisplayName('${row['actor_name'] ?? ''}');
  final action = switch (row['kind']) {
    'like_post' => 'liked your post',
    'like_comment' => 'liked your comment',
    'reply' => 'replied to your comment',
    _ => 'commented on your post',
  };
  return '$actor $action';
}

class CommunityNotifications extends ChangeNotifier
    with WidgetsBindingObserver {
  CommunityNotifications(this.repo, {Future<void> Function()? ding})
      : _ding = ding {
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }
  void _listen() {
    _subscription = repo.notifications().listen(_receive, onError: (Object e) {
      error = e;
      notifyListeners();
    });
  }

  final CommunityRepository repo;
  final Future<void> Function()? _ding;
  AudioPlayer? _player;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  List<Map<String, dynamic>> rows = [];
  Object? error;
  bool loaded = false;
  Set<String> _known = {};
  bool _foreground = true;
  int get unread => rows.where((row) => row['read_at'] == null).length;
  Future<void> retry() async {
    await _subscription?.cancel();
    error = null;
    loaded = false;
    notifyListeners();
    _listen();
  }

  void _receive(List<Map<String, dynamic>> incoming) {
    final fresh =
        incoming.any((r) => !_known.contains(r['id']) && r['read_at'] == null);
    if (loaded && fresh && _foreground) unawaited(_play());
    _known = incoming.map((r) => r['id'] as String).toSet();
    rows = incoming;
    error = null;
    loaded = true;
    notifyListeners();
  }

  Future<void> _play() async {
    try {
      if (_ding != null) {
        await _ding();
      } else {
        _player ??= AudioPlayer();
        await _player!.play(AssetSource('community-ding.wav'), volume: .55);
      }
    } catch (_) {/* Sound failure must not block notifications. */}
  }

  Future<void> markRead(String id) async {
    await repo.readNotification(id);
    rows = rows
        .map((r) => r['id'] == id
            ? {...r, 'read_at': DateTime.now().toUtc().toIso8601String()}
            : r)
        .toList();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }
}
