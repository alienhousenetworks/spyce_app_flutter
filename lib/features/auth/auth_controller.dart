import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/onboarding.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/api_repositories.dart';

/// High-level auth UI steps.
enum AuthStep {
  /// Choose Sign in or Sign up.
  welcome,
  /// Enter email.
  email,
  /// Enter OTP.
  otp,
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

  /// Commit email only when sending OTP / verifying — not on every keystroke.
  void setEmail(String email) {
    state = state.copyWith(email: email.trim(), clearError: true);
  }

  /// `/users/me/` has no username — merge from `/profile/me/` for watermarks.
  Future<AuthUser> _withProfileIdentity(AuthUser user) async {
    try {
      final profile = await _profile.getMyProfile();
      final uname = profile.username?.trim();
      final fname =
          (profile.firstName ?? profile.name)?.trim();
      if ((uname == null || uname.isEmpty) &&
          (fname == null || fname.isEmpty) &&
          (user.username == null || user.username!.isEmpty) &&
          (user.firstName == null || user.firstName!.isEmpty)) {
        return user;
      }
      return user.copyWith(
        username: (uname != null && uname.isNotEmpty) ? uname : user.username,
        firstName:
            (fname != null && fname.isNotEmpty) ? fname : user.firstName,
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
      state = state.copyWith(
        user: current.copyWith(username: username.trim()),
      );
      return;
    }
    final enriched = await _withProfileIdentity(current);
    state = state.copyWith(user: enriched);
  }

  /// Resolve whether the user already finished first-time signup.
  /// Prefer session flag + core profile fields; never use only is_discoverable
  /// (false when paused/hidden → wrongly re-opens signup / gender immutable).
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

    // Explicit false from API only when we have no profile evidence
    if (verifyFlag == false || sessionFlag == false) {
      // Still trust core fields if profile loaded mid-check
      return isProfileOnboarded(p);
    }
    return false;
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
                firstName: ((profile.firstName ?? profile.name)?.trim().isNotEmpty ==
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
        state = state.copyWith(
          loading: false,
          error: data['error'].toString(),
        );
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

      // Backend: is_new_user (and alias is_new). Never force from UI mode —
      // choosing "Sign up" with an existing email is blocked server-side;
      // if login succeeds, treat as returning user regardless of button used.
      final isNewUser = result.data['is_new_user'] == true ||
          result.data['is_new'] == true;
      final verifyOnboarding = result.data['onboarding_complete'] is bool
          ? result.data['onboarding_complete'] as bool
          : null;

      var user = await _auth.getMe() ??
          AuthUser(
            id: result.data['user_id']?.toString() ?? 'user',
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
      );
      return true;
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
    state = const AuthState(bootstrapped: true);
  }

  void markOnboardingComplete({String? username}) {
    final u = state.user;
    state = state.copyWith(
      onboardingComplete: true,
      user: (username != null &&
              username.trim().isNotEmpty &&
              u != null)
          ? u.copyWith(username: username.trim())
          : u,
    );
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});

/// Navigation-only slice — router should listen to this, not full auth state.
final authNavProvider = Provider<AuthNavSnapshot>((ref) {
  return ref.watch(
    authControllerProvider.select((s) => s.navSnapshot),
  );
});

/// Logged-in viewer's username for media watermarks (never UUID).
final viewerUsernameProvider = Provider<String?>((ref) {
  return ref.watch(
    authControllerProvider.select((s) => s.user?.displayUsername),
  );
});
