import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// State of the on-device text-to-speech engine.
enum TtsState { idle, speaking, error }

/// Owns the [FlutterTts] instance for the whole app.
///
/// Unlike the original lazy creation in `TranslationProvider`, this service
/// is pre-warmed on app startup with the configured language, rate, and
/// `awaitSpeakCompletion(true)`. The first `speak` call no longer has to pay
/// the TTS engine setup cost, and configuration changes propagate without
/// re-instantiating the engine.
class TtsService extends ChangeNotifier {
  TtsService();

  final FlutterTts _tts = FlutterTts();
  TtsState _state = TtsState.idle;
  String? _lastError;
  String _language = 'en-NG';
  double _rate = 0.5;
  bool _isWarmedUp = false;

  TtsState get state => _state;
  String? get lastError => _lastError;
  bool get isWarmedUp => _isWarmedUp;
  String get language => _language;
  double get rate => _rate;

  /// Configures language, rate, and the completion handler. Safe to call
  /// multiple times — each call updates the engine and notifies listeners.
  Future<void> warmUp({
    required String language,
    required double rate,
  }) async {
    _language = language;
    _rate = rate;
    try {
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(rate);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      _tts.setStartHandler(() {
        _state = TtsState.speaking;
        _lastError = null;
        notifyListeners();
      });
      _tts.setCompletionHandler(() {
        _state = TtsState.idle;
        notifyListeners();
      });
      _tts.setCancelHandler(() {
        _state = TtsState.idle;
        notifyListeners();
      });
      _tts.setErrorHandler((message) {
        _state = TtsState.error;
        _lastError = message;
        notifyListeners();
      });
      _isWarmedUp = true;
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('TTS warm-up failed: $error\n$stackTrace');
      // On iOS, en-NG may not be installed; fall back to en-US and retry once.
      if (language != 'en-US') {
        await warmUp(language: 'en-US', rate: rate);
      }
    }
  }

  /// Speaks [text]. If a previous utterance is still playing, it's stopped
  /// first so the listener never hears overlapping phrases.
  Future<void> speak(String text) async {
    if (!_isWarmedUp) {
      await warmUp(language: _language, rate: _rate);
    }
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (error, stackTrace) {
      _state = TtsState.error;
      _lastError = error.toString();
      debugPrint('TTS speak failed: $error\n$stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
      _state = TtsState.idle;
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('TTS stop failed: $error\n$stackTrace');
    }
  }

  Future<void> setLanguage(String language) async {
    _language = language;
    await warmUp(language: language, rate: _rate);
  }

  Future<void> setRate(double rate) async {
    _rate = rate;
    await warmUp(language: _language, rate: rate);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}