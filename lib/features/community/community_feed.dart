part of '../../main.dart';

Future<void> _communityAction(
    BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(communityErrorMessage(error))));
    }
  }
}

class _CommunityTimestamp extends StatefulWidget {
  const _CommunityTimestamp(this.value);
  final Object? value;
  @override
  State<_CommunityTimestamp> createState() => _CommunityTimestampState();
}

class _CommunityTimestampState extends State<_CommunityTimestamp>
    with WidgetsBindingObserver {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final date = DateTime.tryParse('${widget.value}');
    if (date == null) return;
    final age = DateTime.now().difference(date).inMilliseconds;
    _timer = Timer(Duration(milliseconds: 60000 - age % 60000), () {
      if (mounted) {
        setState(() {});
        _schedule();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _CommunityTimestamp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _schedule();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time = communityTime(widget.value);
    return Text(
        time.exact.isEmpty ? time.relative : '${time.relative} · ${time.exact}',
        style: const TextStyle(fontSize: 12, color: CcColors.muted));
  }
}

String _communityAuthorName(BuildContext context, CommunityRepository repo,
        Map<String, dynamic> author) =>
    author['user_id'] == repo.userId
        ? communityDisplayName(AppScope.of(context).farmerName)
        : communityDisplayName('${author['author_name'] ?? ''}');

class _CommunityAvatar extends StatefulWidget {
  const _CommunityAvatar(this.name,
      {this.repo, this.author, this.radius = 19, this.interactive = true});
  final String name;
  final CommunityRepository? repo;
  final Map<String, dynamic>? author;
  final double radius;
  final bool interactive;
  @override
  State<_CommunityAvatar> createState() => _CommunityAvatarState();
}

class _CommunityAvatarState extends State<_CommunityAvatar> {
  String? _path;
  Future<String>? _url;

  Future<void> _openProfile(String name) {
    final since = (widget.repo == null
            ? Future<String?>.value(
                DiagnosisRepository.instance.currentUser?.createdAt)
            : widget.repo!
                .memberSince(widget.author?['user_id'] ?? widget.repo!.userId))
        .catchError((Object _) => null);
    return showDialog<void>(
        context: context,
        builder: (_) => _CommunityProfileDialog(
            name: name,
            repo: widget.repo,
            author: widget.author,
            memberSince: since));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final own = widget.author == null ||
        widget.author!['user_id'] == widget.repo?.userId;
    final name = own ? communityDisplayName(state.farmerName) : widget.name;
    final local = own && state.avatarPath.isNotEmpty;
    final path = own ? null : widget.author?['author_avatar_path'] as String?;
    if (path != _path) {
      _path = path;
      _url = path == null ? null : widget.repo?.avatarUrl(path);
    }
    Widget fallback() => Text(
        name.trim().isEmpty ? 'F' : name.trim().substring(0, 1).toUpperCase(),
        style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: widget.radius > 19 ? 36 : null));
    Widget photo(ImageProvider provider) => ClipOval(
        child: Image(
            image: provider,
            width: widget.radius * 2,
            height: widget.radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback()));
    final avatar = CircleAvatar(
        radius: widget.radius,
        backgroundColor: CcColors.soft,
        foregroundColor: CcColors.green,
        child: own
            ? (local
                ? photo(ResizeImage(FileImage(File(state.avatarPath)),
                    width: widget.radius > 19 ? 384 : 192,
                    height: widget.radius > 19 ? 384 : 192,
                    policy: ResizeImagePolicy.fit))
                : fallback())
            : FutureBuilder<String>(
                future: _url,
                builder: (_, snapshot) => snapshot.hasData
                    ? photo(ResizeImage(NetworkImage(snapshot.data!),
                        width: widget.radius > 19 ? 384 : 192,
                        height: widget.radius > 19 ? 384 : 192,
                        policy: ResizeImagePolicy.fit))
                    : fallback()));
    if (!widget.interactive) return avatar;
    return Semantics(
        button: true,
        label: 'View $name profile',
        child: Tooltip(
            message: 'View profile',
            child: InkResponse(
                onTap: () => _openProfile(name),
                child: SizedBox(
                    width: max(48, widget.radius * 2),
                    height: max(48, widget.radius * 2),
                    child: Center(
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: CcColors.green, width: 1.5)),
                            child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: avatar)))))));
  }
}

class _CommunityProfileDialog extends StatelessWidget {
  const _CommunityProfileDialog(
      {required this.name,
      required this.repo,
      required this.author,
      required this.memberSince});
  final String name;
  final CommunityRepository? repo;
  final Map<String, dynamic>? author;
  final Future<String?> memberSince;

