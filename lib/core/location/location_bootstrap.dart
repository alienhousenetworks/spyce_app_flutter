import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/api_repositories.dart';
import '../utils/num_parse.dart';

/// First-open GPS bootstrap:
/// 1) request location permission
/// 2) read device GPS
/// 3) reverse-geocode + PATCH profile
///
/// Safe against `String is not a subtype of num` from API responses.
class LocationBootstrap {
  LocationBootstrap(this._ref);

  final Ref _ref;
  static const _doneKey = 'location_bootstrap_done_v1';
  bool _running = false;

  /// Call once after login / app shell mount.
  /// Enforces GPS location permission and detection on first open.
  Future<bool> ensureOnFirstOpen() async {
    if (_running) return true;
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();

      // If profile already has coords, verify location permission & saved coords
      try {
        final p = await _ref.read(profileRepositoryProvider).getMyProfile();
        if (p.latitude != null && p.longitude != null) {
          final perm = await Geolocator.checkPermission();
          if (perm != LocationPermission.denied &&
              perm != LocationPermission.deniedForever) {
            await prefs.setBool(_doneKey, true);
            return true;
          }
        }
      } catch (_) {}

      // Prompt and demand location permission & detection
      final success = await detectAndSave(force: true);
      if (success) {
        await prefs.setBool(_doneKey, true);
      }
      return success;
    } finally {
      _running = false;
    }
  }

  Future<bool> detectAndSave({bool force = false}) async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        debugPrint('[LOC] services disabled');
        return false;
      }

      // Permission: geolocator + permission_handler
      var gPerm = await Geolocator.checkPermission();
      if (gPerm == LocationPermission.denied) {
        gPerm = await Geolocator.requestPermission();
      }
      if (gPerm == LocationPermission.denied ||
          gPerm == LocationPermission.deniedForever) {
        // Also try permission_handler
        final ph = await Permission.locationWhenInUse.request();
        if (!ph.isGranted) {
          debugPrint('[LOC] permission denied');
          return false;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final lat = parseDouble(pos.latitude.toStringAsFixed(6));
      final lon = parseDouble(pos.longitude.toStringAsFixed(6));
      if (lat == null || lon == null) return false;

      String? city;
      String? state;
      String? country;
      try {
        final geo = await _ref
            .read(profileRepositoryProvider)
            .reverseGeocode(lat, lon);
        city = geo['city']?.toString();
        state = geo['state']?.toString();
        country = geo['country']?.toString();
        if (city == null || city.isEmpty || city == 'Unknown') {
          final display = geo['display_name']?.toString();
          if (display != null && display.isNotEmpty) {
            city = display.split(',').first.trim();
          }
        }
      } catch (e) {
        debugPrint('[LOC] reverse geocode failed: $e');
      }

      // Always send numbers (not strings) to avoid backend/serializer issues
      final payload = <String, dynamic>{
        'latitude': lat,
        'longitude': lon,
        if (city != null && city.isNotEmpty && city != 'Unknown') 'city': city,
        if (state != null && state.isNotEmpty && state != 'Unknown')
          'state': state,
        if (country != null && country.isNotEmpty && country != 'Unknown')
          'country': country,
      };

      await _ref.read(profileRepositoryProvider).updateMyProfile(payload);
      debugPrint('[LOC] saved $lat,$lon city=$city');
      return true;
    } catch (e, st) {
      debugPrint('[LOC] detect failed: $e\n$st');
      return false;
    }
  }
}

final locationBootstrapProvider = Provider<LocationBootstrap>((ref) {
  return LocationBootstrap(ref);
});
