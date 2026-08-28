import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/onboarding_theme.dart';
import '../../core/utils/language_labels.dart';
import '../../core/utils/onboarding.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/api_repositories.dart';
import '../../shared/widgets/onboarding_widgets.dart';
import '../../shared/widgets/photo_guidelines_sheet.dart';
import '../auth/auth_controller.dart';
import 'face_liveness_screen.dart';
import 'widgets/bio_photo_step.dart';
import 'widgets/complete_step.dart';
import 'widgets/face_verify_step.dart';
import 'widgets/identity_step.dart';
import 'widgets/intent_match_step.dart';

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
  bool isUploadingPhoto = false;
  bool faceVerified = false;

  bool? faceVerificationEnabled;
  bool mockMode = true;
  String? error;

  final usernameCtrl = TextEditingController();
  final dobCtrl = TextEditingController();
  final bioCtrl = TextEditingController();

  String? gender;
  String? sexuality;
  String? selectedIntent;
  final preferredGenders = <String>{};
  final selectedLanguageIds = <String>{};
  final List<ProfileImage> uploadedPhotos = [];

  bool genderLocked = false;
  bool sexualityLocked = false;

  List<CatalogOption> genderOpts = [];
  List<CatalogOption> sexualityOpts = [];
  List<CatalogOption> languageOpts = [];
  List<CatalogOption> intentOpts = [];

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
        opts.intents(),
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

      final profile = results[4] as UserProfile?;
      final faceCfg = results[5] as FaceVerificationConfig?;

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
        intentOpts = results[3] as List<CatalogOption>;
        LanguageLabels.setCatalog(languageOpts);

        if (faceCfg != null) {
          faceVerificationEnabled = faceCfg.faceVerification;
          mockMode = faceCfg.mockMode;
          if (faceCfg.verified) faceVerified = true;
        } else {
          faceVerificationEnabled = false;
          mockMode = true;
        }

        if (profile != null) {
          final u = profile.username?.trim();
          if (u != null && u.isNotEmpty) usernameCtrl.text = u;

          final dob = profile.dateOfBirth?.trim();
          if (dob != null && dob.isNotEmpty) {
            dobCtrl.text = dob.length >= 10 ? dob.substring(0, 10) : dob;
          }

          final b = profile.bio?.trim();
          if (b != null && b.isNotEmpty) bioCtrl.text = b;

          if (profile.genderId != null && profile.genderId!.isNotEmpty) {
            final valid = genderOpts.where((o) => o.id == profile.genderId || o.name.toLowerCase() == profile.genderLabel?.toLowerCase());
            if (valid.isNotEmpty) {
              gender = valid.first.id;
            } else {
              gender = profile.genderId;
            }
            genderLocked = true;
          }
          if (profile.sexualityId != null && profile.sexualityId!.isNotEmpty) {
            final valid = sexualityOpts.where((o) => o.id == profile.sexualityId || o.name.toLowerCase() == profile.sexualityLabel?.toLowerCase());
            if (valid.isNotEmpty) {
              sexuality = valid.first.id;
            } else {
              sexuality = profile.sexualityId;
            }
            sexualityLocked = true;
          }
          if (profile.intentId != null && profile.intentId!.isNotEmpty) {
            if (intentOpts.any((o) => o.id == profile.intentId)) {
              selectedIntent = profile.intentId;
            }
          }

          final validPreferred = profile.preferredGenderIds
              .where((id) => genderOpts.isEmpty || genderOpts.any((o) => o.id == id));
          preferredGenders
            ..clear()
            ..addAll(validPreferred);

          selectedLanguageIds
            ..clear()
            ..addAll(profile.languageIds);

          if (profile.images.isNotEmpty) {
            uploadedPhotos
              ..clear()
              ..addAll(profile.images);
          }
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

  Future<void> _ensureIdentitySaved() async {
    if (gender == null || sexuality == null) return;
    final langNames = LanguageLabels.namesForSave(selectedLanguageIds);
    final payload = <String, dynamic>{
      'username': usernameCtrl.text.trim().toLowerCase(),
      'date_of_birth': dobCtrl.text.trim(),
      'languages': langNames,
    };
    if (!genderLocked && gender != null &&
        (genderOpts.isEmpty || genderOpts.any((o) => o.id == gender))) {
      payload['gender'] = gender;
    }
    if (!sexualityLocked && sexuality != null &&
        (sexualityOpts.isEmpty || sexualityOpts.any((o) => o.id == sexuality))) {
      payload['sexuality'] = sexuality;
    }
    try {
      await ref.read(profileRepositoryProvider).updateMyProfile(payload);
      genderLocked = true;
      sexualityLocked = true;
    } on ApiException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('gender cannot be changed') || msg.contains('gender cannot be removed')) {
        genderLocked = true;
      }
      if (msg.contains('sexuality cannot be changed') || msg.contains('sexuality cannot be removed')) {
        sexualityLocked = true;
      }
    } catch (_) {}
  }

  Future<void> _addPhoto() async {
    final agreed = await PhotoGuidelinesSheet.ensureAccepted(context);
    if (!agreed || !mounted) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => isUploadingPhoto = true);
    try {
      await _ensureIdentitySaved();
      final res = await ref.read(profileRepositoryProvider).uploadImage(file.path);
      final imgUrl = res['image_url']?.toString() ?? res['url']?.toString() ?? file.path;
      final imgId = res['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      setState(() {
        uploadedPhotos.add(ProfileImage(id: imgId, imageUrl: imgUrl));
        isUploadingPhoto = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload photo: $e')),
      );
    }
  }

  Future<void> _removePhoto(String imageId) async {
    try {
      await ref.read(profileRepositoryProvider).deleteImage(imageId);
    } catch (_) {}
    setState(() {
      uploadedPhotos.removeWhere((p) => p.id == imageId);
    });
  }

  Future<void> _next() async {
    setState(() => error = null);

    if (step == 1) {
      final username = usernameCtrl.text.trim().toLowerCase();
      final dob = dobCtrl.text.trim();
      if (!_validUsername(username)) {
        setState(() {
          error = 'Username is required (3–30 letters, numbers, . or _).';
        });
        return;
      }
      if (dob.isEmpty) {
        setState(() => error = 'Date of birth is required.');
        return;
      }
      final age = _ageFromDob(dob);
      if (age == null) {
        setState(() => error = 'Enter a valid date of birth (YYYY-MM-DD).');
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

      if (gender == null) {
        setState(() => error = 'Gender selection is required.');
        return;
      }
      if (sexuality == null) {
        setState(() => error = 'Sexuality selection is required.');
        return;
      }
      if (selectedLanguageIds.isEmpty) {
        setState(() => error = 'Select at least one language you speak.');
        return;
      }

      setState(() => submitting = true);
      try {
        final langNames = LanguageLabels.namesForSave(selectedLanguageIds);
        final payload = <String, dynamic>{
          'username': username,
          'date_of_birth': dob,
          'languages': langNames,
        };
        if (!genderLocked && gender != null &&
            (genderOpts.isEmpty || genderOpts.any((o) => o.id == gender))) {
          payload['gender'] = gender;
        }
        if (!sexualityLocked && sexuality != null &&
            (sexualityOpts.isEmpty || sexualityOpts.any((o) => o.id == sexuality))) {
          payload['sexuality'] = sexuality;
        }
        await ref.read(profileRepositoryProvider).updateMyProfile(payload);
        genderLocked = true;
        sexualityLocked = true;
      } on ApiException catch (e) {
        final msg = e.message.toLowerCase();
        final genderImmutable = msg.contains('gender cannot be changed') ||
            msg.contains('gender cannot be removed');
        final sexualityImmutable = msg.contains('sexuality cannot be changed') ||
            msg.contains('sexuality cannot be removed');

        if (genderImmutable || sexualityImmutable) {
          try {
            final retry = <String, dynamic>{
              'username': username,
              'date_of_birth': dob,
              'languages': LanguageLabels.namesForSave(selectedLanguageIds),
            };
            if (genderImmutable) genderLocked = true;
            if (sexualityImmutable) sexualityLocked = true;
            if (!genderLocked && gender != null) retry['gender'] = gender;
            if (!sexualityLocked && sexuality != null) retry['sexuality'] = sexuality;
            await ref.read(profileRepositoryProvider).updateMyProfile(retry);
          } catch (_) {}
        } else {
          setState(() {
            error = e.message;
            submitting = false;
          });
          return;
        }
      } catch (e) {
        setState(() {
          error = 'Could not save profile. Check your connection and try again.';
          submitting = false;
        });
        return;
      } finally {
        if (mounted) setState(() => submitting = false);
      }
    } else if (step == 2) {
      if (selectedIntent == null || selectedIntent!.isEmpty) {
        setState(() => error = 'Choose your dating intent to continue.');
        return;
      }
      if (preferredGenders.isEmpty) {
        setState(() => error = 'Select at least one match preference gender.');
        return;
      }

      setState(() => submitting = true);
      try {
        final validPref = genderOpts.isNotEmpty
            ? preferredGenders.where((id) => genderOpts.any((o) => o.id == id)).toList()
            : preferredGenders.toList();
        final payload = <String, dynamic>{
          'preferred_genders': validPref,
          if (selectedIntent != null &&
              (intentOpts.isEmpty || intentOpts.any((o) => o.id == selectedIntent)))
            'intent': selectedIntent,
        };
        await ref.read(profileRepositoryProvider).updateMyProfile(payload);
      } on ApiException catch (e) {
        setState(() {
          error = e.message;
          submitting = false;
        });
        return;
      } catch (e) {
        setState(() {
          error = 'Could not save preferences. Check your connection and try again.';
          submitting = false;
        });
        return;
      } finally {
        if (mounted) setState(() => submitting = false);
      }
    } else if (step == 3) {
      final bio = bioCtrl.text.trim();
      if (bio.isEmpty) {
        setState(() => error = 'Bio is required.');
        return;
      }
      if (bio.length < _minBioLen) {
        setState(() {
          error = 'Bio must be at least $_minBioLen characters (${bio.length}/$_minBioLen).';
        });
        return;
      }

      setState(() => submitting = true);
      try {
        await ref.read(profileRepositoryProvider).updateMyProfile({'bio': bio});
      } on ApiException catch (e) {
        setState(() {
          error = e.message;
          submitting = false;
        });
        return;
      } catch (e) {
        setState(() {
          error = 'Could not save bio. Check your connection and try again.';
          submitting = false;
        });
        return;
      } finally {
        if (mounted) setState(() => submitting = false);
      }
    } else if (step == 4) {
      if (!faceVerified) {
        setState(() {
          error = 'Complete face verification to proceed.';
        });
        return;
      }
    } else if (step == 5) {
      await _submit();
      return;
    }

    setState(() => step++);
  }

  bool get _useRealFaceLiveness =>
      faceVerificationEnabled == true && !mockMode;

  Future<void> _runFaceVerification() async {
    if (verifying || faceVerified) return;
    await _ensureIdentitySaved();
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
          step = 5;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face verification complete!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      } else {
        setState(() {
          verifying = false;
          error = 'Face verification was not completed. Please try again.';
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
          error = res['error']?.toString() ?? 'Verification failed. Try again.';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        faceVerified = true;
        verifying = false;
        step = 5;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face verification complete (mock)'),
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

    final validPref = genderOpts.isNotEmpty
        ? preferredGenders.where((id) => genderOpts.any((o) => o.id == id)).toList()
        : preferredGenders.toList();

    final payload = <String, dynamic>{
      'username': uname,
      'date_of_birth': dobCtrl.text.trim(),
      'preferred_genders': validPref,
      'languages': langNames,
      'bio': bioCtrl.text.trim(),
      if (selectedIntent != null &&
          (intentOpts.isEmpty || intentOpts.any((o) => o.id == selectedIntent)))
        'intent': selectedIntent,
    };
    if (!genderLocked && gender != null &&
        (genderOpts.isEmpty || genderOpts.any((o) => o.id == gender))) {
      payload['gender'] = gender;
    }
    if (!sexualityLocked && sexuality != null &&
        (sexualityOpts.isEmpty || sexualityOpts.any((o) => o.id == sexuality))) {
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

  @override
  Widget build(BuildContext context) {
    final isFaceStep = step == 4 || step == 5;

    return Scaffold(
      body: OnboardingWaveBackground(
        child: SafeArea(
          child: loadingOpts
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Progress Bar with Back Action
                      OnboardingProgressHeader(
                        step: step,
                        totalSteps: _totalSteps,
                        onBack: (step > 1 && !submitting && !verifying)
                            ? () => setState(() {
                                  error = null;
                                  step--;
                                })
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Glass Content Container
                      Expanded(
                        child: OnboardingGlassCard(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: switch (step) {
                                    1 => IdentityStep(
                                        usernameCtrl: usernameCtrl,
                                        dobCtrl: dobCtrl,
                                        genderOpts: genderOpts,
                                        sexualityOpts: sexualityOpts,
                                        languageOpts: languageOpts,
                                        gender: gender,
                                        sexuality: sexuality,
                                        selectedLanguageIds: selectedLanguageIds,
                                        genderLocked: genderLocked,
                                        sexualityLocked: sexualityLocked,
                                        onGenderChanged: (id) =>
                                            setState(() => gender = id),
                                        onSexualityChanged: (id) =>
                                            setState(() => sexuality = id),
                                        onLanguagesChanged: (ids) =>
                                            setState(() {
                                          selectedLanguageIds
                                            ..clear()
                                            ..addAll(ids);
                                        }),
                                      ),
                                    2 => IntentMatchStep(
                                        intentOpts: intentOpts,
                                        genderOpts: genderOpts,
                                        selectedIntent: selectedIntent,
                                        preferredGenders: preferredGenders,
                                        onIntentChanged: (id) =>
                                            setState(() => selectedIntent = id),
                                        onPreferredToggle: (id) =>
                                            setState(() {
                                          if (preferredGenders.contains(id)) {
                                            preferredGenders.remove(id);
                                          } else {
                                            preferredGenders.add(id);
                                          }
                                        }),
                                      ),
                                    3 => BioPhotoStep(
                                        bioCtrl: bioCtrl,
                                        minBioLen: _minBioLen,
                                        photos: uploadedPhotos,
                                        isUploadingPhoto: isUploadingPhoto,
                                        onBioChanged: () => setState(() {}),
                                        onAddPhoto: _addPhoto,
                                        onRemovePhoto: _removePhoto,
                                      ),
                                    4 => FaceVerifyStep(
                                        verifying: verifying,
                                        verified: faceVerified,
                                        realMode: _useRealFaceLiveness,
                                        onVerify: _runFaceVerification,
                                      ),
                                    _ => CompleteStep(
                                        submitting: submitting,
                                        onSubmit: _submit,
                                      ),
                                  },
                                ),
                              ),
                              if (error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFFF6B81),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),

                              // Primary Button Action
                              OnboardingPrimaryButton(
                                label: step == 5
                                    ? 'Apply & finish scanning'
                                    : (step == 4 && !faceVerified)
                                        ? 'Start face verification'
                                        : 'Continue',
                                loading: submitting,
                                isRedAccent: isFaceStep,
                                onPressed: (submitting || verifying)
                                    ? null
                                    : () {
                                        if (step == 4 && !faceVerified) {
                                          _runFaceVerification();
                                        } else {
                                          _next();
                                        }
                                      },
                              ),

                              // Secondary "Skip for now" Action (Step 3 & Step 4)
                              if (step == 3 || step == 4) ...[
                                const SizedBox(height: 6),
                                Center(
                                  child: TextButton(
                                    onPressed: (submitting || verifying)
                                        ? null
                                        : () {
                                            if (step == 4 && !faceVerified) {
                                              // Dev bypass to complete step if skipped
                                              setState(() => step = 5);
                                            } else {
                                              _next();
                                            }
                                          },
                                    child: Text(
                                      'Skip for now',
                                      style: GoogleFonts.dmSans(
                                        color: OnboardingColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