  @override
  Widget build(BuildContext context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: const Color(0xFFE1EEE4),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                  builder: (context, constraints) =>
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Row(children: [
                          DecoratedBox(
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: CcColors.green)),
                              child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: _CommunityAvatar(name,
                                      repo: repo,
                                      author: author,
                                      radius: 18,
                                      interactive: false))),
                          const SizedBox(width: 10),
                          const Expanded(
                              child: Text('Community Member',
                                  style: TextStyle(
                                      fontSize: 18, color: CcColors.ink))),
                          const SizedBox(width: 8),
                          const Tooltip(
                              message: 'Community member profile',
                              child: Padding(
                                  padding: EdgeInsets.all(7),
                                  child: Icon(Icons.person_outline_rounded,
                                      size: 30, color: CcColors.muted))),
                        ]),
                        const SizedBox(height: 36),
                        DecoratedBox(
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: CcColors.green, width: 3),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x26000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 3))
                                ]),
                            child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: _CommunityAvatar(name,
                                    repo: repo,
                                    author: author,
                                    radius: min(76, constraints.maxWidth * .21),
                                    interactive: false))),
                        const SizedBox(height: 18),
                        Text(name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 24, color: CcColors.ink)),
                        const SizedBox(height: 10),
                        FutureBuilder<String?>(
                            future: memberSince,
                            builder: (context, snapshot) {
                              final date =
                                  DateTime.tryParse(snapshot.data ?? '')
                                      ?.toLocal();
                              const months = [
                                'Jan',
                                'Feb',
                                'Mar',
                                'Apr',
                                'May',
                                'Jun',
                                'Jul',
                                'Aug',
                                'Sep',
                                'Oct',
                                'Nov',
                                'Dec'
                              ];
                              return Text(
                                  date != null
                                      ? 'Member since: ${months[date.month - 1]} ${date.year}'
                                      : snapshot.connectionState ==
                                              ConnectionState.waiting
                                          ? 'Loading membership date...'
                                          : 'Membership date unavailable',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 14, color: CcColors.ink));
                            }),
                        const SizedBox(height: 28),
                        Tooltip(
                            message: 'Close profile',
                            child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'))),
                      ])))));
}

class _CommunityPhoto extends StatefulWidget {
  const _CommunityPhoto(this.repo, this.path);
  final CommunityRepository repo;
  final String path;
  @override
  State<_CommunityPhoto> createState() => _CommunityPhotoState();
}

class _CommunityPhotoState extends State<_CommunityPhoto> {
  late Future<String> _url = widget.repo.photoUrl(widget.path);
  @override
  void didUpdateWidget(covariant _CommunityPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _url = widget.repo.photoUrl(widget.path);
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: FutureBuilder<String>(
              future: _url,
              builder: (context, snapshot) => snapshot.hasData
                  ? Image.network(snapshot.data!,
                      fit: BoxFit.cover,
                      cacheWidth: 900,
                      errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined)))
                  : ColoredBox(
                      color: CcColors.bg,
                      child: Center(
                          child: snapshot.hasError
                              ? const Icon(Icons.broken_image_outlined)
                              : const CircularProgressIndicator(
                                  strokeWidth: 2))))));
}

class CommunityImageGallery extends StatefulWidget {
  const CommunityImageGallery(
      {super.key, required this.paths, this.repo, this.onRemove});
  final List<String> paths;
  final CommunityRepository? repo;
  final ValueChanged<int>? onRemove;
  @override
  State<CommunityImageGallery> createState() => _CommunityImageGalleryState();
}

