import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationUtils {
  /// Request location permissions (foreground only)
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  /// Check if location permission is granted
  static Future<bool> isLocationPermissionGranted() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  /// Get the current device location (high accuracy)
  static Future<Position?> getCurrentLocation() async {
    final hasPermission = await isLocationPermissionGranted();
    if (!hasPermission) {
      final requested = await requestLocationPermission();
      if (!requested) return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }
}
