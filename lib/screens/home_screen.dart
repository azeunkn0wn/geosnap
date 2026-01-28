import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/captured_photo.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';

class GeoSnapHome extends StatefulWidget {
  const GeoSnapHome({super.key});

  @override
  State<GeoSnapHome> createState() => _GeoSnapHomeState();
}

class _GeoSnapHomeState extends State<GeoSnapHome> {
  final ImagePicker _picker = ImagePicker();
  final LocationService _locationService = LocationService();
  final StorageService _storageService = StorageService();

  bool _isLoading = false;
  String? _statusMessage;
  final List<CapturedPhoto> _capturedPhotos = [];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }

  Future<void> _startLocationTracking() async {
    final hasPermission = await _locationService.checkLocationPermission();
    if (!hasPermission) return;

    await _locationService.startTracking();

    if (mounted && _locationService.currentPosition != null) {
      setState(() {
        _statusMessage = 'Location ready';
      });
    }
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking permissions...';
    });

    // Check if location services are enabled first
    final serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Location services disabled';
      });
      _showLocationServiceDialog();
      return;
    }

    // Check if permission is permanently denied
    final isPermanentlyDenied = await _locationService.isPermissionDeniedForever();
    if (isPermanentlyDenied) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Location permission required';
      });
      _showPermanentlyDeniedDialog();
      return;
    }

    // Try to get permission
    final locationPermission = await _locationService.checkLocationPermission();
    if (!locationPermission) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Location permission required';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _statusMessage = 'Ready to capture';
    });
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text(
          'Location services are disabled. Please enable them in your device settings to use GeoSnap.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location permission is permanently denied. GeoSnap needs location access to embed GPS coordinates in your photos.\n\n'
          'Please go to Settings and enable location permission for this app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
              // Re-check permissions after returning from settings
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  _checkPermissions();
                }
              });
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateLocation() async {
    setState(() {
      _isLoading = true;
    });

    final position = await _locationService.getCurrentLocation();

    if (position != null) {
      setState(() {
        _statusMessage = 'Location updated';
        _isLoading = false;
      });
      _showSnackBar(
        'Location updated\nLat: ${position.latitude.toStringAsFixed(6)}\nLon: ${position.longitude.toStringAsFixed(6)}',
      );
    } else {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Could not get location';
      });
    }
  }

  Future<void> _captureImage() async {
    // Check if location is available
    if (_locationService.currentPosition == null) {
      _showSnackBar('Location not available yet. Please wait...');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Opening camera...';
    });

    try {
      final position = _locationService.currentPosition!;

      // Capture image
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Capture cancelled';
        });
        return;
      }

      setState(() {
        _statusMessage = 'Processing image...';
      });

      // Save image with geolocation metadata
      final savedFile = await _storageService.saveImageWithLocation(
        image,
        position,
        onError: _showSnackBar,
      );

      if (savedFile != null) {
        final photo = CapturedPhoto(
          file: savedFile,
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
        );

        setState(() {
          _capturedPhotos.insert(0, photo);
          _isLoading = false;
          _statusMessage = 'Photo saved with GPS data!';
        });

        _showSnackBar(
          'Photo saved!\nLat: ${position.latitude.toStringAsFixed(6)}\nLon: ${position.longitude.toStringAsFixed(6)}',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
      });
      _showSnackBar('Error capturing image: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GeoSnap'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _isLoading ? null : _updateLocation,
            tooltip: 'Update location',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkPermissions,
            tooltip: 'Refresh permissions',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    _statusMessage?.contains('Ready') == true
                        ? Icons.check_circle
                        : Icons.info,
                    size: 16,
                    color: _statusMessage?.contains('Ready') == true
                        ? Colors.green
                        : Colors.orange,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage ?? 'Initializing...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),

          // Current location display
          if (_locationService.currentPosition != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.teal.withAlpha(25),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.teal, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lat: ${_locationService.currentPosition!.latitude.toStringAsFixed(6)}, '
                      'Lon: ${_locationService.currentPosition!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Main content
          Expanded(
            child: _capturedPhotos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 80,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No photos yet',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the camera button to capture\na photo with GPS coordinates',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _capturedPhotos.length,
                    itemBuilder: (context, index) {
                      final photo = _capturedPhotos[index];
                      return _buildPhotoCard(photo);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _captureImage,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Capture'),
        backgroundColor: _isLoading ? Colors.grey : null,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildPhotoCard(CapturedPhoto photo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.file(
              photo.file,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.teal),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${photo.latitude.toStringAsFixed(6)}, ${photo.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat(
                        'MMM dd, yyyy HH:mm:ss',
                      ).format(photo.timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
