import '../../data/models/user_models.dart';

/// Parses onboarding DOB. Accepts `yyyy-MM-dd` (API) and `DD/MM/YYYY` (typed).
DateTime? parseDob(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;

  final iso = DateTime.tryParse(t);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);

  final m = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})$').firstMatch(t);
  if (m != null) {
    final day = int.tryParse(m.group(1)!);
    final month = int.tryParse(m.group(2)!);
    final year = int.tryParse(m.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final dt = DateTime(year, month, day);
    if (dt.year != year || dt.month != month || dt.day != day) return null;
    return dt;
  }
  return null;
}

String formatDobDisplay(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

String formatDobIso(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

/// Convert API `yyyy-MM-dd` into typed `DD/MM/YYYY` for the onboarding field.
String dobApiToDisplay(String raw) {
  final dt = parseDob(raw);
  return dt == null ? raw.trim() : formatDobDisplay(dt);
}

int? ageFromDob(DateTime d) {
  final now = DateTime.now();
  var age = now.year - d.year;
  if (now.month < d.month || (now.month == d.month && now.day < d.day)) {
    age--;
  }
  return age >= 0 ? age : null;
}

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
