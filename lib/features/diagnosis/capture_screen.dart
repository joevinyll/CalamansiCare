part of '../../main.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, this.openGallery = false});
  final bool openGallery;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  final _images = <XFile>[];
  CameraController? _camera;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  int _generation = 0;
  bool _busy = false;
  bool _initializing = true;
  FlashMode _flashMode = FlashMode.off;
  bool _changingFlash = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    if (widget.openGallery) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _upload());
    }
  }

  Future<void> _initializeCamera() async {
    final generation = ++_generation;
    final previous = _camera;
    _camera = null;
    if (mounted) {
      setState(() {
        _initializing = true;
        _cameraError = null;
      });
    }
    CameraController? controller;
    try {
      await previous?.dispose();
      if (!mounted || generation != _generation) return;
      _cameras = await availableCameras();
      if (!mounted || generation != _generation) return;
      if (_cameras.isEmpty) {
        throw StateError('No camera available. You can still upload photos.');
      }
      _cameraIndex %= _cameras.length;
      controller = CameraController(
          _cameras[_cameraIndex], ResolutionPreset.high,
          enableAudio: false);
      await controller.initialize();
      try {
        await controller.setFlashMode(FlashMode.off);
      } on CameraException {
        // Cameras without flash can still capture images.
      }
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _initializing = false;
        _flashMode = FlashMode.off;
      });
    } catch (error) {
      await controller?.dispose();
      if (mounted && generation == _generation) {
        setState(() {
          _initializing = false;
          _cameraError =
              'Camera unavailable. Check camera permission or upload photos.';
        });
      }
    }
  }

  Future<void> _releaseCamera() async {
    ++_generation;
    final controller = _camera;
    _camera = null;
    if (mounted) setState(() {});
    await controller?.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _releaseCamera();
    } else if (state == AppLifecycleState.resumed && !_busy) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ++_generation;
    _camera?.dispose();
    super.dispose();
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _upload() async {
    if (_busy) return;
    if (_images.length == 10) {
      _notice('You can select up to 10 images.');
      return;
    }
    setState(() => _busy = true);
    await _releaseCamera();
    try {
      final files =
          await ImagePicker().pickMultiImage(imageQuality: 90, maxWidth: 1600);
      if (!mounted) return;
      final remaining = 10 - _images.length;
      setState(() => _images.addAll(files.take(remaining)));
      if (files.length > remaining) {
        _notice(
            'Only the first $remaining additional images were added. The limit is 10.');
      }
    } catch (_) {
      _notice('Could not open the photo gallery. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _initializeCamera();
      }
    }
  }

  Future<void> _capture() async {
    final controller = _camera;
    if (_busy ||
        controller == null ||
        !controller.value.isInitialized ||
        _images.length == 10) {
      return;
    }
    setState(() => _busy = true);
    try {
      final file = await controller.takePicture();
      if (mounted) setState(() => _images.add(file));
    } catch (_) {
      _notice('Could not capture the image. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _flip() async {
    if (_busy || _initializing || _cameras.length < 2) return;
    setState(() => _busy = true);
    await _releaseCamera();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _initializeCamera();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _toggleFlash() async {
    final controller = _camera;
    if (controller == null || _busy || _changingFlash) return;
    final nextMode = switch (_flashMode) {
      FlashMode.off => FlashMode.always,
      FlashMode.always => FlashMode.auto,
      _ => FlashMode.off,
    };
    setState(() => _changingFlash = true);
    try {
      await controller.setFlashMode(nextMode);
      if (mounted && identical(controller, _camera)) {
        setState(() => _flashMode = nextMode);
      }
    } catch (_) {
      _notice('Flash is unavailable on this camera.');
    } finally {
      if (mounted) setState(() => _changingFlash = false);
    }
  }

  Future<void> _scan() async {
    if (_busy || _images.isEmpty) return;
    setState(() => _busy = true);
    await _releaseCamera();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            BatchCheckingScreen(images: List.unmodifiable(_images))));
    if (mounted) {
      setState(() => _busy = false);
      await _initializeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _camera;
    return Scaffold(
      backgroundColor: const Color(0xFF203D2B),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: LayoutBuilder(builder: (context, constraints) {
              final compact = constraints.maxHeight < 700;
              final gap = compact ? 4.0 : 10.0;
              final thumbnailSize = compact ? 64.0 : 82.0;
              final shutterSize = compact ? 64.0 : 78.0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    IconButton.filledTonal(
                        tooltip: context.t('Back'),
                        onPressed: () => Navigator.maybePop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: CcColors.limeLight,
                          foregroundColor: CcColors.blackGreen,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: OfflinePill(
                                    label: AppScope.of(context).readinessLabel,
                                    onDark: true)))),
                  ]),
                  SizedBox(height: gap),
                  const Text('Capture images',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Capture or upload up to 10 images.',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                          tooltip: switch (_flashMode) {
                            FlashMode.always => 'Flash on',
                            FlashMode.auto => 'Flash auto',
                            _ => 'Flash off',
                          },
                          onPressed:
                              controller == null || _busy || _changingFlash
                                  ? null
                                  : _toggleFlash,
                          style: IconButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                          ),
                          icon: Icon(
                              switch (_flashMode) {
                                FlashMode.always => Icons.flash_on,
                                FlashMode.auto => Icons.flash_auto,
                                _ => Icons.flash_off,
                              },
                              color: Colors.white))),
                  Expanded(
                      child: Center(
                          child: Padding(
                              padding: EdgeInsets.zero,
                              child: AspectRatio(
                                  aspectRatio: 1,
                                  child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                          color: CcColors.limeLight,
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(17),
                                          clipBehavior: Clip.antiAlias,
                                          child: ColoredBox(
                                            color: CcColors.blackGreen,
                                            child: controller != null &&
                                                    controller
                                                        .value.isInitialized
                                                ? ClipRect(
                                                    child: SizedBox.expand(
                                                        child: FittedBox(
                                                            fit: BoxFit.cover,
                                                            child: SizedBox(
                                                                width: controller
                                                                    .value
                                                                    .previewSize!
                                                                    .height,
                                                                height: controller
                                                                    .value
                                                                    .previewSize!
                                                                    .width,
                                                                child: CameraPreview(
                                                                    controller)))))
                                                : Center(
                                                    child: _initializing
                                                        ? const CircularProgressIndicator(
                                                            color: CcColors.limeLight)
                                                        : Padding(
                                                            padding: const EdgeInsets.all(18),
                                                            child: FittedBox(
                                                                fit: BoxFit.scaleDown,
                                                                child: SizedBox(
                                                                    width: 200,
                                                                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                                                                      Text(
                                                                          _cameraError ??
                                                                              'Camera unavailable',
                                                                          textAlign: TextAlign
                                                                              .center,
                                                                          style:
                                                                              const TextStyle(color: Colors.white70)),
                                                                      TextButton(
                                                                          onPressed: _busy
                                                                              ? null
                                                                              : _initializeCamera,
                                                                          child:
                                                                              const Text('Retry camera'))
                                                                    ]))))),
                                          ))))))),
                  const SizedBox(height: 8),
                  Center(
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.circle,
                                size: 10,
                                color: controller == null
                                    ? Colors.grey
                                    : CcColors.limeLight),
                            const SizedBox(width: 8),
                            Flexible(
                                child: Text(
                                    controller == null
                                        ? 'Camera unavailable'
                                        : 'Live camera',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13)))
                          ]))),
                  SizedBox(height: gap),
                  Row(children: [
                    const Expanded(
                        child: Text('Selected images',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700))),
                    Text('${_images.length} / 10',
                        style: const TextStyle(color: Colors.white))
                  ]),
                  const SizedBox(height: 8),
                  SizedBox(
                      height: thumbnailSize,
                      child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount:
                              _images.length + (_images.length < 10 ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            if (index == _images.length) {
                              return SizedBox(
                                  width: thumbnailSize,
                                  child: OutlinedButton(
                                      onPressed: _busy ? null : _upload,
                                      style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          padding: EdgeInsets.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          side: const BorderSide(
                                              color: CcColors.limeLight)),
                                      child: const Icon(
                                          Icons.add_circle_outline,
                                          color: CcColors.limeLight)));
                            }
                            return SizedBox(
                                width: thumbnailSize,
                                child: Stack(fit: StackFit.expand, children: [
                                  ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                          File(_images[index].path),
                                          fit: BoxFit.cover,
                                          cacheWidth: 180,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.broken_image,
                                                  color: Colors.white))),
                                  Positioned(
                                      left: 4,
                                      bottom: 4,
                                      child: CircleAvatar(
                                          radius: 10,
                                          backgroundColor: Colors.black87,
                                          child: Text('${index + 1}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white)))),
                                  Positioned(
                                      right: 0,
                                      top: 0,
                                      child: SizedBox(
                                          width: 36,
                                          height: 36,
                                          child: IconButton(
                                              tooltip:
                                                  'Remove image ${index + 1}',
                                              padding: EdgeInsets.zero,
                                              alignment: Alignment.topRight,
                                              onPressed: _busy
                                                  ? null
                                                  : () => setState(() =>
                                                      _images.removeAt(index)),
                                              icon: Container(
                                                width: 22,
                                                height: 22,
                                                margin: const EdgeInsets.all(2),
                                                decoration: const BoxDecoration(
                                                  color: CcColors.green,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.close,
                                                    color: Colors.white,
                                                    size: 13),
                                              ))))
                                ]));
                          })),
                  SizedBox(height: gap),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                            child: TextButton(
                                onPressed: _busy || _images.length == 10
                                    ? null
                                    : _upload,
                                child: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.photo_library_outlined,
                                          color: Colors.white, size: 30),
                                      Text('Upload',
                                          style: TextStyle(color: Colors.white))
                                    ]))),
                        SizedBox(
                            width: shutterSize,
                            height: shutterSize,
                            child: IconButton.filled(
                                tooltip: 'Capture image',
                                style: IconButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: CcColors.blackGreen,
                                    side: const BorderSide(
                                        color: Colors.white, width: 2)),
                                onPressed: _busy ||
                                        controller == null ||
                                        _images.length == 10
                                    ? null
                                    : _capture,
                                icon: const Icon(Icons.camera_alt, size: 34))),
                        Expanded(
                            child: TextButton(
                                onPressed: _busy ||
                                        _initializing ||
                                        _cameras.length < 2
                                    ? null
                                    : _flip,
                                child: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.flip_camera_android,
                                          color: Colors.white, size: 30),
                                      Text('Flip',
                                          style: TextStyle(color: Colors.white))
                                    ]))),
                      ]),
                  SizedBox(height: gap),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: CcColors.limeLight,
                              foregroundColor: CcColors.blackGreen,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.all(14)),
                          onPressed: _busy || _images.isEmpty ? null : _scan,
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: Text(_images.isEmpty
                              ? 'Scan images'
                              : 'Scan ${_images.length} ${_images.length == 1 ? 'image' : 'images'}'))),
                ],
              );
            })),
      ))),
    );
  }
}

