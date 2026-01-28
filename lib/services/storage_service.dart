import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'exif_service.dart';

class StorageService {
  final ExifService _exifService = ExifService();

  /// Save image with GPS metadata to gallery
  Future<File?> saveImageWithLocation(
    XFile image,
    Position position, {
    Function(String)? onError,
  }) async {
    try {
      // Request photos permission for Android 13+
      if (Platform.isAndroid) {
        final photosPermission = await Permission.photos.request();
        if (!photosPermission.isGranted) {
          onError?.call(
            'Photos permission denied. Image saved to app folder only.',
          );
        }
      }

      // Create temporary file with EXIF data in app's temp directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'GeoSnap_$timestamp.jpg';
      final tempPath = path.join(tempDir.path, fileName);

      // Copy image to temp location
      final tempFile = await File(image.path).copy(tempPath);

      // Write EXIF data with GPS coordinates
      await _exifService.writeGpsData(tempFile.path, position);

      // Save to gallery using gal package
      try {
        await Gal.putImage(tempFile.path, album: 'GeoSnap');
        debugPrint('Image saved to gallery successfully');
      } catch (galError) {
        debugPrint('Error saving to gallery: $galError');
        onError?.call('Photo saved locally. Gallery save failed: $galError');
      }

      // Return the temp file for display in the app
      // Note: The image is now also saved to the device gallery
      return tempFile;
    } catch (e) {
      debugPrint('Error saving image: $e');
      onError?.call('Error saving image: $e');
      return null;
    }
  }
}