class _CommunityImageGalleryState extends State<CommunityImageGallery> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    if (widget.paths.isEmpty) return const SizedBox();
    _index = min(_index, widget.paths.length - 1);
    final path = widget.paths[_index];
    return Column(children: [
      Stack(children: [
        if (widget.repo != null)
          _CommunityPhoto(widget.repo!, path)
        else
          AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(File(path),
                      fit: BoxFit.cover,
                      cacheWidth: 900,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined)))),
        if (widget.onRemove != null)
          Positioned(
              right: 4,
              top: 4,
              child: IconButton(
                  iconSize: 28,
                  padding: const EdgeInsets.all(10),
                  tooltip: 'Remove image ${_index + 1}',
                  onPressed: () => widget.onRemove!(_index),
                  icon: const DecoratedBox(
                      decoration: BoxDecoration(
                          color: CcColors.green, shape: BoxShape.circle),
                      child: SizedBox(
                          width: 28,
                          height: 28,
                          child: Icon(Icons.close,
                              size: 16, color: Colors.white))))),
      ]),
      if (widget.paths.length > 1)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
              tooltip: 'Previous image',
              onPressed: _index == 0 ? null : () => setState(() => _index--),
              icon: const Icon(Icons.chevron_left)),
          SizedBox(
              width: 64,
              child: Text('${_index + 1} / ${widget.paths.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12))),
          IconButton(
              tooltip: 'Next image',
              onPressed: _index == widget.paths.length - 1
                  ? null
                  : () => setState(() => _index++),
              icon: const Icon(Icons.chevron_right)),
        ]),
    ]);
  }
}

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key, this.repository, this.myPosts = false});
  final CommunityRepository? repository;
  final bool myPosts;
  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen>
    with WidgetsBindingObserver {
  CommunityRepository? _repo;
  CommunityNotifications? _notifications;
  Stream<List<Map<String, dynamic>>>? _posts, _likes;
  String _search = '';
  bool _searching = false;
  bool _keyboardOpen = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final open = View.of(context).viewInsets.bottom > 0;
    if (open != _keyboardOpen) setState(() => _keyboardOpen = open);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifications?.dispose();
    super.dispose();
  }

  final _random = Random();
  final _postRanks = <String, double>{};
  Future<void> _refreshFeed() async {
    final ready = Completer<void>();
    final stream = _loadPosts().transform(StreamTransformer<
        List<Map<String, dynamic>>,
        List<Map<String, dynamic>>>.fromHandlers(handleData: (rows, sink) {
      if (!ready.isCompleted) {
        _postRanks.clear();
        ready.complete();
      }
      sink.add(rows);
    }, handleError: (error, stack, sink) {
      if (!ready.isCompleted) ready.completeError(error, stack);
      sink.addError(error, stack);
    }));
    setState(() {
      _posts = stream;
      _likes = _repo!.likes();
    });
    await _communityAction(
        context, () => ready.future.timeout(const Duration(seconds: 20)));
  }

  Stream<List<Map<String, dynamic>>> _loadPosts() =>
      widget.myPosts ? _repo!.myPosts() : _repo!.posts();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _keyboardOpen = View.of(context).viewInsets.bottom > 0;
    _repo ??= widget.repository;
    if (_repo != null && _posts == null) {
      _posts = _loadPosts();
      _likes = _repo!.likes();
    }
    if (_repo == null &&
        AppScope.of(context).isSignedIn &&
        DiagnosisRepository.instance.isSupabaseConfigured) {
      _repo = CommunityRepository(DiagnosisRepository.instance.communityClient);
      _posts = _loadPosts();
      _likes = _repo!.likes();
    }
    if (_repo != null && !widget.myPosts) {
      _notifications ??= CommunityNotifications(_repo!);
    }
  }

  Future<void> _compose() async {
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => CreateCommunityPostScreen(repo: _repo!)));
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = _keyboardOpen;
    if (_repo == null) {
      return ScreenFrame(
          child: ListView(children: [
        const Text('Community',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 24),
        const NoticeCard(
            text: 'Sign in to view and share updates with other farmers.'),
        const SizedBox(height: 16),
        PrimaryButton(
            label: 'Sign in',
            icon: Icons.login,
            onPressed: () => go(context, const AuthLandingScreen())),
      ]));
    }
    return ScreenFrame(
        showNav: !keyboardOpen,
        allowCameraOverlap: true,
        child: Column(children: [
          Row(textDirection: TextDirection.ltr, children: [
            Expanded(
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                  if (widget.myPosts)
                    IconButton(
                        tooltip: 'Back to Community',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back)),
                  Flexible(
                      child: Text(widget.myPosts ? 'My posts' : 'Community',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w700))),
                ])),
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                  tooltip: 'Search posts',
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() => _searching = !_searching)),
              if (!widget.myPosts)
                AnimatedBuilder(
                    animation: _notifications!,
                    builder: (context, _) => IconButton(
                        tooltip: 'Notifications',
                        icon: Badge(
                            isLabelVisible: _notifications!.unread > 0,
                            label: Text(_notifications!.unread > 99
                                ? '99+'
                                : '${_notifications!.unread}'),
                            child: const Icon(Icons.notifications_outlined)),
                        onPressed: () => go(
                            context,
                            CommunityActivityScreen(
                                repo: _repo!, notifications: _notifications)))),
              if (!widget.myPosts)
                IconButton(
                    tooltip: 'My posts',
                    icon: const Icon(Icons.article_outlined),
                    onPressed: () => go(context,
                        CommunityFeedScreen(repository: _repo, myPosts: true))),
            ]),
          ]),
          if (_searching)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                    textAlignVertical: TextAlignVertical.center,
                    maxLines: 1,
                    decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(999))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(999)),
                            borderSide: BorderSide(color: Colors.black26)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(999)),
                            borderSide:
                                BorderSide(color: CcColors.green, width: 1.5)),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        prefixIconConstraints:
                            BoxConstraints(minWidth: 48, minHeight: 48),
                        hintText: 'Search posts or farmers',
                        prefixIcon: Icon(Icons.search)),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    onChanged: (value) =>
                        setState(() => _search = value.toLowerCase().trim()))),
          if (!widget.myPosts && !keyboardOpen)
            Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                    onTap: _compose,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          _CommunityAvatar(AppScope.of(context).farmerName,
                              repo: _repo),
                          const SizedBox(width: 12),
                          const Expanded(
                              child: Text('Share an update...',
                                  style: TextStyle(color: CcColors.muted))),
                          const Icon(Icons.add_photo_alternate_outlined,
                              color: CcColors.green),
                        ])))),
          const SizedBox(height: 12),
          Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _posts,
                  builder: (context, posts) {
                    if (posts.hasError) {
                      return _CommunityError(
                          error: posts.error, onRetry: _refreshFeed);
                    }
                    if (!posts.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final rows = posts.data!
                        .where((p) =>
                            widget.myPosts || p['visibility'] != 'only_me')
                        .where((p) =>
                            !widget.myPosts || p['user_id'] == _repo!.userId)
                        .where((p) => '${p['body']} ${p['author_name']}'
                            .toLowerCase()
                            .contains(_search))
                        .toList();
                    if (!widget.myPosts) {
                      final ids =
                          posts.data!.map((p) => p['id'] as String).toSet();
                      _postRanks.removeWhere((id, _) => !ids.contains(id));
                      for (final id in ids) {
                        _postRanks.putIfAbsent(id, _random.nextDouble);
                      }
                      rows.sort((a, b) =>
                          _postRanks[a['id']]!.compareTo(_postRanks[b['id']]!));
                    }
                    if (rows.isEmpty) {
                      return RefreshIndicator(
                          onRefresh: _refreshFeed,
                          child: ListView(
                              padding: EdgeInsets.only(
                                  bottom: keyboardOpen ? 0 : 34),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 32),
                                    child: Text(
                                        _search.isEmpty
                                            ? (widget.myPosts
                                                ? 'You have not shared any posts yet.'
                                                : 'No community posts yet.')
                                            : 'No matching posts.',
                                        textAlign: TextAlign.center))
                              ]));
                    }
                    return StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _likes,
                        builder: (context, likes) => RefreshIndicator(
                            onRefresh: _refreshFeed,
                            child: ListView.separated(
                                padding: EdgeInsets.only(
                                    bottom: keyboardOpen ? 0 : 34),
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: rows.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, i) => _CommunityPostCard(
                                    key: ValueKey(rows[i]['id']),
                                    repo: _repo!,
                                    post: rows[i],
                                    likes: likes.data ?? [],
                                    comments: const []))));
                  })),
        ]));
  }
}

