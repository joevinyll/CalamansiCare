part of '../../main.dart';

typedef BatchScanResult = ({
  XFile file,
  DiseasePrediction? prediction,
  int? id,
  String? error,
});

const _batchIssueGroups = {
  'Needs another scan',
  'Could not scan',
  'Could not save'
};

String _batchResultLabel(BatchScanResult result) {
  if (result.prediction == null) return 'Could not scan';
  if (confidenceTier(result.prediction!.confidence) !=
      ConfidenceTier.accepted) {
    return 'Needs another scan';
  }
  if (result.id == null || result.error != null) return 'Could not save';
  return result.prediction!.label;
}

class BatchResultsScreen extends StatelessWidget {
  const BatchResultsScreen({super.key, required this.results});
  final List<BatchScanResult> results;

  Future<void> _viewReportSummary(BuildContext context) async {
    final ids = results
        .where((r) => r.id != null && r.error == null)
        .map((r) => r.id!)
        .toSet();
    try {
      final rows =
          (await DiagnosisRepository.instance.getRecentDiagnoses(limit: null))
              .where((row) => ids.contains(row['id']))
              .toList();
      if (!context.mounted) return;
      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No saved images are available to report.')));
        return;
      }
      await Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) =>
              BatchReportSummaryScreen(batch: ScanHistoryBatch(rows))));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not open the report summary. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<int>>{};
    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      final label = _batchResultLabel(result);
      groups.putIfAbsent(label, () => []).add(i);
    }
    final conditions = groups.keys
        .where((key) =>
            !_batchIssueGroups.contains(key) && !_isHealthyCondition(key))
        .toList();
    final textTheme = Theme.of(context)
        .textTheme
        .apply(
          fontFamily: 'Roboto',
          bodyColor: const Color(0xFF263B31),
          displayColor: const Color(0xFF20372A),
          letterSpacingFactor: 0,
          letterSpacingDelta: 0,
        )
        .copyWith(
          bodyLarge: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15,
              height: 1.5,
              letterSpacing: 0,
              color: Color(0xFF263B31)),
          bodyMedium: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              height: 1.5,
              letterSpacing: 0,
              color: Color(0xFF52645A)),
          titleMedium: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              color: Color(0xFF20372A)),
          labelLarge: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0),
        );
    return Theme(
        data: Theme.of(context).copyWith(
          textTheme: textTheme,
          dividerColor: const Color(0xFFE5EBE6),
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: const Color(0xFF36764B),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: const Color(0xFF263B31),
                onSurfaceVariant: const Color(0xFF52645A),
              ),
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: CcColors.line),
            ),
            title:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Diagnosis results',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text('${results.length} images scanned',
                  style: const TextStyle(fontSize: 13, color: CcColors.muted)),
            ]),
          ),
          body: SafeArea(
              top: false,
              maintainBottomViewPadding: true,
              minimum: const EdgeInsets.only(bottom: 16),
              child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                      _BatchPanel(
                          child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: results.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6,
                                childAspectRatio: .8),
                        itemBuilder: (_, index) => _BatchPhoto(
                            result: results[index], number: index + 1),
                      )),
                      const SizedBox(height: 20),
                      _BatchPanel(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('Batch summary',
                                style: TextStyle(
                                    fontSize: 20,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600)),
                            const Text('Share of scanned images',
                                style: TextStyle(color: CcColors.muted)),
                            const SizedBox(height: 12),
                            for (final entry in groups.entries) ...[
                              _BatchCondition(
                                  label: entry.key,
                                  indices: entry.value,
                                  results: results),
                              if (entry.key != groups.keys.last)
                                const Divider(height: 28, color: CcColors.line),
                            ],
                          ])),
                      if (conditions.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _BatchCare(conditions: conditions, groups: groups),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () {
                            AppScope.of(context).setTab(1);
                            go(context, const HistoryScreen());
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: CcColors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.save_alt_rounded),
                          label: const Text('Save results'),
                        ),
                      ],
                      if (results
                          .any((r) => r.id != null && r.error == null)) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _viewReportSummary(context),
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('View report summary'),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52)),
                        ),
                      ],
                      TextButton(
                          onPressed: () => Navigator.maybePop(context),
                          child: const Text('Back to camera')),
                    ]),
                  ))),
        ));
  }
}

