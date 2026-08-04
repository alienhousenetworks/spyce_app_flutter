import '../../data/models/user_models.dart';

/// Min bio length matching backend / web onboarding gate.
const int kMinOnboardingBioLen = 20;

/// Whether core first-time signup fields are present.
///
/// Does **not** require [UserProfile.isDiscoverable] — that is false when the
/// profile is paused/hidden, or for older accounts missing face-verify flags.
/// Returning users with gender already set must skip signup (gender is immutable).
bool isProfileOnboarded(UserProfile? profile) {
  if (profile == null) return false;

  // Explicit API flags when present
  final raw = profile.raw;
  if (raw['onboarding_complete'] == true) return true;
  if (raw['is_completed'] == true) return true;
  if (profile.isDiscoverable) return true;

  final username = (profile.username ?? '').trim();
  final dob = profile.dateOfBirth;
  final hasDob = (dob != null && dob.trim().isNotEmpty) || profile.age != null;
  final hasGender =
      (profile.genderId != null && profile.genderId!.trim().isNotEmpty) ||
          (profile.genderLabel != null && profile.genderLabel!.trim().isNotEmpty);
  final hasSexuality =
      (profile.sexualityId != null && profile.sexualityId!.trim().isNotEmpty) ||
          (profile.sexualityLabel != null &&
              profile.sexualityLabel!.trim().isNotEmpty);
  final bio = (profile.bio ?? '').trim();

  final coreFilled = username.length >= 3 &&
      hasDob &&
      hasGender &&
      hasSexuality &&
      profile.preferredGenderIds.isNotEmpty &&
      bio.length >= kMinOnboardingBioLen;

  if (coreFilled) return true;

  // High completion % + username ≈ returning user, not brand-new
  final pct = raw['completion_percentage'];
  final pctNum = pct is num ? pct.toDouble() : double.tryParse('$pct');
  if (username.length >= 3 && pctNum != null && pctNum >= 50) {
    return true;
  }

  return false;
}

/// True when gender is already locked on the server (immutable).
bool profileHasLockedGender(UserProfile? profile) {
  if (profile == null) return false;
  return (profile.genderId != null && profile.genderId!.trim().isNotEmpty) ||
      (profile.genderLabel != null && profile.genderLabel!.trim().isNotEmpty);
}
