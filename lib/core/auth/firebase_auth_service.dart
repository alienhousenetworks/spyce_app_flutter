import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/firebase_options.dart';

class FirebaseSession {
  const FirebaseSession({required this.idToken, required this.email});

  final String idToken;
  final String email;
}

/// Firebase Auth (Google Sign-In + Email/Password + Verification) → Backend `/auth/firebase-login/`.
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

  /// Sign up with email & password via Firebase and send verification link.
  static Future<String> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    await ensureInitialized();
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
      final user = credential.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
      return 'A verification link has been sent to ${email.trim()}. Please verify your email before signing in.';
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw StateError('An account with this email already exists. Please sign in.');
        case 'invalid-email':
          throw StateError('Invalid email address.');
        case 'weak-password':
          throw StateError('Password is too weak. Please use at least 8 characters.');
        default:
          throw StateError(e.message ?? 'Registration failed. Please try again.');
      }
    }
  }

  /// Sign in with email & password via Firebase. Requires email verification.
  static Future<FirebaseSession> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    await ensureInitialized();
    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
      final user = credential.user;
      if (user == null) {
        throw StateError('Could not sign in with provided credentials.');
      }

      await user.reload();
      final freshUser = FirebaseAuth.instance.currentUser;
      if (freshUser != null && !freshUser.emailVerified) {
        try {
          await freshUser.sendEmailVerification();
        } catch (_) {}
        throw StateError(
          'Email not verified yet. We resent a verification link to $email. Please click the link to verify.',
        );
      }

      final idToken = await freshUser?.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Could not obtain authentication token.');
      }

      return FirebaseSession(
        idToken: idToken,
        email: freshUser?.email ?? email.trim(),
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          throw StateError('Invalid email or password.');
        case 'user-disabled':
          throw StateError('This account has been disabled.');
        case 'too-many-requests':
          throw StateError('Too many failed attempts. Please wait a moment and try again.');
        default:
          throw StateError(e.message ?? 'Sign-in failed. Please try again.');
      }
    }
  }

  /// Send password reset link to user email via Firebase.
  static Future<void> sendPasswordResetEmail(String email) async {
    await ensureInitialized();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw StateError('No account found with this email.');
        case 'invalid-email':
          throw StateError('Invalid email address.');
        default:
          throw StateError(e.message ?? 'Could not send password reset email.');
      }
    }
  }

  static Future<FirebaseSession?> signInWithGoogle() async {
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

  static Future<FirebaseSession> _exchangeGoogleAccount(
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
    return FirebaseSession(idToken: firebaseToken, email: email);
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
