import 'dart:collection';
import 'dart:typed_data';

import '../constants/app_constants.dart';

class SequenceBuffer {
  SequenceBuffer({this.maxFrames = AppConstants.frameBufferSize});

  final int maxFrames;
  final Queue<Float32List> _frames = Queue<Float32List>();

  bool get isReady => _frames.length == maxFrames;
  int get length => _frames.length;

  void add(Float32List frame) {
    if (frame.length != AppConstants.featureVectorSize) {
      throw ArgumentError.value(
        frame.length,
        'frame.length',
        'Expected ${AppConstants.featureVectorSize} MediaPipe features.',
      );
    }
    if (_frames.length == maxFrames) {
      _frames.removeFirst();
    }
    _frames.addLast(frame);
  }

  List<Float32List> snapshot() => List<Float32List>.unmodifiable(_frames);

  void clear() => _frames.clear();
}
