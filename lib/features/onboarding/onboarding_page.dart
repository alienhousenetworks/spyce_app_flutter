import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/spyce_colors.dart';
import '../../core/utils/language_labels.dart';
import '../../core/utils/onboarding.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/api_repositories.dart';
import '../../shared/widgets/language_picker.dart';
import '../../shared/widgets/spyce_widgets.dart';
import '../auth/auth_controller.dart';
import 'face_liveness_screen.dart';

/// First-time user creation — all core steps are mandatory (no skip).
///
/// 1 Username + age · 2 Gender / sexuality / preferred · 3 Languages ·
/// 4 Bio · 5 Live face verification
///
/// Face step uses backend `FACE_VERIFICATION`:
/// - false → mock-complete (dev/staging)
/// - true  → AWS Rekognition Face Liveness (start → detector → complete)
///
/// Returning users with core fields already set are redirected out immediately
/// (gender is immutable server-side once set).
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const _totalSteps = 5;
  static const _minBioLen = 20;

  int step = 1;
  bool loadingOpts = true;
  bool submitting = false;
  bool verifying = false;
  bool faceVerified = false;
  /// null until status is fetched; true = real AWS path
  bool? faceVerificationEnabled;
  bool mockMode = true;
  String? error;

  final usernameCtrl = TextEditingController();
  final dobCtrl = TextEditingController();
  final bioCtrl = TextEditingController();

  String? gender;
  String? sexuality;
  final preferredGenders = <String>{};
  final selectedLanguageIds = <String>{};

  /// When true, gender was already locked on the server — do not PATCH it.
  bool genderLocked = false;
  bool sexualityLocked = false;

  List<CatalogOption> genderOpts = [];
  List<CatalogOption> sexualityOpts = [];
  List<CatalogOption> languageOpts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final opts = ref.read(optionsRepositoryProvider);
    final profileRepo = ref.read(profileRepositoryProvider);
    try {
      final results = await Future.wait<Object?>([
        opts.genders(),
        opts.sexualities(),
        opts.languages(),
        () async {
          try {
            return await profileRepo.getMyProfile();
          } catch (_) {
            return null;
          }
        }(),
        () async {
          try {
            return await ref.read(verificationRepositoryProvider).getConfig();
          } catch (_) {
            return null;
          }
        }(),
      ]);
      if (!mounted) return;

      final profile = results[3] as UserProfile?;
      final faceCfg = results[4] as FaceVerificationConfig?;

      // Existing account already finished signup → enter app, never re-signup
      if (isProfileOnboarded(profile)) {
        ref.read(authControllerProvider.notifier).markOnboardingComplete(
              username: profile?.username,
            );
        if (!mounted) return;
        context.go('/app/discover');
        return;
      }

      setState(() {
        genderOpts = results[0] as List<CatalogOption>;
        sexualityOpts = results[1] as List<CatalogOption>;
        languageOpts = results[2] as List<CatalogOption>;
        LanguageLabels.setCatalog(languageOpts);

        if (faceCfg != null) {
          faceVerificationEnabled = faceCfg.faceVerification;
          mockMode = faceCfg.mockMode;
          if (faceCfg.verified) faceVerified = true;
        } else {
          // Safe default: mock until server config is known
          faceVerificationEnabled = false;
          mockMode = true;
        }

        // Prefill any partial profile (e.g. username set, gender locked mid-flow)
        if (profile != null) {
          final u = profile.username?.trim();
          if (u != null && u.isNotEmpty) usernameCtrl.text = u;
          final dob = profile.dateOfBirth?.trim();
          if (dob != null && dob.isNotEmpty) {
            // API may return ISO datetime — keep YYYY-MM-DD for the field
            dobCtrl.text = dob.length >= 10 ? dob.substring(0, 10) : dob;
          }
          final b = profile.bio?.trim();
          if (b != null && b.isNotEmpty) bioCtrl.text = b;

          if (profile.genderId != null && profile.genderId!.isNotEmpty) {
            gender = profile.genderId;
            genderLocked = true;
          }
          if (profile.sexualityId != null && profile.sexualityId!.isNotEmpty) {
            sexuality = profile.sexualityId;
            sexualityLocked = true;
          }
          preferredGenders
            ..clear()
            ..addAll(profile.preferredGenderIds);
          selectedLanguageIds
            ..clear()
            ..addAll(profile.languageIds);
        }

        loadingOpts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingOpts = false);
    }
  }

  @override
  void dispose() {
    usernameCtrl.dispose();
    dobCtrl.dispose();
    bioCtrl.dispose();
    super.dispose();
  }

  bool _validUsername(String u) {
    return RegExp(r'^[a-zA-Z0-9._]{3,30}$').hasMatch(u);
  }

  int? _ageFromDob(String raw) {
    final d = DateTime.tryParse(raw.trim());
    if (d == null) return null;
    final now = DateTime.now();
    var age = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) {
      age--;
    }
    return age;
  }

  Future<void> _next() async {
    setState(() => error = null);

    if (step == 1) {
      final username = usernameCtrl.text.trim().toLowerCase();
      final dob = dobCtrl.text.trim();
      if (!_validUsername(username)) {
        setState(() {
          error =
              'Username is required (3–30 letters, numbers, . or _). Cannot skip.';
        });
        return;
      }
      if (dob.isEmpty) {
        setState(() => error = 'Date of birth is required. Cannot skip.');
        return;
      }
      final age = _ageFromDob(dob);
      if (age == null) {
        setState(() => error = 'Enter a valid date of birth.');
        return;
      }
      if (age < 18) {
        setState(() => error = 'You must be at least 18 years old to join SPYCE.');
        return;
      }
      try {
        final ok = await ref
            .read(profileRepositoryProvider)
            .isUsernameAvailable(username);
        if (!ok) {
          setState(() => error = 'This username is already taken.');
          return;
        }
      } on ApiException catch (e) {
        setState(() => error = e.message);
        return;
      }
    } else if (step == 2) {
      if (genderOpts.isEmpty || sexualityOpts.isEmpty) {
        setState(() {
          error =
              'Identity options failed to load. Check your connection and try again — this step cannot be skipped.';
        });
        return;
      }
      if (gender == null) {
        setState(() => error = 'Gender is required. Cannot skip.');
        return;
      }
      if (sexuality == null) {
        setState(() => error = 'Sexuality is required. Cannot skip.');
        return;
      }
      if (preferredGenders.isEmpty) {
        setState(() {
          error = 'Select at least one preferred gender. Cannot skip.';
        });
        return;
      }
    } else if (step == 3) {
      if (languageOpts.isEmpty) {
        setState(() {
          error =
              'Language options failed to load. Reconnect and try again — cannot skip.';
        });
        return;
      }
      if (selectedLanguageIds.isEmpty) {
        setState(() => error = 'Select at least one language you speak.');
        return;
      }
    } else if (step == 4) {
      final bio = bioCtrl.text.trim();
      if (bio.isEmpty) {
        setState(() => error = 'Bio is required. Cannot skip.');
        return;
      }
      if (bio.length < _minBioLen) {
        setState(() {
          error =
              'Bio must be at least $_minBioLen characters (${bio.length}/$_minBioLen).';
        });
        return;
      }
    } else if (step == 5) {
      if (!faceVerified) {
        setState(() {
          error = 'Complete face verification to continue. Cannot skip.';
        });
        return;
      }
      await _submit();
      return;
    }

    setState(() => step++);
  }

  bool get _useRealFaceLiveness =>
      faceVerificationEnabled == true && !mockMode;

  Future<void> _runFaceVerification() async {
    if (verifying || faceVerified) return;
    if (_useRealFaceLiveness) {
      await _runRealFaceLiveness();
    } else {
      await _runMockFaceVerification();
    }
  }

  Future<void> _runRealFaceLiveness() async {
    if (verifying || faceVerified) return;
    setState(() {
      verifying = true;
      error = null;
    });
    try {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const FaceLivenessScreen(),
        ),
      );
      if (!mounted) return;
      if (ok == true) {
        setState(() {
          faceVerified = true;
          verifying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face verification complete'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      } else {
        setState(() {
          verifying = false;
          error = error ??
              'Face verification was not completed. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        verifying = false;
        error = 'Face verification failed: $e';
      });
    }
  }

  Future<void> _runMockFaceVerification() async {
    if (verifying || faceVerified) return;
    setState(() {
      verifying = true;
      error = null;
    });
    try {
      final res =
          await ref.read(verificationRepositoryProvider).mockComplete();
      final ok = res['status']?.toString().toUpperCase() == 'SUCCESS' ||
          res['is_identity_verified'] == true ||
          res['verified'] == true;
      if (!ok && res['error'] != null) {
        setState(() {
          verifying = false;
          error = res['error']?.toString() ??
              'Verification failed. Try again.';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        faceVerified = true;
        verifying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face verification complete (dev mock)'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        verifying = false;
        error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        verifying = false;
        error = 'Verification failed. Check your connection and try again.';
      });
    }
  }

  Future<void> _submit() async {
    if (!faceVerified) {
      setState(() {
        error = 'Face verification is required before entering SPYCE.';
      });
      return;
    }
    setState(() => submitting = true);
    final uname = usernameCtrl.text.trim().toLowerCase();
    final langNames = LanguageLabels.namesForSave(selectedLanguageIds);

    // Never PATCH immutable identity fields once the server has them —
    // backend rejects with "Gender cannot be changed once set."
    final payload = <String, dynamic>{
      'username': uname,
      'date_of_birth': dobCtrl.text.trim(),
      'preferred_genders': preferredGenders.toList(),
      'languages': langNames,
      'bio': bioCtrl.text.trim(),
    };
    if (!genderLocked && gender != null) {
      payload['gender'] = gender;
    }
    if (!sexualityLocked && sexuality != null) {
      payload['sexuality'] = sexuality;
    }

    try {
      await ref.read(profileRepositoryProvider).updateMyProfile(payload);
      ref
          .read(authControllerProvider.notifier)
          .markOnboardingComplete(username: uname);
      if (!mounted) return;
      context.go('/app/discover');
    } on ApiException catch (e) {
      final msg = e.message.toLowerCase();
      final genderImmutable = msg.contains('gender cannot be changed') ||
          msg.contains('gender cannot be removed');
      final sexualityImmutable = msg.contains('sexuality cannot be changed') ||
          msg.contains('sexuality cannot be removed');

      // Retry without immutable fields (returning account mid-signup path).
      if (genderImmutable || sexualityImmutable) {
        try {
          final retry = Map<String, dynamic>.from(payload);
          if (genderImmutable) {
            retry.remove('gender');
            genderLocked = true;
          }
          if (sexualityImmutable) {
            retry.remove('sexuality');
            sexualityLocked = true;
          }
          await ref.read(profileRepositoryProvider).updateMyProfile(retry);
          ref
              .read(authControllerProvider.notifier)
              .markOnboardingComplete(username: uname);
          if (!mounted) return;
          context.go('/app/discover');
          return;
        } catch (_) {
          // Fall through: if profile already complete, just enter app
          try {
            final profile =
                await ref.read(profileRepositoryProvider).getMyProfile();
            if (isProfileOnboarded(profile)) {
              ref.read(authControllerProvider.notifier).markOnboardingComplete(
                    username: profile.username ?? uname,
                  );
              if (!mounted) return;
              context.go('/app/discover');
              return;
            }
          } catch (_) {}
        }
      }
      setState(() {
        error = e.message;
        submitting = false;
      });
    } catch (_) {
      setState(() {
        error = 'Could not save profile. Check your connection and try again.';
        submitting = false;
      });
    }
  }

  String get _title => switch (step) {
        1 => 'Who are you?',
        2 => 'Identity',
        3 => 'Languages you speak',
        4 => 'Your bio',
        _ => 'Face verification',
      };

  String get _subtitle => switch (step) {
        1 => 'Username and age are required — not skippable.',
        2 => 'Gender, sexuality, and who you want to meet — all required.',
        3 => 'Pick popular languages, or search if yours isn’t listed.',
        4 => 'Write a short bio (min $_minBioLen characters). Required.',
        _ => 'Live face check builds trust. Required to finish signup.',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background pattern + mesh
          SvgPicture.asset(
            'assets/backgrounds/HexSplashSpyce.svg',
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.15),
              BlendMode.dstATop,
            ),
            errorBuilder: (_, error, stackTrace) => const SizedBox.shrink(),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1F0A14),
                  Color(0xFF0D0D0D),
                  SpyceColors.dark950,
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          Positioned(
            top: -60,
            left: -40,
            child: _Orb(
              size: 260,
              color: SpyceColors.pink.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            bottom: 40,
            right: -50,
            child: _Orb(
              size: 220,
              color: const Color(0xFFA855F7).withValues(alpha: 0.12),
            ),
          ),
          SafeArea(
            child: loadingOpts
                ? const Center(
                    child: CircularProgressIndicator(color: SpyceColors.pink),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SpyceLogo(size: 22),
                        const SizedBox(height: 16),
                        _SegmentProgress(step: step, total: _totalSteps),
                        const SizedBox(height: 14),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF120E16).withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: SpyceColors.pink.withValues(alpha: 0.18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 32,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    22, 20, 22, 0,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Step $step of $_totalSteps',
                                          style: GoogleFonts.dmSans(
                                            color: SpyceColors.dark200,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: SpyceColors.pink
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: SpyceColors.pink
                                                .withValues(alpha: 0.28),
                                          ),
                                        ),
                                        child: Text(
                                          'Required',
                                          style: GoogleFonts.dmSans(
                                            color: SpyceColors.pinkSoft,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    22, 14, 22, 6,
                                  ),
                                  child: Text(
                                    _title,
                                    style: GoogleFonts.syne(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    22, 0, 22, 12,
                                  ),
                                  child: Text(
                                    _subtitle,
                                    style: GoogleFonts.dmSans(
                                      color: SpyceColors.dark100,
                                      fontSize: 13,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      22, 4, 22, 12,
                                    ),
                                    child: switch (step) {
                                      1 => _IdentityBasics(
                                          usernameCtrl: usernameCtrl,
                                          dobCtrl: dobCtrl,
                                        ),
                                      2 => _IdentityChips(
                                          genderOpts: genderOpts,
                                          sexualityOpts: sexualityOpts,
                                          gender: gender,
                                          sexuality: sexuality,
                                          preferredGenders: preferredGenders,
                                          onGender: (id) =>
                                              setState(() => gender = id),
                                          onSexuality: (id) =>
                                              setState(() => sexuality = id),
                                          onPreferredToggle: (id) =>
                                              setState(() {
                                            if (preferredGenders
                                                .contains(id)) {
                                              preferredGenders.remove(id);
                                            } else {
                                              preferredGenders.add(id);
                                            }
                                          }),
                                        ),
                                      3 => LanguagePicker(
                                          options: languageOpts,
                                          selectedIds: selectedLanguageIds,
                                          onChanged: (ids) => setState(() {
                                            selectedLanguageIds
                                              ..clear()
                                              ..addAll(ids);
                                          }),
                                        ),
                                      4 => _BioStep(
                                          bioCtrl: bioCtrl,
                                          minLen: _minBioLen,
                                          onChanged: () => setState(() {}),
                                        ),
                                      _ => _FaceVerifyStep(
                                          verifying: verifying,
                                          verified: faceVerified,
                                          realMode: _useRealFaceLiveness,
                                          onVerify: _runFaceVerification,
                                        ),
                                    },
                                  ),
                                ),
                                if (error != null)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      22, 0, 22, 8,
                                    ),
                                    child: Text(
                                      error!,
                                      style: const TextStyle(
                                        color: Color(0xFFFF6B81),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16, 4, 16, 16,
                                  ),
                                  child: Row(
                                    children: [
                                      if (step > 1)
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed:
                                                (submitting || verifying)
                                                    ? null
                                                    : () => setState(() {
                                                          error = null;
                                                          step--;
                                                        }),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  SpyceColors.dark100,
                                              side: const BorderSide(
                                                color: SpyceColors.dark500,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 14,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                            child: const Text('Back'),
                                          ),
                                        ),
                                      if (step > 1) const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: SpycePrimaryButton(
                                          label: step == _totalSteps
                                              ? (faceVerified
                                                  ? 'Enter SPYCE'
                                                  : 'Verify face to continue')
                                              : 'Continue',
                                          loading: submitting,
                                          onPressed: (submitting || verifying)
                                              ? null
                                              : () {
                                                  if (step == _totalSteps &&
                                                      !faceVerified) {
                                                    _runFaceVerification();
                                                  } else {
                                                    _next();
                                                  }
                                                },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _SegmentProgress extends StatelessWidget {
  const _SegmentProgress({required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < step;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(
                      colors: [SpyceColors.pink, Color(0xFFC026D3)],
                    )
                  : null,
              color: active ? null : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}

class _IdentityBasics extends StatelessWidget {
  const _IdentityBasics({
    required this.usernameCtrl,
    required this.dobCtrl,
  });

  final TextEditingController usernameCtrl;
  final TextEditingController dobCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: usernameCtrl,
          style: const TextStyle(color: SpyceColors.white),
          decoration: const InputDecoration(
            labelText: 'Username *',
            hintText: 'yourname',
            prefixText: '@ ',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: dobCtrl,
          style: const TextStyle(color: SpyceColors.white),
          decoration: const InputDecoration(
            labelText: 'Date of birth (age) *',
            hintText: 'YYYY-MM-DD',
            prefixIcon: Icon(Icons.cake_outlined, color: SpyceColors.dark200),
          ),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime(now.year - 21, now.month, now.day),
              firstDate: DateTime(now.year - 80),
              lastDate: DateTime(now.year - 18),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: SpyceColors.pink,
                      surface: SpyceColors.dark800,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              dobCtrl.text =
                  '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
            }
          },
          readOnly: true,
        ),
        const SizedBox(height: 10),
        const Text(
          '* Required — must be 18+',
          style: TextStyle(color: SpyceColors.dark200, fontSize: 12),
        ),
      ],
    );
  }
}

class _IdentityChips extends StatelessWidget {
  const _IdentityChips({
    required this.genderOpts,
    required this.sexualityOpts,
    required this.gender,
    required this.sexuality,
    required this.preferredGenders,
    required this.onGender,
    required this.onSexuality,
    required this.onPreferredToggle,
  });

  final List<CatalogOption> genderOpts;
  final List<CatalogOption> sexualityOpts;
  final String? gender;
  final String? sexuality;
  final Set<String> preferredGenders;
  final ValueChanged<String> onGender;
  final ValueChanged<String> onSexuality;
  final ValueChanged<String> onPreferredToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Gender *'),
        _chipWrap(
          options: genderOpts,
          selected: {if (gender != null) gender!},
          multi: false,
          onToggle: onGender,
        ),
        const SizedBox(height: 18),
        _sectionTitle('Sexuality *'),
        _chipWrap(
          options: sexualityOpts,
          selected: {if (sexuality != null) sexuality!},
          multi: false,
          onToggle: onSexuality,
        ),
        const SizedBox(height: 18),
        _sectionTitle('Preferred gender(s) *'),
        Text(
          'Who do you want to see on the feed?',
          style: TextStyle(
            color: SpyceColors.white.withValues(alpha: 0.55),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        _chipWrap(
          options: genderOpts,
          selected: preferredGenders,
          multi: true,
          onToggle: onPreferredToggle,
        ),
        const SizedBox(height: 12),
        const Text(
          '* All fields required — cannot skip',
          style: TextStyle(color: SpyceColors.dark200, fontSize: 12),
        ),
      ],
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          t,
          style: GoogleFonts.syne(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      );

  Widget _chipWrap({
    required List<CatalogOption> options,
    required Set<String> selected,
    required bool multi,
    required ValueChanged<String> onToggle,
  }) {
    if (options.isEmpty) {
      return const Text(
        'Options unavailable — reconnect and retry. This step cannot be skipped.',
        style: TextStyle(color: Color(0xFFFF6B81), fontSize: 13),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final on = selected.contains(o.id);
        return FilterChip(
          label: Text(o.emoji != null ? '${o.emoji} ${o.name}' : o.name),
          selected: on,
          onSelected: (_) {
            onToggle(o.id);
          },
          selectedColor: SpyceColors.pinkDim,
          checkmarkColor: SpyceColors.pink,
          labelStyle: TextStyle(
            color: on ? SpyceColors.pinkSoft : SpyceColors.white,
          ),
          side: BorderSide(
            color: on
                ? SpyceColors.pink.withValues(alpha: 0.5)
                : SpyceColors.dark400,
          ),
        );
      }).toList(),
    );
  }
}

class _BioStep extends StatelessWidget {
  const _BioStep({
    required this.bioCtrl,
    required this.minLen,
    required this.onChanged,
  });

  final TextEditingController bioCtrl;
  final int minLen;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final len = bioCtrl.text.trim().length;
    final ok = len >= minLen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: bioCtrl,
          onChanged: (_) => onChanged(),
          maxLines: 6,
          maxLength: 300,
          style: const TextStyle(color: SpyceColors.white, height: 1.4),
          decoration: InputDecoration(
            labelText: 'Bio *',
            hintText: 'Tell people who you are and what you\'re looking for…',
            alignLabelWithHint: true,
            counterText: '$len / 300 · min $minLen',
            counterStyle: TextStyle(
              color: ok ? const Color(0xFF6EE7B7) : SpyceColors.dark200,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '* Required — at least $minLen characters. Cannot skip.',
          style: const TextStyle(color: SpyceColors.dark200, fontSize: 12),
        ),
      ],
    );
  }
}

class _FaceVerifyStep extends StatelessWidget {
  const _FaceVerifyStep({
    required this.verifying,
    required this.verified,
    required this.realMode,
    required this.onVerify,
  });

  final bool verifying;
  final bool verified;
  final bool realMode;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final bodyText = verified
        ? 'Your identity check passed. Tap Enter SPYCE to finish.'
        : realMode
            ? 'Hold your face in frame. We run a short live camera check '
                '(Amazon Rekognition) so every profile is a real person.'
            : 'Hold your face in frame. We use a short liveness check so '
                'profiles stay real.\n\n'
                '(Dev mock mode — set FACE_VERIFICATION=True on the server '
                'for real AWS liveness.)';

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: verified
                  ? const Color(0xFF34D399).withValues(alpha: 0.5)
                  : SpyceColors.pink.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: verified
                      ? const Color(0xFF065F46)
                      : SpyceColors.pink.withValues(alpha: 0.15),
                  border: Border.all(
                    color: verified
                        ? const Color(0xFF34D399)
                        : SpyceColors.pink.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Icon(
                  verified
                      ? Icons.verified_user
                      : Icons.face_retouching_natural,
                  size: 40,
                  color: verified
                      ? const Color(0xFF6EE7B7)
                      : SpyceColors.pinkSoft,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                verified ? 'Verified' : 'Live face check',
                style: GoogleFonts.syne(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bodyText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SpyceColors.white.withValues(alpha: 0.75),
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              if (!verified)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: verifying ? null : onVerify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SpyceColors.pink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: verifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_front_outlined),
                    label: Text(
                      verifying
                          ? (realMode ? 'Opening camera…' : 'Checking face…')
                          : 'Start face verification',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xFF34D399), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      realMode ? 'Face verified' : 'Face verified (mock)',
                      style: const TextStyle(
                        color: Color(0xFF6EE7B7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Face verification is required — there is no skip.',
          style: TextStyle(color: SpyceColors.dark200, fontSize: 12),
        ),
      ],
    );
  }
}
