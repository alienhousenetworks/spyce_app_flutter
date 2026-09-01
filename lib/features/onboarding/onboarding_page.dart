import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/location/location_bootstrap.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/spyce_colors.dart';
import '../../core/utils/image_compressor.dart';
import '../../core/utils/image_pick.dart';
import '../../core/utils/language_labels.dart';
import '../../core/utils/onboarding.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/api_repositories.dart';
import '../../shared/widgets/onboarding_widgets.dart';
import '../../shared/widgets/photo_guidelines_sheet.dart';
import '../../shared/widgets/spyce_loaders.dart';
import '../auth/auth_controller.dart';
import '../settings/dpdp_consent_page.dart';
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
  static const _minTurnOns = 3;
  static const _maxHotTakes = 3;
  static const _maxPhotos = 5;

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
  final hotTakeCtrls = List.generate(3, (_) => TextEditingController());

  String? gender;
  String? sexuality;
  String? selectedIntent;
  final preferredGenders = <String>{};
  final selectedLanguageIds = <String>{};
  final selectedTurnOns = <String>{};
  final List<ProfileImage> uploadedPhotos = [];

  bool genderLocked = false;
  bool sexualityLocked = false;

  double? locLat;
  double? locLon;
  String? locCity;
  bool locLoading = false;
  String? locHint;
  Future<bool>? _locInFlight;

  List<CatalogOption> genderOpts = [];
  List<CatalogOption> sexualityOpts = [];
  List<CatalogOption> languageOpts = [];
  List<CatalogOption> intentOpts = [];
  List<CatalogOption> turnOnOpts = [];

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
        opts.turnOns(),
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

      final profile = results[5] as UserProfile?;
      final faceCfg = results[6] as FaceVerificationConfig?;

      if (isProfileOnboarded(profile)) {
        ref
            .read(authControllerProvider.notifier)
            .markOnboardingComplete(username: profile?.username);
        if (!mounted) return;
        context.go('/app/discover');
        return;
      }

      setState(() {
        genderOpts = results[0] as List<CatalogOption>;
        sexualityOpts = results[1] as List<CatalogOption>;
        languageOpts = results[2] as List<CatalogOption>;
        intentOpts = results[3] as List<CatalogOption>;
        turnOnOpts = results[4] as List<CatalogOption>;
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
            dobCtrl.text = dobApiToDisplay(dob);
          }

          final b = profile.bio?.trim();
          if (b != null && b.isNotEmpty) bioCtrl.text = b;

          if (profile.genderId != null && profile.genderId!.isNotEmpty) {
            final valid = genderOpts.where(
              (o) =>
                  o.id == profile.genderId ||
                  o.name.toLowerCase() == profile.genderLabel?.toLowerCase(),
            );
            if (valid.isNotEmpty) {
              gender = valid.first.id;
            } else {
              gender = profile.genderId;
            }
            genderLocked = true;
          }
          if (profile.sexualityId != null && profile.sexualityId!.isNotEmpty) {
            final valid = sexualityOpts.where(
              (o) =>
                  o.id == profile.sexualityId ||
                  o.name.toLowerCase() == profile.sexualityLabel?.toLowerCase(),
            );
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

          final validPreferred = profile.preferredGenderIds.where(
            (id) => genderOpts.isEmpty || genderOpts.any((o) => o.id == id),
          );
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

          selectedTurnOns
            ..clear()
            ..addAll(profile.turnOnIds);
          final existingTakes = FeedProfile.parseHotTakeTexts(profile.hottakes);
          for (var i = 0; i < hotTakeCtrls.length; i++) {
            hotTakeCtrls[i].text =
                i < existingTakes.length ? existingTakes[i] : '';
          }

          if (profile.latitude != null && profile.longitude != null) {
            locLat = profile.latitude;
            locLon = profile.longitude;
            locCity = profile.city;
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
    for (final c in hotTakeCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validUsername(String u) {
    return RegExp(r'^[a-zA-Z0-9._]{3,30}$').hasMatch(u);
  }

  int? _ageFromDob(String raw) {
    final d = parseDob(raw);
    if (d == null) return null;
    return ageFromDob(d);
  }

  String? _isoDob() {
    final d = parseDob(dobCtrl.text);
    return d == null ? null : formatDobIso(d);
  }

  List<String> _hotTakesPayload() {
    return hotTakeCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .take(_maxHotTakes)
        .toList();
  }

  Future<void> _ensureIdentitySaved() async {
    if (gender == null || sexuality == null) return;
    final langNames = LanguageLabels.namesForSave(selectedLanguageIds);
    final payload = <String, dynamic>{
      'username': usernameCtrl.text.trim().toLowerCase(),
      if (_isoDob() != null) 'date_of_birth': _isoDob(),
      'languages': langNames,
    };
    if (!genderLocked &&
        gender != null &&
        (genderOpts.isEmpty || genderOpts.any((o) => o.id == gender))) {
      payload['gender'] = gender;
    }
    if (!sexualityLocked &&
        sexuality != null &&
        (sexualityOpts.isEmpty ||
            sexualityOpts.any((o) => o.id == sexuality))) {
      payload['sexuality'] = sexuality;
    }
    try {
      await ref.read(profileRepositoryProvider).updateMyProfile(payload);
      genderLocked = true;
      sexualityLocked = true;
    } on ApiException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('gender cannot be changed') ||
          msg.contains('gender cannot be removed')) {
        genderLocked = true;
      }
      if (msg.contains('sexuality cannot be changed') ||
          msg.contains('sexuality cannot be removed')) {
        sexualityLocked = true;
      }
    } catch (_) {}
  }

  Future<void> _addPhoto() async {
    if (uploadedPhotos.length >= _maxPhotos) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can upload up to $_maxPhotos photos.')),
      );
      return;
    }
    final agreed = await PhotoGuidelinesSheet.ensureAccepted(context);
    if (!agreed || !mounted) return;

    final file = await pickProfileImage(context);
    if (file == null || !mounted) return;

    setState(() => isUploadingPhoto = true);
    try {
      final compressedFile = await ImageCompressor.compressToWebp(
        File(file.path),
        targetMaxKb: 200,
      );
      if (!mounted) return;

      await _ensureIdentitySaved();
      final res = await ref
          .read(profileRepositoryProvider)
          .uploadImage(compressedFile.path);
      final status = (res['status'] ?? '').toString().toLowerCase();
      final imgUrl =
          res['image_url']?.toString() ?? res['url']?.toString() ?? '';
      final imgId = res['id']?.toString() ?? '';
      if (imgId.isEmpty &&
          imgUrl.isEmpty &&
          status != 'ok' &&
          status != 'success') {
        throw Exception(
          res['error'] ?? 'Photo is still processing. Try again in a moment.',
        );
      }
      setState(() {
        uploadedPhotos.add(
          ProfileImage(
            id: imgId.isEmpty
                ? DateTime.now().millisecondsSinceEpoch.toString()
                : imgId,
            imageUrl: imgUrl.isEmpty ? file.path : imgUrl,
          ),
        );
        isUploadingPhoto = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload photo: ${ApiException.describe(e)}')),
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
        setState(() => error = 'Enter a valid date of birth (DD/MM/YYYY).');
        return;
      }
      if (age < 18) {
        setState(
          () => error = 'You must be at least 18 years old to join SPYCE.',
        );
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

      final isoDob = _isoDob();
      if (isoDob == null) {
        setState(() => error = 'Enter a valid date of birth (DD/MM/YYYY).');
        return;
      }

      setState(() => submitting = true);
      try {
        final langNames = LanguageLabels.namesForSave(selectedLanguageIds);
        final payload = <String, dynamic>{
          'username': username,
          'date_of_birth': isoDob,
          'languages': langNames,
        };
        if (!genderLocked &&
            gender != null &&
            (genderOpts.isEmpty || genderOpts.any((o) => o.id == gender))) {
          payload['gender'] = gender;
        }
        if (!sexualityLocked &&
            sexuality != null &&
            (sexualityOpts.isEmpty ||
                sexualityOpts.any((o) => o.id == sexuality))) {
          payload['sexuality'] = sexuality;
        }
        await ref.read(profileRepositoryProvider).updateMyProfile(payload);
        genderLocked = true;
        sexualityLocked = true;
      } on ApiException catch (e) {
        final msg = e.message.toLowerCase();
        final genderImmutable =
            msg.contains('gender cannot be changed') ||
            msg.contains('gender cannot be removed');
        final sexualityImmutable =
            msg.contains('sexuality cannot be changed') ||
            msg.contains('sexuality cannot be removed');

        if (genderImmutable || sexualityImmutable) {
          try {
            final retry = <String, dynamic>{
              'username': username,
              'date_of_birth': isoDob,
              'languages': LanguageLabels.namesForSave(selectedLanguageIds),
            };
            if (genderImmutable) genderLocked = true;
            if (sexualityImmutable) sexualityLocked = true;
            if (!genderLocked && gender != null) retry['gender'] = gender;
            if (!sexualityLocked && sexuality != null)
              retry['sexuality'] = sexuality;
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
          error =
              'Could not save profile. Check your connection and try again.';
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
            ? preferredGenders
                  .where((id) => genderOpts.any((o) => o.id == id))
                  .toList()
            : preferredGenders.toList();
        final payload = <String, dynamic>{
          'preferred_genders': validPref,
          if (selectedIntent != null &&
              (intentOpts.isEmpty ||
                  intentOpts.any((o) => o.id == selectedIntent)))
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
          error =
              'Could not save preferences. Check your connection and try again.';
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
          error =
              'Bio must be at least $_minBioLen characters (${bio.length}/$_minBioLen).';
        });
        return;
      }
      if (turnOnOpts.isNotEmpty && selectedTurnOns.length < _minTurnOns) {
        setState(() {
          error = 'Pick at least $_minTurnOns turn-ons to continue.';
        });
        return;
      }

      setState(() => submitting = true);
      try {
        final locOk = await _ensureLocation(
          fromUser: locLat == null || locLon == null,
        );
        if (!locOk || locLat == null || locLon == null) {
          if (mounted) {
            setState(() {
              submitting = false;
              error =
                  locHint ??
                  'Location is required. Allow location access to continue.';
            });
          }
          return;
        }
        final takes = _hotTakesPayload();
        await ref.read(profileRepositoryProvider).updateMyProfile({
          'bio': bio,
          'turn_ons': selectedTurnOns.toList(),
          'hottakes': takes,
          ..._locationPayload(),
        });
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
    if (step == 3) {
      _ensureLocation();
    }
  }

  Map<String, dynamic> _locationPayload() {
    return {
      if (locLat != null) 'latitude': locLat,
      if (locLon != null) 'longitude': locLon,
      if (locCity != null && locCity!.isNotEmpty && locCity != 'Unknown')
        'city': locCity,
    };
  }

  Future<bool> _ensureLocation({bool fromUser = false}) async {
    if (!fromUser && locLat != null && locLon != null) return true;
    if (_locInFlight != null) return _locInFlight!;

    final future = _runLocationDetect(fromUser: fromUser);
    _locInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_locInFlight, future)) _locInFlight = null;
    }
  }

  Future<bool> _runLocationDetect({required bool fromUser}) async {
    setState(() {
      locLoading = true;
      locHint = null;
      error = null;
    });

    final result = await ref
        .read(locationBootstrapProvider)
        .detect(openSettingsIfNeeded: fromUser);

    if (!mounted) return false;

    if (result.ok) {
      try {
        await ref
            .read(profileRepositoryProvider)
            .updateMyProfile(result.toProfilePayload());
      } catch (_) {
        // Still keep coords locally so the bio PATCH can include them.
      }
      if (!mounted) return false;
      setState(() {
        locLat = result.lat;
        locLon = result.lon;
        locCity = result.city;
        locLoading = false;
        locHint = null;
      });
      return true;
    }

    final hint = switch (result.status) {
      LocationDetectStatus.servicesOff =>
        'Turn on Location Services, then tap Enable.',
      LocationDetectStatus.deniedForever =>
        'Location is blocked. Open Settings and allow it for SPYCE.',
      LocationDetectStatus.denied =>
        'Allow location when prompted — it is required to continue.',
      LocationDetectStatus.timeout =>
        'Could not get a GPS fix. Move near a window and try again.',
      _ => 'Could not detect location. Tap Enable to try again.',
    };

    setState(() {
      locLoading = false;
      locHint = hint;
    });
    return false;
  }

  bool get _useRealFaceLiveness => faceVerificationEnabled == true && !mockMode;

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
            backgroundColor: SpyceColors.success,
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
      final res = await ref.read(verificationRepositoryProvider).mockComplete();
      final ok =
          res['status']?.toString().toUpperCase() == 'SUCCESS' ||
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
          backgroundColor: SpyceColors.success,
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
        ? preferredGenders
              .where((id) => genderOpts.any((o) => o.id == id))
              .toList()
        : preferredGenders.toList();

    final payload = <String, dynamic>{
      'username': uname,
      if (_isoDob() != null) 'date_of_birth': _isoDob(),
      'preferred_genders': validPref,
      'languages': langNames,
      'bio': bioCtrl.text.trim(),
      if (selectedTurnOns.isNotEmpty) 'turn_ons': selectedTurnOns.toList(),
      'hottakes': _hotTakesPayload(),
      if (selectedIntent != null &&
          (intentOpts.isEmpty || intentOpts.any((o) => o.id == selectedIntent)))
        'intent': selectedIntent,
    };
    if (!genderLocked &&
        gender != null &&
        (genderOpts.isEmpty || genderOpts.any((o) => o.id == gender))) {
      payload['gender'] = gender;
    }
    if (!sexualityLocked &&
        sexuality != null &&
        (sexualityOpts.isEmpty ||
            sexualityOpts.any((o) => o.id == sexuality))) {
      payload['sexuality'] = sexuality;
    }
    payload.addAll(_locationPayload());

    try {
      var consented = false;
      try {
        final existing = await ref.read(authRepositoryProvider).getDpdpConsent();
        consented = existing['has_consented'] == true &&
            existing['matchmaking_consent'] != false &&
            existing['location_processing_consent'] != false &&
            existing['sensitive_data_consent'] != false;
      } catch (_) {}
      if (!consented && mounted) {
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const DpdpConsentPage(requiredToContinue: true),
          ),
        );
        if (ok != true) {
          if (!mounted) return;
          setState(() {
            submitting = false;
            error = 'Privacy consent is required to use SPYCE.';
          });
          return;
        }
      }
      await ref.read(profileRepositoryProvider).updateMyProfile(payload);
      ref
          .read(authControllerProvider.notifier)
          .markOnboardingComplete(username: uname);
      if (!mounted) return;
      context.go('/app/discover');
    } on ApiException catch (e) {
      final msg = e.message.toLowerCase();
      final genderImmutable =
          msg.contains('gender cannot be changed') ||
          msg.contains('gender cannot be removed');
      final sexualityImmutable =
          msg.contains('sexuality cannot be changed') ||
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
            final profile = await ref
                .read(profileRepositoryProvider)
                .getMyProfile();
            if (isProfileOnboarded(profile)) {
              ref
                  .read(authControllerProvider.notifier)
                  .markOnboardingComplete(username: profile.username ?? uname);
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
    1 => "Let's get to know you",
    2 => 'What are you here for?',
    3 => 'Show a little personality',
    4 => "Prove you're real",
    _ => "You're in",
  };

  String get _subtitle => switch (step) {
    1 => "This is how you'll appear on SPYCE.",
    2 => "We'll use this to find better matches.",
    3 => 'Bio, at least 3 turn-ons, and location. Photos and hot takes can wait.',
    4 => 'A quick live check keeps SPYCE genuine.',
    _ => 'Thanks for helping keep this a real space.',
  };

  String get _primaryLabel {
    if (step == 5) return 'Enter SPYCE';
    if (step == 4 && !faceVerified) return 'Start face verification';
    return 'Continue';
  }

  @override
  Widget build(BuildContext context) {
    if (loadingOpts) {
      return const Scaffold(
        backgroundColor: SpyceColors.dark950,
        body: OnboardingWaveBackground(
          child: SpyceLoadingView(message: 'Setting things up…'),
        ),
      );
    }

    return OnboardingScaffold(
      showProgress: true,
      step: step,
      totalSteps: _totalSteps,
      onBack: (step > 1 && !submitting && !verifying)
          ? () => setState(() {
              error = null;
              step--;
            })
          : null,
      title: _title,
      subtitle: _subtitle,
      error: error,
      primaryLabel: _primaryLabel,
      primaryLoading: submitting || verifying,
      secondaryLabel: step == 3 ? 'Skip for now' : null,
      onSecondary: (submitting || verifying)
          ? null
          : () {
              _next();
            },
      onPrimary: (submitting || verifying)
          ? null
          : () {
              if (step == 4 && !faceVerified) {
                _runFaceVerification();
              } else {
                _next();
              }
            },
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(step),
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
              onGenderChanged: (id) => setState(() => gender = id),
              onSexualityChanged: (id) => setState(() => sexuality = id),
              onLanguagesChanged: (ids) => setState(() {
                selectedLanguageIds
                  ..clear()
                  ..addAll(ids);
              }),
              onDobChanged: () => setState(() {}),
            ),
            2 => IntentMatchStep(
              intentOpts: intentOpts,
              genderOpts: genderOpts,
              selectedIntent: selectedIntent,
              preferredGenders: preferredGenders,
              onIntentChanged: (id) => setState(() => selectedIntent = id),
              onPreferredToggle: (id) => setState(() {
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
              locationLoading: locLoading,
              locationReady: locLat != null && locLon != null,
              locationCity: locCity,
              locationHint: locHint,
              onDetectLocation: () => _ensureLocation(fromUser: true),
              turnOnOpts: turnOnOpts,
              selectedTurnOns: selectedTurnOns,
              onTurnOnsChanged: (ids) => setState(() {
                selectedTurnOns
                  ..clear()
                  ..addAll(ids);
              }),
              minTurnOns: _minTurnOns,
              hotTakeCtrls: hotTakeCtrls,
              onHotTakesChanged: () => setState(() {}),
            ),
            4 => FaceVerifyStep(
              verifying: verifying,
              verified: faceVerified,
              realMode: _useRealFaceLiveness,
              onVerify: _runFaceVerification,
            ),
            _ => CompleteStep(submitting: submitting, onSubmit: _submit),
          },
        ),
      ),
    );
  }
}
