import 'dart:convert';

/// Builds Amplify Gen1-style `amplifyconfiguration.json` for Auth (Cognito).
///
/// Used by:
/// - `Amplify.configure(...)` in Dart
/// - `scripts/generate_amplify_config.sh` for Android `res/raw` + iOS bundle
///
/// Only **public** Cognito identifiers — never Rekognition secret keys.
class AmplifyCognitoConfig {
  const AmplifyCognitoConfig({
    required this.region,
    required this.identityPoolId,
    this.userPoolId = '',
    this.appClientId = '',
  });

  final String region;
  final String identityPoolId;
  final String userPoolId;
  final String appClientId;

  bool get isValid =>
      region.trim().isNotEmpty && identityPoolId.trim().isNotEmpty;

  bool get hasUserPool =>
      userPoolId.trim().isNotEmpty && appClientId.trim().isNotEmpty;

  /// JSON string accepted by [Amplify.configure].
  String toAmplifyConfigJson() {
    final authPlugin = <String, dynamic>{
      'UserAgent': 'aws-amplify-cli/0.1.0',
      'Version': '0.1.0',
      'IdentityManager': {
        'Default': {},
      },
      'CredentialsProvider': {
        'CognitoIdentity': {
          'Default': {
            'PoolId': identityPoolId.trim(),
            'Region': region.trim(),
          },
        },
      },
      'Auth': {
        'Default': {
          'authenticationFlowType': 'USER_SRP_AUTH',
        },
      },
    };

    if (hasUserPool) {
      authPlugin['CognitoUserPool'] = {
        'Default': {
          'PoolId': userPoolId.trim(),
          'AppClientId': appClientId.trim(),
          'Region': region.trim(),
        },
      };
    }

    final root = {
      'UserAgent': 'aws-amplify-cli/2.0',
      'Version': '1.0',
      'auth': {
        'plugins': {
          'awsCognitoAuthPlugin': authPlugin,
        },
      },
    };

    return const JsonEncoder.withIndent('  ').convert(root);
  }

  factory AmplifyCognitoConfig.fromMap(Map<String, dynamic> map) {
    return AmplifyCognitoConfig(
      region: (map['cognito_region'] ?? map['region'] ?? 'us-east-1')
          .toString(),
      identityPoolId:
          (map['cognito_identity_pool_id'] ?? map['identityPoolId'] ?? '')
              .toString(),
      userPoolId:
          (map['cognito_user_pool_id'] ?? map['userPoolId'] ?? '').toString(),
      appClientId:
          (map['cognito_app_client_id'] ?? map['appClientId'] ?? '').toString(),
    );
  }
}
