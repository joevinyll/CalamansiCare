import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'community_repository.dart';

class CommunityFeedController extends ChangeNotifier {
  CommunityFeedController(this.repo, {this.own = false}) {
    _likesSubscription = repo.likes().listen((rows) {
      _likedIds = rows.map((row) => row['post_id'] as String).toSet();
      for (final entry in _likeSignals.entries) {
        entry.value.value = _likedIds.contains(entry.key);
      }
    }, onError: (Object _) {});
    unawaited(refresh());
  }
  final CommunityRepository repo;
  final bool own;
  final _random = Random();
  final _records = <String, Map<String, dynamic>>{};
  final _order = <String>[];
  final _incoming = <String, Map<String, dynamic>>{};
  final newPosts = ValueNotifier<int>(0);
  final _postSignals = <String, ValueNotifier<Map<String, dynamic>>>{};
  final _likeSignals = <String, ValueNotifier<bool>>{};
  Set<String> _likedIds = {};
  StreamSubscription<List<Map<String, dynamic>>>? _likesSubscription;
  StreamSubscription<CommunityPostChange>? _changes;
  final _pending = <CommunityPostChange>[];
  final _pageChanges = <CommunityPostChange>[];
  Map<String, dynamic>? _cursor;
  int _generation = 0;
  bool _disposed = false;
  String _query = '';
  bool loaded = false, loadingMore = false, hasMore = false;
  Object? error, pageError;
  List<Map<String, dynamic>> get rows => _order
      .map((id) => _records[id]!)
      .where((row) =>
          _query.isEmpty ||
          '${row['body']} ${row['author_name']}'.toLowerCase().contains(_query))
      .toList();
  void setSearch(String query) {
    _query = query.toLowerCase().trim();
    notifyListeners();
  }

  int get newPostCount => newPosts.value;
  ValueListenable<Map<String, dynamic>> post(String id) =>
      _postSignals.putIfAbsent(id, () => ValueNotifier(_records[id]!));
  ValueListenable<bool> liked(String id) =>
      _likeSignals.putIfAbsent(id, () => ValueNotifier(_likedIds.contains(id)));

  bool _setRecord(String id, Map<String, dynamic> row) {
    if (mapEquals(_records[id], row)) return false;
    _records[id] = row;
    _postSignals[id]?.value = row;
    return true;
  }

  void showNewPosts() {
    if (_disposed || _incoming.isEmpty) return;
    final posts = _incoming.values.toList()
      ..sort((a, b) {
        final date = '${b['created_at']}'.compareTo('${a['created_at']}');
        return date != 0 ? date : '${b['id']}'.compareTo('${a['id']}');
      });
    for (final row in posts) {
      _setRecord(row['id'] as String, row);
    }
    _order.insertAll(0, posts.map((row) => row['id'] as String));
    _incoming.clear();
    newPosts.value = 0;
    notifyListeners();
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    unawaited(_changes?.cancel());
    if (_disposed || generation != _generation) return;
    loaded = false;
    loadingMore = false;
    error = pageError = null;
    _records.clear();
    _order.clear();
    _clearSignals();
    _incoming.clear();
    newPosts.value = 0;
    _pending.clear();
    _pageChanges.clear();
    _cursor = null;
    hasMore = false;
    _changes = repo.postChanges(own: own).listen((change) {
      if (_disposed || generation != _generation) return;
      if (!loaded) {
        _pending.add(change);
        return;
      }
      if (loadingMore) _pageChanges.add(change);
      if (_change(change)) notifyListeners();
    });
    notifyListeners();
    try {
      final page = await repo.postPage(own: own);
      if (_disposed || generation != _generation) return;
      _append(page);
      loaded = true;
      for (final change in _pending) {
        _change(change);
      }
      _pending.clear();
    } catch (e) {
      if (_disposed || generation != _generation) return;
      error = e;
    }
    notifyListeners();
  }

  void _append(List<Map<String, dynamic>> page) {
    if (page.isNotEmpty) _cursor = page.last;
    hasMore = page.length == communityPageSize;
    final ordered = List<Map<String, dynamic>>.of(page);
    if (!own) ordered.shuffle(_random);
    for (final row in ordered) {
      final id = row['id'] as String;
      if (!_records.containsKey(id)) _order.add(id);
      _incoming.remove(id);
      _setRecord(id, row);
    }
    newPosts.value = _incoming.length;
  }

  bool _change(CommunityPostChange change) {
    final row = change.row;
    final id = row['id'] as String;
    if (change.deleted || (!own && row['visibility'] == 'only_me')) {
      _incoming.remove(id);
      newPosts.value = _incoming.length;
      final removed = _records.remove(id) != null;
      if (removed) _order.remove(id);
      return removed;
    } else if (_records.containsKey(id)) {
      final changed = _setRecord(id, row);
      return changed && _query.isNotEmpty;
    } else if (_cursor == null ||
        '${row['created_at']}'.compareTo('${_cursor!['created_at']}') > 0 ||
        (row['created_at'] == _cursor!['created_at'] &&
            id.compareTo('${_cursor!['id']}') > 0)) {
      _incoming[id] = row;
      newPosts.value = _incoming.length;
    }
    return false;
  }

  Future<void> loadMore() async {
    if (_disposed || !loaded || loadingMore || !hasMore || _cursor == null) {
      return;
    }
    final generation = _generation;
    final cursor = _cursor!;
    loadingMore = true;
    _pageChanges.clear();
    pageError = null;
    notifyListeners();
    try {
      final page = await repo.postPage(own: own, before: cursor);
      if (_disposed || generation != _generation) return;
      _append(page);
      for (final change in _pageChanges) {
        _change(change);
      }
    } catch (e) {
      if (_disposed || generation != _generation) return;
      pageError = e;
    }
    if (_disposed || generation != _generation) return;
    loadingMore = false;
    _pageChanges.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_changes?.cancel());
    unawaited(_likesSubscription?.cancel());
    newPosts.dispose();
    _clearSignals();
    super.dispose();
  }

  void _clearSignals() {
    for (final signal in _postSignals.values) {
      signal.dispose();
    }
    for (final signal in _likeSignals.values) {
      signal.dispose();
    }
    _postSignals.clear();
    _likeSignals.clear();
  }
}
