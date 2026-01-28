# GeoSnap

A Flutter mobile application that captures photos and automatically embeds GPS coordinates in the image metadata (EXIF data).

## Features

- **Camera Capture**: Take photos directly from the app using your device camera
- **GPS Embedding**: Automatically embeds GPS coordinates (latitude, longitude, altitude) into photo EXIF metadata
- **Gallery Storage**: Photos saved to Pictures/GeoSnap folder (Android) - accessible in Gallery app and file managers
- **Permission Management**: Intelligent handling of camera, location, and storage permissions
- **Settings Redirect**: If location permission is permanently denied, prompts user to open device settings
- **Photo Gallery**: View all captured photos with their GPS coordinates and timestamps
- **Real-time Location**: Displays current GPS coordinates while capturing

## Screenshots

The app includes:

- Status bar showing permission and location status
- Current GPS coordinates display
- Photo gallery with location information
- Floating action button for quick camera access

## Requirements

- **Android**: Minimum SDK 21 (Android 5.0 Lollipop)
- **iOS**: iOS 12.0 or higher
- Device with camera and GPS capabilities
- Location services enabled

## Permissions

### Android

The app requires the following permissions:

- `CAMERA` - To capture photos
- `ACCESS_FINE_LOCATION` - To get precise GPS coordinates
- `ACCESS_COARSE_LOCATION` - Fallback location access
- `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` - For devices below Android 13
- `READ_MEDIA_IMAGES` - For Android 13+

### iOS

The app requires:

- Camera access
- Photo library access
- Location access (when in use)

## Installation

### Prerequisites

- Flutter SDK installed ([Install Flutter](https://flutter.dev/docs/get-started/install))
- Android Studio / Xcode for respective platforms
- Connected device or emulator

### Steps

1. Clone this repository:

```bash
git clone https://github.com/azeunkn0wn/geosnap.git
cd geosnap
```

1. Install dependencies:

```bash
flutter pub get
```

1. Run the app:

```bash
flutter run
```

1. Build APK for Android:

```bash
flutter build apk --release
```

1. Build for iOS:

```bash
flutter build ios --release
```

## Dependencies

| Package | Version | Purpose |
| ------- | ------- | ------- |
| `image_picker` | ^1.0.7 | Camera access and image capture |
| `geolocator` | ^14.0.2 | GPS location services |
| `permission_handler` | ^12.0.1 | Runtime permission management |
| `native_exif` | ^0.7.0 | Write GPS data to image EXIF metadata |
| `gal` | ^2.3.0 | Save images to device gallery/Photos app |
| `path_provider` | ^2.1.2 | Access device directories |
| `path` | ^1.9.0 | Path manipulation utilities |
| `intl` | ^0.20.2 | Date/time formatting |

## How It Works

1. **App Launch**: Checks if location services are enabled and requests location permission
1. **Permission Handling**:
   - If denied: Shows informational message
   - If permanently denied: Opens dialog with link to app settings
   - If granted: Shows "Ready to capture" status
1. **Capture Process**:
   - User taps "Capture" button
   - App retrieves current GPS coordinates
   - Camera opens for photo capture
   - Photo is saved to app documents directory
   - GPS data is written to EXIF metadata
   - Photo appears in the gallery with location info

## EXIF Metadata

The app writes the following GPS data to captured images:

- `GPSLatitude` - Latitude in degrees, minutes, seconds
- `GPSLatitudeRef` - N (North) or S (South)
- `GPSLongitude` - Longitude in degrees, minutes, seconds
- `GPSLongitudeRef` - E (East) or W (West)
- `GPSAltitude` - Altitude in meters
- `GPSAltitudeRef` - Above/below sea level

## Permission Denied Scenarios

### Location Services Disabled

If GPS is turned off on the device, the app shows a dialog prompting the user to enable location services in device settings.

### Location Permission Denied (First Time)

The app requests permission again when the user attempts to capture a photo.

### Location Permission Permanently Denied

A dialog appears with two options:

- **Cancel**: Dismisses the dialog
- **Open Settings**: Takes user directly to the app settings page where they can manually enable location permission

## Troubleshooting

### Location not available

- Ensure location services are enabled on your device
- Check that the app has location permission in device settings
- Try going outside or near a window for better GPS signal

### Camera not opening

- Verify camera permission is granted
- Check that no other app is using the camera
- Restart the app

### Photos not saving

- Ensure sufficient storage space
- Check storage permissions (Android)

## Storage Location

Photos are automatically saved to your device's native gallery using the `gal` package:

- **Android**: Saved to Pictures folder in the "GeoSnap" album (accessible via Gallery app and file managers)
- **iOS**: Saved to Photos app in the "GeoSnap" album

File naming format: `GeoSnap_YYYYMMDD_HHMMSS.jpg`

**Note**: Photos are immediately visible in your device's Gallery/Photos app without any additional steps. They can be easily shared, backed up via cloud services (Google Photos, iCloud), or managed through any file manager or gallery app.

## Future Enhancements

Potential features for future versions:

- Share photos with location data
- View photos on map
- Filter photos by location/date
- Delete individual photos
- Location history tracking
- Batch EXIF editing
- Cloud backup integration

## License

This project is available for personal and commercial use.

## Support

For issues or questions, please open an issue in the project repository.
