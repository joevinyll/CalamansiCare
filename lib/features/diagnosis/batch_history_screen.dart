part of '../../main.dart';

class ScanHistoryBatch {
  ScanHistoryBatch(this.rows) {
    rows.sort((a, b) => ((a['batch_image_index'] as int?) ?? 0)
        .compareTo((b['batch_image_index'] as int?) ?? 0));
  }
  final List<Map<String, Object?>> rows;
  String get key => '${rows.first['batch_id'] ?? 'scan-${rows.first['id']}'}';
  String get title =>
      '${scannedCount == 1 ? 'Image' : 'Batch'} ${rows.map((r) => r['id'] as int).reduce((a, b) => a < b ? a : b).toString().padLeft(3, '0')}';
  DateTime get date => rows
      .map((r) => DateTime.parse(r['created_at'] as String))
      .reduce((a, b) => a.isBefore(b) ? a : b)
      .toLocal();
  int get scannedCount =>
      (rows.first['batch_total_count'] as int?) ?? rows.length;
  bool get sent => rows.every((r) => r['report_status'] == reportStatusSynced);
  bool get waiting => !sent && rows.any((r) => r['report_id'] != null);
  String get status => sent
      ? 'Sent'
      : waiting
          ? 'Queued to send'
          : 'Saved on device';
  Map<String, List<Map<String, Object?>>> get conditions {
    final result = <String, List<Map<String, Object?>>>{};
    for (final row in rows) {
      result.putIfAbsent(row['disease'] as String, () => []).add(row);
    }
    return result;
  }

  List<BatchScanResult> get results => rows
      .map((r) => (
            file: XFile(r['image_path'] as String? ?? ''),
            prediction: DiseasePrediction(
                label: r['disease'] as String,
                confidence: (r['confidence'] as num).toDouble()),
            id: r['id'] as int,
            error: null,
          ))
      .toList();
}

