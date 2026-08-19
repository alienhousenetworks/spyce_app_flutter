import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/firebase_options.dart';

class FirebaseGoogleSession {
  const FirebaseGoogleSession({required this.idToken, required this.email});

  final String idToken;
  final String email;
}

/// Google → Firebase ID token → backend `/auth/firebase-login/`.
class FirebaseAuthService {
  FirebaseAuthService._();

  static bool _ready = false;

  static Future<void> ensureInitialized() async {
    if (_ready) return;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await GoogleSignIn.instance.initialize(
      serverClientId: DefaultFirebaseOptions.webClientId,
    );
    _ready = true;
  }

  static Future<FirebaseGoogleSession?> signInWithGoogle() async {
    await ensureInitialized();
    try {
      if (GoogleSignIn.instance.supportsAuthenticate()) {
        final account = await GoogleSignIn.instance.authenticate(
          scopeHint: const ['email', 'profile'],
        );
        return _exchangeGoogleAccount(account);
      }
      final lightweight = await GoogleSignIn.instance
          .attemptLightweightAuthentication();
      if (lightweight == null) {
        throw StateError('Google Sign-In is not available on this device.');
      }
      return _exchangeGoogleAccount(lightweight);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  static Future<FirebaseGoogleSession> _exchangeGoogleAccount(
    GoogleSignInAccount account,
  ) async {
    final auth = account.authentication;
    final googleIdToken = auth.idToken;
    if (googleIdToken == null || googleIdToken.isEmpty) {
      throw StateError('Google did not return an ID token.');
    }
    // google_sign_in 7+ only exposes idToken on authentication; Firebase
    // accepts a Google credential with just the OpenID ID token.
    final credential = GoogleAuthProvider.credential(idToken: googleIdToken);
    final userCred = await FirebaseAuth.instance.signInWithCredential(
      credential,
    );
    final firebaseToken = await userCred.user?.getIdToken();
    if (firebaseToken == null || firebaseToken.isEmpty) {
      throw StateError('Firebase did not return an ID token.');
    }
    final email = (userCred.user?.email ?? account.email).trim();
    return FirebaseGoogleSession(idToken: firebaseToken, email: email);
  }

  static Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('[AUTH] Firebase signOut failed: $e');
    }
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('[AUTH] Google signOut failed: $e');
    }
  }
}
