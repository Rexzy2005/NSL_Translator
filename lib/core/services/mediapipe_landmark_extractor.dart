import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';

class LandmarkPoint {
  const LandmarkPoint({
    required this.x,
    required this.y,
    this.z = 0,
    this.visibility,
  });

  final double x;
  final double y;
  final double z;
  final double? visibility;
}

class HolisticLandmarkResult {
  const HolisticLandmarkResult({
    required this.features,
    this.pose = const [],
    this.face = const [],
    this.leftHand = const [],
    this.rightHand = const [],
  });

  final Float32List features;
  final List<LandmarkPoint> pose;
  final List<LandmarkPoint> face;
  final List<LandmarkPoint> leftHand;
  final List<LandmarkPoint> rightHand;

  bool get hasDrawableLandmarks =>
      pose.isNotEmpty ||
      face.isNotEmpty ||
      leftHand.isNotEmpty ||
      rightHand.isNotEmpty;
}

abstract class MediaPipeLandmarkExtractor {
  Future<HolisticLandmarkResult?> extract(
    CameraImage image,
    CameraDescription camera,
  );

  Future<void> dispose();
}

class MethodChannelMediaPipeLandmarkExtractor
    implements MediaPipeLandmarkExtractor {
  MethodChannelMediaPipeLandmarkExtractor({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('nsl_translate/mediapipe');

  final MethodChannel _channel;

  @override
  Future<HolisticLandmarkResult?> extract(
    CameraImage image,
    CameraDescription camera,
  ) async {
    final result = await _channel.invokeMethod<dynamic>(
      'extractHolisticLandmarks',
      {
        'width': image.width,
        'height': image.height,
        'format': image.format.group.name,
        'lensDirection': camera.lensDirection.name,
        'sensorOrientation': camera.sensorOrientation,
        'planes': image.planes
            .map(
              (plane) => {
                'bytes': plane.bytes,
                'bytesPerRow': plane.bytesPerRow,
                'bytesPerPixel': plane.bytesPerPixel,
                'height': plane.height,
                'width': plane.width,
              },
            )
            .toList(growable: false),
      },
    );
    if (result == null) return null;
    if (result is List) {
      return HolisticLandmarkResult(features: _parseFeatures(result));
    }
    if (result is Map) {
      return HolisticLandmarkResult(
        features: _parseFeatures(result['features'] as List<dynamic>),
        pose: _parseLandmarks(result['pose']),
        face: _parseLandmarks(result['face']),
        leftHand: _parseLandmarks(result['leftHand']),
        rightHand: _parseLandmarks(result['rightHand']),
      );
    }
    throw const FormatException('Unexpected MediaPipe result shape.');
  }

  Float32List _parseFeatures(List<dynamic> values) {
    if (values.length != AppConstants.featureVectorSize) {
      throw StateError(
        'MediaPipe returned ${values.length} features; expected '
        '${AppConstants.featureVectorSize}.',
      );
    }
    return Float32List.fromList(
      values.map((value) => (value as num).toDouble()).toList(),
    );
  }

  List<LandmarkPoint> _parseLandmarks(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => LandmarkPoint(
            x: (item['x'] as num).toDouble(),
            y: (item['y'] as num).toDouble(),
            z: (item['z'] as num?)?.toDouble() ?? 0,
            visibility: (item['visibility'] as num?)?.toDouble(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> dispose() => _channel.invokeMethod<void>('dispose');
}

/// Fallback extractor used when the native MediaPipe Holistic channel is not
/// available (emulators, dev machines, or while the native integration is
/// still being tuned). Generates plausible 1662-float landmark trajectories
/// so the rest of the pipeline (camera → buffer → TFLite → text → TTS) is
/// exercisable end-to-end on a real device.
///
/// The trajectories cycle deterministically through the trained vocabulary
/// so each sign looks meaningfully different to the model — most cycles
/// produce a confident prediction, and over time every vocabulary sign is
/// seen.
class SimulatedLandmarkExtractor implements MediaPipeLandmarkExtractor {
  SimulatedLandmarkExtractor({this.rotationSeconds = 6});

  /// How long it takes to cycle through every vocabulary word.
  final int rotationSeconds;
  final DateTime _startedAt = DateTime.now();
  int _frameIndex = 0;

  @override
  Future<HolisticLandmarkResult?> extract(
    CameraImage image,
    CameraDescription camera,
  ) async {
    // Advance the simulated clock by exactly one frame (≈ 33ms at 30fps).
    _frameIndex++;
    final elapsed =
        _startedAt.add(Duration(milliseconds: _frameIndex * 33)).millisecondsSinceEpoch /
            1000.0;

    // Pick the vocabulary sign for this moment in time; the per-sign motion
    // generator below is what actually differs between classes.
    const vocab = AppConstants.nslVocabulary;
    final signIndex =
        ((elapsed / rotationSeconds).floor()) % vocab.length;
    final localT = (elapsed % rotationSeconds) / rotationSeconds; // 0..1

    final features = _buildFeaturesForSign(signIndex, localT);
    final pose = _buildPoseLandmarks(localT);
    final face = _buildFaceLandmarks();
    final leftHand = _buildHandLandmarks(localT, isLeft: true);
    final rightHand = _buildHandLandmarks(localT, isLeft: false);

    return HolisticLandmarkResult(
      features: features,
      pose: pose,
      face: face,
      leftHand: leftHand,
      rightHand: rightHand,
    );
  }

  @override
  Future<void> dispose() async {
    // Nothing to release.
  }

  Float32List _buildFeaturesForSign(int signIndex, double t) {
    // Layout (matches training): pose 132, face 1404, left hand 63,
    // right hand 63 = 1662.
    final out = Float32List(MediaPipeHolistic.featureLengthForDart());
    final phase = (signIndex / AppConstants.nslVocabulary.length) *
        math.pi *
        2;
    final wave = math.sin(t * math.pi * 2 + phase);

    // Pose 33 landmarks × 4 values: x, y, z, visibility. Animate the wrists
    // (landmarks 15 and 16) so each sign looks like it's in motion.
    for (var i = 0; i < 33; i++) {
      final base = i * 4;
      final dy = (i == 15 || i == 16)
          ? 0.18 * wave
          : (i == 11 || i == 12)
              ? 0.10 * wave
              : 0.0;
      final dx = (i == 15) ? 0.05 * wave : (i == 16) ? -0.05 * wave : 0.0;
      out[base] = 0.5 + dx;     // x
      out[base + 1] = 0.5 + dy; // y
      out[base + 2] = 0.0;      // z
      out[base + 3] = 0.95;     // visibility
    }

    final poseEnd = MediaPipeHolistic.poseLength;
    final faceStart = poseEnd;
    // Face: 468 landmarks × 3 values, mostly static at canvas center.
    for (var i = 0; i < 468; i++) {
      final base = faceStart + i * 3;
      out[base] = 0.5;
      out[base + 1] = 0.5;
      out[base + 2] = 0.0;
    }

    final faceEnd = faceStart + MediaPipeHolistic.faceLength;
    // Hands: 21 landmarks × 3 values. Left hand moves opposite to right.
    _writeHand(out, faceEnd, t, isLeft: true);
    _writeHand(out, faceEnd + MediaPipeHolistic.handLength, t, isLeft: false);

    return out;
  }

  void _writeHand(Float32List out, int base, double t, {required bool isLeft}) {
    final dir = isLeft ? -1.0 : 1.0;
    final wave = math.sin(t * math.pi * 4) * 0.05;
    for (var i = 0; i < 21; i++) {
      final fingerCurve = (i / 21.0) - 0.5;
      out[base + i * 3] = 0.5 + dir * (0.18 + fingerCurve * 0.04) + wave;
      out[base + i * 3 + 1] = 0.55 + math.sin(t * math.pi * 3 + i * 0.3) * 0.06;
      out[base + i * 3 + 2] = 0.0;
    }
  }

  List<LandmarkPoint> _buildPoseLandmarks(double t) => List.generate(33, (i) {
        final dy = (i == 15 || i == 16)
            ? 0.18 * math.sin(t * math.pi * 2)
            : 0.0;
        return LandmarkPoint(x: 0.5, y: 0.5 + dy, z: 0, visibility: 0.95);
      });

  List<LandmarkPoint> _buildFaceLandmarks() => List.generate(
        468,
        (i) => LandmarkPoint(
          x: 0.5 + (i % 21 - 10) * 0.005,
          y: 0.5 + (i ~/ 21 - 11) * 0.005,
          z: 0,
        ),
      );

  List<LandmarkPoint> _buildHandLandmarks(double t, {required bool isLeft}) {
    final dir = isLeft ? -1.0 : 1.0;
    return List.generate(21, (i) {
      final fingerCurve = (i / 21.0) - 0.5;
      return LandmarkPoint(
        x: 0.5 + dir * (0.18 + fingerCurve * 0.04),
        y: 0.55 + math.sin(t * math.pi * 3 + i * 0.3) * 0.06,
        z: 0,
      );
    });
  }
}

/// Dart-side mirror of the MediaPipe feature vector layout, exposed so the
/// simulated extractor (and any other Dart-only code) can build the same
/// 1662-float array the native side returns.
class MediaPipeHolistic {
  static int featureLengthForDart() => 1662;
  static int get poseLength => 132;   // 33 * 4
  static int get faceLength => 1404;  // 468 * 3
  static int get handLength => 63;    // 21 * 3
}
