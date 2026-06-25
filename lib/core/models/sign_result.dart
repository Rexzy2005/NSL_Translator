/// A single model prediction: the label and its softmax confidence.
class Prediction {
  const Prediction({required this.label, required this.confidence});

  final String label;
  final double confidence;
}

class SignResult {
  final String label;
  final double confidence;
  final DateTime timestamp;

  /// The next-best predictions, sorted by confidence descending. The top
  /// entry is always the same as [label]/[confidence]; the rest are the
  /// runner-ups shown muted under the primary guess.
  final List<Prediction> alternatives;

  const SignResult({
    required this.label,
    required this.confidence,
    required this.timestamp,
    this.alternatives = const [],
  });

  bool get isHighConfidence => confidence >= 0.80;

  /// The runner-up labels (excluding the winning one), for the small muted
  /// "also seen as" row under the primary guess.
  List<String> get alternativeLabels =>
      alternatives.skip(1).map((p) => p.label).toList(growable: false);
}
