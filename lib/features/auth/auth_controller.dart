import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/firebase_auth_service.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/onboarding.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/api_repositories.dart';

/// High-level auth UI steps.
enum AuthStep {
  /// Choose Sign in or Sign up.
  welcome,

  /// Enter email (or password / OTP).
  email,

  /// Enter OTP for email verification.
  otp,

  /// Request password reset OTP.
  forgotPassword,

  /// Enter OTP and new password.
  resetPassword,
}

enum AuthMethod {
  otp,
  password,
}

enum AuthMode { signIn, signUp }

/// Only the fields that should affect GoRouter redirects.
/// Watching this (not full [AuthState]) prevents router remount on keystrokes.
typedef AuthNavSnapshot = ({
  bool bootstrapped,
  bool isLoggedIn,
  bool onboardingComplete,
});

class AuthState {
  const AuthState({
    this.step = AuthStep.welcome,
    this.mode = AuthMode.signIn,
    this.method = AuthMethod.otp,
    this.email = '',
    this.user,
    this.loading = false,
    this.error,
    this.message,
    this.bootstrapped = false,
    this.onboardingComplete,
  });

  final AuthStep step;
  final AuthMode mode;
  final AuthMethod method;
  final String email;
  final AuthUser? user;
  final bool loading;
  final String? error;
  final String? message;
  final bool bootstrapped;
  final bool? onboardingComplete;

  bool get isLoggedIn => user != null;

  AuthNavSnapshot get navSnapshot => (
    bootstrapped: bootstrapped,
    isLoggedIn: isLoggedIn,
    onboardingComplete: onboardingComplete == true,
  );

