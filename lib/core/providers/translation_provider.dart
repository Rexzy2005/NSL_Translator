import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:uuid/uuid.dart';

import '../models/sign_result.dart';
import '../models/translation_entry.dart';
import '../services/hive_service.dart';
import '../services/inference_service.dart';
import 'settings_provider.dart';

class TranslationProvider extends ChangeNotifier {
  TranslationProvider({
    required HiveService hiveService,
    required InferenceService inferenceService,
    required SettingsProvider settings,
  })  : _hiveService = hiveService,
        _inferenceService = inferenceService,
        _settings = settings;

  final HiveService _hiveService;
  final InferenceService _inferenceService;
  final SettingsProvider _settings;
  final FlutterTts _tts = FlutterTts();
  final Uuid _uuid = const Uuid();
  SignResult? _currentResult;
  final List<SignResult> _sessionHistory = [];
  bool _isProcessing = false;
  bool _isCameraActive = true;

  SignResult? get currentResult => _currentResult;
  List<SignResult> get sessionHistory => List.unmodifiable(_sessionHistory);
  bool get isProcessing => _isProcessing;
  bool get isCameraActive => _isCameraActive;
  InferenceService get inferenceService => _inferenceService;

  Future<void> setResult(SignResult result) async {
    _currentResult = result;
    _sessionHistory.insert(0, result);
    _isProcessing = false;
    notifyListeners();
    try {
      await _hiveService.saveTranslation(
        TranslationEntry(
          id: _uuid.v4(),
          signLabel: result.label,
          confidence: result.confidence,
          timestamp: result.timestamp,
          syncedToCloud: false,
        ),
      );
      if (result.confidence >= _settings.confidenceThreshold) {
        await speak(result.label);
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to save or speak translation: $error\n$stackTrace');
    }
  }

  void setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  void setCameraActive(bool value) {
    _isCameraActive = value;
    notifyListeners();
  }

  Future<void> speak(String label) async {
    try {
      await _tts.setLanguage(_settings.ttsLanguage);
      await _tts.setSpeechRate(_settings.ttsRate);
      await _tts.speak(label);
    } catch (error, stackTrace) {
      debugPrint('TTS failed: $error\n$stackTrace');
    }
  }

  void clearSession() {
    _currentResult = null;
    _sessionHistory.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.stop();
    _inferenceService.dispose();
    super.dispose();
  }
}
