import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/api_client.dart';
import '../../auth/providers/auth_provider.dart';

/// Model representing a reward template from the API.
class RewardTemplate {
  final String id;
  final String rewardType;
  final int rewardValue;
  final String? rewardDescription;
  final double bearingDegrees;
  final double elevationDegrees;
  final bool isActive;

  RewardTemplate({
    required this.id,
    required this.rewardType,
    required this.rewardValue,
    this.rewardDescription,
    required this.bearingDegrees,
    required this.elevationDegrees,
    required this.isActive,
  });

  factory RewardTemplate.fromJson(Map<String, dynamic> json) {
    return RewardTemplate(
      id: json['id'],
      rewardType: json['reward_type'],
      rewardValue: json['reward_value'],
      rewardDescription: json['reward_description'],
      bearingDegrees: (json['bearing_degrees'] as num).toDouble(),
      elevationDegrees: (json['elevation_degrees'] as num).toDouble(),
      isActive: json['is_active'] ?? true,
    );
  }
}

/// Model representing a treasure location from the API.
class TreasureLocation {
  final String id;
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final String? address;
  final String? imageUrl;
  final int radiusM;
  final String city;
  final double distanceM;
  final RewardTemplate? rewardTemplate;

  TreasureLocation({
    required this.id,
    required this.name,
    this.description,
    required this.latitude,
    required this.longitude,
    this.address,
    this.imageUrl,
    required this.radiusM,
    required this.city,
    required this.distanceM,
    this.rewardTemplate,
  });

  factory TreasureLocation.fromJson(Map<String, dynamic> json) {
    return TreasureLocation(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'],
      imageUrl: json['image_url'],
      radiusM: json['radius_m'] ?? 100,
      city: json['city'],
      distanceM: (json['distance_m'] as num?)?.toDouble() ?? 0,
      rewardTemplate: json['reward_template'] != null
          ? RewardTemplate.fromJson(json['reward_template'])
          : null,
    );
  }
}

/// Current user position provider.
final userPositionProvider = FutureProvider<Position>((ref) async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Location services are disabled');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception('Location permission permanently denied');
  }

  return await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
});

/// Nearby locations fetched from the backend API.
final nearbyLocationsProvider = FutureProvider<List<TreasureLocation>>((
  ref,
) async {
  // Wait for authentication state
  final authState = await ref.watch(authStateProvider.future);

  // Return empty list if not authenticated
  if (authState == null) {
    return [];
  }

  final dio = ref.read(dioProvider);
  final position = await ref.watch(userPositionProvider.future);

  try {
    final response = await dio.get(
      '/map/locations',
      queryParameters: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'radius_km': 1000.0,
      },
    );

    final List data = response.data;
    return data.map((e) => TreasureLocation.fromJson(e)).toList();
  } on DioException catch (e) {
    throw Exception(e.response?.data?['detail'] ?? 'Failed to load locations');
  }
});