Color _batchConditionColor(String label) {
  if (_batchIssueGroups.contains(label)) return CcColors.muted;
  if (label.toLowerCase().contains('healthy')) return CcColors.green;
  if (label == 'Melanose') return const Color(0xFFC46D56);
  if (label.contains('HLB') || label.contains('Canker')) {
    return Colors.red.shade700;
  }
  return const Color(0xFFAF7B18);
}

bool _isHealthyCondition(String label) =>
    label.toLowerCase().contains('healthy');

String? diseaseSpreadFor(String label) => switch (label) {
      'HLB (Greening)' =>
        'Citrus psyllid insects and infected grafting material.',
      'Citrus Canker' =>
        'Mainly wind-driven rain; also infected plants, tools, hands, and clothing.',
      'Brown Spot' => 'If caused by Alternaria: airborne fungal spores.',
      'Anthracnose' => 'Mainly dripping and splashing water carrying spores.',
      'Citrus Scab' => 'Water splash carrying spores from existing lesions.',
      'Melanose' => 'Rain carries spores mainly from dead twigs.',
      _ => null,
    };

String _batchRisk(String label) {
  if (_isHealthyCondition(label)) return 'No risk';
  if (label.contains('HLB') || label.contains('Canker')) return 'High risk';
  return 'Medium risk';
}

class _BatchPanel extends StatelessWidget {
  const _BatchPanel(
      {required this.child,
      this.color = Colors.white,
      this.borderColor = CcColors.line});
  final Widget child;
  final Color color;
  final Color borderColor;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor)),
        child: Material(color: Colors.transparent, child: child),
      );
}

class _BatchPhoto extends StatelessWidget {
  const _BatchPhoto(
      {required this.result,
      required this.number,
      this.showConfidence = false});
  final BatchScanResult result;
  final int number;
  final bool showConfidence;
  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(
            child: Semantics(
          label: 'View image $number',
          button: true,
          child: InkWell(
              onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => Dialog(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                  tooltip: 'Close',
                                  onPressed: () => Navigator.pop(dialogContext),
                                  icon: const Icon(Icons.close))),
                          Flexible(
                              child: InteractiveViewer(
                                  child: Image.file(File(result.file.path),
                                      cacheWidth: 1600,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          const Padding(
                                              padding: EdgeInsets.all(24),
                                              child:
                                                  Text('Photo unavailable'))))),
                          Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(result.error ??
                                  'Image $number: ${result.prediction!.label} - ${(result.prediction!.confidence * 100).toStringAsFixed(0)}% confidence')),
                          if (result.id != null && result.error == null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextButton.icon(
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Open scan details'),
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  go(
                                      context,
                                      DiagnosisScreen(
                                        prediction: result.prediction!,
                                        imageFile: result.file,
                                        diagnosisId: result.id!,
                                        imageNumber: number,
                                      ));
                                },
                              ),
                            ),
                        ]),
                      )),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(fit: StackFit.expand, children: [
                    Image.file(File(result.file.path),
                        fit: BoxFit.cover,
                        cacheWidth: 300,
                        gaplessPlayback: true,
                        frameBuilder: (context, child, frame, synchronous) =>
                            synchronous || frame != null
                                ? child
                                : const ColoredBox(
                                    color: Color(0xFFEEF2ED),
                                    child: Center(
                                        child: Icon(Icons.image_outlined,
                                            color: CcColors.muted)),
                                  ),
                        errorBuilder: (_, __, ___) => const ColoredBox(
                            color: CcColors.bg,
                            child: Icon(Icons.broken_image_outlined))),
                    Positioned(
                        left: 3,
                        bottom: 3,
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: .75),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text('$number',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11)))),
                  ]))),
        )),
        if (showConfidence)
          Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                  'Image $number${result.prediction == null ? '' : ' - ${(result.prediction!.confidence * 100).toStringAsFixed(0)}%'}',
                  style: const TextStyle(
                      fontSize: 12, height: 1.35, letterSpacing: 0))),
      ]);
}

class _BatchCondition extends StatefulWidget {
  const _BatchCondition(
      {required this.label, required this.indices, required this.results});
  final String label;
  final List<int> indices;
  final List<BatchScanResult> results;
  @override
  State<_BatchCondition> createState() => _BatchConditionState();
}