class _CommunityError extends StatelessWidget {
  const _CommunityError({required this.onRetry, this.error});
  final VoidCallback onRetry;
  final Object? error;
  @override
  Widget build(BuildContext context) => Center(
      child: SingleChildScrollView(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline,
                    size: 32, color: CcColors.muted),
                const SizedBox(height: 12),
                const Text('Community could not load.',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(communityErrorMessage(error), textAlign: TextAlign.center),
                TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry')),
              ]))));
}

class _CommunityPostCard extends StatefulWidget {
  const _CommunityPostCard(
      {super.key,
      required this.repo,
      required this.post,
      required this.likes,
      required this.comments});
  final CommunityRepository repo;
  final Map<String, dynamic> post;
  final List<Map<String, dynamic>> likes, comments;
  @override
  State<_CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<_CommunityPostCard> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final likes = widget.likes.where((l) => l['post_id'] == p['id']).toList();
    final liked = likes.any((l) => l['user_id'] == widget.repo.userId);
    final comments = p['comment_count'] ?? 0;
    return _BatchPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _CommunityAvatar(p['author_name'], repo: widget.repo, author: p),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_communityAuthorName(context, widget.repo, p),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          _CommunityTimestamp(p['created_at']),
          if (p['visibility'] == 'only_me')
            const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.lock_outline, size: 12, color: CcColors.muted),
                  SizedBox(width: 4),
                  Text('Only Me',
                      style: TextStyle(fontSize: 11, color: CcColors.muted)),
                ])),
        ])),
        PopupMenuButton<String>(
            tooltip: 'Post options',
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 4,
            position: PopupMenuPosition.under,
            menuPadding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFFDAE3D7))),
            onSelected: (action) async {
              if (action == 'edit') {
                await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => EditCommunityPostScreen(
                            repo: widget.repo, post: p)));
              } else if (action == 'delete') {
                final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                            title: const Text('Delete post?'),
                            content: const Text(
                                'The post and its comments will be removed.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel')),
                              TextButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Delete'))
                            ]));
                if (confirmed == true && context.mounted) {
                  await _communityAction(
                      context, () => widget.repo.deletePost(p['id']));
                }
              } else {
                await _communityAction(context, () async {
                  await widget.repo.flag(p['id']);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Post reported for review.')));
                  }
                });
              }
            },
            itemBuilder: (_) => [
                  if (p['user_id'] == widget.repo.userId)
                    const PopupMenuItem(
                        value: 'edit',
                        height: 56,
                        child: Row(children: [
                          DecoratedBox(
                              decoration: BoxDecoration(
                                  color: Color(0xFFEAF3E7),
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(6))),
                              child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.edit_outlined,
                                      size: 18, color: CcColors.green))),
                          SizedBox(width: 12),
                          Expanded(
                              child: Text('Edit post',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: CcColors.ink))),
                        ])),
                  if (p['user_id'] == widget.repo.userId)
                    const PopupMenuDivider(height: 12),
                  PopupMenuItem(
                      height: 56,
                      value: p['user_id'] == widget.repo.userId
                          ? 'delete'
                          : 'report',
                      child: Row(children: [
                        DecoratedBox(
                            decoration: const BoxDecoration(
                                color: Color(0xFFFCEDEA),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(6))),
                            child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                    p['user_id'] == widget.repo.userId
                                        ? Icons.delete_outline
                                        : Icons.flag_outlined,
                                    size: 18,
                                    color: CcColors.red))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(
                                p['user_id'] == widget.repo.userId
                                    ? 'Delete post'
                                    : 'Report post',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: CcColors.red))),
                      ]))
                ]),
      ]),
      if ((p['body'] as String).isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(p['body'], style: const TextStyle(fontSize: 14, height: 1.45))
      ],
      if (communityImagePaths(p).isNotEmpty) ...[
        const SizedBox(height: 12),
        CommunityImageGallery(repo: widget.repo, paths: communityImagePaths(p))
      ],
      const SizedBox(height: 10),
      Row(children: [
        Icon(Icons.favorite,
            size: 18, color: liked ? CcColors.red : CcColors.muted),
        const SizedBox(width: 6),
        Text('${p['like_count'] ?? 0}'),
        const SizedBox(width: 20),
        const Icon(Icons.chat_bubble_outline, size: 18),
        const SizedBox(width: 6),
        Flexible(
            child: Text('$comments comments',
                style: const TextStyle(fontSize: 12)))
      ]),
      const Divider(height: 20),
      Row(children: [
        Expanded(
            child: TextButton.icon(
                icon: Icon(liked ? Icons.favorite : Icons.favorite_border,
                    size: 19),
                label: const Text('Like'),
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        await _communityAction(context,
                            () => widget.repo.toggleLike(p['id'], liked));
                        if (mounted) setState(() => _busy = false);
                      })),
        Expanded(
            child: TextButton.icon(
                icon: const Icon(Icons.chat_bubble_outline, size: 19),
                label: const Text('Comment'),
                onPressed: () => go(context,
                    CommunityCommentsScreen(repo: widget.repo, post: p))))
      ]),
    ]));
  }
}

