part of '../../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      await AppScope.of(context).refreshStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ScreenFrame(
      allowCameraOverlap: true,
      child: RefreshIndicator(
        onRefresh: () async {
          await state.checkConnectivityAndSync();
          await state.refreshStats();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 34),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TopLine(
                title: timeGreetingKey(),
                subtitle: 'Ready to check leaves and fruits in the field.',
                pill: state.readinessLabel,
              ),
              const SizedBox(height: 16),
              DarkActionCard(
                title: 'New disease check',
                subtitle: 'Run AI diagnosis offline using your phone camera.',
                buttonLabel: 'Capture',
                secondaryLabel: 'Upload',
                onPrimary: () => go(context, const CaptureScreen()),
                onSecondary: () =>
                    go(context, const CaptureScreen(openGallery: true)),
              ),
              const SizedBox(height: 18),
              SectionCard(
                title: 'Field summary',
                child: Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        value: '${state.checksCount}',
                        label: 'Checks',
                        onTap: () => openFieldSummaryOverlay(
                            context, FieldSummaryKind.checks),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatCard(
                        value: '${state.queuedReportsCount}',
                        label: 'Queued',
                        valueColor: CcColors.orange,
                        onTap: () => openFieldSummaryOverlay(
                            context, FieldSummaryKind.queued),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatCard(
                        value: '${state.sentReportsCount}',
                        label: 'Sent',
                        onTap: () => openFieldSummaryOverlay(
                            context, FieldSummaryKind.sent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionCard(
                title: 'Supported conditions',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: diseaseLabels
                      .map(
                        (item) => SmallPill(
                          item,
                          onTap: () => showDiseaseInfoOverlay(context, item),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 18),
              SectionCard(
                title: 'Barangay reporting',
                child: OutlineAction(
                  label: 'Open barangay reports',
                  icon: Icons.map_outlined,
                  backgroundColor: CcColors.green,
                  foregroundColor: Colors.white,
                  borderColor: CcColors.green,
                  onTap: () => go(context, const BarangayReportsScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum FieldSummaryKind { checks, queued, sent }

String _fieldSummaryTitle(FieldSummaryKind kind) {
  return switch (kind) {
    FieldSummaryKind.checks => 'Checks details',
    FieldSummaryKind.queued => 'Queued reports',
    FieldSummaryKind.sent => 'Sent reports',
  };
}

String _fieldSummaryEmptyText(FieldSummaryKind kind) {
  return switch (kind) {
    FieldSummaryKind.checks => 'No checks yet.',
    FieldSummaryKind.queued => 'No reports waiting.',
    FieldSummaryKind.sent => 'No sent reports yet.',
  };
}

bool _matchesFieldSummaryKind(
  FieldSummaryKind kind,
  Map<String, Object?> row,
) {
  final status = row['report_status'];
  return switch (kind) {
    FieldSummaryKind.checks => true,
    FieldSummaryKind.queued => status == reportStatusWaitingInternet ||
        status == reportStatusSyncing ||
        status == reportStatusFailedRetry,
    FieldSummaryKind.sent => status == reportStatusSynced,
  };
}

Future<void> openFieldSummaryOverlay(
  BuildContext context,
  FieldSummaryKind kind,
) async {
  final state = AppScope.of(context);
  await state.refreshStats();
  final rows = (await DiagnosisRepository.instance.getRecentDiagnoses())
      .where((row) => _matchesFieldSummaryKind(kind, row))
      .toList();
  if (!context.mounted) return;
  showFieldSummaryOverlay(context, kind, rows);
}

void showFieldSummaryOverlay(
  BuildContext context,
  FieldSummaryKind kind,
  List<Map<String, Object?>> rows,
) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: CcColors.bgAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.t(_fieldSummaryTitle(kind)),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: context.t('Close'),
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (rows.isEmpty)
                  NoticeCard(text: _fieldSummaryEmptyText(kind))
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final tile = FieldSummaryDetailTile(
                          row: rows[index],
                          kind: kind,
                        );
                        if (kind != FieldSummaryKind.queued) return tile;
                        return Semantics(
                          button: true,
                          label: 'Open batch in history',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => openQueuedSummaryBatch(
                                dialogContext, rows[index]),
                            child: tile,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> openQueuedSummaryBatch(
    BuildContext context, Map<String, Object?> row) async {
  final navigator = Navigator.of(context);
  final state = AppScope.of(context);
  try {
    final batches = groupScanHistory(
        await DiagnosisRepository.instance.getRecentDiagnoses(limit: null));
    final matches = batches
        .where((batch) => batch.rows.any((scan) => scan['id'] == row['id']));
    if (!context.mounted) return;
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This batch is no longer available.')));
      return;
    }
    final batch = matches.first;
    navigator.pop();
    state.setTab(1);
    await navigator.push<void>(MaterialPageRoute(
        builder: (_) => BatchHistoryDetailsScreen(batch: batch)));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open the batch. Please try again.')));
    }
  }
}

class FieldSummaryDetailTile extends StatelessWidget {
  const FieldSummaryDetailTile({
    super.key,
    required this.row,
    required this.kind,
  });

  final Map<String, Object?> row;
  final FieldSummaryKind kind;

  @override
  Widget build(BuildContext context) {
    final disease = '${row['disease'] ?? 'Unknown'}';
    final confidence = ((row['confidence'] as num?)?.toDouble() ?? 0) * 100;
    final createdAt = '${row['created_at'] ?? ''}';
    final queuedAt = row['report_created_at'] as String?;
    final syncedAt = row['report_synced_at'] as String?;
    final reportEmail = row['report_email'] as String?;
    final status = _reportStatusLabel(row['report_status'] as String?);
    final statusColor = switch (row['report_status']) {
      reportStatusSynced => CcColors.green,
      reportStatusWaitingInternet ||
      reportStatusSyncing ||
      reportStatusFailedRetry =>
        CcColors.orange,
      _ => CcColors.muted,
    };
    final dateLabel = switch (kind) {
      FieldSummaryKind.checks => 'Scan date',
      FieldSummaryKind.queued => 'Report date',
      FieldSummaryKind.sent => 'Sent',
    };
    final dateValue = switch (kind) {
      FieldSummaryKind.checks =>
        createdAt.isEmpty ? '---' : _formatHistoryDateTime(createdAt),
      FieldSummaryKind.queued =>
        queuedAt == null ? '---' : _formatHistoryDateTime(queuedAt),
      FieldSummaryKind.sent =>
        syncedAt == null ? '---' : _formatHistoryDateTime(syncedAt),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CcColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CcColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(disease),
            style: const TextStyle(
              color: CcColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          InfoRow(
            label: 'Confidence',
            value: '${confidence.toStringAsFixed(0)}%',
          ),
          if (kind == FieldSummaryKind.checks) ...[
            FieldSummaryStatusRow(
              label: 'Risk level',
              value: _batchRisk(disease).replaceFirst(' risk', ' Risk'),
              color: switch (_batchRisk(disease)) {
                'No risk' || 'Low risk' => CcColors.green,
                'High risk' => Colors.red.shade700,
                _ => const Color(0xFFAF7B18),
              },
            ),
            InfoRow(label: 'Disease type', value: guidanceFor(disease).kind),
          ],
          FieldSummaryStatusRow(
            label: 'Status',
            value: status,
            color: statusColor,
          ),
          if (kind != FieldSummaryKind.checks)
            InfoRow(label: 'Target email', value: reportEmail ?? '---'),
          InfoRow(label: dateLabel, value: dateValue),
        ],
      ),
    );
  }
}

class FieldSummaryStatusRow extends StatelessWidget {
  const FieldSummaryStatusRow({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              context.t(label),
              style: const TextStyle(
                color: CcColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              context.t(value),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: color,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

void showDiseaseInfoOverlay(BuildContext context, String disease) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: CcColors.bgAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430, maxHeight: 650),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.t(disease),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: context.t('Close'),
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GuideTile(
                  icon: Icons.info_outline_rounded,
                  title: 'Description',
                  text: diseaseDescriptionFor(disease),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class CheckingScreen extends StatefulWidget {
  const CheckingScreen(
      {super.key, required this.imageFile, required this.fromGallery});

  final XFile imageFile;
  final bool fromGallery;

  @override
  State<CheckingScreen> createState() => _CheckingScreenState();
}

class _CheckingScreenState extends State<CheckingScreen> {
  String? _error;
  bool _isAnalyzing = true;

  @override
  void initState() {
    super.initState();
    _classifyImage();
  }

  Future<void> _classifyImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final prediction =
          await DiseaseClassifier.instance.classify(bytes, diseaseLabels);

      if (confidenceTier(prediction.confidence) != ConfidenceTier.accepted) {
        // Below the report confidence threshold: don't save this as a
        // diagnosis, so unclear scans do not appear in History.
        if (mounted) {
          setState(() {
            _error = lowConfidenceRejectionMessage;
            _isAnalyzing = false;
          });
        }
        return;
      }

      final localImagePath = await DiagnosisRepository.instance
          .cacheDiagnosisImage(widget.imageFile.path);
      final diagnosisId = await DiagnosisRepository.instance.saveDiagnosis(
        disease: prediction.label,
        confidence: prediction.confidence,
        imagePath: localImagePath,
      );
      if (mounted) {
        await AppScope.of(context).refreshStats();
      }
      if (mounted) {
        replaceWith(
            context,
            DiagnosisScreen(
                prediction: prediction,
                imageFile: widget.imageFile,
                diagnosisId: diagnosisId));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      showNav: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TopLine(
            title: 'Checking image',
            subtitle: 'Offline model is analyzing image features.',
          ),
          const SizedBox(height: 22),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 285,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: CcColors.softStrong,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LeafImage(
                              imageFile: widget.imageFile,
                              height: 250,
                              width: double.infinity,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 18,
                          child: LinearProgressIndicator(
                            minHeight: 9,
                            borderRadius: BorderRadius.circular(99),
                            color: CcColors.lime,
                            backgroundColor: CcColors.softStrong,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionCard(
                    title: _error == null
                        ? 'Analyzing visual patterns'
                        : 'Unable to check image',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error == null) ...[
                          Center(
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: CircularProgressIndicator(
                                strokeWidth: 5,
                                color: _isAnalyzing
                                    ? CcColors.green
                                    : CcColors.lime,
                                backgroundColor: CcColors.softStrong,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.t('Please wait while AI checks the photo.'),
                            style: const TextStyle(
                              color: CcColors.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.t(
                              'Checking image color, spots, texture, and shape.',
                            ),
                          ),
                          const SizedBox(height: 10),
                          const SmallPill('Offline model active'),
                        ] else ...[
                          Text(
                            context.t(_error!),
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              color: CcColors.ink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () =>
                                replaceWith(context, const CaptureScreen()),
                            child: Text(context.t('Scan Again')),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlineAction(
            label: 'Cancel',
            icon: Icons.close,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class DiagnosisScreen extends StatelessWidget {
  const DiagnosisScreen(
      {super.key,
      required this.prediction,
      required this.imageFile,
      required this.diagnosisId,
      this.imageNumber});

  final DiseasePrediction prediction;
  final XFile imageFile;
  final int diagnosisId;
  final int? imageNumber;

  @override
  Widget build(BuildContext context) {
    final shouldRetakePhoto =
        prediction.confidence < reportAcceptanceConfidenceThreshold;
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconButton(
              tooltip: context.t('Back'),
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: TopLine(
              title: imageNumber == null
                  ? 'Diagnosis result'
                  : 'Image $imageNumber Result',
              subtitle: 'Review before preparing the report.',
            )),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                AspectRatio(
                  key: const ValueKey('diagnosis-photo-frame'),
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ColoredBox(
                      color: CcColors.bgAlt,
                      child: LeafImage(
                        imageFile: imageFile,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (shouldRetakePhoto)
                  const RetakePhotoNoticeCard()
                else ...[
                  SectionCard(
                    title: 'Likely disease',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t(prediction.label),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Confidence ${(prediction.confidence * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: CcColors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: prediction.confidence.clamp(0, 1),
                            minHeight: 8,
                            color: CcColors.green,
                            backgroundColor: CcColors.softStrong,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(diseaseDescriptionFor(prediction.label)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (shouldRetakePhoto)
            PrimaryButton(
              label: 'Scan Again',
              icon: Icons.camera_alt_rounded,
              onPressed: () => replaceWith(context, const CaptureScreen()),
            )
          else if (!_isHealthyCondition(prediction.label))
            PrimaryButton(
              label: 'View treatment guide',
              icon: Icons.medical_services_outlined,
              onPressed: () => go(
                  context,
                  TreatmentScreen(
                      disease: prediction.label,
                      diagnosisId: diagnosisId,
                      confidence: prediction.confidence)),
            ),
        ],
      ),
    );
  }
}

class LeafImage extends StatelessWidget {
  const LeafImage({
    super.key,
    required this.imageFile,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
  });

  final XFile imageFile;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(imageFile.path),
      width: width,
      height: height,
      fit: fit,
      cacheWidth: 1600,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, synchronous) => synchronous ||
              frame != null
          ? child
          : SizedBox(
              width: width,
              height: height,
              child: const Center(
                  child: Icon(Icons.image_outlined, color: CcColors.muted))),
      errorBuilder: (_, __, ___) => SizedBox(
          width: width,
          height: height,
          child: const Center(child: Text('Photo unavailable'))),
    );
  }
}

Future<void> selectLeafImage(BuildContext context, ImageSource source) async {
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1600,
    );
    if (file != null && context.mounted) {
      go(
        context,
        CheckingScreen(
          imageFile: file,
          fromGallery: source == ImageSource.gallery,
        ),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open ${source == ImageSource.camera ? 'the camera' : 'the photo gallery'}: $error',
          ),
        ),
      );
    }
  }
}

class TreatmentScreen extends StatelessWidget {
  const TreatmentScreen({
    super.key,
    required this.disease,
    required this.diagnosisId,
    this.confidence,
  });

  final String disease;
  final int diagnosisId;
  final double? confidence;

  @override
  Widget build(BuildContext context) {
    final guidance = guidanceFor(disease);
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopLine(
            title: 'Treatment guide',
            subtitle: 'Prioritize containment and expert confirmation.',
            trailing: IconButton(
              tooltip: context.t('Back'),
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(height: 16),
          PriorityCard(message: guidance.recommendation),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SectionCard(
                    title: 'Disease type',
                    child: Text(
                      '${context.t(disease)} is classified as ${guidance.kind.toLowerCase()}.',
                      style: const TextStyle(
                          fontSize: 13.5, height: 1.4, color: CcColors.ink),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GuideTile(
                    icon: Icons.science_outlined,
                    title: 'Chemical Options',
                    text: guidance.conventionalTreatment,
                  ),
                  GuideTile(
                    icon: Icons.spa_outlined,
                    title: 'Cultural / Nonchemical Methods',
                    text: guidance.organicTreatment,
                  ),
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
            label: 'Prepare report',
            icon: Icons.description_outlined,
            onPressed: () => go(
              context,
              ReportPreviewScreen(
                disease: disease,
                diagnosisId: diagnosisId,
                confidence: confidence,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReportPreviewScreen extends StatefulWidget {
  const ReportPreviewScreen({
    super.key,
    required this.disease,
    required this.diagnosisId,
    this.confidence,
  });

  final String disease;
  final int diagnosisId;
  final double? confidence;

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  bool isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final previewTime = _formatHistoryDateTime(
      DateTime.now().toUtc().toIso8601String(),
    );
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopLine(
            title: 'Report preview',
            subtitle: 'Prepared for barangay agriculture review.',
            trailing: IconButton(
              tooltip: context.t('Back'),
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Barangay Agriculture Office',
            child: Column(
              children: [
                InfoRow(
                  label: 'Farmer',
                  value: state.farmerName.trim().isEmpty
                      ? '---'
                      : state.farmerName,
                ),
                InfoRow(
                  label: 'Location',
                  value: state.farmerLocation.trim().isEmpty
                      ? '---'
                      : state.farmerLocation,
                ),
                InfoRow(label: 'Diagnosis', value: widget.disease),
                InfoRow(
                  label: 'Confidence',
                  value: widget.confidence == null
                      ? '-'
                      : '${(widget.confidence! * 100).toStringAsFixed(0)}%',
                ),
                InfoRow(label: 'Report time', value: previewTime),
                const InfoRow(label: 'Status', value: 'Ready to send'),
                InfoRow(
                  label: 'Email',
                  value: state.officeEmail.trim().isEmpty
                      ? '---'
                      : state.officeEmail,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const NoticeCard(
            text:
                'Shared to barangay: name, city or municipality, diagnosis, and photo. Shared to other farmers: diagnosis, photo, and city or municipality only.',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CcColors.soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: state.consentEnabled,
                  onChanged: (value) => state.setConsent(value ?? false),
                  activeColor: CcColors.green,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t('Allow sending diagnosis details'),
                    style: const TextStyle(
                      color: CcColors.green,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          PrimaryButton(
            label: isSubmitting ? 'Sending report...' : 'Report',
            icon: Icons.outbox_rounded,
            color: CcColors.hero,
            isLoading: isSubmitting,
            onPressed: state.consentEnabled && !isSubmitting
                ? () async {
                    final isSignedIn = await ensureAccountReady(context);
                    if (!isSignedIn || !context.mounted) return;
                    final canSend = await ensureReportProfileComplete(context);
                    if (!canSend || !context.mounted) return;
                    setState(() => isSubmitting = true);
                    try {
                      final reportId =
                          await DiagnosisRepository.instance.queueReport(
                        diagnosisId: widget.diagnosisId,
                        officeEmail: state.officeEmail,
                        consent: state.consentEnabled,
                        settings: state.currentSettings(),
                      );
                      await state.refreshStats();
                      await state.checkConnectivityAndSync();
                      if (context.mounted) {
                        final reportStatus = await DiagnosisRepository.instance
                            .getReportStatus(reportId);
                        if (!context.mounted) return;
                        final sentNow = reportStatus == reportStatusSynced;
                        if (sentNow) {
                          await showReportSentDialog(context);
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.t(
                                  'Report is pending and waiting for internet connection.',
                                ),
                              ),
                            ),
                          );
                        }
                        if (!context.mounted) return;
                        go(context, const OfflineQueueScreen());
                      }
                    } finally {
                      if (mounted) setState(() => isSubmitting = false);
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

Future<bool> ensureReportProfileComplete(BuildContext context) async {
  final state = AppScope.of(context);
  if (state.hasCompleteReportProfile) return true;
  final missingFields = state.missingReportProfileFields;

  final editSettings = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(context.t('Complete farmer information first')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('Please complete this information before sending:'),
            ),
            const SizedBox(height: 10),
            for (final field in missingFields)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '- ${context.t(field)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t('Edit settings')),
          ),
        ],
      );
    },
  );

  if (editSettings == true && context.mounted) {
    state.setTab(2);
    replaceWith(context, const MainShell());
  }
  return false;
}

Future<bool> ensureAccountReady(BuildContext context) async {
  final state = AppScope.of(context);
  await state.refreshAuthState();
  if (!context.mounted) return false;
  if (state.isSignedIn) return true;

  final openAuth = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(context.t('Sign in to send this report')),
        content: Text(
          context.t(
            'Your scan is already saved on your phone. Sign in when you are ready to send it online.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('Not now, keep it on my phone')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t('Sign in')),
          ),
        ],
      );
    },
  );

  if (openAuth == true && context.mounted) {
    go(context, const AuthLandingScreen());
  }
  return false;
}

Future<void> showReportSentDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(context.t('Report sent')),
        content: Text(context.t('Your report was sent to the barangay.')),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t('OK')),
          ),
        ],
      );
    },
  );
}

Future<bool> ensureTermsAgreementAccepted(BuildContext context) async {
  final state = AppScope.of(context);
  if (state.termsAccepted) return true;

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(context.t('Terms of agreement')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t(
                  'Before using CalamansiCare, please acknowledge how the app handles report information.',
                ),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              const TermsAgreementPoint(
                title: 'What we collect',
                body:
                    'Device signature, model, Android version, farmer name, farm location, barangay email, diagnosis result, confidence score, report date, and report image when you send a report.',
              ),
              const TermsAgreementPoint(
                title: 'How we use it',
                body:
                    'This information is used to save reports offline, avoid duplicate uploads, send reports to the barangay office, and show community disease alerts.',
              ),
              const TermsAgreementPoint(
                title: 'Offline and online storage',
                body:
                    'Reports are saved locally on this phone first. When internet is available, approved reports are uploaded to Supabase and may be emailed to the target barangay email.',
              ),
              const TermsAgreementPoint(
                title: 'Farmer responsibility',
                body:
                    'The app gives guidance only. Confirm serious disease findings with the local agriculture office before applying treatment.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t('I understand and agree')),
          ),
        ],
      );
    },
  );

  if (accepted == true) {
    await state.acceptTermsAgreement();
    return true;
  }
  return false;
}

class TermsAgreementPoint extends StatelessWidget {
  const TermsAgreementPoint({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(
              Icons.check_circle_rounded,
              color: CcColors.green,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(title),
                  style: const TextStyle(
                    color: CcColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t(body),
                  style: const TextStyle(
                    color: CcColors.muted,
                    height: 1.35,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void showAboutAppDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: CcColors.bgAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.t('About CalamansiCare'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: context.t('Close'),
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TermsAgreementPoint(
                          title: 'About CalamansiCare',
                          body:
                              'CalamansiCare helps farmers check calamansi leaves and fruits using an offline AI model, view simple disease information, save scan history on the phone, and prepare reports for the barangay agriculture office.',
                        ),
                        TermsAgreementPoint(
                          title: 'Treatment recommendation',
                          body:
                              'The treatment and recommendation content is based on expert-verified guidance for calamansi disease management and should be used as support for farmer decisions.',
                        ),
                        TermsAgreementPoint(
                          title: 'Important reminder',
                          body:
                              'For serious or spreading symptoms, farmers should still confirm findings with the local agriculture office before removing trees or applying chemical treatment.',
                        ),
                        TermsAgreementPoint(
                          title: 'What we collect',
                          body:
                              'Device signature, model, Android version, farmer name, farm location, barangay email, diagnosis result, confidence score, report date, and report image when you send a report.',
                        ),
                        TermsAgreementPoint(
                          title: 'How we use it',
                          body:
                              'This information is used to save reports offline, avoid duplicate uploads, send reports to the barangay office, and show community disease alerts.',
                        ),
                        TermsAgreementPoint(
                          title: 'Offline and online storage',
                          body:
                              'Reports are saved locally on this phone first. When internet is available, approved reports are uploaded to Supabase and may be emailed to the target barangay email.',
                        ),
                        TermsAgreementPoint(
                          title: 'Farmer responsibility',
                          body:
                              'The app gives guidance only. Confirm serious disease findings with the local agriculture office before applying treatment.',
                        ),
                        TermsAgreementPoint(
                          title: 'Design credits',
                          body:
                              'Profile icon: UIcons by Flaticon (https://www.flaticon.com/uicons). Profile typeface: Libre Baskerville, SIL Open Font License.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class OfflineQueueScreen extends StatefulWidget {
  const OfflineQueueScreen({super.key});

  @override
  State<OfflineQueueScreen> createState() => _OfflineQueueScreenState();
}

class _OfflineQueueScreenState extends State<OfflineQueueScreen> {
  bool isSyncing = false;
  late Future<Map<String, Object?>?> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = DiagnosisRepository.instance.getLatestReportSummary();
  }

  void _refreshSummary() {
    setState(() {
      _summaryFuture = DiagnosisRepository.instance.getLatestReportSummary();
    });
  }

  Future<void> _pullToRefresh() async {
    final state = AppScope.of(context);
    await state.checkConnectivityAndSync();
    final nextSummary = DiagnosisRepository.instance.getLatestReportSummary();
    if (mounted) {
      setState(() {
        _summaryFuture = nextSummary;
      });
    }
    await nextSummary;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ScreenFrame(
      child: RefreshIndicator(
        onRefresh: _pullToRefresh,
        child: FutureBuilder<Map<String, Object?>?>(
          future: _summaryFuture,
          builder: (context, snapshot) {
            final summary = snapshot.data;
            final imagePath = summary?['image_path'] as String?;
            final disease = '${summary?['disease'] ?? '---'}';
            final statusLabel =
                _reportStatusLabel(summary?['status'] as String?);
            final confidence =
                ((summary?['confidence'] as num?)?.toDouble() ?? 0) * 100;
            final farmerName = _summaryValue(summary?['farmer_name']);
            final farmerLocation = _summaryValue(summary?['farmer_location']);
            final targetEmail = _summaryValue(summary?['office_email']);
            final scanDate = _summaryDate(summary?['scan_created_at']);
            final reportDate = _summaryDate(summary?['report_created_at']);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                TopLine(
                  title: 'Report Summary',
                  subtitle: 'Details of the latest reported scan.',
                  pill: state.readinessLabel,
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 34),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (summary == null) ...[
                  const NoticeCard(text: 'No reported scans yet.'),
                  const SizedBox(height: 260),
                ] else ...[
                  SectionCard(
                    title: 'Reported scan',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ReportSummaryImage(imagePath: imagePath),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                children: [
                                  InfoRow(label: 'Diagnosis', value: disease),
                                  InfoRow(
                                    label: 'Confidence',
                                    value: '${confidence.toStringAsFixed(0)}%',
                                  ),
                                  InfoRow(label: 'Status', value: statusLabel),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InfoRow(label: 'Farmer', value: farmerName),
                        InfoRow(label: 'Location', value: farmerLocation),
                        InfoRow(label: 'Target email', value: targetEmail),
                        InfoRow(label: 'Scan date', value: scanDate),
                        InfoRow(label: 'Report date', value: reportDate),
                        const InfoRow(label: 'Saved in', value: 'This phone'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  NoticeCard(
                    text: state.queuedReportsCount == 0
                        ? 'No reports waiting to send'
                        : 'Reports will send automatically when internet is available.',
                  ),
                  const SizedBox(height: 24),
                  if (state.queuedReportsCount > 0) ...[
                    OutlineAction(
                      label: isSyncing ? 'Sending now...' : 'Try sending now',
                      icon: Icons.wifi_rounded,
                      isLoading: isSyncing,
                      onTap: isSyncing
                          ? null
                          : () async {
                              setState(() => isSyncing = true);
                              final before = state.queuedReportsCount;
                              await state.checkConnectivityAndSync();
                              if (mounted) setState(() => isSyncing = false);
                              _refreshSummary();
                              if (!context.mounted) return;
                              final sent =
                                  before > 0 && state.queuedReportsCount == 0;
                              final message = sent
                                  ? 'Report sent successfully.'
                                  : 'Report is still waiting. Please connect to the internet and try again.';
                              if (sent) {
                                await showReportSentDialog(context);
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(context.t(message))),
                                );
                              }
                            },
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                PrimaryButton(
                  label: 'Back to home',
                  icon: Icons.home_rounded,
                  onPressed: () => replaceWith(context, const MainShell()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _summaryValue(Object? value) {
  final text = '$value'.trim();
  return text.isEmpty || text == 'null' ? '---' : text;
}

String _summaryDate(Object? value) {
  final text = '$value'.trim();
  return text.isEmpty || text == 'null' ? '---' : _formatHistoryDateTime(text);
}

class ReportSummaryImage extends StatelessWidget {
  const ReportSummaryImage({super.key, required this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final path = imagePath?.trim();
    final hasImage = path != null && path.isNotEmpty && File(path).existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 86,
        height: 86,
        color: CcColors.softStrong,
        child: hasImage
            ? Image.file(
                File(path),
                fit: BoxFit.cover,
              )
            : const Icon(
                Icons.image_not_supported_outlined,
                color: CcColors.muted,
              ),
      ),
    );
  }
}

void showHistoryDetailSheet(
  BuildContext context,
  Map<String, Object?> row, {
  required Future<void> Function() onDeleted,
}) {
  final disease = row['disease'] as String? ?? 'Unknown';
  final diagnosisId = row['id'] as int?;
  final confidence = ((row['confidence'] as num?)?.toDouble() ?? 0) * 100;
  final createdAt = row['created_at'] as String? ?? '';
  final imagePath = row['image_path'] as String?;
  final reportId = row['report_id'] as int?;
  final reportStatus = _reportStatusLabel(row['report_status'] as String?);
  final hasQueuedReport = row['report_status'] == reportStatusWaitingInternet ||
      row['report_status'] == reportStatusFailedRetry ||
      row['report_status'] == reportStatusSyncing;
  final canRetryReport = diagnosisId != null && hasQueuedReport;
  final hasAnyReport = row['report_status'] != null;
  final canReportFromHistory = diagnosisId != null &&
      !hasAnyReport &&
      confidence / 100 >= reportAcceptanceConfidenceThreshold;
  final reportEmail = row['report_email'] as String?;
  final reportConsent = row['report_consent'] == null
      ? '-'
      : row['report_consent'] == 1
          ? 'Allowed'
          : 'Not allowed';
  final reportCreatedAt = row['report_created_at'] as String?;
  final reportSyncedAt = row['report_synced_at'] as String?;
  final guidance = guidanceFor(disease);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: CcColors.bgAlt,
    showDragHandle: true,
    builder: (sheetContext) {
      final mediaQuery = MediaQuery.of(sheetContext);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        minChildSize: .45,
        maxChildSize: .94,
        builder: (_, controller) {
          return ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              24,
              4,
              24,
              mediaQuery.padding.bottom + 92,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('Diagnosis details'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: context.t('Close'),
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Scan result',
                child: Column(
                  children: [
                    InfoRow(label: 'Diagnosis', value: disease),
                    InfoRow(
                      label: 'Confidence',
                      value: '${confidence.toStringAsFixed(0)}%',
                    ),
                    InfoRow(
                      label: 'Scan date',
                      value: _formatHistoryDateTime(createdAt),
                    ),
                    InfoRow(label: 'Report status', value: reportStatus),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!_isHealthyCondition(disease))
                SectionCard(
                  title: 'Treatment recommendation',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InfoRow(label: 'Condition type', value: guidance.kind),
                      const SizedBox(height: 10),
                      TreatmentMethodBlock(
                        icon: Icons.science_outlined,
                        title: 'Chemical Options',
                        text: guidance.conventionalTreatment,
                        color: CcColors.red,
                      ),
                      const SizedBox(height: 8),
                      TreatmentMethodBlock(
                        icon: Icons.spa_outlined,
                        title: 'Cultural / Nonchemical Methods',
                        text: guidance.organicTreatment,
                        color: CcColors.green,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Saved details',
                child: Column(
                  children: [
                    InfoRow(label: 'Local ID', value: '${row['id'] ?? '-'}'),
                    if (imagePath != null && imagePath.trim().isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: CcColors.link,
                            padding: EdgeInsets.zero,
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          onPressed: () => showHistoryImageDialog(
                            context,
                            imagePath.trim(),
                          ),
                          child: Text(context.t('See Image taken')),
                        ),
                      ),
                    InfoRow(label: 'Consent', value: reportConsent),
                    InfoRow(label: 'Target email', value: reportEmail ?? '-'),
                    InfoRow(
                      label: 'Queued at',
                      value: reportCreatedAt == null
                          ? '-'
                          : _formatHistoryDateTime(reportCreatedAt),
                    ),
                    InfoRow(
                      label: 'Synced at',
                      value: reportSyncedAt == null
                          ? '-'
                          : _formatHistoryDateTime(reportSyncedAt),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (canRetryReport) ...[
                NoticeCard(
                  text: row['report_status'] == reportStatusSynced
                      ? 'Already reported'
                      : 'Report is saved locally. Tap retry when internet is stable.',
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Retry upload',
                  icon: Icons.sync_rounded,
                  onPressed: () async {
                    final appState = AppScope.of(context);
                    await DiagnosisRepository.instance
                        .markDiagnosisReportForRetry(diagnosisId);
                    await appState.checkConnectivityAndSync();
                    await onDeleted();
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                    if (context.mounted) {
                      final latestStatus = reportId == null
                          ? null
                          : await DiagnosisRepository.instance
                              .getReportStatus(reportId);
                      if (!context.mounted) return;
                      final message = latestStatus == reportStatusSynced
                          ? 'Report sent successfully.'
                          : 'Report is still waiting. Please connect to the internet and try again.';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.t(message))),
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),
              ] else if (canReportFromHistory) ...[
                PrimaryButton(
                  label: 'Report this scan',
                  icon: Icons.description_outlined,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    go(
                      context,
                      ReportPreviewScreen(
                        disease: disease,
                        diagnosisId: diagnosisId,
                        confidence: confidence / 100,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
              ] else if (hasAnyReport) ...[
                const NoticeCard(text: 'Already reported'),
                const SizedBox(height: 10),
              ] else if (diagnosisId != null) ...[
                const NoticeCard(
                  text:
                      'Only scans with 80% confidence or higher can be reported.',
                ),
                const SizedBox(height: 10),
              ],
              PrimaryButton(
                label: 'Delete history',
                icon: Icons.delete_outline_rounded,
                color: CcColors.red,
                onPressed: diagnosisId == null
                    ? null
                    : () async {
                        final confirmed = await showDeleteHistoryConfirmation(
                          context,
                          hasQueuedReport: hasQueuedReport,
                        );
                        if (!confirmed) return;
                        await DiagnosisRepository.instance
                            .deleteDiagnosis(diagnosisId);
                        await onDeleted();
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.t('History deleted')),
                            ),
                          );
                        }
                      },
              ),
            ],
          );
        },
      );
    },
  );
}

Future<bool> showDeleteHistoryConfirmation(
  BuildContext context, {
  required bool hasQueuedReport,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(context.t('Are you sure to delete this history?')),
        content: Text(
          context.t(
            hasQueuedReport
                ? 'This will cancel the queued report and delete this history.'
                : 'This will permanently remove this scan from local history.',
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CcColors.softStrong,
                    foregroundColor: CcColors.dark,
                  ),
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.t('Cancel')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: CcColors.red),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(context.t('Delete')),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

Future<bool> showSignOutConfirmation(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(context.t('Sign out?'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        content: Text(
          context.t(
            'When you log out, this account\'s saved data on this phone will be deleted. Reports already sent online will stay in Barangay Reports.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CcColors.softStrong,
                    foregroundColor: CcColors.dark,
                  ),
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.t('Stay signed in')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: CcColors.red),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(context.t('Sign out')),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

void showHistoryImageDialog(BuildContext context, String imagePath) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: CcColors.bgAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.t('Image taken'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: context.t('Close'),
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          color: CcColors.soft,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            context.t('Image unavailable'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: CcColors.muted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

String _reportStatusLabel(String? status) {
  switch (status) {
    case reportStatusSynced:
      return 'Sent to barangay';
    case reportStatusWaitingInternet:
      return 'Waiting for internet';
    case reportStatusSyncing:
      return 'Sending...';
    case reportStatusFailedRetry:
      return 'Could not send. Tap to try again';
    default:
      return 'Saved on phone';
  }
}

String _formatHistoryDate(String isoTimestamp) {
  final date = DateTime.tryParse(isoTimestamp)?.toLocal();
  if (date == null) return isoTimestamp;
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
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _formatHistoryDateTime(String isoTimestamp) {
  final date = DateTime.tryParse(isoTimestamp)?.toLocal();
  if (date == null) return isoTimestamp;
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${_formatHistoryDate(isoTimestamp)} at $hour:$minute $period';
}
