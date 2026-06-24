import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/models/feedback_entry.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/sqlite_service.dart';
import '../../shared/theme/app_theme.dart';

class ContributeScreen extends StatefulWidget {
  const ContributeScreen({super.key});

  @override
  State<ContributeScreen> createState() => _ContributeScreenState();
}

class _ContributeScreenState extends State<ContributeScreen> {
  final TextEditingController _labelController = TextEditingController();
  CameraController? _cameraController;
  CameraLensDirection _lensDirection = CameraLensDirection.front;
  StreamSubscription<bool>? _connectivitySubscription;
  List<FeedbackEntry> _pending = [];
  String? _videoPath;
  String? _cameraError;
  bool _initializing = false;
  bool _contributing = false;
  bool _recording = false;
  bool _submitting = false;

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
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Synced $synced videos')));
        }
      });
    });
  }

  Future<void> _initializeCamera() async {
    if (_initializing || _cameraController != null) return;
    setState(() {
      _initializing = true;
      _cameraError = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'No camera found');
      }
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == _lensDirection,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _contributing = true;
        _initializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = error.toString();
        _initializing = false;
      });
    }
  }

  Future<void> _flipCamera() async {
    _lensDirection = _lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    if (!_contributing) {
      setState(() {});
      return;
    }
    await _stopContribution();
    await _initializeCamera();
  }

  Future<void> _stopContribution() async {
    final controller = _cameraController;
    if (_recording && controller != null && controller.value.isRecordingVideo) {
      await _toggleRecording();
    }
    await controller?.dispose();
    if (!mounted) return;
    setState(() {
      _cameraController = null;
      _contributing = false;
      _initializing = false;
      _recording = false;
      _cameraError = null;
    });
  }

  Future<void> _load() async {
    final pending = await context.read<SqliteService>().getUnsynced();
    if (mounted) setState(() => _pending = pending);
  }

  Future<void> _toggleRecording() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (_recording) {
      final file = await controller.stopVideoRecording();
      final dir = await getApplicationDocumentsDirectory();
      final contributionsDir = Directory(p.join(dir.path, 'contributions'));
      await contributionsDir.create(recursive: true);
      final savedPath = p.join(
        contributionsDir.path,
        'sign_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      await File(file.path).copy(savedPath);
      if (mounted) {
        setState(() {
          _videoPath = savedPath;
          _recording = false;
        });
      }
    } else {
      await controller.startVideoRecording();
      setState(() {
        _videoPath = null;
        _recording = true;
      });
    }
  }

  Future<void> _submit() async {
    final label = _labelController.text.trim();
    final path = _videoPath;
    if (label.isEmpty || path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Record a video and enter its meaning.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<SqliteService>().insertFeedback(
            FeedbackEntry(
              signLabel: label,
              videoPath: path,
              submittedAt: DateTime.now(),
              synced: false,
            ),
          );
      _labelController.clear();
      await _load();
      if (!mounted) return;
      setState(() => _videoPath = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contribution saved for upload.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _cameraController?.dispose();
    _labelController.dispose();
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
              'Contribute',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Record a sign and label its meaning so the model can learn from real examples.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _initializing
                  ? null
                  : _contributing
                      ? _stopContribution
                      : _initializeCamera,
              icon: Icon(_contributing ? Icons.stop : Icons.play_arrow),
              label: Text(
                _contributing ? 'Stop contribution' : 'Start contribution',
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    _contributing ? AppTheme.error : AppTheme.primary,
              ),
            ),
            if (_contributing) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _initializing ? null : _flipCamera,
                icon: const Icon(Icons.cameraswitch_outlined),
                label: const Text('Flip camera'),
              ),
            ],
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _cameraPreview(),
              ),
            ),
            const SizedBox(height: 12),
            if (_contributing)
              FilledButton.icon(
                onPressed: _initializing ? null : _toggleRecording,
                icon: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
                label:
                    Text(_recording ? 'Stop recording' : 'Record sign video'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _recording ? AppTheme.error : AppTheme.primary,
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Meaning of this sign',
                hintText: 'Example: Good morning',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send contribution'),
            ),
            const SizedBox(height: 20),
            Chip(label: Text('${_pending.length} videos pending upload')),
            const SizedBox(height: 8),
            if (_pending.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Column(
                  children: [
                    Icon(Icons.video_library_outlined, size: 48),
                    SizedBox(height: 12),
                    Text('No pending contributions.'),
                  ],
                ),
              )
            else
              ..._pending.map(
                (entry) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.upload_file_outlined),
                    title: Text(entry.signLabel),
                    subtitle: Text(entry.videoPath),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cameraPreview() {
    if (_initializing) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_contributing) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Start contribution to open the camera.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }
    if (_cameraError != null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _cameraError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    return CameraPreview(controller);
  }
}