class _CommunityAudiencePicker extends StatelessWidget {
  const _CommunityAudiencePicker(
      {required this.value, required this.onChanged});
  final CommunityAudience value;
  final ValueChanged<CommunityAudience>? onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 160,
      child: Theme(
          data: Theme.of(context).copyWith(focusColor: const Color(0xFFEAF3E7)),
          child: DropdownButton<CommunityAudience>(
              value: value,
              hint: const Text('Post visibility'),
              underline: const SizedBox(),
              isExpanded: true,
              itemHeight: null,
              menuMaxHeight: 300,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(8),
              elevation: 4,
              padding: EdgeInsets.zero,
              focusColor: CcColors.soft,
              icon: const Icon(Icons.expand_more,
                  size: 18, color: CcColors.muted),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 12, color: CcColors.muted),
              selectedItemBuilder: (_) => [
                    for (final audience in CommunityAudience.values)
                      Row(children: [
                        Icon(
                            audience == CommunityAudience.onlyMe
                                ? Icons.lock_outline
                                : Icons.public,
                            size: 16,
                            color: CcColors.muted),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                                audience == CommunityAudience.onlyMe
                                    ? 'Only Me'
                                    : 'Community',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w400))),
                      ]),
                  ],
              onChanged: onChanged == null
                  ? null
                  : (value) {
                      if (value != null) onChanged!(value);
                    },
              items: [
                for (final audience in CommunityAudience.values)
                  DropdownMenuItem(
                      value: audience,
                      child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                          decoration: BoxDecoration(
                              color: audience == value
                                  ? const Color(0xFFEAF3E7)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(6)),
                          child: Row(children: [
                            Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFDDEBD9),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Icon(
                                    audience == CommunityAudience.onlyMe
                                        ? Icons.lock_outline
                                        : Icons.groups_outlined,
                                    size: 18,
                                    color: CcColors.green)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      audience == CommunityAudience.onlyMe
                                          ? 'Only Me'
                                          : 'Community',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: CcColors.ink)),
                                  const SizedBox(height: 3),
                                  Text(
                                      audience == CommunityAudience.onlyMe
                                          ? 'Private to you'
                                          : 'Signed-in members',
                                      style: const TextStyle(
                                          fontSize: 12, color: CcColors.muted)),
                                ])),
                            const SizedBox(width: 8),
                            SizedBox(
                                width: 18,
                                child: audience == value
                                    ? const Icon(Icons.check_circle,
                                        size: 18, color: CcColors.green)
                                    : null),
                          ]))),
              ])));
}

