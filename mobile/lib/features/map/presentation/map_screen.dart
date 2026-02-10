import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../providers/map_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  TreasureLocation? _selectedLocation;
  bool _hasMovedToUserLocation = false;

  @override
  void initState() {
    super.initState();
    // Move to user location on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final positionAsync = ref.read(userPositionProvider);
      positionAsync.whenData((pos) {
        if (!_hasMovedToUserLocation) {
          _mapController.move(
            LatLng(pos.latitude, pos.longitude),
            AppConstants.defaultZoom,
          );
          _hasMovedToUserLocation = true;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final positionAsync = ref.watch(userPositionProvider);
    final locationsAsync = ref.watch(nearbyLocationsProvider);
    
    // Move map to user location when position first becomes available
    ref.listen(userPositionProvider, (previous, next) {
      next.whenData((pos) {
        if (!_hasMovedToUserLocation) {
          _mapController.move(
            LatLng(pos.latitude, pos.longitude),
            AppConstants.defaultZoom,
          );
          _hasMovedToUserLocation = true;
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('HotNCold'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              positionAsync.whenData((pos) {
                _mapController.move(
                  LatLng(pos.latitude, pos.longitude),
                  AppConstants.defaultZoom,
                );
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                AppConstants.defaultLat,
                AppConstants.defaultLng,
              ),
              initialZoom: AppConstants.defaultZoom,
              onTap: (_, _) => setState(() => _selectedLocation = null),
            ),
            children: [
              // OSM tile layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.hotncold.hotncold',
              ),

              // User position marker
              positionAsync.when(
                data: (pos) => MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(pos.latitude, pos.longitude),
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.secondary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                loading: () => const MarkerLayer(markers: []),
                error: (_, _) => const MarkerLayer(markers: []),
              ),

              // Treasure location markers
              locationsAsync.when(
                data: (locations) => MarkerLayer(
                  markers: locations
                      .map(
                        (loc) => Marker(
                          point: LatLng(loc.latitude, loc.longitude),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedLocation = loc),
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.primary,
                              size: 40,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                loading: () => const MarkerLayer(markers: []),
                error: (_, _) => const MarkerLayer(markers: []),
              ),
            ],
          ),

          // Location detail bottom sheet
          if (_selectedLocation != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _LocationCard(
                location: _selectedLocation!,
                onClaim: () => context.push(
                  '/ar-claim',
                  extra: {
                    'locationId': _selectedLocation!.id,
                    'locationName': _selectedLocation!.name,
                    'rewardBearing': _selectedLocation!.rewardTemplate?.bearingDegrees ?? 45.0,
                    'rewardElevation': _selectedLocation!.rewardTemplate?.elevationDegrees ?? 0.0,
                    'distanceM': _selectedLocation!.distanceM,
                    'rewardType': _selectedLocation!.rewardTemplate?.rewardType ?? 'points',
                  },
                ),
                onClose: () => setState(() => _selectedLocation = null),
              ),
            ),

          // Loading indicator
          if (locationsAsync.isLoading)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),

          // Error message
          if (locationsAsync.hasError)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Cannot connect to backend',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        locationsAsync.error.toString(),
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => ref.refresh(nearbyLocationsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final TreasureLocation location;
  final VoidCallback onClaim;
  final VoidCallback onClose;

  const _LocationCard({
    required this.location,
    required this.onClaim,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    location.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (location.description != null) ...[
              const SizedBox(height: 4),
              Text(
                location.description!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.place,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${location.distanceM.toStringAsFixed(0)}m away',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onClaim,
                  icon: const Icon(Icons.explore, size: 18),
                  label: const Text('Claim Reward'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
