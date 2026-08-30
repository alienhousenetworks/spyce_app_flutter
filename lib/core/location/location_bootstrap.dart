import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/api_repositories.dart';
import '../utils/num_parse.dart';

enum LocationDetectStatus {
  ok,
  servicesOff,
  denied,
  deniedForever,
  timeout,
  failed,
}

class LocationDetectResult {
  const LocationDetectResult({
    required this.status,
    this.lat,
    this.lon,
    this.city,
    this.state,
    this.country,
  });

  final LocationDetectStatus status;
  final double? lat;
  final double? lon;
  final String? city;
  final String? state;
  final String? country;

  bool get ok =>
      status == LocationDetectStatus.ok && lat != null && lon != null;

  Map<String, dynamic> toProfilePayload() {
    return {
      if (lat != null) 'latitude': lat,
      if (lon != null) 'longitude': lon,
      if (city != null && city!.isNotEmpty && city != 'Unknown') 'city': city,
      if (state != null && state!.isNotEmpty && state != 'Unknown')
        'state': state,
      if (country != null && country!.isNotEmpty && country != 'Unknown')
        'country': country,
    };
  }
}

/// GPS bootstrap: OS permission dialog → device position → reverse-geocode
/// → PATCH profile. Location is mandatory for discovery.
class LocationBootstrap {
  LocationBootstrap(this._ref);

  final Ref _ref;
  static const _doneKey = 'location_bootstrap_done_v1';
  bool _running = false;

  /// Call once after login / app shell mount.
  Future<bool> ensureOnFirstOpen() async {
    if (_running) return true;
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();

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
    final result = await detect(openSettingsIfNeeded: force);
    if (!result.ok) return false;
    try {
      await _ref
          .read(profileRepositoryProvider)
          .updateMyProfile(result.toProfilePayload());
      debugPrint('[LOC] saved ${result.lat},${result.lon} city=${result.city}');
      return true;
    } catch (e, st) {
      debugPrint('[LOC] save failed: $e\n$st');
      return false;
    }
  }

  /// Always shows the OS location prompt when permission is not granted.
  /// Does not skip the prompt just because GPS is currently off.
  Future<LocationDetectResult> detect({
    bool openSettingsIfNeeded = true,
  }) async {
    try {
      // 1) Permission first — this is what shows the system popup.
      final perm = await _requestPermission();
      if (perm == LocationPermission.deniedForever) {
        debugPrint('[LOC] permission denied forever');
        if (openSettingsIfNeeded) {
          await openAppSettings();
        }
        return const LocationDetectResult(
          status: LocationDetectStatus.deniedForever,
        );
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.unableToDetermine) {
        debugPrint('[LOC] permission denied');
        return const LocationDetectResult(status: LocationDetectStatus.denied);
      }

      // 2) Device location services (GPS)
      var enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        debugPrint('[LOC] services disabled — opening location settings');
        if (openSettingsIfNeeded) {
          await Geolocator.openLocationSettings();
          enabled = await Geolocator.isLocationServiceEnabled();
        }
        if (!enabled) {
          return const LocationDetectResult(
            status: LocationDetectStatus.servicesOff,
          );
        }
      }

      // 3) GPS fix
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final lat = parseDouble(pos.latitude.toStringAsFixed(6));
      final lon = parseDouble(pos.longitude.toStringAsFixed(6));
      if (lat == null || lon == null) {
        return const LocationDetectResult(status: LocationDetectStatus.failed);
      }

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

      return LocationDetectResult(
        status: LocationDetectStatus.ok,
        lat: lat,
        lon: lon,
        city: city,
        state: state,
        country: country,
      );
    } on TimeoutException {
      debugPrint('[LOC] GPS timed out');
      return const LocationDetectResult(status: LocationDetectStatus.timeout);
    } catch (e, st) {
      debugPrint('[LOC] detect failed: $e\n$st');
      if ('$e'.toLowerCase().contains('timeout')) {
        return const LocationDetectResult(status: LocationDetectStatus.timeout);
      }
      return const LocationDetectResult(status: LocationDetectStatus.failed);
    }
  }

  /// Shows the OS permission dialog whenever the status is not already granted.
  Future<LocationPermission> _requestPermission() async {
    var gPerm = await Geolocator.checkPermission();
    if (gPerm == LocationPermission.always ||
        gPerm == LocationPermission.whileInUse) {
      return gPerm;
    }

    // First-time / denied → system sheet (Android + iOS).
    if (gPerm == LocationPermission.denied ||
        gPerm == LocationPermission.unableToDetermine) {
      gPerm = await Geolocator.requestPermission();
    }

    if (gPerm == LocationPermission.always ||
        gPerm == LocationPermission.whileInUse) {
      return gPerm;
    }

    // Some OEM Android builds only respond to permission_handler.
    final ph = await Permission.locationWhenInUse.request();
    if (ph.isGranted || ph.isLimited) {
      return LocationPermission.whileInUse;
    }
    if (ph.isPermanentlyDenied) {
      return LocationPermission.deniedForever;
    }
    return gPerm;
  }
}

final locationBootstrapProvider = Provider<LocationBootstrap>((ref) {
  return LocationBootstrap(ref);
});