  AuthState copyWith({
    AuthStep? step,
    AuthMode? mode,
    AuthMethod? method,
    String? email,
    AuthUser? user,
    bool clearUser = false,
    bool? loading,
    String? error,
    bool clearError = false,
    String? message,
    bool clearMessage = false,
    bool? bootstrapped,
    bool? onboardingComplete,
    bool clearOnboarding = false,
  }) {
    return AuthState(
      step: step ?? this.step,
      mode: mode ?? this.mode,
      method: method ?? this.method,
      email: email ?? this.email,
      user: clearUser ? null : (user ?? this.user),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      message: clearMessage ? null : (message ?? this.message),
      bootstrapped: bootstrapped ?? this.bootstrapped,
      onboardingComplete: clearOnboarding
          ? null
          : (onboardingComplete ?? this.onboardingComplete),
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState());

  final Ref _ref;

  AuthRepository get _auth => _ref.read(authRepositoryProvider);
  ProfileRepository get _profile => _ref.read(profileRepositoryProvider);

  void chooseSignIn() {
    state = state.copyWith(
      mode: AuthMode.signIn,
      step: AuthStep.email,
      clearError: true,
      clearMessage: true,
    );
  }

  void chooseSignUp() {
    state = state.copyWith(
      mode: AuthMode.signUp,
      step: AuthStep.email,
      clearError: true,
      clearMessage: true,
    );
  }

  void setAuthMethod(AuthMethod method) {
    state = state.copyWith(
      method: method,
      clearError: true,
      clearMessage: true,
    );
  }

  void goBackToWelcome() {
    state = state.copyWith(
      step: AuthStep.welcome,
      email: '',
      clearError: true,
      clearMessage: true,
    );
  }

  /// Flip between sign-in and sign-up while staying on the email step.
  void switchMode() {
    state = state.copyWith(
      mode: state.mode == AuthMode.signIn ? AuthMode.signUp : AuthMode.signIn,
      clearError: true,
      clearMessage: true,
    );
  }

  void goBackToEmail() {
    state = state.copyWith(
      step: AuthStep.email,
      clearError: true,
      clearMessage: true,
    );
  }

  void goToForgotPassword() {
    state = state.copyWith(
      step: AuthStep.forgotPassword,
      clearError: true,
      clearMessage: true,
    );
  }

  /// Commit email only when sending OTP / verifying — not on every keystroke.
  void setEmail(String email) {
    state = state.copyWith(email: email.trim(), clearError: true);
  }

  /// `/users/me/` has no username — merge from `/profile/me/` for watermarks.
  Future<AuthUser> _withProfileIdentity(AuthUser user) async {
    try {
      final profile = await _profile.getMyProfile();
      final uname = profile.username?.trim();
      final fname = (profile.firstName ?? profile.name)?.trim();
      if ((uname == null || uname.isEmpty) &&
          (fname == null || fname.isEmpty) &&
          (user.username == null || user.username!.isEmpty) &&
          (user.firstName == null || user.firstName!.isEmpty)) {
        return user;
      }
      return user.copyWith(
        username: (uname != null && uname.isNotEmpty) ? uname : user.username,
        firstName: (fname != null && fname.isNotEmpty) ? fname : user.firstName,
      );
    } catch (_) {
      return user;
    }
  }

  /// Refresh viewer username from profile (e.g. after onboarding).
  Future<void> refreshViewerIdentity({String? username}) async {
    final current = state.user;
    if (current == null) return;
    if (username != null && username.trim().isNotEmpty) {
      state = state.copyWith(user: current.copyWith(username: username.trim()));
      return;
    }
    final enriched = await _withProfileIdentity(current);
    state = state.copyWith(user: enriched);
  }

  /// Resolve whether the user already finished first-time signup.
  Future<bool> _resolveOnboardingComplete({
    bool? sessionFlag,
    bool? verifyFlag,
    UserProfile? profile,
    bool isNewUser = false,
  }) async {
    if (isNewUser) return false;
    if (verifyFlag == true || sessionFlag == true) return true;
    if (isProfileOnboarded(profile)) return true;

    UserProfile? p = profile;
    if (p == null) {
      try {
        p = await _profile.getMyProfile();
      } catch (_) {
        p = null;
      }
    }
    if (isProfileOnboarded(p)) return true;

    if (verifyFlag == false || sessionFlag == false) {
      return isProfileOnboarded(p);
    }
    return false;
  }

  Future<bool> _handleAuthSuccess(Map<String, dynamic> data) async {
    final isNewUser =
        data['is_new_user'] == true || data['is_new'] == true;
    final verifyOnboarding = data['onboarding_complete'] is bool
        ? data['onboarding_complete'] as bool
        : null;

    var user =
        await _auth.getMe() ??
        AuthUser(
          id: data['user_id']?.toString() ?? 'user',
          email: state.email,
          isNew: isNewUser,
        );
    user = user.copyWith(isNew: isNewUser);

    bool? sessionFlag;
    UserProfile? profile;
    try {
      final session = await _auth.getSession();
      sessionFlag = session?.onboardingComplete;
    } catch (_) {}
    try {
      profile = await _profile.getMyProfile();
      user = user.copyWith(
        username: (profile.username?.trim().isNotEmpty == true)
            ? profile.username!.trim()
            : user.username,
        firstName:
            ((profile.firstName ?? profile.name)?.trim().isNotEmpty == true)
            ? (profile.firstName ?? profile.name)!.trim()
            : user.firstName,
      );
    } catch (_) {
      user = await _withProfileIdentity(user);
    }

    final onboarding = await _resolveOnboardingComplete(
      sessionFlag: sessionFlag,
      verifyFlag: verifyOnboarding,
      profile: profile,
      isNewUser: isNewUser,
    );

    state = state.copyWith(
      loading: false,
      user: user,
      onboardingComplete: onboarding,
      clearError: true,
    );
    return true;
  }

  Future<void> bootstrap() async {
    state = state.copyWith(loading: true);
    try {
      final user = await _auth.getMe();
      if (user != null) {
        bool? sessionFlag;
        UserProfile? profile;
        try {
          final session = await _auth.getSession();
          sessionFlag = session?.onboardingComplete;
        } catch (_) {}
        try {
          profile = await _profile.getMyProfile();
        } catch (_) {}

        final onboarding = await _resolveOnboardingComplete(
          sessionFlag: sessionFlag,
          profile: profile,
        );

        final enriched = profile != null
            ? user.copyWith(
                username: (profile.username?.trim().isNotEmpty == true)
                    ? profile.username!.trim()
                    : user.username,
                firstName:
                    ((profile.firstName ?? profile.name)?.trim().isNotEmpty ==
                        true)
                    ? (profile.firstName ?? profile.name)!.trim()
                    : user.firstName,
              )
            : await _withProfileIdentity(user);
        state = state.copyWith(
          user: enriched,
          onboardingComplete: onboarding,
          loading: false,
          bootstrapped: true,
        );
      } else {
        state = state.copyWith(
          clearUser: true,
          loading: false,
          bootstrapped: true,
          clearOnboarding: true,
        );
      }
    } catch (_) {
      state = state.copyWith(
        clearUser: true,
        loading: false,
        bootstrapped: true,
      );
    }
  }

  Future<bool> requestOtp(String email, {String? captchaToken}) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      state = state.copyWith(error: 'Enter a valid email address.');
      return false;
    }
    state = state.copyWith(
      email: trimmed,
      loading: true,
      clearError: true,
      clearMessage: true,
    );
    try {
      final intent = state.mode == AuthMode.signUp ? 'signup' : 'login';
      final data = await _auth.requestOtp(
        trimmed,
        intent: intent,
        captchaToken: captchaToken,
      );
      if (data['error'] != null) {
        state = state.copyWith(loading: false, error: data['error'].toString());
        return false;
      }
      state = state.copyWith(
        loading: false,
        step: AuthStep.otp,
        message: data['message']?.toString() ?? 'OTP sent to $trimmed',
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Could not send OTP. Check your connection and try again.',
      );
      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    final code = otp.trim();
    if (code.length < 4) {
      state = state.copyWith(error: 'Enter the 6-digit code.');
      return false;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await _auth.verifyOtp(state.email.trim(), code);
      if (!result.ok) {
        state = state.copyWith(
          loading: false,
          error: result.data['error']?.toString() ?? 'Invalid OTP. Try again.',
        );
        return false;
      }
      return _handleAuthSuccess(result.data);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Could not verify OTP. Check your connection and try again.',
      );
      return false;
    }
  }

  Future<bool> registerWithPassword(
    String email,
    String password, {
    String? captchaToken,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      state = state.copyWith(error: 'Enter a valid email address.');
      return false;
    }
    if (password.length < 8) {
      state = state.copyWith(error: 'Password must be at least 8 characters.');
      return false;
    }
    state = state.copyWith(
      email: trimmedEmail,
      loading: true,
      clearError: true,
      clearMessage: true,
    );
    try {
      // 1. Try Firebase Auth (sends verification email)
      final msg = await FirebaseAuthService.signUpWithEmailPassword(
        email: trimmedEmail,
        password: password,
      );
      state = state.copyWith(
        loading: false,
        mode: AuthMode.signIn,
        message: msg,
      );
      return false; // Return false so user verifies before navigating
    } on StateError catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (_) {
      // Fallback to direct backend registration
      try {
        final result = await _auth.registerWithPassword(
          trimmedEmail,
          password,
          captchaToken: captchaToken,
        );
        if (!result.ok) {
          state = state.copyWith(
            loading: false,
            error: result.data['error']?.toString() ?? 'Registration failed.',
          );
          return false;
        }
        return _handleAuthSuccess(result.data);
      } on ApiException catch (e) {
        state = state.copyWith(loading: false, error: e.message);
        return false;
      } catch (_) {
        state = state.copyWith(
          loading: false,
          error: 'Could not complete registration. Check your connection.',
        );
        return false;
      }
    }
  }

  Future<bool> loginWithPassword(
    String email,
    String password, {
    String? captchaToken,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      state = state.copyWith(error: 'Enter a valid email address.');
      return false;
    }
    if (password.isEmpty) {
      state = state.copyWith(error: 'Enter your password.');
      return false;
    }
    state = state.copyWith(
      email: trimmedEmail,
      loading: true,
      clearError: true,
      clearMessage: true,
    );
    try {
      // 1. Sign in with Firebase & verify email ownership
      final session = await FirebaseAuthService.signInWithEmailPassword(
        email: trimmedEmail,
        password: password,
      );
      return signInWithFirebaseToken(session.idToken);
    } on StateError catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (_) {
      // Fallback to direct backend password login
      try {
        final result = await _auth.loginWithPassword(
          trimmedEmail,
          password,
          captchaToken: captchaToken,
        );
        if (!result.ok) {
          state = state.copyWith(
            loading: false,
            error: result.data['error']?.toString() ?? 'Invalid email or password.',
          );
          return false;
        }
        return _handleAuthSuccess(result.data);
      } on ApiException catch (e) {
        state = state.copyWith(loading: false, error: e.message);
        return false;
      } catch (_) {
        state = state.copyWith(
          loading: false,
          error: 'Could not sign in. Check your connection.',
        );
        return false;
      }
    }
  }

  Future<bool> requestPasswordReset(
    String email, {
    String? captchaToken,
  }) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      state = state.copyWith(error: 'Enter a valid email address.');
      return false;
    }
    state = state.copyWith(
      email: trimmed,
      loading: true,
      clearError: true,
      clearMessage: true,
    );
    try {
      // Try Firebase password reset email first
      await FirebaseAuthService.sendPasswordResetEmail(trimmed);
      state = state.copyWith(
        loading: false,
        step: AuthStep.email,
        message: 'Password reset link sent to $trimmed. Check your inbox.',
      );
      return true;
    } catch (_) {
      // Fallback to direct backend OTP reset
      try {
        final data = await _auth.requestPasswordReset(
          trimmed,
          captchaToken: captchaToken,
        );
        if (data['error'] != null) {
          state = state.copyWith(loading: false, error: data['error'].toString());
          return false;
        }
        state = state.copyWith(
          loading: false,
          step: AuthStep.resetPassword,
          message: data['message']?.toString() ?? 'Reset code sent to $trimmed',
        );
        return true;
      } on ApiException catch (e) {
        state = state.copyWith(loading: false, error: e.message);
        return false;
      } catch (_) {
        state = state.copyWith(
          loading: false,
          error: 'Could not send reset code. Check your connection.',
        );
        return false;
      }
    }
  }

  Future<bool> confirmPasswordReset(String otp, String newPassword) async {
    final code = otp.trim();
    if (code.length < 4) {
      state = state.copyWith(error: 'Enter the reset code.');
      return false;
    }
    if (newPassword.length < 8) {
      state = state.copyWith(error: 'Password must be at least 8 characters.');
      return false;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await _auth.confirmPasswordReset(
        state.email,
        code,
        newPassword,
      );
      if (!result.ok) {
        state = state.copyWith(
          loading: false,
          error: result.data['error']?.toString() ?? 'Password reset failed.',
        );
        return false;
      }
      return _handleAuthSuccess(result.data);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Could not reset password. Check your connection.',
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(loading: true, clearError: true, clearMessage: true);
    try {
      final session = await FirebaseAuthService.signInWithGoogle();
      if (session == null) {
        state = state.copyWith(loading: false);
        return false;
      }
      if (session.email.isNotEmpty) {
        state = state.copyWith(email: session.email);
      }
      return signInWithFirebaseToken(session.idToken);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString().contains('Google')
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Google Sign-In failed. You can still use Email OTP or Password.',
      );
      return false;
    }
  }

  Future<bool> signInWithFirebaseToken(String idToken) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final intent = state.mode == AuthMode.signUp ? 'signup' : 'login';
      final result = await _auth.firebaseLogin(idToken, intent: intent);
      if (!result.ok) {
        state = state.copyWith(
          loading: false,
          error: result.data['error']?.toString() ?? 'Firebase login failed.',
        );
        return false;
      }
      return _handleAuthSuccess(result.data);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Could not complete Firebase login. Check your connection.',
      );
      return false;
    }
  }

  Future<void> resendOtp({String? captchaToken}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final intent = state.mode == AuthMode.signUp ? 'signup' : 'login';
      final data = await _auth.resendOtp(
        state.email.trim(),
        intent: intent,
        captchaToken: captchaToken,
      );
      state = state.copyWith(
        loading: false,
        message: data['message']?.toString() ?? 'OTP resent',
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Could not resend OTP. Please wait and try again.',
      );
    }
  }

  Future<void> logout() async {
    try {
      await _auth.logout();
    } catch (_) {}
    try {
      await FirebaseAuthService.signOut();
    } catch (_) {}
    state = const AuthState(bootstrapped: true);
  }

  void markOnboardingComplete({String? username}) {
    final u = state.user;
    state = state.copyWith(
      onboardingComplete: true,
      user: (username != null && username.trim().isNotEmpty && u != null)
          ? u.copyWith(username: username.trim())
          : u,
    );
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(ref);
  },
);

/// Navigation-only slice — router should listen to this, not full auth state.
final authNavProvider = Provider<AuthNavSnapshot>((ref) {
  return ref.watch(authControllerProvider.select((s) => s.navSnapshot));
});

/// Logged-in viewer's username for media watermarks (never UUID).
final viewerUsernameProvider = Provider<String?>((ref) {
  return ref.watch(
    authControllerProvider.select((s) => s.user?.displayUsername),
  );
});
