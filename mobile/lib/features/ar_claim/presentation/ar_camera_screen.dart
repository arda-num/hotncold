import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../providers/claim_provider.dart';
import '../services/ar_platform_channel.dart';

/// Native AR camera screen using ARKit (iOS) and ARCore (Android).
///
/// This screen embeds a native platform view that handles all AR rendering,
/// 3D model placement, and user interactions at the native level.
class ARCameraScreen extends ConsumerStatefulWidget {
  final String locationId;
  final String locationName;
  final double rewardBearing;
  final double rewardElevation;
  final double distanceM;
  final String rewardType;
  final String? modelPath;

  const ARCameraScreen({
    required this.locationId,
    required this.locationName,
    required this.rewardBearing,
    required this.rewardElevation,
    required this.distanceM,
    this.rewardType = 'points',
    this.modelPath,
    super.key,
  });

  @override
  ConsumerState<ARCameraScreen> createState() => _ARCameraScreenState();
}

class _ARCameraScreenState extends ConsumerState<ARCameraScreen> {
  bool _arSupported = false;
  bool _isLoading = true;
  bool _isCollecting = false;
  bool _hasCollected = false;
  String? _errorMessage;
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _checkARSupport();
  }

  Future<void> _checkARSupport() async {
    try {
      // Get user position
      _userPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Check if AR is supported
      final supported = await ARPlatformChannel.isARSupported();

      if (!supported) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'AR is not supported on this device';
        });
        return;
      }

      setState(() => _arSupported = true);

      // Listen to AR events
      _eventSubscription = ARPlatformChannel.arEvents.listen(_handleAREvent);

      // Wait for the platform view to be created before starting AR session
      // This ensures the native AR view is ready to receive commands
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Give the platform view a moment to initialize
        await Future.delayed(const Duration(milliseconds: 500));

        try {
          // Start AR session
          await ARPlatformChannel.startARSession(
            rewardBearing: widget.rewardBearing,
            rewardDistance: widget.distanceM,
            rewardElevation: widget.rewardElevation,
            rewardType: widget.rewardType,
            userLatitude: _userPosition!.latitude,
            userLongitude: _userPosition!.longitude,
            modelPath: widget.modelPath,
          );

          setState(() => _isLoading = false);
        } catch (e) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to start AR session: $e';
          });
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize AR: $e';
      });
    }
  }

  void _handleAREvent(Map<String, dynamic> event) {
    final eventType = parseAREventType(event['type'] as String?);

    switch (eventType) {
      case AREventType.arSessionStarted:
        // AR session successfully started
        break;
      case AREventType.rewardInView:
        // Reward is currently visible in AR view
        break;
      case AREventType.rewardCollected:
        // User tapped to collect — trigger backend claim
        _claimReward();
        break;
      case AREventType.arSessionFailed:
        final error = event['error'] as String?;
        setState(() => _errorMessage = error ?? 'AR session failed');
        break;
      case AREventType.arTrackingQualityChanged:
        final quality = event['quality'] as String?;
        // Could show UI hint if tracking quality is low
        break;
      default:
        break;
    }
  }

  Future<void> _claimReward() async {
    if (_isCollecting || _hasCollected) return;

    setState(() => _isCollecting = true);

    try {
      final result = await ref.read(
        claimRewardProvider(widget.locationId).future,
      );

      setState(() {
        _hasCollected = true;
        _isCollecting = false;
      });

      if (mounted) _showSuccessDialog(result);
    } catch (e) {
      setState(() => _isCollecting = false);
      _showErrorSnackBar(_getErrorMessage(e));
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _getErrorMessage(Object error) {
    if (error is DioException) {
      final message = error.response?.data['detail'] ?? error.message;
      return message?.toString() ?? 'Failed to claim reward';
    }
    return error.toString();
  }

  void _showSuccessDialog(ClaimResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Text('Reward Claimed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.rewardDescription ?? '+${result.rewardValue} points',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Total Points: ${result.totalPoints}'),
            Text('Location: ${result.locationName}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop();
            },
            child: const Text('Back to Map'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    ARPlatformChannel.stopARSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Native AR view (show early to ensure platform view is created)
          if (_arSupported && _errorMessage == null) _buildNativeARView(),

          // Loading overlay
          if (_isLoading) _buildLoadingOverlay(),

          // Error overlay
          if (_errorMessage != null) _buildErrorOverlay(),

          // Top bar
          _buildTopBar(),

          // Instruction overlay (when AR is active)
          if (_arSupported &&
              !_isLoading &&
              _errorMessage == null &&
              !_hasCollected)
            _buildInstructionOverlay(),

          // Direction indicator
          if (_arSupported &&
              !_isLoading &&
              _errorMessage == null &&
              !_hasCollected)
            _buildDirectionIndicator(),

          // Center crosshair
          if (_arSupported &&
              !_isLoading &&
              _errorMessage == null &&
              !_hasCollected)
            _buildCrosshair(),

          // Collecting overlay
          if (_isCollecting) _buildCollectingOverlay(),
        ],
      ),
    );
  }

  Widget _buildNativeARView() {
    // Platform-specific AR view
    if (Platform.isIOS) {
      return UiKitView(
        viewType: 'com.hotncold.ar/arkit_view',
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (Platform.isAndroid) {
      return AndroidView(
        viewType: 'com.hotncold.ar/arcore_view',
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return const Center(child: Text('Platform not supported'));
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Initializing AR...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Unknown error',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          8,
          MediaQuery.of(context).padding.top + 4,
          8,
          12,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                widget.locationName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionOverlay() {
    return Positioned(
      bottom: 40,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore, color: Colors.orange, size: 32),
            const SizedBox(height: 8),
            Text(
              'Look around to find the reward',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Distance: ${widget.distanceM.toStringAsFixed(0)}m away',
              style: const TextStyle(color: Colors.orange, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap the glowing object to collect it',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionIndicator() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_searching,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.rewardBearing.toStringAsFixed(0)}° • ${widget.distanceM.toStringAsFixed(0)}m',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCrosshair() {
    String elevationHint = '';
    if (widget.rewardElevation > 10) {
      elevationHint = 'Look up ↑';
    } else if (widget.rewardElevation < -10) {
      elevationHint = 'Look down ↓';
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crosshair
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange, width: 2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.circle, color: Colors.orange, size: 8),
            ),
          ),
          // Elevation hint
          if (elevationHint.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                elevationHint,
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollectingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Collecting reward...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
