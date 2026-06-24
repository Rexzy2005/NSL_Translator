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
