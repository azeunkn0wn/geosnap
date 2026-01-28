import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:native_exif/native_exif.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const GeoSnapApp());
}

class GeoSnapApp extends StatelessWidget {
  const GeoSnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoSnap',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const GeoSnapHome(),
    );
  }
}

class GeoSnapHome extends StatefulWidget {
  const GeoSnapHome({super.key});

  @override
  State<GeoSnapHome> createState() => _GeoSnapHomeState();
}

class _GeoSnapHomeState extends State<GeoSnapHome> {
  final ImagePicker _picker = ImagePicker();
  Position? _currentPosition;
  bool _isLoading = false;
  String? _statusMessage;
  final List<CapturedPhoto> _capturedPhotos = [];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking permissions...';
    });

    final locationPermission = await _checkLocationPermission();
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

  Future<bool> _checkLocationPermission() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        _showLocationServiceDialog();
      }
      return false;
    }

    // Check permission status
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          _showSnackBar('Location permission denied');
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        _showPermanentlyDeniedDialog();
      }
      return false;
    }

    return true;
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

  Future<Position?> _getCurrentLocation() async {
    try {
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) return null;

      setState(() {
        _statusMessage = 'Getting location...';
      });

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      return position;
    } catch (e) {
      _showSnackBar('Error getting location: $e');
      return null;
    }
  }

  Future<void> _updateLocation() async {
    setState(() {
      _isLoading = true;
    });

    final position = await _getCurrentLocation();

    if (position != null) {
      setState(() {
        _currentPosition = position;
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
    setState(() {
      _isLoading = true;
      _statusMessage = 'Preparing camera...';
    });

    try {
      // Get location first
      final position = await _getCurrentLocation();
      if (position == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Could not get location';
        });
        return;
      }

      setState(() {
        _currentPosition = position;
        _statusMessage = 'Opening camera...';
      });

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
      final savedFile = await _saveImageWithLocation(image, position);

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

  Future<File?> _saveImageWithLocation(XFile image, Position position) async {
    try {
      // Create temporary file with EXIF data in app's temp directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'GeoSnap_$timestamp.jpg';
      final tempPath = path.join(tempDir.path, fileName);

      // Copy image to temp location
      final tempFile = await File(image.path).copy(tempPath);

      // Write EXIF data with GPS coordinates
      await _writeExifData(tempFile.path, position);

      // Save to gallery using gal package (handles permissions automatically)
      await Gal.putImage(tempFile.path, album: 'GeoSnap');

      // Return the temp file for display in the app
      // Note: The image is now also saved to the device gallery
      return tempFile;
    } catch (e) {
      _showSnackBar('Error saving image: $e');
      return null;
    }
  }

  Future<void> _writeExifData(String imagePath, Position position) async {
    try {
      final exif = await Exif.fromPath(imagePath);

      // Set GPS coordinates
      await exif.writeAttributes({
        'GPSLatitude': _convertToExifGps(position.latitude.abs()),
        'GPSLatitudeRef': position.latitude >= 0 ? 'N' : 'S',
        'GPSLongitude': _convertToExifGps(position.longitude.abs()),
        'GPSLongitudeRef': position.longitude >= 0 ? 'E' : 'W',
        'GPSAltitude': position.altitude.toString(),
        'GPSAltitudeRef': position.altitude >= 0 ? '0' : '1',
      });

      await exif.close();
    } catch (e) {
      debugPrint('Error writing EXIF data: $e');
    }
  }

  String _convertToExifGps(double coordinate) {
    final degrees = coordinate.floor();
    final minutesFloat = (coordinate - degrees) * 60;
    final minutes = minutesFloat.floor();
    final seconds = (minutesFloat - minutes) * 60;

    return '$degrees/1,$minutes/1,${(seconds * 10000).round()}/10000';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
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
          if (_currentPosition != null)
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
                      'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, '
                      'Lon: ${_currentPosition!.longitude.toStringAsFixed(6)}',
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the camera button to capture\na photo with GPS coordinates',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                      DateFormat('MMM dd, yyyy HH:mm:ss').format(photo.timestamp),
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

class CapturedPhoto {
  final File file;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  CapturedPhoto({
    required this.file,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
}
