import 'dart:math';

import '../constants/app_constants.dart';
import '../models/sign_result.dart';

// INFERENCE SERVICE - AI STUB
//
// This service is intentionally stubbed. When the TFLite LSTM model
// is ready, replace the body of runInference() with:
//   1. Load nsl_model.tflite via tflite_flutter
//   2. Accept List<List<double>> frameBuffer (shape: [30, 1662])
//   3. Run interpreter.run(input, output)
//   4. Parse softmax output, return SignResult
//
// The rest of the app calls only this interface - zero changes needed elsewhere.
class InferenceService {
  bool _isInitialized = false;
  final Random _random = Random();

  Future<void> initialize() async {
    // TODO: Load TFLite model from assets/models/nsl_model.tflite.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _isInitialized = true;
  }

  bool get isInitialized => _isInitialized;

  Future<SignResult?> runInference(List<List<double>> frameBuffer) async {
    if (!_isInitialized) return null;
    if (frameBuffer.length < AppConstants.frameBufferSize) return null;

    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (_random.nextDouble() < 0.08) return null;

    final label = AppConstants
        .nslVocabulary[_random.nextInt(AppConstants.nslVocabulary.length)];
    final confidence = 0.52 + _random.nextDouble() * 0.47;

    return SignResult(
      label: label,
      confidence: double.parse(confidence.toStringAsFixed(2)),
      timestamp: DateTime.now(),
    );
  }

  void dispose() {
    // TODO: Dispose TFLite interpreter.
    _isInitialized = false;
  }
}
