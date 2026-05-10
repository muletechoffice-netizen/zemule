import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static const double lusakaLatitude = -15.3875;
  static const double lusakaLongitude = 28.3228;

  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }

  Future<LocationPermission> checkAndRequestPermissions() async {
    final isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      return LocationPermission.denied;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  Future<Position> getCurrentLocation() async {
    return await getCurrentLocationOrNull() ?? _fallbackPosition();
  }

  Future<Position?> getCurrentLocationIfPermittedOrNull() async {
    try {
      final isEnabled = await isLocationServiceEnabled();
      if (!isEnabled) {
        return null;
      }

      final permission = await checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Position?> getCurrentLocationOrNull() async {
    try {
      final permission = await checkAndRequestPermissions();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    final meters = Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
    return meters / 1000;
  }

  Future<String> getAreaNameFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final marks = await placemarkFromCoordinates(latitude, longitude);
      if (marks.isNotEmpty) {
        final mark = marks.first;
        final area =
            mark.subLocality ?? mark.locality ?? mark.subAdministrativeArea;
        if (area != null && area.trim().isNotEmpty) {
          return area.trim();
        }
      }
    } catch (_) {
      // Fallback handled below.
    }
    return _nearestKnownArea(latitude, longitude);
  }

  Position _fallbackPosition() {
    return Position(
      latitude: lusakaLatitude,
      longitude: lusakaLongitude,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  String _nearestKnownArea(double latitude, double longitude) {
    const knownAreas = <String, Map<String, double>>{
      'Kabwata': {'lat': -15.4269, 'lng': 28.3161},
      'Matero': {'lat': -15.3726, 'lng': 28.2848},
      'East Park': {'lat': -15.3972, 'lng': 28.3370},
      'Lusaka City': {'lat': -15.4167, 'lng': 28.2833},
      'Woodlands': {'lat': -15.4371, 'lng': 28.3282},
      'Kabulonga': {'lat': -15.4325, 'lng': 28.3377},
      'Chilenje': {'lat': -15.4475, 'lng': 28.3053},
    };

    var bestArea = 'Lusaka';
    var shortest = double.infinity;
    for (final entry in knownAreas.entries) {
      final areaLat = entry.value['lat']!;
      final areaLng = entry.value['lng']!;
      final distance = calculateDistance(latitude, longitude, areaLat, areaLng);
      if (distance < shortest) {
        shortest = distance;
        bestArea = entry.key;
      }
    }
    return bestArea;
  }
}
