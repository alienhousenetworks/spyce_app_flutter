import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class TokenStorage {
  TokenStorage({
    FlutterSecureStorage? secure,
    SharedPreferences? prefs,
  })  : _secure = secure ?? const FlutterSecureStorage(),
        _prefs = prefs;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _deviceIdKey = 'device_id';

  final FlutterSecureStorage _secure;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<String?> getAccessToken() => _secure.read(key: _accessKey);
  Future<String?> getRefreshToken() => _secure.read(key: _refreshKey);

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _secure.write(key: _accessKey, value: access);
    await _secure.write(key: _refreshKey, value: refresh);
  }

  Future<void> clearTokens() async {
    await _secure.delete(key: _accessKey);
    await _secure.delete(key: _refreshKey);
  }

  Future<String> getOrCreateDeviceId() async {
    final prefs = await _p;
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = 'flutter-${const Uuid().v4()}';
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }
}