class _BatchConditionState extends State<_BatchCondition> {
  bool _expanded = false;
  String get label => widget.label;
  List<int> get indices => widget.indices;
  List<BatchScanResult> get results => widget.results;
  @override
  Widget build(BuildContext context) {
    final accepted = !_batchIssueGroups.contains(label);
    final color = _batchConditionColor(label);
    final percent = indices.length / results.length;
    final confidences = indices
        .map((i) => results[i].prediction?.confidence)
        .whereType<double>()
        .toList()
      ..sort();
    final confidence = confidences.isEmpty
        ? ''
        : confidences.first == confidences.last
            ? '${(confidences.first * 100).toStringAsFixed(0)}%'
            : '${(confidences.first * 100).toStringAsFixed(0)}-${(confidences.last * 100).toStringAsFixed(0)}%';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(top: 2, right: 12),
            child: Icon(Icons.circle, size: 18, color: color)),
        Expanded(
            child: Text(context.t(label),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16, height: 1.3))),
        const SizedBox(width: 6),
        Flexible(
            child: Text(
                '${(percent * 100).toStringAsFixed(0)}% (${indices.length} ${indices.length == 1 ? 'image' : 'images'})',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13, height: 1.5))),
      ]),
      const SizedBox(height: 10),
      Padding(
          padding: const EdgeInsets.only(left: 30),
          child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              color: color,
              backgroundColor: CcColors.line,
              borderRadius: BorderRadius.circular(4))),
      const SizedBox(height: 6),
      Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Text(
                    accepted
                        ? 'Confidence: $confidence'
                        : switch (label) {
                            'Could not save' =>
                              'Predictions were produced but could not be saved. Restart the app and try again.',
                            'Could not scan' =>
                              'These images could not be processed. Try scanning them again.',
                            _ =>
                              'Retake these images in good lighting and keep the calamansi fruit or leaf clearly in focus.',
                          },
                    style:
                        const TextStyle(color: CcColors.muted, fontSize: 13))),
            if (accepted && !_expanded) ...[
              const SizedBox(width: 8),
              Flexible(
                  child: Text(
                      context
                          .t(_batchRisk(label))
                          .replaceFirst(' risk', ' Risk'),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 13,
                          color: switch (_batchRisk(label)) {
                            'High risk' => Colors.red.shade700,
                            'Low risk' || 'No risk' => CcColors.green,
                            _ => const Color(0xFFAF7B18),
                          }))),
            ],
          ])),
      const SizedBox(height: 8),
      ExpansionTile(
        onExpansionChanged: (expanded) => setState(() => _expanded = expanded),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.all(12),
        collapsedBackgroundColor: const Color(0xFFF5F6F7),
        backgroundColor: color.withValues(alpha: .05),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: color.withValues(alpha: .4))),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('View Images', style: TextStyle(fontSize: 14)),
        children: [
          SizedBox(
              height: 140,
              child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: indices.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => SizedBox(
                      width: 110,
                      child: _BatchPhoto(
                          result: results[indices[i]],
                          number: indices[i] + 1,
                          showConfidence: true)))),
        ],
      ),
    ]);
  }
}

class _BatchCare extends StatefulWidget {
  const _BatchCare({required this.conditions, required this.groups});
  final List<String> conditions;
  final Map<String, List<int>> groups;
  @override
  State<_BatchCare> createState() => _BatchCareState();
}

