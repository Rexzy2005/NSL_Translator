import 'package:flutter_test/flutter_test.dart';
import 'package:nsl_translate/core/models/feedback_entry.dart';
import 'package:nsl_translate/core/models/sign_result.dart';
import 'package:nsl_translate/core/models/translation_entry.dart';

void main() {
  test('SignResult reports high confidence at threshold', () {
    final result = SignResult(
      label: 'Hello',
      confidence: 0.80,
      timestamp: DateTime.utc(2026, 6, 9),
    );

    expect(result.isHighConfidence, isTrue);
  });

  test('TranslationEntry copyWith preserves existing fields', () {
    final timestamp = DateTime.utc(2026, 6, 9, 12);
    final entry = TranslationEntry(
      id: 'entry-id',
      signLabel: 'Help',
      confidence: 0.72,
      timestamp: timestamp,
      syncedToCloud: false,
    );

    final synced = entry.copyWith(syncedToCloud: true);

    expect(synced.id, 'entry-id');
    expect(synced.signLabel, 'Help');
    expect(synced.confidence, 0.72);
    expect(synced.timestamp, timestamp);
    expect(synced.syncedToCloud, isTrue);
  });

  test('FeedbackEntry maps to and from SQLite row shape', () {
    final submittedAt = DateTime.utc(2026, 6, 9, 13, 30);
    final entry = FeedbackEntry(
      id: 7,
      signLabel: 'Doctor',
      videoPath: 'pending_video',
      submittedAt: submittedAt,
      synced: false,
    );

    final restored = FeedbackEntry.fromMap(entry.toMap());

    expect(restored.id, 7);
    expect(restored.signLabel, 'Doctor');
    expect(restored.videoPath, 'pending_video');
    expect(restored.submittedAt, submittedAt);
    expect(restored.synced, isFalse);
  });
}
