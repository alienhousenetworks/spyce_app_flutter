/// Client-Side Content Safety & Compliance Engine ($0 AI Budget)
/// Fast regex and leetspeak-normalized checker for instant user feedback.
class ContentSafetyValidator {
  static const Map<String, String> _leetMap = {
    '0': 'o', '1': 'i', '!': 'i', '|': 'i',
    '3': 'e', '4': 'a', '@': 'a', '5': 's',
    '\$': 's', '7': 't', '+': 't', '8': 'b',
    '9': 'g', '2': 'z'
  };

  static String normalizeText(String input) {
    String text = input.toLowerCase();
    _leetMap.forEach((leet, regular) {
      text = text.replaceAll(leet, regular);
    });
    return text;
  }

  static String stripSeparators(String text) {
    return text.replaceAll(RegExp(r'[\s\.\-_,:\*\#/\\]+'), '');
  }

  // Extreme Violence & Terrorism
  static final List<String> _terrorismViolenceKeywords = [
    'terrorist', 'terrorism', 'isis', 'al-qaeda', 'taliban', 'jihadist',
    'bomb making', 'make a bomb', 'pipe bomb', 'suicide vest', 'car bomb',
    'mass shoot', 'mass shooting', 'school shoot', 'kill everyone', 'massacre',
    'behead', 'beheading', 'genocide', 'lynch', 'lynching',
  ];

  // Religious, Hate & Violence Incitement
  static final List<String> _hateViolenceKeywords = [
    'kill all hindus', 'kill all muslims', 'kill all christians', 'kill all jews',
    'kill all sikhs', 'death to hindus', 'death to muslims', 'death to christians',
    'death to jews', 'gas the jews', 'nazi', 'neo-nazi', 'white power',
    'ethnic cleansing', 'communal riot', 'burn down mosque', 'burn down temple',
    'burn down church', 'exterminate all'
  ];

  // Child Safety
  static final List<String> _childSafetyKeywords = [
    'cp link', 'child porn', 'underage sex', 'minor sex', 'pedophile',
    'pedo link', 'lolicon', 'jailbait', 'child abuse', 'csam'
  ];

  // Self Harm
  static final List<String> _selfHarmKeywords = [
    'how to commit suicide', 'how to kill myself', 'ways to hang myself',
    'slit your wrists', 'go kill yourself', 'kys', 'drink bleach'
  ];

  // Social & PII Patterns
  static final List<RegExp> _socialPatterns = [
    RegExp(r'(?:wa\.me|chat\.whatsapp\.com|whatsapp|whatapp|wapp|watsapp)\s*[:\-\/]?\s*[\w\d\+]+', caseSensitive: false),
    RegExp(r'(?:t\.me|telegram)\s*[:\-\/]?\s*[\w\d_]+', caseSensitive: false),
    RegExp(r'(?:insta|instagram|ig|snap|snapchat)\s*[:\-\s]\s*@?[\w\d_\.]{3,30}', caseSensitive: false),
    RegExp(r'[\w\.-]+@[\w\.-]+\.\w{2,8}', caseSensitive: false),
  ];

  /// Returns null if safe, or a user-friendly error message if prohibited content is found.
  static String? validate(String text) {
    if (text.trim().isEmpty) return null;

    final norm = normalizeText(text);
    final collapsed = stripSeparators(norm);

    // 1. Child safety
    for (final kw in _childSafetyKeywords) {
      if (norm.contains(kw) || collapsed.contains(stripSeparators(kw))) {
        return "Content violates Child Safety & Protection policies.";
      }
    }

    // 2. Terrorism & Extreme Violence
    for (final kw in _terrorismViolenceKeywords) {
      if (norm.contains(kw) || collapsed.contains(stripSeparators(kw))) {
        return "Public feed prohibits violent or extremist content.";
      }
    }

    // 3. Religious / Political Hate & Incitement
    for (final kw in _hateViolenceKeywords) {
      if (norm.contains(kw) || collapsed.contains(stripSeparators(kw))) {
        return "Content violates community guidelines on hate speech and incitement.";
      }
    }

    // 4. Self Harm
    for (final kw in _selfHarmKeywords) {
      if (norm.contains(kw) || collapsed.contains(stripSeparators(kw))) {
        return "Content contains prohibited self-harm references.";
      }
    }

    // 5. Social Handles
    for (final pattern in _socialPatterns) {
      if (pattern.hasMatch(text) || pattern.hasMatch(norm)) {
        return "Sharing direct contact handles or external links is prohibited in public confessions.";
      }
    }

    // 6. Phone Numbers (10+ digits)
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length >= 10) {
      if (RegExp(r'[6-9]\d{9}').hasMatch(digitsOnly) || RegExp(r'\d{10,12}').hasMatch(digitsOnly)) {
        return "Sharing phone numbers in public confessions is not permitted.";
      }
    }

    return null;
  }
}
