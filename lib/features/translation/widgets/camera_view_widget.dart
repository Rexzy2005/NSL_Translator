import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/sign_result.dart';
import '../../../core/services/inference_service.dart';
import '../../../core/services/mediapipe_landmark_extractor.dart';
import '../../../core/services/sequence_buffer.dart';

class CameraViewWidget extends StatefulWidget {
  const CameraViewWidget({
    super.key,
    required this.inferenceService,
    required this.isTranslating,
    required this.lensDirection,
    required this.onResult,
    required this.onCameraReady,
    this.landmarkExtractor,
  });

  final InferenceService inferenceService;
  final bool isTranslating;
  final CameraLensDirection lensDirection;
  final ValueChanged<SignResult> onResult;
  final ValueChanged<CameraController> onCameraReady;
  final MediaPipeLandmarkExtractor? landmarkExtractor;

  @override
  State<CameraViewWidget> createState() => _CameraViewWidgetState();
}

class _CameraViewWidgetState extends State<CameraViewWidget> {
  late final MediaPipeLandmarkExtractor _landmarkExtractor =
      widget.landmarkExtractor ?? MethodChannelMediaPipeLandmarkExtractor();
  final SequenceBuffer _sequenceBuffer = SequenceBuffer();
  CameraController? _controller;
  CameraDescription? _camera;
  HolisticLandmarkResult? _latestLandmarks;
  String? _error;
  String? _pipelineMessage;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSceneCheckAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _loading = true;
  bool _sceneDetected = false;
  bool _mediaPipeUnavailable = false;
  bool _processingFrame = false;
  bool _runningInference = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant CameraViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isTranslating == widget.isTranslating) return;
    _sequenceBuffer.clear();
    _mediaPipeUnavailable = false;
    setState(() {
      _pipelineMessage = widget.isTranslating ? _readinessMessage() : null;
    });
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'No camera is available.');
      }
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == widget.lensDirection,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      _camera = selected;
      widget.onCameraReady(controller);
      setState(() => _loading = false);
      await controller.startImageStream(_processImage);
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.description ?? error.code;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  String? _readinessMessage() {
    if (widget.inferenceService.isInitialized) return null;
    return switch (widget.inferenceService.status) {
      InferenceStatus.modelMissing =>
        'Add assets/models/nsl_model.tflite to enable translation.',
      InferenceStatus.failed =>
        widget.inferenceService.errorMessage ?? 'Model failed to load.',
      _ => 'Model is not ready yet.',
    };
  }

  Future<void> _processImage(CameraImage image) async {
    final camera = _camera;
    if (camera == null || _processingFrame || _runningInference) return;

    final now = DateTime.now();
    if (now.difference(_lastSceneCheckAt) >=
        const Duration(milliseconds: 500)) {
      _lastSceneCheckAt = now;
      final detected = _hasVisibleScene(image);
      if (detected != _sceneDetected && mounted) {
        setState(() => _sceneDetected = detected);
      }
    }

    if (!widget.isTranslating) return;
    final readinessMessage = _readinessMessage();
    if (readinessMessage != null) {
      if (_pipelineMessage != readinessMessage && mounted) {
        setState(() => _pipelineMessage = readinessMessage);
      }
      return;
    }
    if (_mediaPipeUnavailable) return;

    final minInterval =
        Duration(milliseconds: (1000 / AppConstants.frameRate).round());
    if (now.difference(_lastFrameAt) < minInterval) return;
    _lastFrameAt = now;
    _processingFrame = true;

    try {
      final landmarkResult = await _landmarkExtractor.extract(image, camera);
      if (landmarkResult == null) return;
      if (landmarkResult.hasDrawableLandmarks && mounted) {
        setState(() => _latestLandmarks = landmarkResult);
      }
      _sequenceBuffer.add(landmarkResult.features);
      if (!_sequenceBuffer.isReady) return;
      _runningInference = true;
      final signResult = await widget.inferenceService
          .runInference(_sequenceBuffer.snapshot());
      if (signResult != null && mounted) widget.onResult(signResult);
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          _mediaPipeUnavailable = true;
          _pipelineMessage =
              'MediaPipe Holistic is not connected in the native app layer.';
        });
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _mediaPipeUnavailable = error.code == 'MEDIAPIPE_NOT_CONFIGURED';
          _pipelineMessage =
              error.message ?? 'MediaPipe landmark extraction failed.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _pipelineMessage = error.toString());
      }
    } finally {
      _runningInference = false;
      _processingFrame = false;
    }
  }

  bool _hasVisibleScene(CameraImage image) {
    final bytes = image.planes.first.bytes;
    if (bytes.isEmpty) return false;
    var total = 0;
    var samples = 0;
    final step = (bytes.length / 120).floor().clamp(1, 4096);
    for (var index = 0; index < bytes.length; index += step) {
      total += bytes[index];
      samples++;
    }
    return samples > 0 && total / samples > 24;
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      controller.stopImageStream();
    }
    _landmarkExtractor.dispose();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.no_photography_outlined,
                    color: Colors.white70, size: 56),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 1,
            height: controller.value.previewSize?.width ?? 1,
            child: CameraPreview(controller),
          ),
        ),
        if (_pipelineMessage != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _pipelineMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (_latestLandmarks != null)
          Positioned.fill(
            child: CustomPaint(
              painter: _HolisticLandmarkPainter(_latestLandmarks!),
            ),
          ),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sceneDetected
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _sceneDetected ? 'Subject detected' : 'Scanning scene',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HolisticLandmarkPainter extends CustomPainter {
  const _HolisticLandmarkPainter(this.result);

  final HolisticLandmarkResult result;

  @override
  void paint(Canvas canvas, Size size) {
    _drawPoints(canvas, size, result.face, const Color(0x99FFFFFF), 1.4);
    _drawPoints(canvas, size, result.pose, const Color(0xFF1D9E75), 3);
    _drawPoints(canvas, size, result.leftHand, const Color(0xFF38BDF8), 3);
    _drawPoints(canvas, size, result.rightHand, const Color(0xFFFBBF24), 3);
  }

  void _drawPoints(
    Canvas canvas,
    Size size,
    List<LandmarkPoint> points,
    Color color,
    double radius,
  ) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final point in points) {
      if (point.visibility != null && point.visibility! < 0.35) continue;
      canvas.drawCircle(
        Offset(point.x * size.width, point.y * size.height),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HolisticLandmarkPainter oldDelegate) {
    return oldDelegate.result != result;
  }
}
