import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import 'hive_service.dart';

class ModelUpdateService {
  ModelUpdateService({required HiveService hiveService})
      : _hiveService = hiveService;

  /// Name of the bundled TFLite model and the staged / active model file on
  /// disk. Kept in sync with [AppConstants.modelAssetPath].
  static const String modelFileName = 'nsl_model_fp16.tflite';

  static const String _localVersionKey = 'local_model_version';
  static const String _stagedVersionKey = 'staged_model_version';
  final HiveService _hiveService;
  String? _remoteVersion;

  /// Optional hook invoked after [applyUpdate] finishes, so the
  /// [InferenceService] can hot-reload the new model without an app restart.
  /// Set from `main.dart` after both services are constructed.
  Future<void> Function()? onModelApplied;

  Future<bool> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(AppConstants.modelVersionEndpoint))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Version check failed with ${response.statusCode}.');
      }
      final payload = await compute(_decodeVersionPayload, response.body);
      final remote = payload['version'] as String?;
      if (remote == null || remote.isEmpty) return false;
      _remoteVersion = remote;
      return _compareVersions(remote, getLocalModelVersion()) > 0;
    } catch (error, stackTrace) {
      debugPrint('Model update check failed: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> downloadAndStageModel() async {
    try {
      final version = _remoteVersion;
      if (version == null || version.isEmpty) {
        throw StateError('No remote model version is available.');
      }
      // Use the configured endpoint, but if it points at the old filename,
      // rewrite to the actual shipped model file.
      final endpoint = _resolveDownloadEndpoint();
      final response = await http
          .get(Uri.parse(endpoint))
          .timeout(const Duration(minutes: 2));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Model download failed with ${response.statusCode}.');
      }
      final dir = await getApplicationDocumentsDirectory();
      final staged =
          File(p.join(dir.path, '${modelFileName.replaceFirst('.tflite', '')}_staged.tflite'));
      await staged.writeAsBytes(response.bodyBytes, flush: true);
      await _hiveService.saveStringSetting(_stagedVersionKey, version);
    } catch (error, stackTrace) {
      debugPrint('Model download failed: $error\n$stackTrace');
      rethrow;
    }
  }

  String _resolveDownloadEndpoint() {
    final base = AppConstants.modelDownloadEndpoint;
    if (base.contains(modelFileName)) return base;
    // Strip the old placeholder filename and substitute the real one.
    final directory = base.substring(0, base.lastIndexOf('/') + 1);
    return '$directory$modelFileName';
  }

  Future<void> applyUpdate() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final staged = File(p.join(
        dir.path,
        '${modelFileName.replaceFirst('.tflite', '')}_staged.tflite',
      ));
      if (!await staged.exists()) {
        throw StateError('No staged model file exists.');
      }
      final active = File(p.join(dir.path, modelFileName));
      if (await active.exists()) {
        await active.delete();
      }
      await staged.rename(active.path);
      final stagedVersion = _hiveService.getStringSetting(_stagedVersionKey,
              defaultValue: '0.0.0') ??
          '0.0.0';
      await _hiveService.saveStringSetting(_localVersionKey, stagedVersion);
      // Hot-reload the interpreter so the new model is ready immediately —
      // no app restart required.
      final hook = onModelApplied;
      if (hook != null) {
        try {
          await hook();
        } catch (error, stackTrace) {
          debugPrint(
              'Inference reload after model apply failed: $error\n$stackTrace');
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Applying model update failed: $error\n$stackTrace');
      rethrow;
    }
  }

  String getLocalModelVersion() {
    return _hiveService.getStringSetting(
          _localVersionKey,
          defaultValue: '0.0.0',
        ) ??
        '0.0.0';
  }

  int _compareVersions(String a, String b) {
    final left = a.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final right = b.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final l = i < left.length ? left[i] : 0;
      final r = i < right.length ? right[i] : 0;
      if (l != r) return l.compareTo(r);
    }
    return 0;
  }

  void dispose() {}
}

Map<String, dynamic> _decodeVersionPayload(String body) {
  return jsonDecode(body) as Map<String, dynamic>;
}
