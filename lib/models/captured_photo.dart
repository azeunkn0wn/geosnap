import 'dart:io';

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
