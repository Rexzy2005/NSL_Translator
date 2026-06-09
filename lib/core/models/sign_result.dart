class SignResult {
  final String label;
  final double confidence;
  final DateTime timestamp;

  const SignResult({
    required this.label,
    required this.confidence,
    required this.timestamp,
  });

  bool get isHighConfidence => confidence >= 0.80;
}