class _BatchCareState extends State<_BatchCare> {
  late String _selected = widget.conditions.first;
  final _pages = PageController(viewportFraction: .9);
  int _page = 0;
  int? _targetPage;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _selectPage(int page) async {
    if (!_pages.hasClients ||
        _targetPage != null ||
        (_pages.page! - page).abs() < .001) {
      return;
    }
    setState(() => _targetPage = page);
    try {
      if (MediaQuery.disableAnimationsOf(context)) {
        _pages.jumpToPage(page);
      } else {
        await _pages.animateToPage(page,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeInOutCubic);
      }
    } finally {
      if (mounted) setState(() => _targetPage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final advice = guidanceFor(_selected);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Recommendations',
          style: TextStyle(
              fontSize: 20, height: 1.3, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      const Text('Select a condition to view care options.',
          style: TextStyle(color: CcColors.muted, fontSize: 14)),
      const SizedBox(height: 12),
      StickyHeader(
        header: Material(
            key: const ValueKey('sticky-care-selector'),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: LayoutBuilder(
                    builder: (context, constraints) => DropdownMenu<String>(
                          key: ValueKey(_selected),
                          width: constraints.maxWidth,
                          initialSelection: _selected,
                          requestFocusOnTap: false,
                          textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF263B31),
                              letterSpacing: 0),
                          leadingIcon: Icon(Icons.circle,
                              size: 14, color: _batchConditionColor(_selected)),
                          trailingIcon: const Icon(Icons.expand_more_rounded,
                              color: CcColors.green),
                          selectedTrailingIcon: const Icon(
                              Icons.expand_less_rounded,
                              color: CcColors.green),
                          inputDecorationTheme: InputDecorationTheme(
                            filled: true,
                            fillColor: const Color(0xFFF7FAF6),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: CcColors.line)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: CcColors.line)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: CcColors.green)),
                          ),
                          menuStyle: MenuStyle(
                            backgroundColor:
                                const WidgetStatePropertyAll(Colors.white),
                            surfaceTintColor: const WidgetStatePropertyAll(
                                Colors.transparent),
                            elevation: const WidgetStatePropertyAll(3),
                            minimumSize: WidgetStatePropertyAll(
                                Size(constraints.maxWidth, 0)),
                            maximumSize: WidgetStatePropertyAll(
                                Size(constraints.maxWidth, 320)),
                            shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8))),
                            side: const WidgetStatePropertyAll(
                                BorderSide(color: CcColors.line)),
                            padding: const WidgetStatePropertyAll(
                                EdgeInsets.symmetric(vertical: 6)),
                          ),
                          dropdownMenuEntries: widget.conditions
                              .map((label) => DropdownMenuEntry<String>(
                                    value: label,
                                    label: context.t(label),
                                    leadingIcon: Icon(Icons.circle,
                                        size: 12,
                                        color: _batchConditionColor(label)),
                                    trailingIcon: label == _selected
                                        ? const Icon(Icons.check_rounded,
                                            size: 18, color: CcColors.green)
                                        : null,
                                  ))
                              .toList(),
                          onSelected: (label) {
                            if (label != null) {
                              setState(() => _selected = label);
                            }
                          },
                        )))),
        content:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Text('${widget.groups[_selected]!.length} matching images'),
          Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                    width: MediaQuery.textScalerOf(context).scale(140) + 16,
                    child: Chip(
                        backgroundColor: _batchConditionColor(_selected)
                            .withValues(alpha: .06),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        side:
                            BorderSide(color: _batchConditionColor(_selected)),
                        label: Text(
                            context
                                .t(_batchRisk(_selected))
                                .replaceFirst(' risk', ' Risk'),
                            style: const TextStyle(fontSize: 14)),
                        avatar: Icon(Icons.warning_amber_rounded,
                            size: 18, color: _batchConditionColor(_selected)))),
                Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF4F6),
                      border: Border.all(color: const Color(0xFFD2E3E8)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          guidanceFor(_selected).kind == 'Bacterial disease'
                              ? Icons.biotech_outlined
                              : Icons.eco_outlined,
                          size: 18,
                          color: const Color(0xFF275D6B)),
                      const SizedBox(width: 7),
                      Flexible(
                          child: Text(context.t(guidanceFor(_selected).kind),
                              key: const ValueKey('care-disease-type'),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF275D6B)))),
                    ])),
              ]),
          if (diseaseSpreadFor(_selected) != null) ...[
            const SizedBox(height: 12),
            _BatchPanel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.hub_outlined, size: 22, color: CcColors.green),
                      SizedBox(width: 10),
                      Expanded(
                          child: Text('How it spreads',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: CcColors.ink))),
                    ]),
                    const SizedBox(height: 10),
                    Text(diseaseSpreadFor(_selected)!,
                        key: const ValueKey('care-disease-spread'),
                        style: const TextStyle(
                            fontSize: 14, height: 1.5, color: CcColors.ink)),
                  ]),
            ),
          ],
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _pages,
            builder: (context, _) {
              final progress =
                  _pages.hasClients && _pages.position.hasContentDimensions
                      ? (_pages.page ?? _page.toDouble()).clamp(0.0, 1.0)
                      : _page.toDouble();
              return LayoutBuilder(
                  builder: (context, constraints) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Material(
                          color: const Color(0xFFF6F8FA),
                          child: Stack(children: [
                            Row(children: [
                              for (var i = 0; i < 2; i++)
                                Expanded(
                                    child: Semantics(
                                  selected: (_targetPage ?? _page) == i,
                                  button: true,
                                  child: TextButton.icon(
                                    key: ValueKey('care-tab-$i'),
                                    onPressed: () => _selectPage(i),
                                    icon: Icon(
                                        i == 0
                                            ? Icons.eco_outlined
                                            : Icons.science_outlined,
                                        size: 18),
                                    label: Text(
                                        i == 0 ? 'Natural' : 'Conventional'),
                                    style: TextButton.styleFrom(
                                        backgroundColor: Color.lerp(
                                            const Color(0xFFF6F8FA),
                                            CcColors.green,
                                            i == 0 ? 1 - progress : progress),
                                        side: const BorderSide(
                                            color: CcColors.line),
                                        minimumSize: const Size(0, 48),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6),
                                        foregroundColor: (i == 0
                                                ? progress < .5
                                                : progress >= .5)
                                            ? Colors.white
                                            : CcColors.ink,
                                        textStyle: const TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700),
                                        shape: const RoundedRectangleBorder()),
                                  ),
                                )),
                            ]),
                          ]),
                        ),
                      ));
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
              height: 330,
              child: PageView(
                controller: _pages,
                padEnds: false,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  _carePanel(context, 'Natural care', Icons.eco_outlined,
                      [advice.organicTreatment]),
                  _carePanel(context, 'Conventional treatment',
                      Icons.science_outlined, [
                    advice.conventionalTreatment,
                    chemicalTreatmentReminder.english
                  ]),
                ],
              )),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _carouselArrow(
                'Natural care',
                Icons.chevron_left,
                _targetPage != null || _page == 0
                    ? null
                    : () => _selectPage(0)),
            const SizedBox(width: 12),
            for (var i = 0; i < 2; i++)
              Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(_page == i ? Icons.circle : Icons.circle_outlined,
                      size: 10, color: CcColors.green)),
            const SizedBox(width: 12),
            _carouselArrow(
                'Conventional treatment',
                Icons.chevron_right,
                _targetPage != null || _page == 1
                    ? null
                    : () => _selectPage(1)),
          ]),
          const SizedBox(height: 16),
          _BatchPanel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Prevention',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CcColors.ink)),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.shield_outlined,
                    size: 20, color: CcColors.green),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(advice.prevention,
                        key: const ValueKey('care-prevention'),
                        style: const TextStyle(
                            fontSize: 14, height: 1.5, color: CcColors.ink))),
              ]),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _carouselArrow(String label, IconData icon, VoidCallback? onPressed) =>
      Material(
        color: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
        child: IconButton(
            tooltip: label,
            onPressed: onPressed,
            icon: Icon(icon),
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero),
      );

  Widget _carePanel(BuildContext context, String title, IconData icon,
          List<String> paragraphs) =>
      Padding(
          padding: const EdgeInsets.only(left: 8, right: 8),
          child: _BatchPanel(
              color: icon == Icons.eco_outlined
                  ? const Color(0xFFF4F8F2)
                  : const Color(0xFFF3F6F9),
              borderColor: icon == Icons.eco_outlined
                  ? const Color(0xFFDFE8DA)
                  : const Color(0xFFDFE5EC),
              child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Icon(icon, size: 26, color: const Color(0xFF36764B)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 17,
                                  height: 1.3,
                                  letterSpacing: 0,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF20372A)))),
                    ]),
                    for (final text in paragraphs)
                      Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                    padding: EdgeInsets.only(top: 9, right: 10),
                                    child: Icon(Icons.circle,
                                        size: 5, color: CcColors.green)),
                                Expanded(
                                    child: Text(context.t(text),
                                        style: const TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: 15,
                                            height: 1.55,
                                            letterSpacing: 0,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF344B3D)))),
                              ])),
                  ]))));
}
