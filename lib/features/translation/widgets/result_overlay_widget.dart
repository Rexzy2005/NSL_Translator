import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/sign_result.dart';
import 'confidence_badge_widget.dart';

class ResultOverlayWidget extends StatefulWidget {
  const ResultOverlayWidget({
    super.key,
    required this.result,
    required this.threshold,
    required this.onSpeak,
  });

  final SignResult? result;
  final double threshold;
  final ValueChanged<String> onSpeak;

  @override
  State<ResultOverlayWidget> createState() => _ResultOverlayWidgetState();
}

class _ResultOverlayWidgetState extends State<ResultOverlayWidget> {
  Timer? _timer;
  bool _visible = true;

  @override
  void didUpdateWidget(covariant ResultOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.result != null && widget.result != oldWidget.result) {
      _timer?.cancel();
      setState(() => _visible = true);
      _timer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return AnimatedSlide(
      offset: result == null || !_visible ? const Offset(0, 1) : Offset.zero,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: result == null || !_visible ? 0 : 1,
        duration: const Duration(milliseconds: 220),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height * 0.28,
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: result == null
                ? const SizedBox.shrink()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              result.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton.filled(
                            onPressed: () => widget.onSpeak(result.label),
                            icon: const Icon(Icons.volume_up),
                            tooltip: 'Play speech',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ConfidenceBadgeWidget(confidence: result.confidence),
                      const SizedBox(height: 12),
                      Text(
                        result.confidence >= widget.threshold
                            ? 'Saved to history'
                            : 'Low confidence - try again',
                        style: TextStyle(
                          color: result.confidence >= widget.threshold
                              ? Colors.white70
                              : const Color(0xFFFBBF24),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
