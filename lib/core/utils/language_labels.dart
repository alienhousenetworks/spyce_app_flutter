import '../../data/models/user_models.dart';

/// Resolves language values from the API into display names.
///
/// Backend stores `languages` as a free-form JSON list. Clients historically
/// saved a mix of:
/// - human names (`"English"`) — web onboarding
/// - LanguageOption UUIDs — Flutter onboarding / profile chips
/// - short codes (`en`, `lang_hi`)
///
/// Feed returns whatever was stored. This resolver normalizes all of them.
abstract final class LanguageLabels {
  static final Map<String, String> _idToName = {};
  static final Map<String, String> _nameByLower = {};

  /// UUID v4 / hex-ish identifiers used as LanguageOption primary keys.
  static final RegExp _uuidLike = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _hexId = RegExp(r'^[0-9a-fA-F]{16,}$');

  /// Common ISO / app codes → display name.
  static const Map<String, String> codeMap = {
    'lang_en': 'English',
    'lang_hi': 'Hindi',
    'lang_es': 'Spanish',
    'lang_fr': 'French',
    'lang_de': 'German',
    'lang_bn': 'Bengali',
    'lang_mr': 'Marathi',
    'lang_te': 'Telugu',
    'lang_ta': 'Tamil',
    'lang_gu': 'Gujarati',
    'lang_kn': 'Kannada',
    'lang_ml': 'Malayalam',
    'lang_pa': 'Punjabi',
    'lang_or': 'Odia',
    'lang_ur': 'Urdu',
    'lang_zh': 'Mandarin',
    'lang_ja': 'Japanese',
    'lang_ko': 'Korean',
    'lang_ru': 'Russian',
    'lang_ar': 'Arabic',
    'lang_pt': 'Portuguese',
    'lang_it': 'Italian',
    'en': 'English',
    'hi': 'Hindi',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'bn': 'Bengali',
    'mr': 'Marathi',
    'te': 'Telugu',
    'ta': 'Tamil',
    'gu': 'Gujarati',
    'kn': 'Kannada',
    'ml': 'Malayalam',
    'pa': 'Punjabi',
    'or': 'Odia',
    'ur': 'Urdu',
    'zh': 'Mandarin',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ru': 'Russian',
    'ar': 'Arabic',
    'pt': 'Portuguese',
    'it': 'Italian',
    'english': 'English',
    'hindi': 'Hindi',
    'bengali': 'Bengali',
    'marathi': 'Marathi',
    'telugu': 'Telugu',
    'tamil': 'Tamil',
    'gujarati': 'Gujarati',
    'urdu': 'Urdu',
    'kannada': 'Kannada',
    'odia': 'Odia',
    'malayalam': 'Malayalam',
    'punjabi': 'Punjabi',
    'spanish': 'Spanish',
    'french': 'French',
    'german': 'German',
    'mandarin': 'Mandarin',
    'japanese': 'Japanese',
    'korean': 'Korean',
    'russian': 'Russian',
    'arabic': 'Arabic',
    'portuguese': 'Portuguese',
    'italian': 'Italian',
  };

  /// Whether the catalog has already been populated in memory.
  static bool get hasCatalog => _idToName.isNotEmpty;

  /// Load `/languages/` catalog so UUIDs resolve to names.
  static void setCatalog(Iterable<CatalogOption> options) {
    _idToName.clear();
    _nameByLower.clear();
    for (final o in options) {
      if (o.id.isEmpty || o.name.isEmpty) continue;
      _idToName[o.id] = o.name;
      _idToName[o.id.toLowerCase()] = o.name;
      _nameByLower[o.name.toLowerCase()] = o.name;
    }
  }

  static bool looksLikeOpaqueId(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    if (_uuidLike.hasMatch(v)) return true;
    if (_hexId.hasMatch(v)) return true;
    // Numeric-only legacy ids
    if (RegExp(r'^\d{6,}$').hasMatch(v)) return true;
    return false;
  }

  static bool looksLikeHumanName(String value) {
    final v = value.trim();
    if (v.isEmpty || v.length > 48) return false;
    if (looksLikeOpaqueId(v)) return false;
    if (codeMap.containsKey(v.toLowerCase())) return true;
    // Letters (incl. common extended Latin) / spaces / apostrophes
    return RegExp(r"^[A-Za-z\u00C0-\u024F][A-Za-z\u00C0-\u024F\s'.-]*$")
        .hasMatch(v);
  }

  /// Resolve a single language token to a display label.
  /// Returns null when the value is an unresolved opaque id (hide it).
  static String? resolveOne(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    // Catalog id → name
    final byId = _idToName[value] ?? _idToName[value.toLowerCase()];
    if (byId != null && byId.isNotEmpty) return byId;

    // Already a known catalog name (case-insensitive)
    final byName = _nameByLower[value.toLowerCase()];
    if (byName != null) return byName;

    // Code maps
    final key = value.toLowerCase();
    if (codeMap.containsKey(key)) return codeMap[key]!;

    if (key.startsWith('lang_') && key.length > 5) {
      final clean = key.substring(5);
      if (codeMap.containsKey(clean)) return codeMap[clean]!;
      if (clean.isNotEmpty && !looksLikeOpaqueId(clean)) {
        return clean[0].toUpperCase() + clean.substring(1);
      }
    }

    // Human-readable name already stored
    if (looksLikeHumanName(value)) {
      // Title-case single word names lightly
      if (value == value.toLowerCase() && !value.contains(' ')) {
        return value[0].toUpperCase() + value.substring(1);
      }
      return value;
    }

    // Unresolved UUID / garbage — do not show raw id
    if (looksLikeOpaqueId(value)) return null;

    return value;
  }

  /// Resolve a list; drops unresolved ids and de-duplicates (case-insensitive).
  static List<String> resolveAll(Iterable<dynamic> raw) {
    final out = <String>[];
    final seen = <String>{};
    for (final item in raw) {
      String? token;
      if (item is Map) {
        token = (item['name'] ?? item['label'] ?? item['title'] ?? item['id'])
            ?.toString();
      } else if (item != null) {
        token = item.toString();
      }
      if (token == null || token.isEmpty) continue;
      final label = resolveOne(token);
      if (label == null || label.isEmpty) continue;
      final sk = label.toLowerCase();
      if (seen.add(sk)) out.add(label);
    }
    return out;
  }

  /// Prefer saving **names** (matches web / feed readability).
  /// Accepts either option ids or names; returns catalog names when known.
  static List<String> namesForSave(Iterable<String> selectedIdsOrNames) {
    final out = <String>[];
    final seen = <String>{};
    for (final raw in selectedIdsOrNames) {
      final label = resolveOne(raw) ??
          (_nameByLower[raw.toLowerCase()] ??
              (looksLikeHumanName(raw) ? raw.trim() : null));
      if (label == null || label.isEmpty) continue;
      if (seen.add(label.toLowerCase())) out.add(label);
    }
    return out;
  }

  /// Selected chip ids for multi-select UI given stored profile values
  /// (ids and/or names).
  static Set<String> selectedOptionIds(
    Iterable<String> stored,
    List<CatalogOption> options,
  ) {
    final selected = <String>{};
    final byName = {
      for (final o in options) o.name.toLowerCase(): o.id,
    };
    final ids = {for (final o in options) o.id};
    for (final s in stored) {
      if (ids.contains(s)) {
        selected.add(s);
        continue;
      }
      final id = byName[s.toLowerCase()];
      if (id != null) selected.add(id);
    }
    return selected;
  }
}