List<ScanHistoryBatch> groupScanHistory(List<Map<String, Object?>> rows) {
  final groups = <String, List<Map<String, Object?>>>{};
  for (final row in rows) {
    groups
        .putIfAbsent('${row['batch_id'] ?? 'scan-${row['id']}'}', () => [])
        .add(row);
  }
  return groups.values.map(ScanHistoryBatch.new).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, Object?>>> _future;
  int _filter = 0;
  bool _searchOpen = false;
  String _query = '';
  String _risk = 'All risk levels';
  bool _deleting = false;

  Future<void> _deleteBatch(ScanHistoryBatch batch) async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text('Delete ${batch.title}?'),
                content: const Text(
                    'Remove all saved scans and queued reports in this batch from this device? This cannot be undone. Sent emails and cloud reports remain, and reports already sending may still arrive. Cloud reports may return after account restoration.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete')),
                ]));
    if (confirmed != true || !mounted || _deleting) return;
    setState(() => _deleting = true);
    try {
      await DiagnosisRepository.instance
          .deleteDiagnoses(batch.rows.map((row) => row['id'] as int).toList());
      if (!mounted) return;
      setState(() => _future =
          DiagnosisRepository.instance.getRecentDiagnoses(limit: null));
      await AppScope.of(context).refreshStats();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not delete this batch. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _future = DiagnosisRepository.instance.getRecentDiagnoses(limit: null);
  }

  Future<void> _refresh() async {
    await AppScope.of(context).checkConnectivityAndSync();
    if (!mounted) return;
    final future = DiagnosisRepository.instance.getRecentDiagnoses(limit: null);
    setState(() => _future = future);
    await future;
  }

  String _day(DateTime date) {
    final now = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(date);
    if (day == now) return 'Today';
    if (day == DateTime(now.year, now.month, now.day - 1)) return 'Yesterday';
    return _formatHistoryDate(date.toIso8601String());
  }

  @override
  Widget build(BuildContext context) => ScreenFrame(
      allowCameraOverlap: true,
      child: Column(children: [
        Row(children: [
          const Expanded(
              child: Text('History',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700))),
          IconButton(
              tooltip: 'Search batches',
              onPressed: () => setState(() {
                    _searchOpen = !_searchOpen;
                    if (!_searchOpen) _query = '';
                  }),
              icon: const Icon(Icons.search)),
          PopupMenuButton<String>(
              tooltip: 'Filter batches',
              icon: const Icon(Icons.filter_alt_outlined),
              initialValue: _risk,
              onSelected: (value) => setState(() => _risk = value),
              itemBuilder: (_) => [
                    'All risk levels',
                    'High risk',
                    'Medium risk',
                    'Low risk'
                  ]
                      .map((value) =>
                          PopupMenuItem(value: value, child: Text(value)))
                      .toList()),
        ]),
        if (_searchOpen)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                  decoration: const InputDecoration(
                      hintText: 'Search batch or condition',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder()),
                  onChanged: (value) =>
                      setState(() => _query = value.toLowerCase()))),
        const SizedBox(height: 12),
        SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
                showSelectedIcon: false,
                style: ButtonStyle(
                    shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                    foregroundColor: WidgetStateProperty.resolveWith((s) =>
                        s.contains(WidgetState.selected)
                            ? Colors.white
                            : CcColors.ink),
                    backgroundColor: WidgetStateProperty.resolveWith((s) =>
                        s.contains(WidgetState.selected)
                            ? CcColors.green
                            : CcColors.bgAlt)),
                segments: const [
                  ButtonSegment(value: 0, label: Text('All')),
                  ButtonSegment(value: 1, label: Text('Waiting')),
                  ButtonSegment(value: 2, label: Text('Sent'))
                ],
                selected: {_filter},
                onSelectionChanged: (value) =>
                    setState(() => _filter = value.first))),
        const SizedBox(height: 16),
        Expanded(
            child: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<Map<String, Object?>>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return ListView(children: [
                          const Text('Could not load history.'),
                          TextButton(
                              onPressed: _refresh, child: const Text('Retry'))
                        ]);
                      }
                      final batches = groupScanHistory(snapshot.data ?? [])
                          .where((batch) =>
                              (_filter == 0 ||
                                  (_filter == 1
                                      ? batch.waiting
                                      : batch.sent)) &&
                              (batch.title.toLowerCase().contains(_query) ||
                                  batch.conditions.keys.any((d) =>
                                      d.toLowerCase().contains(_query))) &&
                              (_risk == 'All risk levels' ||
                                  batch.conditions.keys
                                      .any((d) => _batchRisk(d) == _risk)))
                          .toList();
                      return ListView(
                          padding: const EdgeInsets.only(bottom: 34),
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            if (batches.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Text('No batches found.')),
                            for (var i = 0; i < batches.length; i++) ...[
                              if (i == 0 ||
                                  _day(batches[i].date) !=
                                      _day(batches[i - 1].date))
                                Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 10, top: 8),
                                    child: Text(_day(batches[i].date),
                                        style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600))),
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _HistoryBatchTile(
                                      batch: batches[i],
                                      onDelete: _deleting
                                          ? null
                                          : () => _deleteBatch(batches[i]),
                                      onTap: () async {
                                        await Navigator.push<void>(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    BatchHistoryDetailsScreen(
                                                        batch: batches[i])));
                                        if (mounted) {
                                          setState(() {
                                            _future = DiagnosisRepository
                                                .instance
                                                .getRecentDiagnoses(
                                                    limit: null);
                                          });
                                        }
                                      })),
                            ],
                          ]);
                    }))),
      ]));
}

class _HistoryBatchTile extends StatelessWidget {
  const _HistoryBatchTile(
      {required this.batch, required this.onTap, this.onDelete});
  final ScanHistoryBatch batch;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 12,
                                  runSpacing: 6,
                                  children: [
                                Text(batch.title,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                _BatchStatus(batch: batch),
                              ])),
                          IconButton(
                              tooltip: 'Delete ${batch.title}',
                              onPressed: onDelete,
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent)),
                        ]),
                    const SizedBox(height: 4),
                    Text(_formatHistoryDateTime(batch.date.toIso8601String()),
                        style: const TextStyle(
                            fontSize: 13, color: CcColors.muted)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _BatchStrip(batch: batch)),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: CcColors.muted)
                    ]),
                    const SizedBox(height: 8),
                    Text('${batch.scannedCount} images scanned',
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: batch.conditions.entries
                            .map((e) =>
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.circle,
                                      size: 9,
                                      color: _batchConditionColor(e.key)),
                                  const SizedBox(width: 4),
                                  Text('${e.value.length} ${context.t(e.key)}',
                                      style: const TextStyle(fontSize: 12))
                                ]))
                            .toList()),
                  ]))));
}

