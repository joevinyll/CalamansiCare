part of '../../main.dart';

class BarangayReportsScreen extends StatefulWidget {
  const BarangayReportsScreen({super.key, this.loadReports});
  final Future<List<CommunityReport>> Function()? loadReports;
  @override
  State<BarangayReportsScreen> createState() => _BarangayReportsScreenState();
}

class _BarangayReportsScreenState extends State<BarangayReportsScreen> {
  late Future<List<CommunityReport>> _future;
  String? _expanded;
  bool _initialSelection = true;
  bool _chart = false;
  String _filter = 'All';
  final _expandedCard = GlobalKey();
  final _scroll = ScrollController();
  double _bottomSpace = 34;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _selectReport(CommunityReport report) {
    final opening = _expanded != report.id;
    setState(() {
      _expanded = opening ? report.id : null;
      if (!opening) _bottomSpace = 34;
    });
    if (!opening) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final card = _expandedCard.currentContext;
      if (!mounted ||
          _expanded != report.id ||
          card == null ||
          !_scroll.hasClients) {
        return;
      }
      final box = card.findRenderObject() as RenderBox;
      // Enough trailing space lets the final short card align below the header too.
      setState(() => _bottomSpace =
          max(34, _scroll.position.viewportDimension - box.size.height));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _expandedCard.currentContext;
        if (!mounted || _expanded != report.id || target == null) return;
        unawaited(Scrollable.ensureVisible(target,
            alignment: 0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic));
      });
    });
  }

  static const _green = Color(0xFF1E4D34);
  static const _colors = [
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFF43F5E)
  ];
  static const _risks = ['Low', 'Medium', 'High'];

  Future<List<CommunityReport>> _load() => (widget.loadReports ??
      DiagnosisRepository.instance.fetchCommunityReports)();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _refreshReports() async {
    if (widget.loadReports == null) {
      await AppScope.of(context).checkConnectivityAndSync();
    }
    if (!mounted) return;
    final next = _load();
    setState(() {
      _future = next;
      _initialSelection = true;
    });
    await next;
  }

  Widget _surface(Widget child, {bool selected = false}) => Container(
      decoration: BoxDecoration(
          color: selected ? const Color(0xFFE7F2E4) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected
                  ? const Color(0xFF91B99A)
                  : const Color(0xFFE0E8DC))),
      child: child);

  Widget _field(String label, Widget value) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: CcColors.muted))),
        const SizedBox(width: 12),
        Expanded(child: Align(alignment: Alignment.centerRight, child: value)),
      ]));

  Widget _overview(List<CommunityReport> reports) {
    final counts = [
      for (final risk in _risks)
        reports.where((r) => communityRiskLabel(r) == '$risk risk').length
    ];
    final total = counts.fold<int>(0, (a, b) => a + b);
    return _surface(Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                const Text('Community overview',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                TextButton(
                    onPressed: () => setState(() => _chart = !_chart),
                    style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFECF3E9),
                        foregroundColor: _green,
                        padding: const EdgeInsets.symmetric(horizontal: 10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_chart ? 'Hide Chart' : 'Show Chart',
                          style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Icon(_chart ? Icons.expand_less : Icons.expand_more,
                          size: 16),
                    ])),
              ]),
          _field(
              'Reports source',
              const Text('Other app users',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          _field(
              'Shared reports',
              Text('${reports.length} shared reports',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700))),
          _field(
              'Status',
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var i = 0; i < 3; i++)
                  Text('${counts[i]} ${_risks[i]} risk',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _colors[i])),
              ])),
          const SizedBox(height: 12),
          Semantics(
              button: true,
              label: 'Toggle risk breakdown chart',
              child: InkWell(
                  onTap: () => setState(() => _chart = !_chart),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                              height: 10,
                              child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: total == 0
                                      ? [
                                          const Expanded(
                                              child: ColoredBox(
                                                  color: Color(0xFFEEF1ED)))
                                        ]
                                      : [
                                          for (var i = 0; i < 3; i++)
                                            if (counts[i] > 0)
                                              Expanded(
                                                  flex: counts[i],
                                                  child: ColoredBox(
                                                      color: _colors[i]))
                                        ])))))),
          if (_chart) ...[
            const Divider(height: 24),
            const Text('RISK BREAKDOWN',
                style: TextStyle(
                    fontSize: 11,
                    color: CcColors.muted,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
                height: 160,
                child:
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                        child: Semantics(
                            button: true,
                            label:
                                'Filter ${_risks[i]} risk, ${counts[i]} reports',
                            child: InkWell(
                                key: ValueKey('risk-chart-${_risks[i]}'),
                                onTap: () =>
                                    setState(() => _filter = _risks[i]),
                                child: Column(children: [
                                  Text('${counts[i]}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                  Expanded(
                                      child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: FractionallySizedBox(
                                              heightFactor: counts[i] /
                                                  max(1, counts.reduce(max)),
                                              child: Container(
                                                  width: 24,
                                                  decoration: BoxDecoration(
                                                      color: _colors[i],
                                                      borderRadius:
                                                          const BorderRadius
                                                              .vertical(
                                                              top: Radius
                                                                  .circular(
                                                                      6))))))),
                                  const SizedBox(height: 8),
                                  Text('${_risks[i]} risk',
                                      style: const TextStyle(fontSize: 10)),
                                ])))),
                ])),
          ],
        ])));
  }

  Widget _filters() => Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            const Text('REPORT HISTORY',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0E8DC))),
                child: Wrap(children: [
                  for (final risk in ['All', 'Medium', 'High', 'Low'])
                    TextButton(
                        key: ValueKey('risk-filter-$risk'),
                        onPressed: () => setState(() => _filter = risk),
                        style: TextButton.styleFrom(
                            foregroundColor:
                                _filter == risk ? Colors.white : CcColors.muted,
                            backgroundColor:
                                _filter == risk ? _green : Colors.transparent,
                            minimumSize: const Size(48, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 9),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6))),
                        child: Text(risk,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700))),
                ])),
          ]);

  Widget _reportCard(CommunityReport report) {
    final open = _expanded == report.id;
    final risk = communityRiskLabel(report);
    final index = _risks.indexWhere((r) => risk == '$r risk');
    final color = _colors[index < 0 ? 1 : index];
    final guidance = guidanceFor(report.disease);
    Widget detail(String title, String text, IconData icon, Color background) =>
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDCE7D8))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 16, color: _green),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)))
              ]),
              const SizedBox(height: 6),
              Text(text, style: const TextStyle(fontSize: 12, height: 1.5)),
            ]));
    return KeyedSubtree(
        key: open ? _expandedCard : ValueKey('card-${report.id}'),
        child: _surface(
            Column(children: [
              Semantics(
                  button: true,
                  expanded: open,
                  child: InkWell(
                      key: ValueKey('report-${report.id}'),
                      onTap: () => _selectReport(report),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            SizedBox(
                                width: 48,
                                height: 48,
                                child: CommunityReportPhoto(
                                    imageUrl: report.imageUrl, height: 48)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(report.disease,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${report.location} · ${(report.confidence * 100).toStringAsFixed(0)}% confidence',
                                      style: const TextStyle(
                                          fontSize: 11, color: CcColors.muted)),
                                  const SizedBox(height: 5),
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: color.withValues(alpha: .12),
                                          borderRadius:
                                              BorderRadius.circular(5)),
                                      child: Text(risk,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: index == 0
                                                  ? _green
                                                  : index == 2
                                                      ? const Color(0xFFBE123C)
                                                      : const Color(0xFFB46309),
                                              fontWeight: FontWeight.w700))),
                                ])),
                            const SizedBox(width: 4),
                            Icon(open ? Icons.expand_less : Icons.expand_more,
                                color: CcColors.muted, size: 20),
                          ])))),
              if (open)
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(children: [
                      const Divider(height: 16),
                      Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                                'Recorded: ${report.reportedAt.isEmpty ? 'Not recorded' : _formatHistoryDateTime(report.reportedAt)}',
                                style: const TextStyle(
                                    fontSize: 11, color: CcColors.muted)),
                            const Text('AI prediction · Not confirmed',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _green,
                                    fontWeight: FontWeight.w600)),
                          ]),
                      const SizedBox(height: 12),
                      detail(
                          'Disease information',
                          diseaseDescriptionFor(report.disease),
                          Icons.info_outline,
                          Colors.white.withValues(alpha: .8)),
                      const SizedBox(height: 10),
                      detail('Action advice', guidance.recommendation,
                          Icons.shield_outlined, const Color(0xFFF0F8EF)),
                      const SizedBox(height: 12),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: _green,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8))),
                              onPressed: () => go(context,
                                  BarangayReportDetailScreen(report: report)),
                              icon: const Icon(Icons.fact_check_outlined,
                                  size: 18),
                              label: const Text('Review selected report',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)))),
                    ])),
            ]),
            selected: open));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ScreenFrame(
        allowCameraOverlap: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Expanded(
                child: Text('Community reports',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
            const SizedBox(width: 8),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: state.isOnline ? CcColors.soft : CcColors.orangeSoft,
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle,
                      size: 7,
                      color: state.isOnline
                          ? CcColors.green
                          : const Color(0xFF94510B)),
                  const SizedBox(width: 6),
                  Text(state.isOnline ? 'Internet connected' : 'Offline',
                      style: TextStyle(
                          fontSize: 11,
                          color: state.isOnline
                              ? CcColors.green
                              : const Color(0xFF94510B),
                          fontWeight: FontWeight.w600)),
                ])),
          ]),
          const SizedBox(height: 6),
          const Text('Reports submitted by other farmers using CalamansiCare.',
              style: TextStyle(fontSize: 12, color: CcColors.muted)),
          const SizedBox(height: 16),
          Expanded(
              child: FutureBuilder<List<CommunityReport>>(
                  future: _future,
                  builder: (context, snapshot) {
                    final reports = snapshot.data ?? const <CommunityReport>[];
                    if (_initialSelection && reports.isNotEmpty) {
                      _expanded = reports.first.id;
                      _initialSelection = false;
                    }
                    final visible = reports
                        .where((r) =>
                            _filter == 'All' ||
                            communityRiskLabel(r) == '$_filter risk')
                        .toList();
                    return RefreshIndicator(
                        onRefresh: _refreshReports,
                        child: ListView.builder(
                            controller: _scroll,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.only(bottom: _bottomSpace),
                            addAutomaticKeepAlives: false,
                            itemCount: !state.isOnline ||
                                    snapshot.hasError ||
                                    snapshot.connectionState ==
                                        ConnectionState.waiting
                                ? 1
                                : visible.length +
                                    2 +
                                    (visible.isEmpty ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (!state.isOnline) {
                                return const NoticeCard(
                                    text:
                                        'Please connect to the internet to see barangay reports.');
                              }
                              if (snapshot.hasError) {
                                return Column(children: [
                                  const NoticeCard(
                                      text:
                                          'Could not load reports. Please try again.'),
                                  TextButton.icon(
                                      onPressed: _refreshReports,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry')),
                                ]);
                              }
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                    padding: EdgeInsets.all(32),
                                    child: Center(
                                        child: CircularProgressIndicator()));
                              }
                              if (i == 0) {
                                return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _overview(reports));
                              }
                              if (i == 1) {
                                return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _filters());
                              }
                              if (visible.isEmpty) {
                                return const NoticeCard(
                                    text: 'No reports match this risk level.');
                              }
                              return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _reportCard(visible[i - 2]));
                            }));
                  })),
        ]));
  }
}

