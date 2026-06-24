import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/feedback_entry.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/sqlite_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const String _intro =
      "Help improve NSL Translate by recording yourself signing a word "
      "and labeling it. Videos are saved locally and uploaded to the dataset "
      "when you are online.";

  final TextEditingController _controller = TextEditingController();
  StreamSubscription<bool>? _connectivitySubscription;
  String? _selected;
  List<FeedbackEntry> _pending = [];
  bool _submitting = false;

  // Camera / video state
  CameraController? _cameraController;
  bool _cameraInitializing = false;
  bool _isRecording = false;
  String? _cameraError;
  String? _recordedVideoPath;
  bool _permissionsDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _connectivitySubscription = context
          .read<ConnectivityService>()
          .connectionStream
          .listen((online) async {
        if (!online || !mounted) return;
        final before = _pending.length;
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await _load();
        final synced = before - _pending.length;
        if (synced > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Synced $synced items')),
          );
        }
      });
    });
  }

  Future<void> _load() async {
    final pending = await context.read<SqliteService>().getUnsynced();
    if (mounted) setState(() => _pending = pending);
  }

  Future<void> _ensureCameraPermissions() async {
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    final granted = camera.isGranted && mic.isGranted;
    if (!granted && mounted) {
      setState(() {
        _permissionsDenied = true;
        _cameraError =
            'Camera and microphone permissions are required to record videos.';
      });
    } else if (mounted) {
      setState(() => _permissionsDenied = false);
    }
  }

  Future<void> _initializeCamera() async {
    if (_cameraController != null || _cameraInitializing) return;
    await _ensureCameraPermissions();
    if (_permissionsDenied) return;
    setState(() {
      _cameraInitializing = true;
      _cameraError = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'No camera is available.');
      }
      final front = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _cameraInitializing = false;
      });
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _cameraError = error.description ?? error.code;
          _cameraInitializing = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _cameraError = error.toString();
          _cameraInitializing = false;
        });
      }
    }
  }

  Future<void> _startRecording() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (_isRecording) return;
    try {
      await controller.startVideoRecording();
      if (mounted) setState(() => _isRecording = true);
    } catch (error) {
      if (mounted) {
        setState(() => _cameraError = 'Failed to start recording: $error');
      }
    }
  }

  Future<void> _stopRecording() async {
    final controller = _cameraController;
    if (controller == null || !_isRecording) return;
    try {
      final file = await controller.stopVideoRecording();
      final savedPath = await _persistRecording(file);
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordedVideoPath = savedPath;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _cameraError = 'Failed to stop recording: $error';
        });
      }
    }
  }

  Future<String> _persistRecording(XFile file) async {
    final docs = await getApplicationDocumentsDirectory();
    final contributions = Directory(p.join(docs.path, 'contributions'));
    if (!await contributions.exists()) {
      await contributions.create(recursive: true);
    }
    final ext = p.extension(file.path).isNotEmpty
        ? p.extension(file.path)
        : '.mp4';
    final name =
        'sign_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destination = File(p.join(contributions.path, name));
    await File(file.path).copy(destination.path);
    return destination.path;
  }

  void _discardRecording() {
    final path = _recordedVideoPath;
    if (path != null) {
      // Best-effort cleanup of the discarded local file.
      File(path).delete().catchError((_) => File(path));
    }
    setState(() {
      _recordedVideoPath = null;
      _isRecording = false;
    });
  }

  Future<void> _submit() async {
    final label = (_controller.text.trim().isNotEmpty
            ? _controller.text.trim()
            : _selected)
        ?.trim();
    if (label == null || label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter or select a sign label.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<SqliteService>().insertFeedback(
            FeedbackEntry(
              signLabel: label,
              videoPath: _recordedVideoPath ?? 'pending_video',
              submittedAt: DateTime.now(),
              synced: false,
            ),
          );
      _controller.clear();
      _selected = null;
      setState(() => _recordedVideoPath = null);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback saved for sync.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _controller.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Feedback',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(_intro),
            const SizedBox(height: 20),
            _VideoSection(
              cameraController: _cameraController,
              cameraInitializing: _cameraInitializing,
              isRecording: _isRecording,
              recordedVideoPath: _recordedVideoPath,
              cameraError: _cameraError,
              permissionsDenied: _permissionsDenied,
              onInitialize: _initializeCamera,
              onStartRecording: _startRecording,
              onStopRecording: _stopRecording,
              onDiscard: _discardRecording,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'What sign were you performing?',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selected,
              decoration: const InputDecoration(labelText: 'Select known sign'),
              items: AppConstants.nslVocabulary
                  .map((label) =>
                      DropdownMenuItem(value: label, child: Text(label)))
                  .toList(),
              onChanged: (value) => setState(() => _selected = value),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
            const SizedBox(height: 24),
            Chip(label: Text('${_pending.length} submissions pending sync')),
            const SizedBox(height: 8),
            if (_pending.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Column(
                  children: [
                    Icon(Icons.flag_outlined, size: 48),
                    SizedBox(height: 12),
                    Text('No pending feedback.'),
                  ],
                ),
              )
            else
              ..._pending.map(
                (entry) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: Text(entry.signLabel),
                    subtitle: Text(
                      '${entry.submittedAt.toLocal()}'
                      '${entry.videoPath == 'pending_video' ? '' : ' • video saved'}',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoSection extends StatelessWidget {
  const _VideoSection({
    required this.cameraController,
    required this.cameraInitializing,
    required this.isRecording,
    required this.recordedVideoPath,
    required this.cameraError,
    required this.permissionsDenied,
    required this.onInitialize,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onDiscard,
  });

  final CameraController? cameraController;
  final bool cameraInitializing;
  final bool isRecording;
  final String? recordedVideoPath;
  final String? cameraError;
  final bool permissionsDenied;
  final Future<void> Function() onInitialize;
  final Future<void> Function() onStartRecording;
  final Future<void> Function() onStopRecording;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sign video (optional)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'A short clip of you performing the sign helps train future '
              'model versions. Skip this if you only want to submit a label.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: _VideoPreview(
                cameraController: cameraController,
                isRecording: isRecording,
                recordedVideoPath: recordedVideoPath,
              ),
            ),
            const SizedBox(height: 12),
            if (cameraError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  cameraError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (permissionsDenied)
              TextButton.icon(
                onPressed: () => openAppSettings(),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open app settings'),
              ),
            if (recordedVideoPath == null && !isRecording)
              OutlinedButton.icon(
                onPressed: cameraController == null && !cameraInitializing
                    ? onInitialize
                    : null,
                icon: const Icon(Icons.videocam_outlined),
                label: Text(
                  cameraController == null
                      ? (cameraInitializing
                          ? 'Preparing camera…'
                          : 'Set up camera')
                      : 'Ready to record',
                ),
              ),
            if (recordedVideoPath == null && !isRecording)
              const SizedBox(height: 8),
            if (recordedVideoPath == null &&
                cameraController != null &&
                !isRecording)
              FilledButton.icon(
                onPressed: onStartRecording,
                icon: const Icon(Icons.fiber_manual_record),
                label: const Text('Start recording'),
              ),
            if (isRecording)
              FilledButton.icon(
                onPressed: onStopRecording,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop recording'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            if (recordedVideoPath != null && !isRecording) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Video saved locally — it will upload when online.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onDiscard,
                    icon: const Icon(Icons.replay_outlined),
                    label: const Text('Re-record'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({
    required this.cameraController,
    required this.isRecording,
    required this.recordedVideoPath,
  });

  final CameraController? cameraController;
  final bool isRecording;
  final String? recordedVideoPath;

  @override
  Widget build(BuildContext context) {
    final controller = cameraController;
    if (recordedVideoPath != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_outlined, color: Colors.white, size: 56),
            SizedBox(height: 8),
            Text(
              'Video ready',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }
    if (controller != null && controller.value.isInitialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(controller),
            if (isRecording)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'REC',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 48),
          SizedBox(height: 8),
          Text(
            'Camera not ready',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