class _BatchStrip extends StatelessWidget {
  const _BatchStrip({required this.batch});
  final ScanHistoryBatch batch;
  @override
  Widget build(BuildContext context) {
    final count = batch.rows.length > 5 ? 5 : batch.rows.length;
    return SizedBox(
        height: 58,
        child: Row(children: [
          for (var i = 0; i < count; i++)
            Flexible(
                child: Padding(
                    padding: EdgeInsets.only(right: i == count - 1 ? 0 : 4),
                    child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Stack(fit: StackFit.expand, children: [
                              Image.file(
                                  File(batch.rows[i]['image_path'] as String? ??
                                      ''),
                                  fit: BoxFit.cover,
                                  cacheWidth: 180,
                                  errorBuilder: (_, __, ___) =>
                                      const ColoredBox(
                                          color: CcColors.soft,
                                          child: Icon(Icons.image_outlined))),
                              if (i == 4 && batch.rows.length > 5)
                                ColoredBox(
                                    color: Colors.black54,
                                    child: Center(
                                        child: Text('+${batch.rows.length - 4}',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700)))),
                            ])))))
        ]));
  }
}

class _BatchStatus extends StatelessWidget {
  const _BatchStatus({required this.batch, this.detail = false});
  final ScanHistoryBatch batch;
  final bool detail;
  @override
  Widget build(BuildContext context) {
    final online = AppScope.of(context).isOnline;
    final failed =
        batch.rows.any((r) => r['report_status'] == reportStatusFailedRetry);
    final pendingLabel = !online
        ? 'Waiting for internet connection'
        : failed
            ? 'Waiting for internet connection'
            : 'Queued to send';
    final color = batch.sent
        ? CcColors.green
        : batch.waiting
            ? const Color(0xFF9C5D08)
            : CcColors.muted;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: batch.sent
                ? const Color(0xFFE7F2DC)
                : batch.waiting
                    ? const Color(0xFFFFEFCB)
                    : const Color(0xFFEEF1ED),
            borderRadius: BorderRadius.circular(8)),
        child: Row(
            mainAxisSize: detail ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Icon(
                  batch.sent
                      ? Icons.check_circle
                      : batch.waiting
                          ? (online || failed
                              ? Icons.schedule_send_outlined
                              : Icons.wifi_off)
                          : Icons.description_outlined,
                  size: detail ? 26 : 16,
                  color: color),
              const SizedBox(width: 8),
              Flexible(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        batch.waiting
                            ? detail
                                ? pendingLabel
                                : 'Queued to send'
                            : batch.status,
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    if (detail)
                      Text(
                          batch.waiting
                              ? failed
                                  ? 'Saved on this device. Try again; check the report service if this continues.'
                                  : online
                                      ? 'Internet connected. The report is pending delivery.'
                                      : 'Queued images will send when connected.'
                              : batch.sent
                                  ? 'All saved images have been sent.'
                                  : 'Saved on this device.',
                          style: const TextStyle(fontSize: 12))
                  ])),
            ]));
  }
}

class BatchHistoryDetailsScreen extends StatefulWidget {
  const BatchHistoryDetailsScreen({super.key, required this.batch});
  final ScanHistoryBatch batch;
  @override
  State<BatchHistoryDetailsScreen> createState() =>
      _BatchHistoryDetailsScreenState();
}

