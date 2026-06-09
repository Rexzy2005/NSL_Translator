class FeedbackEntry {
  final int? id;
  final String signLabel;
  final String videoPath;
  final DateTime submittedAt;
  final bool synced;

  const FeedbackEntry({
    this.id,
    required this.signLabel,
    required this.videoPath,
    required this.submittedAt,
    required this.synced,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'sign_label': signLabel,
      'video_path': videoPath,
      'submitted_at': submittedAt.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  factory FeedbackEntry.fromMap(Map<String, Object?> map) {
    return FeedbackEntry(
      id: map['id'] as int?,
      signLabel: map['sign_label'] as String,
      videoPath: map['video_path'] as String,
      submittedAt: DateTime.parse(map['submitted_at'] as String),
      synced: (map['synced'] as int) == 1,
    );
  }
}