class CreateCommunityPostScreen extends StatefulWidget {
  const CreateCommunityPostScreen({super.key, required this.repo});
  final CommunityRepository repo;
  @override
  State<CreateCommunityPostScreen> createState() =>
      _CreateCommunityPostScreenState();
}

class _CreateCommunityPostScreenState extends State<CreateCommunityPostScreen> {
  final _text = TextEditingController();
  final _photos = <File>[];
  CommunityAudience _audience = CommunityAudience.community;
  bool _picking = false;
  bool _busy = false;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_picking || _busy || _photos.length >= maxCommunityPhotos) return;
    setState(() => _picking = true);
    try {
      await _communityAction(context, () async {
        final picker = ImagePicker();
        final files = source == ImageSource.gallery
            ? await picker.pickMultiImage(maxWidth: 1600, imageQuality: 85)
            : [
                if (await picker.pickImage(
                        source: source, maxWidth: 1600, imageQuality: 85)
                    case final file?)
                  file
              ];
        if (!mounted) return;
        if (_photos.length + files.length > maxCommunityPhotos) {
          throw const FormatException('Choose up to 5 photos per post.');
        }
        for (final file in files) {
          if (await File(file.path).length() > 5 * 1024 * 1024) {
            throw const FormatException('Choose a photo of 5 MB or less.');
          }
        }
        if (mounted) {
          setState(() => _photos.addAll(files.map((file) => File(file.path))));
        }
      });
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: CcColors.bg,
      appBar: AppBar(title: const Text('Create post'), actions: [
        Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 36)),
                onPressed: _busy || _picking
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        await _communityAction(context, () async {
                          await widget.repo.publish(_text.text,
                              AppScope.of(context).farmerName, List.of(_photos),
                              audience: _audience);
                          if (context.mounted) Navigator.pop(context);
                        });
                        if (mounted) setState(() => _busy = false);
                      },
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Post')))
      ]),
      body: SafeArea(
          top: false,
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    _BatchPanel(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            _CommunityAvatar(AppScope.of(context).farmerName,
                                repo: widget.repo),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      communityDisplayName(
                                          AppScope.of(context).farmerName),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  _CommunityAudiencePicker(
                                      value: _audience,
                                      onChanged: _busy || _picking
                                          ? null
                                          : (value) => setState(
                                              () => _audience = value)),
                                ]))
                          ]),
                          const SizedBox(height: 16),
                          TextField(
                              controller: _text,
                              maxLines: 5,
                              maxLength: 3000,
                              enabled: !_busy,
                              decoration: const InputDecoration(
                                  hintText: 'Share an update...',
                                  border: OutlineInputBorder())),
                          if (_photos.isNotEmpty)
                            CommunityImageGallery(
                                paths:
                                    _photos.map((photo) => photo.path).toList(),
                                onRemove: _busy || _picking
                                    ? null
                                    : (index) => setState(
                                        () => _photos.removeAt(index))),
                          const SizedBox(height: 12),
                          const Text('Maximum 5 images per post',
                              style: TextStyle(
                                  fontSize: 12, color: CcColors.muted)),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                                child: OutlinedButton.icon(
                                    onPressed: _busy ||
                                            _picking ||
                                            _photos.length >= maxCommunityPhotos
                                        ? null
                                        : () => _pick(ImageSource.gallery),
                                    icon: const Icon(
                                        Icons.photo_library_outlined),
                                    label: const Text('Add photo'))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: OutlinedButton.icon(
                                    onPressed: _busy ||
                                            _picking ||
                                            _photos.length >= maxCommunityPhotos
                                        ? null
                                        : () => _pick(ImageSource.camera),
                                    icon: const Icon(Icons.camera_alt_outlined),
                                    label: const Text('Camera')))
                          ]),
                        ])),
                  ])))));
}

class EditCommunityPostScreen extends StatefulWidget {
  const EditCommunityPostScreen(
      {super.key, required this.repo, required this.post});
  final CommunityRepository repo;
  final Map<String, dynamic> post;
  @override
  State<EditCommunityPostScreen> createState() =>
      _EditCommunityPostScreenState();
}