class _BatchHistoryDetailsScreenState extends State<BatchHistoryDetailsScreen> {
  late ScanHistoryBatch _batch = widget.batch;
  Future<void> _reload() async {
    final batches = groupScanHistory(
        await DiagnosisRepository.instance.getRecentDiagnoses(limit: null));
    final matches = batches.where((b) => b.key == _batch.key);
    if (mounted && matches.isNotEmpty) setState(() => _batch = matches.first);
  }

  @override
  Widget build(BuildContext context) =>
      _BatchHistoryPage(title: _batch.title, children: [
        Text(_formatHistoryDateTime(_batch.date.toIso8601String()),
            style: const TextStyle(color: CcColors.muted)),
        const SizedBox(height: 12),
        Text('${_batch.scannedCount} images scanned'),
        const SizedBox(height: 8),
        _historyCollage(_batch),
        if (_batch.scannedCount > _batch.rows.length)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  '${_batch.scannedCount - _batch.rows.length} images need another scan and were not saved.')),
        const SizedBox(height: 12),
        _BatchPanel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Results by condition',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final e in _batch.conditions.entries) ...[
            _HistoryConditionRow(
                label: e.key,
                indices: [
                  for (var i = 0; i < _batch.rows.length; i++)
                    if (_batch.rows[i]['disease'] == e.key) i
                ],
                results: _batch.results),
            const SizedBox(height: 8)
          ],
          if (_batch.conditions.keys
              .any((label) => !_isHealthyCondition(label)))
            TextButton.icon(
                onPressed: () => _openBatchCare(context, _batch),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('View recommendations')),
        ])),
        const SizedBox(height: 12),
        _BatchPanel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Report status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _BatchStatus(batch: _batch, detail: true),
          const SizedBox(height: 16),
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: () async {
                    await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                BatchReportSummaryScreen(batch: _batch)));
                    await _reload();
                  },
                  child: const Text('View report summary')))
        ])),
      ]);
}

Widget _historyCollage(ScanHistoryBatch batch) => _BatchPanel(
    child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: batch.rows.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 5,
            mainAxisSpacing: 5,
            childAspectRatio: .8),
        itemBuilder: (_, index) => _BatchPhoto(
            result: batch.results[index],
            number:
                ((batch.rows[index]['batch_image_index'] as int?) ?? index) +
                    1)));

void _openBatchCare(BuildContext context, ScanHistoryBatch batch) {
  final groups = <String, List<int>>{};
  for (var i = 0; i < batch.rows.length; i++) {
    if (_isHealthyCondition(batch.rows[i]['disease'] as String)) continue;
    groups.putIfAbsent(batch.rows[i]['disease'] as String, () => []).add(i);
  }
  go(
      context,
      _BatchHistoryPage(title: 'Diagnosis results', children: [
        _BatchCare(conditions: groups.keys.toList(), groups: groups)
      ]));
}

class _HistoryConditionRow extends StatelessWidget {
  const _HistoryConditionRow(
      {required this.label, required this.indices, required this.results});
  final String label;
  final List<int> indices;
  final List<BatchScanResult> results;
  @override
  Widget build(BuildContext context) {
    final scores =
        indices.map((i) => results[i].prediction!.confidence).toList()..sort();
    final min = (scores.first * 100).toStringAsFixed(0);
    final max = (scores.last * 100).toStringAsFixed(0);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      leading: Icon(Icons.circle, size: 15, color: _batchConditionColor(label)),
      title: Text(context.t(label),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Wrap(spacing: 12, runSpacing: 4, children: [
        Text(
            '${indices.length} ${indices.length == 1 ? 'image' : 'images'} - ${(indices.length / results.length * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 12)),
        Text('Confidence ${min == max ? min : '$min-$max'}%',
            style: const TextStyle(fontSize: 12)),
      ]),
      children: [
        SizedBox(
            height: 135,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: indices.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => SizedBox(
                  width: 100,
                  child: _BatchPhoto(
                      result: results[indices[i]],
                      number: indices[i] + 1,
                      showConfidence: true)),
            ))
      ],
    );
  }
}

