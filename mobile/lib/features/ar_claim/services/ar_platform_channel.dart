import 'dart:async';

import 'package:flutter/services.dart';

/// Platform channel for native ARKit (iOS) and ARCore (Android) integration.
class ARPlatformChannel {
  static const MethodChannel _channel = MethodChannel('com.hotncold.ar/native_ar');
  static const EventChannel _eventChannel = EventChannel('com.hotncold.ar/ar_events');

  /// Check if AR is supported on this device.
  static Future<bool> isARSupported() async {
    try {
      final bool? supported = await _channel.invokeMethod('isARSupported');
      return supported ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Initialize AR session with reward data.
  /// 
  /// Parameters:
  /// - rewardBearing: Direction to reward in degrees (0-360, 0=north)
  /// - rewardDistance: Distance to reward in meters
  /// - rewardElevation: Elevation angle in degrees (-90 to +90)
  /// - rewardType: Type of reward (points, coupon, raffle, product)
  static Future<void> startARSession({
    required double rewardBearing,
    required double rewardDistance,
    required double rewardElevation,
    required String rewardType,
    required double userLatitude,
    required double userLongitude,
  }) async {
    try {
      await _channel.invokeMethod('startARSession', {
        'rewardBearing': rewardBearing,
        'rewardDistance': rewardDistance,
        'rewardElevation': rewardElevation,
        'rewardType': rewardType,
        'userLatitude': userLatitude,
        'userLongitude': userLongitude,
      });
    } catch (e) {
      throw Exception('Failed to start AR session: $e');
    }
  }

  /// Stop the current AR session.
  static Future<void> stopARSession() async {
    try {
      await _channel.invokeMethod('stopARSession');
    } catch (e) {
      // Ignore errors on stop
    }
  }

  /// Listen to AR events (reward collected, errors, etc.)
  static Stream<Map<String, dynamic>> get arEvents {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return Map<String, dynamic>.from(event as Map);
    });
  }

  /// Manually trigger reward collection (for testing).
  static Future<void> collectReward() async {
    try {
      await _channel.invokeMethod('collectReward');
    } catch (e) {
      throw Exception('Failed to collect reward: $e');
    }
  }
}

/// AR event types from native side.
enum AREventType {
  rewardInView,
  rewardCollected,
  arSessionFailed,
  arSessionStarted,
  arTrackingQualityChanged,
}

/// Parse event type from string.
AREventType? parseAREventType(String? type) {
  switch (type) {
    case 'rewardInView':
      return AREventType.rewardInView;
    case 'rewardCollected':
      return AREventType.rewardCollected;
    case 'arSessionFailed':
      return AREventType.arSessionFailed;
    case 'arSessionStarted':
      return AREventType.arSessionStarted;
    case 'arTrackingQualityChanged':
      return AREventType.arTrackingQualityChanged;
    default:
      return null;
  }
}
