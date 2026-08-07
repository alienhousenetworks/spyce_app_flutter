import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import 'amplify_config_builder.dart';

/// Configures AWS Amplify Auth (Cognito) for Face Liveness streaming.
///
/// Industry pattern:
/// - Django JWT = app login (unchanged)
/// - Cognito Identity Pool = short-lived AWS creds on device for Rekognition stream
/// - Secret Rekognition keys stay on the backend only
class AmplifyBootstrap {
  AmplifyBootstrap._();

  static bool _configured = false;
  static String? _lastIdentityPoolId;
  static String? _lastError;

  static bool get isConfigured => _configured;
  static String? get lastError => _lastError;

  /// Build config from compile-time dart-defines (optional offline/bootstrap).
  static AmplifyCognitoConfig? fromDartDefines() {
    final identity = Env.cognitoIdentityPoolId.trim();
    if (identity.isEmpty) return null;
    return AmplifyCognitoConfig(
      region: Env.cognitoRegion.trim().isEmpty
          ? 'ap-south-1'
          : Env.cognitoRegion.trim(),
      identityPoolId: identity,
      userPoolId: Env.cognitoUserPoolId.trim(),
      appClientId: Env.cognitoAppClientId.trim(),
    );
  }

  /// Configure Amplify once. Safe to call multiple times with same pool.
  static Future<bool> configure(AmplifyCognitoConfig config) async {
    if (!config.isValid) {
      _lastError =
          'Missing COGNITO_IDENTITY_POOL_ID / region for Amplify Face Liveness.';
      return false;
    }

    if (_configured && _lastIdentityPoolId == config.identityPoolId) {
      return true;
    }

    // Already configured with different pool — Amplify forbids reconfigure.
    if (Amplify.isConfigured) {
      _configured = true;
      _lastIdentityPoolId = config.identityPoolId;
      return true;
    }

    try {
      await Amplify.addPlugin(AmplifyAuthCognito());
      await Amplify.configure(config.toAmplifyConfigJson());
      _configured = true;
      _lastIdentityPoolId = config.identityPoolId;
      _lastError = null;

      // Warm credentials (guest / unauthenticated Identity Pool).
      try {
        await Amplify.Auth.fetchAuthSession();
      } catch (e) {
        // Guest access may still work at native layer; log only.
        if (kDebugMode) {
          debugPrint('Amplify fetchAuthSession: $e');
        }
      }
      return true;
    } on AmplifyAlreadyConfiguredException {
      _configured = true;
      _lastIdentityPoolId = config.identityPoolId;
      _lastError = null;
      return true;
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) {
        debugPrint('Amplify.configure failed: $e');
      }
      return false;
    }
  }

  /// Prefer server public Cognito IDs; fall back to dart-defines.
  static Future<bool> configureFromMaps({
    Map<String, dynamic>? serverStatus,
  }) async {
    AmplifyCognitoConfig? config;
    if (serverStatus != null) {
      final fromServer = AmplifyCognitoConfig.fromMap(serverStatus);
      if (fromServer.isValid) config = fromServer;
    }
    config ??= fromDartDefines();
    if (config == null) {
      _lastError =
          'Cognito not configured. Set COGNITO_* in backend .env or flutter --dart-define.';
      return false;
    }
    return configure(config);
  }

  /// Best-effort early configure at app start (dart-defines only).
  static Future<void> tryConfigureAtStartup() async {
    final config = fromDartDefines();
    if (config == null) return;
    await configure(config);
  }
}
