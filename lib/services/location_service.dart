import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _currentPosition;

  Position? get currentPosition => _currentPosition;

  /// Start continuous location tracking
  Future<void> startTracking() async {
    // Get initial position
    try {
      _currentPosition = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          );

      debugPrint('Initial location obtained');
    } catch (e) {
      debugPrint('Error getting initial position: $e');
    }

    // Start listening to position updates
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 10, // Update when user moves 10 meters
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen(
      (Position position) {
        _currentPosition = position;
        debugPrint('Location updated: ${position.latitude}, ${position.longitude}');
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
      },
    );
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check if location permission is permanently denied
  Future<bool> isPermissionDeniedForever() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.deniedForever;
  }

  /// Check if location permission is granted
  Future<bool> checkLocationPermission() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Check permission status
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current location with caching
  Future<Position?> getCurrentLocation() async {
    try {
      // Try to get last known position first (instant)
      Position? position = await Geolocator.getLastKnownPosition();

      // Check if cached position is too old (older than 2 minutes) or doesn't exist
      final shouldRefresh = position == null ||
          DateTime.now().difference(position.timestamp).inMinutes > 2;

      if (shouldRefresh) {
        // Get fresh current position
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
      }

      _currentPosition = position;
      return position;
    } catch (e) {
      // If current position fails, try last known as fallback
      try {
        final position = await Geolocator.getLastKnownPosition();
        _currentPosition = position;
        return position;
      } catch (_) {
        debugPrint('Error getting location: $e');
        return null;
      }
    }
  }

  /// Stop location tracking and clean up resources
  void dispose() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }
}