bool isLowRiskCommunityReport(CommunityReport report) {
  final disease = report.disease.toLowerCase();
  return disease.contains('healthy');
}

bool isHighRiskCommunityReport(CommunityReport report) {
  final disease = report.disease.toLowerCase();
  return disease.contains('hlb') ||
      disease.contains('greening') ||
      disease.contains('canker');
}

String communityRiskLabel(CommunityReport report) {
  if (isHighRiskCommunityReport(report)) return 'High risk';
  if (isLowRiskCommunityReport(report)) return 'Low risk';
  return 'Medium risk';
}

class BarangayReportDetailScreen extends StatelessWidget {
  const BarangayReportDetailScreen({super.key, required this.report});

  final CommunityReport report;

  @override
  Widget build(BuildContext context) {
    final guidance = guidanceFor(report.disease);
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopLine(
            title: 'Review selected report',
            subtitle: 'Reports submitted by other farmers using CalamansiCare.',
            pill: AppScope.of(context).readinessLabel,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  CommunityReportPhoto(
                    imageUrl: report.imageUrl,
                    height: 220,
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Diagnosis details',
                    child: Column(
                      children: [
                        InfoRow(label: 'Disease', value: report.disease),
                        InfoRow(
                          label: 'Confidence',
                          value:
                              '${(report.confidence * 100).toStringAsFixed(0)}%',
                        ),
                        InfoRow(
                          label: 'Farmer',
                          value: report.farmerName.trim().isEmpty
                              ? '---'
                              : report.farmerName,
                        ),
                        InfoRow(
                            label: 'City / municipality',
                            value: report.location),
                        InfoRow(
                          label: 'Status',
                          value: communityRiskLabel(report),
                        ),
                        InfoRow(
                          label: 'Reported at',
                          value: report.reportedAt.trim().isEmpty
                              ? '---'
                              : _formatHistoryDateTime(report.reportedAt),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TreatmentRecommendationCard(guidance: guidance),
                  const SizedBox(height: 12),
                  GuideTile(
                    icon: Icons.shield_outlined,
                    title: 'Prevention',
                    text: guidance.prevention,
                  ),
                ],
              ),
            ),
          ),
          PrimaryButton(
            label: 'Back to home',
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class CommunityReportPhoto extends StatelessWidget {
  const CommunityReportPhoto({
    super.key,
    required this.imageUrl,
    required this.height,
  });

  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: height,
        color: CcColors.softStrong,
        child: url == null || url.isEmpty
            ? const Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: CcColors.muted,
                  size: 34,
                ),
              )
            : Image(
                image: ResizeImage(NetworkImage(url),
                    width: height <= 48 ? 144 : 720,
                    height: height <= 48 ? 144 : 720,
                    policy: ResizeImagePolicy.fit),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: CcColors.muted,
                    size: 34,
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const ColoredBox(color: CcColors.softStrong);
                },
              ),
      ),
    );
  }
}
