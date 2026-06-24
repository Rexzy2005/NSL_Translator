import 'package:flutter_test/flutter_test.dart';
import 'package:nsl_translate/core/models/feedback_entry.dart';
import 'package:nsl_translate/core/models/sign_result.dart';
import 'package:nsl_translate/core/models/translation_entry.dart';

void main() {
  test('SignResult reports high confidence at threshold', () {
    final result = SignResult(
      label: 'greetings',
      confidence: 0.80,
      timestamp: DateTime.utc(2026, 6, 9),
    );

    expect(result.isHighConfidence, isTrue);
  });

  test('TranslationEntry copyWith preserves existing fields', () {
    final timestamp = DateTime.utc(2026, 6, 9, 12);
    final entry = TranslationEntry(
      id: 'entry-id',
      signLabel: 'greetings',
      confidence: 0.72,
      timestamp: timestamp,
      syncedToCloud: false,
      sessionId: 'session-id',
    );

    final synced = entry.copyWith(syncedToCloud: true);

    expect(synced.id, 'entry-id');
    expect(synced.signLabel, 'greetings');
    expect(synced.confidence, 0.72);
    expect(synced.timestamp, timestamp);
    expect(synced.syncedToCloud, isTrue);
    expect(synced.sessionId, 'session-id');
  });

  test('FeedbackEntry maps to and from SQLite row shape', () {
    final submittedAt = DateTime.utc(2026, 6, 9, 13, 30);
    final entry = FeedbackEntry(
      id: 7,
      signLabel: 'good_morning',
      videoPath: '/tmp/sign_12345.mp4',
      submittedAt: submittedAt,
      synced: false,
    );

    final restored = FeedbackEntry.fromMap(entry.toMap());

    expect(restored.id, 7);
    expect(restored.signLabel, 'good_morning');
    expect(restored.videoPath, '/tmp/sign_12345.mp4');
    expect(restored.submittedAt, submittedAt);
    expect(restored.synced, isFalse);
  });
}