class _BatchHistoryPage extends StatelessWidget {
  const _BatchHistoryPage(
      {required this.title, required this.children, this.controller});
  final String title;
  final List<Widget> children;
  final ScrollController? controller;
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: CcColors.bg,
      appBar: AppBar(
          title: Text(title,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          backgroundColor: CcColors.bg,
          surfaceTintColor: Colors.transparent),
      body: SafeArea(
          top: false,
          maintainBottomViewPadding: true,
          minimum: const EdgeInsets.only(bottom: 16),
          child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      children: children)))));
}

class BatchReportSummaryScreen extends StatefulWidget {
  const BatchReportSummaryScreen({super.key, required this.batch});
  final ScanHistoryBatch batch;
  @override
  State<BatchReportSummaryScreen> createState() =>
      _BatchReportSummaryScreenState();
}

class _BatchReportSummaryScreenState extends State<BatchReportSummaryScreen> {
  late ScanHistoryBatch _batch = widget.batch;
  final _scroll = ScrollController();
  bool _showOfflineActions = false;
  bool _sending = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _revealOfflineActions() async {
    if (!mounted || !_showOfflineActions || !_scroll.hasClients) return;
    if (!MediaQuery.disableAnimationsOf(context)) {
      await _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic);
    }
    if (!mounted || !_showOfflineActions || !_scroll.hasClients) return;
    // Lazy children can change the estimated bottom during the animation.
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  Future<void> _send() async {
    if (_sending) return;
    if (_sending) return;
    final state = AppScope.of(context);
    if (!state.consentEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enable report consent before sending.')));
      return;
    }
    if (!await ensureAccountReady(context) || !mounted) return;
    if (!await ensureReportProfileComplete(context) || !mounted) return;
    setState(() => _sending = true);
    try {
      await DiagnosisRepository.instance.queueBatchReports(
          diagnosisIds: _batch.rows.map((r) => r['id'] as int).toList(),
          settings: state.currentSettings());
      for (final row in _batch.rows) {
        await DiagnosisRepository.instance
            .markDiagnosisReportForRetry(row['id'] as int);
      }
      await state.checkConnectivityAndSync();
      await state.refreshStats();
      final batches = groupScanHistory(
          await DiagnosisRepository.instance.getRecentDiagnoses(limit: null));
      final matches = batches.where((b) => b.key == _batch.key);
      if (!mounted) return;
      if (matches.isNotEmpty) setState(() => _batch = matches.first);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_batch.sent
              ? 'Batch reports sent.'
              : DiagnosisRepository.instance.lastReportSyncError ??
                  'Batch is saved and waiting to send.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not send the batch. Your saved results are still on this device.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final report = _batch.rows
        .firstWhere((row) => row['report_id'] != null, orElse: () => const {});
    final farmer = report['report_farmer_name'] as String? ?? state.farmerName;
    final location =
        report['report_farmer_location'] as String? ?? state.farmerLocation;
    final recipient = report['report_email'] as String? ?? state.officeEmail;
    final showOfflineActions = !state.isOnline && _batch.waiting && !_sending;
    if (showOfflineActions && !_showOfflineActions) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => unawaited(_revealOfflineActions()));
    }
    _showOfflineActions = showOfflineActions;
    return _BatchHistoryPage(
        title: 'Report summary',
        controller: _scroll,
        children: [
          _BatchPanel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(_batch.title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                Text(_formatHistoryDateTime(_batch.date.toIso8601String())),
                const SizedBox(height: 12),
                _BatchStrip(batch: _batch),
                const SizedBox(height: 8),
                Text('${_batch.rows.length} saved images'),
                const Divider(height: 24),
                _summaryField(Icons.person_outline, 'Farmer',
                    farmer.isEmpty ? 'Not set' : farmer),
                _summaryField(Icons.location_on_outlined, 'Location',
                    location.isEmpty ? 'Not set' : location),
                _summaryField(Icons.account_balance_outlined, 'Recipient',
                    recipient.isEmpty ? 'Not set' : recipient),
              ])),
          const SizedBox(height: 12),
          _BatchPanel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Batch results',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                    '${_batch.rows.length} images • ${_batch.conditions.length} conditions',
                    style:
                        const TextStyle(fontSize: 13, color: CcColors.muted)),
                const SizedBox(height: 12),
                Table(
                    border: const TableBorder(
                        horizontalInside: BorderSide(color: CcColors.line)),
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(),
                      2: FlexColumnWidth()
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      const TableRow(children: [
                        Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text('Condition',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: CcColors.muted,
                                    fontWeight: FontWeight.w600))),
                        Text('Images',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                color: CcColors.muted,
                                fontWeight: FontWeight.w600)),
                        Text('Share',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 12,
                                color: CcColors.muted,
                                fontWeight: FontWeight.w600))
                      ]),
                      for (final e in _batch.conditions.entries)
                        TableRow(children: [
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                        padding: const EdgeInsets.only(
                                            top: 4, right: 8),
                                        child: Icon(Icons.circle,
                                            size: 8,
                                            color: _reportRiskColor(e.key))),
                                    Expanded(
                                        child: Text(context.t(e.key),
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: _reportRiskColor(e.key),
                                                fontWeight: FontWeight.w600))),
                                  ])),
                          Text('${e.value.length}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    '${(e.value.length / _batch.rows.length * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                    textAlign: TextAlign.right),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                    value: e.value.length / _batch.rows.length,
                                    minHeight: 4,
                                    borderRadius: BorderRadius.circular(2),
                                    color: _reportRiskColor(e.key),
                                    backgroundColor: CcColors.line),
                              ])
                        ]),
                    ]),
                ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Confidence and matching photos',
                        style: TextStyle(fontSize: 14)),
                    children: [
                      for (final e in _batch.conditions.entries)
                        _HistoryConditionRow(
                            label: e.key,
                            indices: [
                              for (var i = 0; i < _batch.rows.length; i++)
                                if (_batch.rows[i]['disease'] == e.key) i
                            ],
                            results: _batch.results)
                    ]),
              ])),
          const SizedBox(height: 12),
          if (_batch.conditions.keys
              .any((label) => !_isHealthyCondition(label)))
            _BatchPanel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Recommendations included',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  for (final e in _batch.conditions.entries)
                    if (!_isHealthyCondition(e.key))
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.circle,
                              size: 14, color: _batchConditionColor(e.key)),
                          title: Text(context.t(e.key),
                              style: const TextStyle(fontSize: 14)),
                          subtitle: const Text('Natural & conventional',
                              style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openBatchCare(context, _batch))
                ])),
          const SizedBox(height: 12),
          _BatchPanel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Report status',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _BatchStatus(batch: _batch, detail: true),
                if (!_batch.sent) ...[
                  const SizedBox(height: 12),
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow sending diagnosis details',
                          style: TextStyle(fontSize: 13)),
                      value: state.consentEnabled,
                      onChanged: _sending
                          ? null
                          : (value) {
                              state.setConsent(value ?? false);
                              setState(() {});
                            }),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: _sending ? null : _send,
                          child: _sending
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                      SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              semanticsLabel:
                                                  'Sending report')),
                                      SizedBox(width: 12),
                                      Flexible(child: Text('Sending...')),
                                    ])
                              : Text(_batch.rows.length == 1
                                  ? 'Send Report'
                                  : _batch.waiting
                                      ? 'Try sending now'
                                      : 'Send batch report')))
                ],
                if (showOfflineActions) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.dashboard_outlined),
                        label: const Text('Go to Dashboard'),
                        onPressed: () {
                          state.setTab(0);
                          Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute<void>(
                                  builder: (_) => const MainShell()),
                              (_) => false);
                        },
                      )),
                ],
              ])),
        ]);
  }

  Color _reportRiskColor(String label) => switch (_batchRisk(label)) {
        'No risk' || 'Low risk' => CcColors.green,
        'High risk' => Colors.red.shade700,
        _ => const Color(0xFFAF7B18),
      };

  Widget _summaryField(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: CcColors.muted),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: CcColors.muted)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: CcColors.ink,
                  fontWeight: FontWeight.w500)),
        ]))
      ]));
}