class BatchCheckingScreen extends StatefulWidget {
  const BatchCheckingScreen(
      {super.key, required this.images, this.classifyImage});
  final List<XFile> images;
  final Future<DiseasePrediction> Function(XFile file)? classifyImage;
  @override
  State<BatchCheckingScreen> createState() => _BatchCheckingScreenState();
}

class _BatchCheckingScreenState extends State<BatchCheckingScreen> {
  final _results =
      <({XFile file, DiseasePrediction? prediction, int? id, String? error})>[];
  bool _finished = false;
  int _activeIndex = 0;
  String _phase = 'Preparing image';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run();
    });
  }

  Future<void> _run() async {
    final batchId = DateTime.now().microsecondsSinceEpoch.toString();
    for (var index = 0; index < widget.images.length; index++) {
      if (!mounted) return;
      final file = widget.images[index];
      setState(() {
        _activeIndex = index;
        _phase = 'Analyzing image';
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      DiseasePrediction? prediction;
      try {
        prediction = widget.classifyImage != null
            ? await widget.classifyImage!(file)
            : await DiseaseClassifier.instance
                .classify(await file.readAsBytes(), diseaseLabels);
        if (!mounted) return;
        if (confidenceTier(prediction.confidence) != ConfidenceTier.accepted) {
          setState(() => _results.add((
                file: file,
                prediction: prediction,
                id: null,
                error: lowConfidenceRejectionMessage
              )));
          continue;
        }
        setState(() => _phase = 'Saving result');
        final path =
            await DiagnosisRepository.instance.cacheDiagnosisImage(file.path);
        if (!mounted) return;
        final id = await DiagnosisRepository.instance.saveDiagnosis(
            batchId: batchId,
            batchTotalCount: widget.images.length,
            batchImageIndex: _results.length,
            disease: prediction.label,
            confidence: prediction.confidence,
            imagePath: path);
        if (!mounted) return;
        setState(() => _results.add(
            (file: XFile(path), prediction: prediction, id: id, error: null)));
      } catch (error, stackTrace) {
        assert(() {
          debugPrint(
              'CalamansiCare scan ${index + 1} failed during $_phase: $error\n$stackTrace');
          return true;
        }());
        if (!mounted) return;
        setState(() => _results.add((
              file: file,
              prediction: prediction,
              id: null,
              error: prediction == null
                  ? 'The image could not be processed. Please try scanning again.'
                  : 'The prediction could not be saved. Please restart the app and try again.'
            )));
      }
    }
    if (!mounted) return;
    setState(() => _finished = true);
    await AppScope.of(context).refreshStats();
  }

  @override
  Widget build(BuildContext context) => _finished
      ? BatchResultsScreen(results: _results)
      : ScreenFrame(
          showNav: false,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Scanning images',
                style: Theme.of(context).textTheme.headlineSmall),
            Text(
                '${_results.length} / ${widget.images.length} images processed'),
            const SizedBox(height: 8),
            Text('$_phase ${_activeIndex + 1} of ${widget.images.length}',
                style: const TextStyle(fontSize: 14, color: CcColors.muted)),
            if (!_finished)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator(
                    value: widget.images.isEmpty
                        ? 0
                        : _results.length / widget.images.length,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  )),
            Expanded(
                child: ListView.builder(
                    itemCount: widget.images.length,
                    itemBuilder: (context, index) {
                      if (index >= _results.length) {
                        final active = index == _activeIndex;
                        return Card(
                            child: ListTile(
                          leading: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                                color: CcColors.soft,
                                borderRadius: BorderRadius.circular(6)),
                            alignment: Alignment.center,
                            child: active
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.image_outlined,
                                    color: CcColors.muted),
                          ),
                          title: Text('Image ${index + 1}'),
                          subtitle: Text(active ? _phase : 'Queued'),
                        ));
                      }
                      final result = _results[index];
                      return Card(
                          child: ListTile(
                              leading: SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: Image.file(File(result.file.path),
                                      fit: BoxFit.cover,
                                      cacheWidth: 120,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.broken_image))),
                              title: Text(
                                  'Image ${index + 1}: ${_batchResultLabel(result)}'),
                              subtitle: Text(result.error ??
                                  'Confidence ${(result.prediction!.confidence * 100).toStringAsFixed(0)}%'),
                              trailing:
                                  Icon(result.id == null ? Icons.refresh_rounded : Icons.check_circle_outline,
                                      color: result.id == null
                                          ? CcColors.orange
                                          : CcColors.green),
                              onTap: !_finished || result.id == null
                                  ? null
                                  : () => go(
                                      context,
                                      DiagnosisScreen(
                                          prediction: result.prediction!,
                                          imageFile: result.file,
                                          diagnosisId: result.id!))));
                    })),
            if (_finished)
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to camera'))),
          ]));
}
