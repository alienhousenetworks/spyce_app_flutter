import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Firebase client options for project `spyce-95b0d`.
///
/// Public identifiers only (same values as `google-services.json` /
/// `GoogleService-Info.plist`). Override with `--dart-define` if needed.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  /// Web / server OAuth client — required by Google Sign-In on Android.
  static const String webClientId = String.fromEnvironment(
    'FIREBASE_WEB_CLIENT_ID',
    defaultValue:
        '909899990478-r83k10qdh8ij07f0mtqej3c8li5b539e.apps.googleusercontent.com',
  );

  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_ANDROID_API_KEY',
      defaultValue: 'AIzaSyDNUqzN2IeIgz7dWsumUOAAWV4fohBmddA',
    ),
    appId: String.fromEnvironment(
      'FIREBASE_ANDROID_APP_ID',
      defaultValue: '1:909899990478:android:2d8637fa0f9b64b0a1579f',
    ),
    messagingSenderId: '909899990478',
    projectId: 'spyce-95b0d',
    storageBucket: 'spyce-95b0d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_IOS_API_KEY',
      defaultValue: 'AIzaSyBaA2Z7RFt6qRobTlu5_I0IHLJ2denS7pQ',
    ),
    appId: String.fromEnvironment(
      'FIREBASE_IOS_APP_ID',
      defaultValue: '1:909899990478:ios:30a2aab9937c3e45a1579f',
    ),
    messagingSenderId: '909899990478',
    projectId: 'spyce-95b0d',
    storageBucket: 'spyce-95b0d.firebasestorage.app',
    iosBundleId: 'com.spycenow.spyce',
    iosClientId: String.fromEnvironment(
      'FIREBASE_IOS_CLIENT_ID',
      defaultValue:
          '909899990478-1inq93pspd55u9egmfajcicg69flrhlb.apps.googleusercontent.com',
    ),
  );
}
