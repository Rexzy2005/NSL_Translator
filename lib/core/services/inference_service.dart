import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../constants/app_constants.dart';
import '../models/sign_result.dart';
import 'model_update_service.dart';

enum InferenceStatus {
  idle,
  loading,
  ready,
  modelMissing,
  failed,
}

class InferenceService extends ChangeNotifier {
  Interpreter? _interpreter;
  List<String> _labels = AppConstants.nslVocabulary;
  InferenceStatus _status = InferenceStatus.idle;
  String? _errorMessage;
  bool _loadedFromDisk = false;

  bool get isInitialized => _status == InferenceStatus.ready;
  InferenceStatus get status => _status;
  String? get errorMessage => _errorMessage;
  List<String> get labels => List.unmodifiable(_labels);

  /// True when the active interpreter was loaded from a file on disk
  /// (i.e. an OTA model update was applied on a previous run).
  bool get loadedFromDisk => _loadedFromDisk;

  Future<void> initialize() async {
    await reloadModel();
  }

  /// Closes the current interpreter and re-resolves the model from the best
  /// available source (OTA-updated file in the documents dir, falling back to
  /// the bundled asset). Safe to call from any isolate — old interpreter is
  /// released before the new one is opened.
  Future<void> reloadModel() async {
    _setStatus(InferenceStatus.loading, null);
    try {
      // Release the existing interpreter before opening a new one.
      final previous = _interpreter;
      _interpreter = null;
      if (previous != null) {
        try {
          previous.close();
        } catch (error, stackTrace) {
          debugPrint('Failed to close previous interpreter: $error\n$stackTrace');
        }
      }
      _labels = await _loadLabels();
      _interpreter = await _resolveInterpreter();
      _setStatus(InferenceStatus.ready, null);
    } on FlutterError catch (error) {
      _setStatus(InferenceStatus.modelMissing, error.message);
      debugPrint('TFLite model asset is not installed: ${error.message}');
    } catch (error, stackTrace) {
      _setStatus(InferenceStatus.failed, error.toString());
      debugPrint('TFLite initialization failed: $error\n$stackTrace');
    }
  }

  void _setStatus(InferenceStatus status, String? errorMessage) {
    _status = status;
    _errorMessage = errorMessage;
    notifyListeners();
  }

  /// Returns a TFLite interpreter loaded from the OTA-updated file in the
  /// app documents directory if present, otherwise falls back to the model
  /// bundled in the app's assets.
  Future<Interpreter> _resolveInterpreter() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final local = File(p.join(dir.path, ModelUpdateService.modelFileName));
      if (await local.exists()) {
        _loadedFromDisk = true;
        return Interpreter.fromFile(local);
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Falling back to bundled TFLite asset: $error\n$stackTrace',
      );
    }
    _loadedFromDisk = false;
    return await Interpreter.fromAsset(AppConstants.modelAssetPath);
  }

  Future<SignResult?> runInference(List<Float32List> frameBuffer) async {
    final interpreter = _interpreter;
    if (interpreter == null || _status != InferenceStatus.ready) return null;
    if (frameBuffer.length != AppConstants.frameBufferSize) return null;

    final input = [
      frameBuffer.map((frame) {
        if (frame.length != AppConstants.featureVectorSize) {
          throw ArgumentError.value(
            frame.length,
            'frame.length',
            'Expected ${AppConstants.featureVectorSize} MediaPipe features.',
          );
        }
        return frame;
      }).toList(growable: false),
    ];
    final output = [
      Float32List(_labels.length),
    ];

    interpreter.run(input, output);
    final probabilities = output.first;
    // Sort descending so alternatives[] below contains the top predictions
    // (the winner first, then runner-ups) without rescanning the array.
    final ranked = List<int>.generate(probabilities.length, (i) => i)
      ..sort((a, b) => probabilities[b].compareTo(probabilities[a]));
    const topN = 3;
    final top = ranked.take(topN).toList(growable: false);
    final winnerIndex = top.first;
    final alternatives = top
        .map((index) => Prediction(
              label: _labels[index],
              confidence: probabilities[index],
            ))
        .toList(growable: false);

    return SignResult(
      label: _labels[winnerIndex],
      confidence: probabilities[winnerIndex],
      timestamp: DateTime.now(),
      alternatives: alternatives,
    );
  }

  Future<List<String>> _loadLabels() async {
    final raw = await rootBundle.loadString(AppConstants.labelsAssetPath);
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.map((value) => value.toString()).toList(growable: false);
    }
    if (decoded is Map<String, dynamic>) {
      final entries = decoded.entries.toList()
        ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
      return entries.map((entry) => entry.value.toString()).toList();
    }
    throw const FormatException('labels.json must be a list or index map.');
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _status = InferenceStatus.idle;
    super.dispose();
  }
}