class _EditCommunityPostScreenState extends State<EditCommunityPostScreen> {
  late final _text = TextEditingController(text: widget.post['body'] as String);
  late CommunityAudience _audience = widget.post['visibility'] == 'only_me'
      ? CommunityAudience.onlyMe
      : CommunityAudience.community;
  bool _busy = false;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await _communityAction(context, () async {
      await widget.repo
          .editPost(widget.post['id'], _text.text, audience: _audience);
      if (mounted) Navigator.pop(context);
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: CcColors.bg,
      appBar: AppBar(title: const Text('Edit post'), actions: [
        Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 36)),
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'))),
      ]),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Row(children: [
                      _CommunityAvatar(AppScope.of(context).farmerName,
                          repo: widget.repo),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                communityDisplayName(
                                    AppScope.of(context).farmerName),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            _CommunityAudiencePicker(
                                value: _audience,
                                onChanged: _busy
                                    ? null
                                    : (value) =>
                                        setState(() => _audience = value)),
                          ])),
                    ]),
                    const SizedBox(height: 16),
                    TextField(
                        controller: _text,
                        enabled: !_busy,
                        maxLines: 6,
                        maxLength: 3000,
                        decoration: const InputDecoration(
                            labelText: 'Post text',
                            border: OutlineInputBorder())),
                    if (communityImagePaths(widget.post).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      CommunityImageGallery(
                          repo: widget.repo,
                          paths: communityImagePaths(widget.post)),
                    ],
                  ])))));
}

class CommunityCommentsScreen extends StatefulWidget {
  const CommunityCommentsScreen(
      {super.key, required this.repo, required this.post});
  final CommunityRepository repo;
  final Map<String, dynamic> post;
  @override
  State<CommunityCommentsScreen> createState() =>
      _CommunityCommentsScreenState();
}

class _CommunityCommentsScreenState extends State<CommunityCommentsScreen> {
  late Stream<List<Map<String, dynamic>>> _comments =
      widget.repo.comments(widget.post['id']);
  late final _likes = widget.repo.likes();
  final _text = TextEditingController();
  final _focus = FocusNode();
  String? _replyId, _replyName;
  bool _busy = false;
  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Widget _comment(Map<String, dynamic> c, List<Map<String, dynamic>> likes,
      {bool reply = false}) {
    final liked = likes.any((l) =>
        l['comment_id'] == c['id'] && l['user_id'] == widget.repo.userId);
    return Padding(
        padding: EdgeInsets.only(left: reply ? 32 : 0, bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _CommunityAvatar(c['author_name'], repo: widget.repo, author: c),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: reply ? CcColors.bg : CcColors.bgAlt,
                        borderRadius: BorderRadius.circular(8)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_communityAuthorName(context, widget.repo, c),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                          _CommunityTimestamp(c['created_at']),
                          const SizedBox(height: 6),
                          Text(c['body'],
                              style: const TextStyle(fontSize: 14, height: 1.4))
                        ])),
                Wrap(children: [
                  TextButton.icon(
                      icon: Icon(liked ? Icons.favorite : Icons.favorite_border,
                          size: 15),
                      label: Text('${c['like_count'] ?? 0}'),
                      onPressed: () => _communityAction(
                          context,
                          () => widget.repo
                              .toggleLike(c['id'], liked, comment: true))),
                  TextButton.icon(
                      icon: const Icon(Icons.reply, size: 15),
                      label: const Text('Reply'),
                      onPressed: () {
                        setState(() {
                          _replyId = reply ? c['parent_id'] : c['id'];
                          _replyName =
                              _communityAuthorName(context, widget.repo, c);
                        });
                        _focus.requestFocus();
                      }),
                  if (c['user_id'] == widget.repo.userId)
                    IconButton(
                        tooltip: 'Delete comment',
                        icon: const Icon(Icons.delete_outline, size: 17),
                        onPressed: () => _communityAction(
                            context, () => widget.repo.deleteComment(c['id']))),
                ]),
              ]))
        ]));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Comments')),
      body: SafeArea(
          top: false,
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(children: [
                    Expanded(
                        child: StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _comments,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return _CommunityError(
                                    error: snapshot.error,
                                    onRetry: () => setState(() => _comments =
                                        widget.repo
                                            .comments(widget.post['id'])));
                              }
                              if (!snapshot.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              return StreamBuilder<List<Map<String, dynamic>>>(
                                  stream: _likes,
                                  builder: (context, likes) => ListView(
                                          padding: const EdgeInsets.all(16),
                                          children: [
                                            _BatchPanel(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Row(children: [
                                                    _CommunityAvatar(
                                                        _communityAuthorName(
                                                            context,
                                                            widget.repo,
                                                            widget.post),
                                                        repo: widget.repo,
                                                        author: widget.post),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                        child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                          Text(
                                                              _communityAuthorName(
                                                                  context,
                                                                  widget.repo,
                                                                  widget.post),
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700)),
                                                          const SizedBox(
                                                              height: 4),
                                                          _CommunityTimestamp(
                                                              widget.post[
                                                                  'created_at']),
                                                        ])),
                                                  ]),
                                                  const SizedBox(height: 8),
                                                  Text(widget.post['body']),
                                                  if (communityImagePaths(
                                                          widget.post)
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 10),
                                                    CommunityImageGallery(
                                                        repo: widget.repo,
                                                        paths:
                                                            communityImagePaths(
                                                                widget.post))
                                                  ],
                                                ])),
                                            const SizedBox(height: 20),
                                            if (snapshot.data!.isEmpty)
                                              const Padding(
                                                  padding: EdgeInsets.all(24),
                                                  child:
                                                      Text('No comments yet.')),
                                            for (final c in snapshot.data!
                                                .where((c) =>
                                                    c['parent_id'] ==
                                                    null)) ...[
                                              _comment(c, likes.data ?? []),
                                              for (final r in snapshot.data!
                                                  .where((r) =>
                                                      r['parent_id'] ==
                                                      c['id']))
                                                _comment(r, likes.data ?? [],
                                                    reply: true),
                                            ],
                                          ]));
                            })),
                    if (_replyId != null)
                      ListTile(
                          dense: true,
                          title: Text('Replying to $_replyName'),
                          trailing: IconButton(
                              tooltip: 'Cancel reply',
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  setState(() => _replyId = null))),
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _CommunityAvatar(AppScope.of(context).farmerName,
                                  repo: widget.repo),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: TextField(
                                      controller: _text,
                                      focusNode: _focus,
                                      minLines: 1,
                                      maxLines: 4,
                                      maxLength: 2000,
                                      enabled: !_busy,
                                      decoration: const InputDecoration(
                                          hintText: 'Write a comment...',
                                          counterText: '',
                                          border: OutlineInputBorder()))),
                              IconButton(
                                  tooltip: 'Send comment',
                                  icon: _busy
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Icon(Icons.send,
                                          color: CcColors.green),
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          setState(() => _busy = true);
                                          await _communityAction(context,
                                              () async {
                                            await widget.repo.comment(
                                                widget.post['id'],
                                                _text.text,
                                                AppScope.of(context).farmerName,
                                                _replyId);
                                            _text.clear();
                                            if (mounted) {
                                              setState(() => _replyId = null);
                                            }
                                          });
                                          if (mounted) {
                                            setState(() => _busy = false);
                                          }
                                        }),
                            ])),
                  ])))));
}

