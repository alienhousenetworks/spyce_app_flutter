import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/repositories/api_repositories.dart';

/// Keeps Redis presence / last_active fresh while the app is in the foreground.
///
/// Backend online window is ~5 minutes (presence TTL + last_active check).
/// We heartbeat ~every 90s so "Online" stays accurate while SPYCE is open.
class PresenceService with WidgetsBindingObserver {
  PresenceService(this._ref);

  final Ref _ref;
  Timer? _timer;
  bool _started = false;
  bool _pingInFlight = false;
  double? _lat;
  double? _lon;

  static const _interval = Duration(seconds: 90);

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
      await _ensureCoords();
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

  Future<void> _ensureCoords() async {
    if (_lat != null && _lon != null) return;

    // 1) Profile-stored coords (no extra permission prompt)
    try {
      final p = await _ref.read(profileRepositoryProvider).getMyProfile();
      if (p.latitude != null && p.longitude != null) {
        _lat = p.latitude;
        _lon = p.longitude;
        return;
      }
    } catch (_) {}

    // 2) Device GPS if already permitted (don't force prompt on every heartbeat)
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _lat = double.parse(pos.latitude.toStringAsFixed(6));
      _lon = double.parse(pos.longitude.toStringAsFixed(6));
    } catch (_) {}
  }
}

final presenceServiceProvider = Provider<PresenceService>((ref) {
  final service = PresenceService(ref);
  ref.onDispose(service.stop);
  return service;
});
