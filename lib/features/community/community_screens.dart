part of '../../main.dart';

class BarangayReportsScreen extends StatefulWidget {
  const BarangayReportsScreen({super.key});

  @override
  State<BarangayReportsScreen> createState() => _BarangayReportsScreenState();
}

class _BarangayReportsScreenState extends State<BarangayReportsScreen> {
  late Future<List<CommunityReport>> _future;
  CommunityReport? _selectedReport;

  @override
  void initState() {
    super.initState();
    _future = DiagnosisRepository.instance.fetchCommunityReports();
  }

  Future<void> _refreshReports() async {
    final state = AppScope.of(context);
    await state.checkConnectivityAndSync();
    final nextReports = state.isOnline
        ? DiagnosisRepository.instance.fetchCommunityReports()
        : Future<List<CommunityReport>>.value(const <CommunityReport>[]);
    if (mounted) {
      setState(() {
        _selectedReport = null;
        _future = nextReports;
      });
    }
    await nextReports;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.isOnline) {
      return ScreenFrame(
        child: RefreshIndicator(
          onRefresh: _refreshReports,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              TopLine(
                title: 'Community reports',
                subtitle:
                    'Reports submitted by other farmers using CalamansiCare.',
                pill: state.readinessLabel,
              ),
              const SizedBox(height: 16),
              const NoticeCard(
                text: 'Please connect to the internet to see barangay reports.',
              ),
              const SizedBox(height: 280),
              PrimaryButton(
                label: 'Back to home',
                icon: Icons.home_rounded,
                onPressed: () => replaceWith(context, const MainShell()),
              ),
            ],
          ),
        ),
      );
    }
    return ScreenFrame(
      child: FutureBuilder<List<CommunityReport>>(
        future: _future,
        builder: (context, snapshot) {
          final reports = snapshot.data ?? const <CommunityReport>[];
          if (_selectedReport == null && reports.isNotEmpty) {
            _selectedReport = reports.first;
          }
          final highRiskCount = reports
              .where((report) => communityRiskLabel(report) == 'High risk')
              .length;
          final mediumRiskCount = reports
              .where((report) => communityRiskLabel(report) == 'Medium risk')
              .length;
          final lowRiskCount = reports
              .where((report) => communityRiskLabel(report) == 'Low risk')
              .length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TopLine(
                title: 'Community reports',
                subtitle:
                    'Reports submitted by other farmers using CalamansiCare.',
                pill: state.readinessLabel,
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Community overview',
                child: Column(
                  children: [
                    const InfoRow(
                        label: 'Reports source', value: 'Other app users'),
                    InfoRow(
                        label: 'Shared reports',
                        value: '${reports.length} reports from nearby users'),
                    RiskOverviewRow(
                      lowRiskCount: lowRiskCount,
                      mediumRiskCount: mediumRiskCount,
                      highRiskCount: highRiskCount,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : reports.isEmpty
                        ? RefreshIndicator(
                            onRefresh: _refreshReports,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                NoticeCard(
                                  text:
                                      'No barangay reports yet. Please try again later.',
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _refreshReports,
                            child: ListView.builder(
                              itemCount: reports.length,
                              itemBuilder: (context, index) {
                                final report = reports[index];
                                final selected =
                                    _selectedReport?.id == report.id;
                                return HistoryTile(
                                  disease: report.disease,
                                  status: communityRiskLabel(report),
                                  date: report.location,
                                  confidence:
                                      '${(report.confidence * 100).toStringAsFixed(0)}% confidence',
                                  imageUrl: report.imageUrl,
                                  selected: selected,
                                  onTap: () =>
                                      setState(() => _selectedReport = report),
                                );
                              },
                            ),
                          ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Review selected report',
                icon: Icons.open_in_new_rounded,
                onPressed: _selectedReport == null
                    ? null
                    : () => go(
                          context,
                          BarangayReportDetailScreen(report: _selectedReport!),
                        ),
              ),
            ],
          );
        },
      ),
    );
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
            : Image.network(
                url,
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
                  return const Center(child: CircularProgressIndicator());
                },
              ),
      ),
    );
  }
}
