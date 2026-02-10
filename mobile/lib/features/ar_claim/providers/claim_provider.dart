import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/api_client.dart';

/// Response model for reward claim.
class ClaimResult {
  final String rewardType;
  final int rewardValue;
  final String? rewardDescription;
  final int totalPoints;
  final String locationId;
  final String locationName;

  ClaimResult({
    required this.rewardType,
    required this.rewardValue,
    this.rewardDescription,
    required this.totalPoints,
    required this.locationId,
    required this.locationName,
  });

  factory ClaimResult.fromJson(Map<String, dynamic> json) {
    return ClaimResult(
      rewardType: json['reward_type'],
      rewardValue: json['reward_value'],
      rewardDescription: json['reward_description'],
      totalPoints: json['total_points'],
      locationId: json['location_id'],
      locationName: json['location_name'],
    );
  }
}

/// Claim a reward at a specific location.
///
/// Sends user's GPS coordinates to the backend for proximity validation,
/// then awards the reward if all checks pass.
final claimRewardProvider = FutureProvider.family<ClaimResult, String>((
  ref,
  locationId,
) async {
  final dio = ref.watch(dioProvider);

  // Get current position
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );

  // Make claim request
  final response = await dio.post(
    '/locations/$locationId/claim',
    data: {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'device_id': null, // Can add device fingerprinting later
    },
  );

  return ClaimResult.fromJson(response.data);
});
