import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/repositories/api_repositories.dart';

/// Keeps Redis presence / last_active fresh while the app is in the foreground.
///
/// Backend online window is ~5 minutes (presence TTL + last_active check).
/// We heartbeat ~every 90s so "Online" stays accurate while SPYCE is open.
///
/// GPS is refreshed periodically (not frozen at first fix) so when the user
/// travels to another city, profile location + discovery geo update.
class PresenceService with WidgetsBindingObserver {
  PresenceService(this._ref);

  final Ref _ref;
  Timer? _timer;
  bool _started = false;
  bool _pingInFlight = false;
  double? _lat;
  double? _lon;
  DateTime? _lastGpsRefresh;

  static const _interval = Duration(seconds: 90);
  /// Re-read device GPS at least this often (covers city changes while app open).
  static const _gpsRefreshEvery = Duration(minutes: 3);
  /// ~2 km — treat as meaningful move even between GPS refreshes.
  static const _moveThresholdMeters = 2000.0;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _ping(); // immediate
    _timer = Timer.periodic(_interval, (_) => _ping());
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Force a fresh GPS read after background (user may have changed city)
        _lastGpsRefresh = null;
        _ping();
        _timer?.cancel();
        _timer = Timer.periodic(_interval, (_) => _ping());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Stop pings when backgrounded so presence TTL can expire → offline
        _timer?.cancel();
        _timer = null;
    }
  }

  Future<void> _ping() async {
    if (_pingInFlight) return;
    _pingInFlight = true;
    try {
      await _ensureCoords(forceRefresh: _shouldRefreshGps());
      await _ref.read(authRepositoryProvider).heartbeat(
            lat: _lat,
            lon: _lon,
          );
    } catch (_) {
      // Silent — presence is best-effort
    } finally {
      _pingInFlight = false;
    }
  }

  bool _shouldRefreshGps() {
    if (_lat == null || _lon == null) return true;
    if (_lastGpsRefresh == null) return true;
    return DateTime.now().difference(_lastGpsRefresh!) >= _gpsRefreshEvery;
  }

  Future<void> _ensureCoords({bool forceRefresh = false}) async {
    // 1) Prefer live device GPS when permitted (updates when user changes city)
    final gps = await _readDeviceGps();
    if (gps != null) {
      final newLat = gps.$1;
      final newLon = gps.$2;
      if (_lat == null ||
          _lon == null ||
          forceRefresh ||
          _movedEnough(_lat!, _lon!, newLat, newLon)) {
        _lat = newLat;
        _lon = newLon;
      }
      _lastGpsRefresh = DateTime.now();
      return;
    }

    // 2) Fall back to cached / profile coords if GPS unavailable
    if (_lat != null && _lon != null && !forceRefresh) return;

    try {
      final p = await _ref.read(profileRepositoryProvider).getMyProfile();
      if (p.latitude != null && p.longitude != null) {
        _lat = p.latitude;
        _lon = p.longitude;
      }
    } catch (_) {}
  }

  bool _movedEnough(double aLat, double aLon, double bLat, double bLon) {
    try {
      final m = Geolocator.distanceBetween(aLat, aLon, bLat, bLon);
      return m >= _moveThresholdMeters;
    } catch (_) {
      return (aLat - bLat).abs() > 0.02 || (aLon - bLon).abs() > 0.02;
    }
  }

  Future<(double, double)?> _readDeviceGps() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return (
        double.parse(pos.latitude.toStringAsFixed(6)),
        double.parse(pos.longitude.toStringAsFixed(6)),
      );
    } catch (_) {
      return null;
    }
  }
}

final presenceServiceProvider = Provider<PresenceService>((ref) {
  final service = PresenceService(ref);
  ref.onDispose(service.stop);
  return service;
});
