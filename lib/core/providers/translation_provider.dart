import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/sign_result.dart';
import '../models/translation_entry.dart';
import '../services/hive_service.dart';
import '../services/inference_service.dart';
import '../services/tts_service.dart';
import 'settings_provider.dart';

class TranslationProvider extends ChangeNotifier {
  TranslationProvider({
    required HiveService hiveService,
    required InferenceService inferenceService,
    required SettingsProvider settings,
    required TtsService ttsService,
  })  : _hiveService = hiveService,
        _inferenceService = inferenceService,
        _settings = settings,
        _ttsService = ttsService {
    // Forward model status changes (e.g. after an OTA reload) so the UI that
    // watches [TranslationProvider] also rebuilds when the underlying
    // [InferenceService] changes state.
    _inferenceService.addListener(notifyListeners);
    _ttsService.addListener(_onTtsStateChanged);
    // Re-warm TTS when the user changes language or rate in Settings.
    _settings.addListener(_onSettingsChanged);
  }

  final HiveService _hiveService;
  final InferenceService _inferenceService;
  final SettingsProvider _settings;
  final TtsService _ttsService;
  final Uuid _uuid = const Uuid();
  String? _activeSessionId;
  SignResult? _currentResult;
  final List<SignResult> _sessionHistory = [];
  bool _isProcessing = false;
  bool _isCameraActive = true;
  bool _isTranslating = false;
  TtsState _ttsState = TtsState.idle;

  SignResult? get currentResult => _currentResult;
  List<SignResult> get sessionHistory => List.unmodifiable(_sessionHistory);
  bool get isProcessing => _isProcessing;
  bool get isCameraActive => _isCameraActive;
  bool get isTranslating => _isTranslating;
  TtsState get ttsState => _ttsState;
  InferenceService get inferenceService => _inferenceService;
  String? get sessionId => _activeSessionId;

  void _onTtsStateChanged() {
    _ttsState = _ttsService.state;
    notifyListeners();
  }

  void _onSettingsChanged() {
    // Re-warm TTS if the user changed language or rate.
    _ttsService.warmUp(
      language: _settings.ttsLanguage,
      rate: _settings.ttsRate,
    );
  }

  void startTranslating() {
    _activeSessionId = _uuid.v4();
    _currentResult = null;
    _sessionHistory.clear();
    _isProcessing = false;
    _isTranslating = true;
    notifyListeners();
  }

  Future<void> stopTranslating() async {
    _isTranslating = false;
    _isProcessing = false;
    _activeSessionId = null;
    await stopSpeaking();
    notifyListeners();
  }

  Future<void> setResult(SignResult result) async {
    final sessionId = _activeSessionId;
    if (!_isTranslating || sessionId == null) return;
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
          sessionId: sessionId,
        ),
      );
      if (_settings.ttsEnabled &&
          result.confidence >= _settings.confidenceThreshold) {
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
    if (!_settings.ttsEnabled) return;
    try {
      await _ttsService.speak(label);
    } catch (error, stackTrace) {
      debugPrint('TTS failed: $error\n$stackTrace');
    }
  }

  Future<void> stopSpeaking() => _ttsService.stop();

  void clearSession() {
    _activeSessionId = null;
    _isTranslating = false;
    _currentResult = null;
    _sessionHistory.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _inferenceService.removeListener(notifyListeners);
    _ttsService.removeListener(_onTtsStateChanged);
    _settings.removeListener(_onSettingsChanged);
    _inferenceService.dispose();
    super.dispose();
  }
}