class CommunityActivityScreen extends StatefulWidget {
  const CommunityActivityScreen(
      {super.key, required this.repo, this.notifications});
  final CommunityRepository repo;
  final CommunityNotifications? notifications;
  @override
  State<CommunityActivityScreen> createState() =>
      _CommunityActivityScreenState();
}

class _CommunityActivityScreenState extends State<CommunityActivityScreen> {
  late final _notifications =
      widget.notifications ?? CommunityNotifications(widget.repo);
  @override
  void dispose() {
    if (widget.notifications == null) _notifications.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      backgroundColor: CcColors.bg,
      body: SafeArea(
          child: AnimatedBuilder(
              animation: _notifications,
              builder: (context, _) {
                if (_notifications.error != null) {
                  return _CommunityError(
                      error: _notifications.error,
                      onRetry: _notifications.retry);
                }
                if (!_notifications.loaded) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_notifications.rows.isEmpty) {
                  return const Center(child: Text('No notifications yet.'));
                }
                return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final row = _notifications.rows[index];
                      final unread = row['read_at'] == null;
                      return Card(
                          margin: EdgeInsets.zero,
                          elevation: 0,
                          color:
                              unread ? const Color(0xFFF0F7EC) : Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Color(0xFFD7E2D3))),
                          child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              leading: _CommunityAvatar(
                                  communityDisplayName(
                                      '${row['actor_name'] ?? ''}'),
                                  repo: widget.repo,
                                  author: {
                                    'user_id': row['actor_id'],
                                    'author_name': row['actor_name'],
                                    'author_avatar_path':
                                        row['actor_avatar_path'],
                                  }),
                              title: Text(communityNotificationText(row),
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: unread
                                          ? FontWeight.w600
                                          : FontWeight.w400)),
                              subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child:
                                      _CommunityTimestamp(row['created_at'])),
                              trailing: unread
                                  ? const Icon(Icons.circle,
                                      size: 8, color: CcColors.green)
                                  : null,
                              onTap: () => _communityAction(context, () async {
                                    await _notifications.markRead(row['id']);
                                    final post = await widget.repo
                                        .notificationPost(row['post_id']);
                                    if (!context.mounted) return;
                                    if (post == null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'This post is no longer available.')));
                                    } else {
                                      go(
                                          context,
                                          CommunityCommentsScreen(
                                              repo: widget.repo, post: post));
                                    }
                                  })));
                    });
              })));
}
