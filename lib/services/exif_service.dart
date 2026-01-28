import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_exif/native_exif.dart';

class ExifService {
  /// Write GPS EXIF data to an image file
  Future<void> writeGpsData(String imagePath, Position position) async {
    try {
      final exif = await Exif.fromPath(imagePath);

      final gpsData = {
        'GPSLatitude': position.latitude.abs().toString(),
        'GPSLatitudeRef': position.latitude >= 0 ? 'N' : 'S',
        'GPSLongitude': position.longitude.abs().toString(),
        'GPSLongitudeRef': position.longitude >= 0 ? 'E' : 'W',
        'GPSAltitude': position.altitude.toString(),
        'GPSAltitudeRef': position.altitude >= 0 ? '0' : '1',
      };

      debugPrint('Writing GPS data: $gpsData');

      // Set GPS coordinates
      await exif.writeAttributes(gpsData);
      await exif.close();

      // Verify data was written
      final verifyExif = await Exif.fromPath(imagePath);
      final attributes = await verifyExif.getAttributes();
      debugPrint(
        'Verified EXIF data: ${attributes?['GPSLatitude']}, ${attributes?['GPSLongitude']}',
      );
      await verifyExif.close();
    } catch (e) {
      debugPrint('Error writing EXIF data: $e');
      rethrow;
    }
  }
}
