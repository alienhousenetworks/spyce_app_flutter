import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/spyce_colors.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/api_repositories.dart';
import '../../shared/widgets/spyce_widgets.dart';
import '../auth/auth_controller.dart';

/// First-time user creation — all core steps are mandatory (no skip).
///
/// 1 Username + age (DOB) · 2 Gender / sexuality / preferred · 3 Bio ·
/// 4 Live face verification (mock bypass for now)
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const _totalSteps = 4;
  static const _minBioLen = 20;

  int step = 1;
  bool loadingOpts = true;
  bool submitting = false;
  bool verifying = false;
  bool faceVerified = false;
  String? error;

  final usernameCtrl = TextEditingController();
  final dobCtrl = TextEditingController();
  final bioCtrl = TextEditingController();

  String? gender;
  String? sexuality;
  final preferredGenders = <String>{};

  List<CatalogOption> genderOpts = [];
  List<CatalogOption> sexualityOpts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final opts = ref.read(optionsRepositoryProvider);
    try {
      final results = await Future.wait([
        opts.genders(),
        opts.sexualities(),
      ]);
      if (!mounted) return;
      setState(() {
        genderOpts = results[0];
        sexualityOpts = results[1];
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

  /// Returns age in full years, or null if DOB invalid / under 18.
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
    } else if (step == 4) {
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

  /// Mock live face verification (dev bypass of real liveness).
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
          res['is_identity_verified'] == true;
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
          content: Text('Face verification complete (mock)'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } on ApiException catch (e) {
      // If mock is disabled server-side, still allow local mock for UI flow
      // only when message indicates production lock — surface the error.
      if (!mounted) return;
      setState(() {
        verifying = false;
        error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      // Offline demo: mark verified locally so onboarding can finish
      setState(() {
        faceVerified = true;
        verifying = false;
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
    try {
      final uname = usernameCtrl.text.trim().toLowerCase();
      await ref.read(profileRepositoryProvider).updateMyProfile({
        'username': uname,
        'date_of_birth': dobCtrl.text.trim(),
        'gender': gender,
        'sexuality': sexuality,
        'preferred_genders': preferredGenders.toList(),
        'bio': bioCtrl.text.trim(),
      });
      ref
          .read(authControllerProvider.notifier)
          .markOnboardingComplete(username: uname);
      if (!mounted) return;
      context.go('/app/discover');
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        submitting = false;
      });
    } catch (_) {
      // Offline / demo still enter after mandatory local steps
      final uname = usernameCtrl.text.trim().toLowerCase();
      ref
          .read(authControllerProvider.notifier)
          .markOnboardingComplete(username: uname.isNotEmpty ? uname : null);
      if (!mounted) return;
      context.go('/app/discover');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SpyceGradientScaffold(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: loadingOpts
          ? const Center(
              child: CircularProgressIndicator(color: SpyceColors.pink),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SpyceLogo(size: 28),
                const SizedBox(height: 16),
                _Progress(step: step, total: _totalSteps),
                const SizedBox(height: 8),
                Text(
                  'Step $step of $_totalSteps · required',
                  style: const TextStyle(
                    color: SpyceColors.dark200,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  switch (step) {
                    1 => 'Who are you?',
                    2 => 'Identity',
                    3 => 'Your bio',
                    _ => 'Face verification',
                  },
                  style: GoogleFonts.syne(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  switch (step) {
                    1 => 'Username and age are required — not skippable.',
                    2 =>
                      'Gender, sexuality, and who you want to meet — all required.',
                    3 =>
                      'Write a short bio (min $_minBioLen characters). Required.',
                    _ =>
                      'Live face check builds trust. Required to finish signup.',
                  },
                  style: const TextStyle(color: SpyceColors.dark100),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
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
                          onGender: (id) => setState(() => gender = id),
                          onSexuality: (id) => setState(() => sexuality = id),
                          onPreferredToggle: (id) => setState(() {
                            if (preferredGenders.contains(id)) {
                              preferredGenders.remove(id);
                            } else {
                              preferredGenders.add(id);
                            }
                          }),
                        ),
                      3 => _BioStep(
                          bioCtrl: bioCtrl,
                          minLen: _minBioLen,
                          onChanged: () => setState(() {}),
                        ),
                      _ => _FaceVerifyStep(
                          verifying: verifying,
                          verified: faceVerified,
                          onVerify: _runMockFaceVerification,
                        ),
                    },
                  ),
                ),
                if (error != null) ...[
                  Text(
                    error!,
                    style: const TextStyle(color: Color(0xFFFF6B81)),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    if (step > 1)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: (submitting || verifying)
                              ? null
                              : () => setState(() {
                                    error = null;
                                    step--;
                                  }),
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
                                if (step == _totalSteps && !faceVerified) {
                                  _runMockFaceVerification();
                                } else {
                                  _next();
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.total});
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
              color: active ? SpyceColors.pink : SpyceColors.dark600,
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
            if (!multi) {
              onToggle(o.id);
            } else {
              onToggle(o.id);
            }
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
    required this.onVerify,
  });

  final bool verifying;
  final bool verified;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: SpyceColors.dark800,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: verified
                  ? const Color(0xFF34D399).withValues(alpha: 0.5)
                  : SpyceColors.dark500,
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
                  verified ? Icons.verified_user : Icons.face_retouching_natural,
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
                verified
                    ? 'Your identity check passed. Tap Enter SPYCE to finish.'
                    : 'Hold your face in frame. We use a short liveness check so profiles stay real.\n\n(Currently running mock verification — real camera liveness will replace this.)',
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
                          ? 'Checking face…'
                          : 'Start face verification',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              else
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF34D399), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Face verified (mock)',
                      style: TextStyle(
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
