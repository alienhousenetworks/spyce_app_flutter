import '../../core/config/env.dart';
import '../../core/utils/language_labels.dart';
import '../../core/utils/num_parse.dart';

double? _parseDouble(dynamic v) => parseDouble(v);
int? _parseInt(dynamic v) => parseInt(v);

/// Turn relative `/media/...` paths into absolute API URLs.
/// Leaves http(s), local device paths, and storage keys as-is.
String? resolveChatMediaUrl(String? url) {
  if (url == null) return null;
  final u = url.trim();
  if (u.isEmpty) return null;
  if (u.startsWith('http://') ||
      u.startsWith('https://') ||
      u.startsWith('file://')) {
    return u;
  }
  // Server-relative media only (not device paths like /data/user/0/...)
  if (u.startsWith('/media') ||
      u.startsWith('/static') ||
      u.startsWith('/api')) {
    return '${Env.apiBaseUrl}$u';
  }
  return u;
}

class AuthUser {
  const AuthUser({
    required this.id,
    this.email,
    this.username,
    this.firstName,
    this.isNew = false,
  });

  final String id;
  final String? email;
  final String? username;
  final String? firstName;
  final bool isNew;

  /// Prefer profile username for watermarks / display (never raw id).
  String? get displayUsername {
    final u = username?.trim().replaceFirst(RegExp(r'^@+'), '');
    if (u != null && u.isNotEmpty) return u;
    final n = firstName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return null;
  }

  AuthUser copyWith({
    String? id,
    String? email,
    String? username,
    String? firstName,
    bool? isNew,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      isNew: isNew ?? this.isNew,
    );
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    // Username may nest under profile when API merges objects
    final profile = json['profile'] is Map
        ? Map<String, dynamic>.from(json['profile'] as Map)
        : null;
    return AuthUser(
      id: (json['id'] ?? json['user_id'] ?? '').toString(),
      email: json['email']?.toString(),
      username: (json['username'] ?? profile?['username'])?.toString(),
      firstName: (json['first_name'] ??
              json['name'] ??
              profile?['first_name'] ??
              profile?['name'])
          ?.toString(),
      isNew: json['is_new'] == true,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.onboardingComplete,
    this.isIdentityVerified = false,
    this.isEmailVerified = false,
  });

  final String userId;
  final bool onboardingComplete;
  final bool isIdentityVerified;
  final bool isEmailVerified;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      userId: (json['user_id'] ?? json['id'] ?? '').toString(),
      onboardingComplete: json['onboarding_complete'] == true ||
          json['is_discoverable'] == true,
      isIdentityVerified: json['is_identity_verified'] == true,
      isEmailVerified: json['is_email_verified'] == true,
    );
  }
}

class ProfileImage {
  const ProfileImage({
    required this.id,
    required this.imageUrl,
    this.order = 0,
  });

  final String id;
  final String imageUrl;
  final int order;

  factory ProfileImage.fromJson(Map<String, dynamic> json) {
    return ProfileImage(
      id: (json['id'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? json['url'] ?? json['image'] ?? '')
          .toString()
          .trim(),
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }

  ProfileImage copyWith({String? id, String? imageUrl, int? order}) {
    return ProfileImage(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      order: order ?? this.order,
    );
  }
}

class HotTake {
  const HotTake({required this.label, required this.text});
  final String label;
  final String text;
}

class FeedProfile {
  const FeedProfile({
    required this.id,
    this.userId,
    this.username,
    this.firstName,
    this.age,
    this.bio,
    this.city,
    this.state,
    this.country,
    this.distanceKm,
    this.gender,
    this.sexuality,
    this.pronouns,
    this.height,
    this.intent,
    this.images = const [],
    this.avatarUrl,
    this.photoStatus,
    this.layoutId,
    this.bgId,
    this.bgVariantId,
    this.isOnline = false,
    this.lastSeen,
    this.lastActiveAt,
    this.isBoosted = false,
    this.canDirectMessage = false,
    this.canSeeIncomingLikes = false,
    this.turnOns = const [],
    this.interests = const [],
    this.languages = const [],
    this.hotTakes = const [],
    this.moods = const [],
    this.favouriteTrack,
    this.isLiked = false,
    this.isFallbackLiked = false,
  });

  final String id;
  final String? userId;
  final String? username;
  final String? firstName;
  final int? age;
  final String? bio;
  final String? city;
  final String? state;
  final String? country;
  final double? distanceKm;
  final String? gender;
  final String? sexuality;
  final String? pronouns;
  final String? height;
  final String? intent;
  final List<ProfileImage> images;
  /// Admin gender+sexuality avatar pool URL (`avatar_detail.image`).
  final String? avatarUrl;
  /// Backend: `CUSTOM` = user uploads, `AVATAR` = admin pool.
  final String? photoStatus;
  final String? layoutId;
  final String? bgId;
  final String? bgVariantId;
  final bool isOnline;
  /// Human label from API (`Online`, `Last seen recently`, …).
  final String? lastSeen;
  /// Optional raw timestamp if API sends `last_active`.
  final DateTime? lastActiveAt;
  final bool isBoosted;
  final bool canDirectMessage;
  final bool canSeeIncomingLikes;
  final List<String> turnOns;
  final List<String> interests;
  final List<String> languages;
  final List<HotTake> hotTakes;
  final List<String> moods;
  final String? favouriteTrack;
  /// Viewer already liked this profile within LIKE_TTL (backend ~36h).
  final bool isLiked;
  /// Profile returned as liked fallback when organic feed is exhausted.
  final bool isFallbackLiked;

  FeedProfile copyWith({
    List<String>? languages,
    bool? isLiked,
    bool? isFallbackLiked,
  }) {
    return FeedProfile(
      id: id,
      userId: userId,
      username: username,
      firstName: firstName,
      age: age,
      bio: bio,
      city: city,
      state: state,
      country: country,
      distanceKm: distanceKm,
      gender: gender,
      sexuality: sexuality,
      pronouns: pronouns,
      height: height,
      intent: intent,
      images: images,
      avatarUrl: avatarUrl,
      photoStatus: photoStatus,
      layoutId: layoutId,
      bgId: bgId,
      bgVariantId: bgVariantId,
      isOnline: isOnline,
      lastSeen: lastSeen,
      lastActiveAt: lastActiveAt,
      isBoosted: isBoosted,
      canDirectMessage: canDirectMessage,
      canSeeIncomingLikes: canSeeIncomingLikes,
      turnOns: turnOns,
      interests: interests,
      languages: languages ?? this.languages,
      hotTakes: hotTakes,
      moods: moods,
      favouriteTrack: favouriteTrack,
      isLiked: isLiked ?? this.isLiked,
      isFallbackLiked: isFallbackLiked ?? this.isFallbackLiked,
    );
  }

  /// True when user has uploaded profile photos.
  /// Slot 1 (lowest order) is the main/profile picture — not a separate field.
  /// Prefer non-empty `images` over photo_status so stale AVATAR never hides uploads.
  bool get hasUserPhotos {
    return images.any((i) => i.imageUrl.isNotEmpty);
  }

  bool get isUsingAdminAvatar =>
      !hasUserPhotos &&
      avatarUrl != null &&
      avatarUrl!.isNotEmpty;

  /// Display image for feed/cards:
  /// 1) user-uploaded images (`images[]`) when present / CUSTOM
  /// 2) else admin pool `avatar_detail.image` (gender + sexuality)
  /// 3) any non-empty image URL as last resort
  String? get heroImageUrl {
    if (hasUserPhotos) {
      final u = images.first.imageUrl.trim();
      if (u.isNotEmpty) return u;
    }
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return avatarUrl!.trim();
    }
    for (final img in images) {
      final u = img.imageUrl.trim();
      if (u.isNotEmpty) return u;
    }
    return null;
  }

  /// Gallery page only for real uploads (admin pool is a single hero image).
  List<ProfileImage> get galleryImages =>
      hasUserPhotos ? images : const [];

  String get displayName {
    if (username != null && username!.isNotEmpty) return username!;
    if (firstName != null && firstName!.isNotEmpty) return firstName!;
    return 'Someone';
  }

  String get shortName => displayName;

  /// City, state, country (no distance). Empty when none set.
  String get locationSummary {
    final parts = <String>[
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (state != null && state!.trim().isNotEmpty) state!.trim(),
      if (country != null && country!.trim().isNotEmpty) country!.trim(),
    ];
    return parts.join(', ');
  }

  factory FeedProfile.fromJson(Map<String, dynamic> json) {
    final theme = json['theme'] is Map
        ? Map<String, dynamic>.from(json['theme'] as Map)
        : <String, dynamic>{};

    final images = <ProfileImage>[];
    final imagesRaw = json['images'];
    if (imagesRaw is List) {
      for (final item in imagesRaw) {
        if (item is Map) {
          final img =
              ProfileImage.fromJson(Map<String, dynamic>.from(item));
          if (img.imageUrl.isNotEmpty) images.add(img);
        }
      }
      // Slot 1 (lowest order) = main profile photo
      images.sort((a, b) => a.order.compareTo(b.order));
    }

    // Admin avatar pool (gender + sexuality) — avatar_detail.image
    final avatarDetail = json['avatar_detail'] ?? json['avatar'];
    String? avatarUrl;
    if (avatarDetail is Map) {
      avatarUrl = (avatarDetail['image'] ??
              avatarDetail['image_url'] ??
              avatarDetail['url'])
          ?.toString();
    }
    avatarUrl ??= (json['avatar_url'] ??
            json['pool_avatar_url'] ??
            json['default_avatar_url'] ??
            json['placeholder_image_url'])
        ?.toString();

    final photoStatus =
        (json['photo_status'] ?? json['photoStatus'])?.toString();

    final turnOns =
        _stringList(json['turn_ons'] ?? json['turn_ons_detail'] ?? json['turnOns']);
    final interests = _stringList(
      json['interests'] ?? json['into'] ?? json['hobbies'],
    );
    // Keep raw values (names and/or LanguageOption UUIDs).
    // Discover / profile load the language catalog then call LanguageLabels.resolveAll.
    final languages = _stringList(
      json['languages_detail'] ?? json['languages'],
    );

    final moods = _stringList(json['current_moods'] ?? json['moods']);
    final hotTakes = _parseHotTakes(json['hottakes'] ?? json['hot_takes']);

    final gender = _label(json['gender'] ?? json['gender_detail']);
    final sexuality = _label(json['sexuality'] ?? json['sexuality_detail']);

    return FeedProfile(
      id: (json['id'] ?? json['user_id'] ?? '').toString(),
      userId: (json['user_id'] ?? json['id'])?.toString(),
      username: json['username']?.toString(),
      firstName: (json['first_name'] ?? json['name'])?.toString(),
      age: (json['age'] as num?)?.toInt(),
      bio: json['bio']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      country: json['country']?.toString(),
      distanceKm: _parseDouble(json['distance_km'] ?? json['distance']),
      gender: gender,
      sexuality: sexuality,
      pronouns: json['pronouns']?.toString() ??
          (gender?.toLowerCase() == 'female'
              ? 'she/her'
              : gender?.toLowerCase() == 'male'
                  ? 'he/him'
                  : null),
      height: json['height']?.toString() ??
          (json['height_cm'] != null ? "${json['height_cm']} cm" : null),
      intent: _label(json['intent'] ?? json['intent_detail']),
      images: images,
      avatarUrl: avatarUrl,
      photoStatus: photoStatus,
      layoutId: (json['layout_id'] ?? theme['layout_id'])?.toString(),
      bgId: (json['bg_id'] ?? theme['bg_id'])?.toString(),
      bgVariantId:
          (json['bg_variant_id'] ?? theme['bg_variant_id'])?.toString(),
      isOnline: json['is_online'] == true,
      lastSeen: json['last_seen']?.toString(),
      lastActiveAt: () {
        final raw = json['last_active'] ?? json['last_active_at'];
        if (raw == null) return null;
        if (raw is num) {
          final n = raw.toDouble();
          final ms = n > 1e12 ? n.toInt() : (n * 1000).toInt();
          return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
        }
        return DateTime.tryParse(raw.toString());
      }(),
      isBoosted: json['is_boosted'] == true,
      canDirectMessage: json['can_direct_message'] == true,
      canSeeIncomingLikes: json['can_see_incoming_likes'] == true ||
          json['can_view_likes'] == true,
      turnOns: turnOns,
      interests: interests,
      languages: languages,
      hotTakes: hotTakes,
      moods: moods,
      favouriteTrack: (json['favourite_track'] ??
              json['favorite_track'] ??
              json['spotify_track'])
          ?.toString(),
      isLiked: json['is_liked'] == true ||
          json['already_liked'] == true ||
          json['is_fallback_liked'] == true,
      isFallbackLiked: json['is_fallback_liked'] == true,
    );
  }

  static FeedProfile mapFeedItem(dynamic raw) {
    if (raw is! Map) return const FeedProfile(id: '');
    final r = Map<String, dynamic>.from(raw);
    final profile = r['profile_card'] ?? r['profile'] ?? r;
    final map = profile is Map
        ? Map<String, dynamic>.from(profile)
        : <String, dynamic>{};
    map['id'] = r['id'] ?? map['user_id'] ?? map['id'];
    map['user_id'] = r['id'] ?? map['user_id'] ?? map['id'];
    map['can_direct_message'] =
        r['can_direct_message'] ?? map['can_direct_message'];
    map['is_boosted'] = r['is_boosted'] ?? map['is_boosted'];
    // Presence may live on envelope or profile_card
    map['is_online'] = map['is_online'] ?? r['is_online'];
    map['last_seen'] = map['last_seen'] ?? r['last_seen'];
    // Distance often set on feed envelope after cache merge
    map['distance_km'] = map['distance_km'] ?? r['distance_km'] ?? r['distance'];
    if (r['theme'] != null) map['theme'] = r['theme'];
    // Images / avatar may sit on envelope when profile_card is sparse
    map['images'] ??= r['images'];
    map['avatar_detail'] ??= r['avatar_detail'];
    map['avatar'] ??= r['avatar'];
    map['avatar_url'] ??= r['avatar_url'];
    map['photo_status'] ??= r['photo_status'] ?? r['photoStatus'];
    // Liked state: profile_card flag and/or feed envelope fallback
    map['is_liked'] = map['is_liked'] == true ||
        r['is_liked'] == true ||
        r['is_fallback_liked'] == true ||
        map['is_fallback_liked'] == true;
    map['is_fallback_liked'] =
        r['is_fallback_liked'] == true || map['is_fallback_liked'] == true;
    return FeedProfile.fromJson(map);
  }

  static String? _label(dynamic v) {
    if (v == null) return null;
    if (v is Map) return (v['name'] ?? v['label'] ?? v['title'])?.toString();
    return v.toString();
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <String>[];
    for (final t in raw) {
      if (t is Map) {
        final s = (t['name'] ?? t['label'] ?? t['id'] ?? '').toString();
        if (s.isNotEmpty) out.add(s);
      } else {
        final s = t.toString();
        if (s.isNotEmpty) out.add(s);
      }
    }
    return out;
  }

  /// Backend `hottakes`: list of 0–3 non-empty strings (or map/object forms).
  static List<HotTake> _parseHotTakes(dynamic raw) {
    if (raw == null) return const [];
    final out = <HotTake>[];

    void addTake(String text, {String? label, int? index}) {
      final t = text.trim();
      if (t.isEmpty) return;
      final n = (index ?? out.length) + 1;
      out.add(HotTake(
        label: (label != null && label.trim().isNotEmpty)
            ? label.trim()
            : 'Hot take #$n',
        text: t,
      ));
    }

    if (raw is String && raw.trim().isNotEmpty) {
      addTake(raw, index: 0);
    } else if (raw is Map) {
      // Prefer ordered values if keys look numeric; else each entry.
      final entries = raw.entries.toList();
      var i = 0;
      for (final e in entries) {
        final v = e.value;
        if (v is String) {
          addTake(v, label: 'Hot take #${i + 1}', index: i);
        } else if (v != null && v.toString().trim().isNotEmpty) {
          addTake(v.toString(), label: e.key.toString(), index: i);
        }
        i++;
        if (out.length >= 3) break;
      }
    } else if (raw is List) {
      for (var i = 0; i < raw.length && out.length < 3; i++) {
        final item = raw[i];
        if (item is Map) {
          final text = (item['text'] ??
                  item['answer'] ??
                  item['value'] ??
                  item['content'] ??
                  item['take'] ??
                  '')
              .toString();
          final label = (item['label'] ??
                  item['title'] ??
                  item['prompt'] ??
                  'Hot take #${i + 1}')
              .toString();
          addTake(text, label: label, index: i);
        } else if (item != null) {
          addTake(item.toString(), index: i);
        }
      }
    }

    // Hard cap: backend allows max 3
    if (out.length > 3) return out.sublist(0, 3);
    return out;
  }
}

class FeedResponse {
  const FeedResponse({
    required this.results,
    this.nextCursor,
    this.emptyReason,
    this.profileIncomplete = false,
  });

  final List<FeedProfile> results;
  final int? nextCursor;
  final String? emptyReason;
  final bool profileIncomplete;

  factory FeedResponse.fromJson(Map<String, dynamic> json) {
    final resultsRaw = json['results'] ?? json['data'] ?? [];
    final results = <FeedProfile>[];
    if (resultsRaw is List) {
      for (final item in resultsRaw) {
        final p = FeedProfile.mapFeedItem(item);
        if (p.id.isNotEmpty) results.add(p);
      }
    }
    final next = json['next_cursor'];
    return FeedResponse(
      results: results,
      nextCursor: next == null ? null : int.tryParse(next.toString()),
      emptyReason: json['empty_reason']?.toString(),
      profileIncomplete: json['profile_incomplete'] == true,
    );
  }
}

class CatalogOption {
  const CatalogOption({required this.id, required this.name, this.emoji});
  final String id;
  final String name;
  final String? emoji;

  factory CatalogOption.fromJson(Map<String, dynamic> json) {
    return CatalogOption(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['label'] ?? json['title'] ?? '').toString(),
      emoji: json['emoji']?.toString(),
    );
  }
}

// ── Discovery theme (from GET/PATCH /theme/*) ─────────────────

/// Current user theme selection from API.
class DiscoveryTheme {
  const DiscoveryTheme({
    this.layoutId,
    this.bgId,
    this.bgVariantId,
    this.colorToken,
    this.assignedAt,
  });

  final String? layoutId;
  final String? bgId;
  final String? bgVariantId;
  final String? colorToken;
  final String? assignedAt;

  factory DiscoveryTheme.fromJson(Map<String, dynamic> json) {
    return DiscoveryTheme(
      layoutId: json['layout_id']?.toString(),
      bgId: json['bg_id']?.toString(),
      bgVariantId: json['bg_variant_id']?.toString(),
      colorToken: json['color_token']?.toString(),
      assignedAt: json['assigned_at']?.toString(),
    );
  }

  Map<String, dynamic> toPatch({
    String? layoutId,
    String? bgId,
    String? bgVariantId,
  }) {
    final map = <String, dynamic>{};
    if (layoutId != null) map['layout_id'] = layoutId;
    if (bgId != null) map['bg_id'] = bgId;
    if (bgVariantId != null) map['bg_variant_id'] = bgVariantId;
    return map;
  }
}

class ThemeLayoutOption {
  const ThemeLayoutOption({
    required this.layoutId,
    required this.name,
    this.description,
    this.minAppVersion,
  });

  final String layoutId;
  final String name;
  final String? description;
  final String? minAppVersion;

  factory ThemeLayoutOption.fromJson(Map<String, dynamic> json) {
    return ThemeLayoutOption(
      layoutId: (json['layout_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? json['layout_id'] ?? '').toString(),
      description: json['description']?.toString(),
      minAppVersion: json['min_app_version']?.toString(),
    );
  }
}

class ThemeVariantOption {
  const ThemeVariantOption({
    required this.bgVariantId,
    required this.name,
    this.colorToken,
    this.minAppVersion,
  });

  final String bgVariantId;
  final String name;
  final String? colorToken;
  final String? minAppVersion;

  factory ThemeVariantOption.fromJson(Map<String, dynamic> json) {
    return ThemeVariantOption(
      bgVariantId: (json['bg_variant_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? json['bg_variant_id'] ?? '').toString(),
      colorToken: json['color_token']?.toString(),
      minAppVersion: json['min_app_version']?.toString(),
    );
  }
}

class ThemeBackgroundOption {
  const ThemeBackgroundOption({
    required this.bgId,
    required this.name,
    this.description,
    this.minAppVersion,
    this.variants = const [],
  });

  final String bgId;
  final String name;
  final String? description;
  final String? minAppVersion;
  final List<ThemeVariantOption> variants;

  factory ThemeBackgroundOption.fromJson(Map<String, dynamic> json) {
    final variantsRaw = json['variants'];
    final variants = <ThemeVariantOption>[];
    if (variantsRaw is List) {
      for (final v in variantsRaw) {
        if (v is Map) {
          variants.add(
            ThemeVariantOption.fromJson(Map<String, dynamic>.from(v)),
          );
        }
      }
    }
    return ThemeBackgroundOption(
      bgId: (json['bg_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? json['bg_id'] ?? '').toString(),
      description: json['description']?.toString(),
      minAppVersion: json['min_app_version']?.toString(),
      variants: variants,
    );
  }
}

/// Payload from GET /theme/options/
class ThemeOptions {
  const ThemeOptions({
    this.layouts = const [],
    this.backgrounds = const [],
    this.appVersion,
  });

  final List<ThemeLayoutOption> layouts;
  final List<ThemeBackgroundOption> backgrounds;
  final String? appVersion;

  factory ThemeOptions.fromJson(Map<String, dynamic> json) {
    final layouts = <ThemeLayoutOption>[];
    final layoutsRaw = json['layouts'];
    if (layoutsRaw is List) {
      for (final item in layoutsRaw) {
        if (item is Map) {
          layouts.add(
            ThemeLayoutOption.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final backgrounds = <ThemeBackgroundOption>[];
    final bgRaw = json['backgrounds'];
    if (bgRaw is List) {
      for (final item in bgRaw) {
        if (item is Map) {
          backgrounds.add(
            ThemeBackgroundOption.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return ThemeOptions(
      layouts: layouts,
      backgrounds: backgrounds,
      appVersion: json['app_version']?.toString(),
    );
  }
}

class MatchItem {
  const MatchItem({
    required this.id,
    this.userId,
    this.username,
    this.firstName,
    this.imageUrl,
    this.matchedAt,
    this.conversationId,
    this.isOnline = false,
  });

  final String id;
  final String? userId;
  final String? username;
  final String? firstName;
  final String? imageUrl;
  final DateTime? matchedAt;
  final String? conversationId;
  final bool isOnline;

  String get displayName {
    if (username != null && username!.isNotEmpty) return '@$username';
    if (firstName != null && firstName!.isNotEmpty) return firstName!;
    return 'Match';
  }

  String get shortOrName {
    if (username != null && username!.isNotEmpty) return username!;
    if (firstName != null && firstName!.isNotEmpty) return firstName!;
    return 'M';
  }

  factory MatchItem.fromJson(Map<String, dynamic> json) {
    final other = json['other_user'] ??
        json['matched_user'] ??
        json['profile'] ??
        json['profile_card'] ??
        json['user'] ??
        json;
    final o = other is Map
        ? Map<String, dynamic>.from(other)
        : <String, dynamic>{};
    // Prefer uploaded photos; fall back to admin avatar pool
    final photoStatus = (o['photo_status'] ?? json['photo_status'])?.toString();
    final images = o['images'] ?? json['images'];
    String? imageUrl;
    final hasCustom =
        photoStatus == null || photoStatus.toUpperCase() != 'AVATAR';
    if (hasCustom && images is List && images.isNotEmpty && images.first is Map) {
      imageUrl =
          (images.first['image_url'] ?? images.first['url'])?.toString();
    }
    if (imageUrl == null || imageUrl.isEmpty) {
      final avatar = o['avatar_detail'] ?? o['avatar'] ?? json['avatar_detail'];
      if (avatar is Map) {
        imageUrl =
            (avatar['image'] ?? avatar['image_url'] ?? avatar['url'])?.toString();
      }
    }
    imageUrl ??= (o['image_url'] ??
            o['avatar_url'] ??
            o['photo'] ??
            json['image_url'])
        ?.toString();
    DateTime? matchedAt;
    final rawDate = json['matched_at'] ?? json['created_at'];
    if (rawDate != null) matchedAt = DateTime.tryParse(rawDate.toString());

    return MatchItem(
      id: (json['id'] ?? json['match_id'] ?? '').toString(),
      userId: (o['id'] ?? o['user_id'] ?? json['user_id'])?.toString(),
      username: o['username']?.toString(),
      firstName: o['first_name']?.toString(),
      imageUrl: imageUrl,
      matchedAt: matchedAt,
      conversationId:
          (json['conversation_id'] ?? json['conversation'])?.toString(),
      isOnline: o['is_online'] == true || json['is_online'] == true,
    );
  }
}

class ConversationItem {
  const ConversationItem({
    required this.id,
    this.peerName,
    this.peerUsername,
    this.peerImage,
    this.lastMessage,
    this.updatedAt,
    this.unreadCount = 0,
    this.peerUserId,
    this.isOnline = false,
    this.lastSeen,
  });

  final String id;
  /// Display label for list (prefer @username).
  final String? peerName;
  final String? peerUsername;
  final String? peerImage;
  final String? lastMessage;
  final DateTime? updatedAt;
  final int unreadCount;
  final String? peerUserId;
  final bool isOnline;
  final String? lastSeen;

  /// WhatsApp-style primary line: @username
  String get displayUsername {
    final u = peerUsername?.trim();
    if (u != null && u.isNotEmpty) {
      return u.startsWith('@') ? u : '@$u';
    }
    final n = peerName?.trim();
    if (n != null && n.isNotEmpty && n.toLowerCase() != 'chat') {
      return n.startsWith('@') ? n : '@$n';
    }
    if (peerUserId != null && peerUserId!.isNotEmpty) {
      final short = peerUserId!.length > 8
          ? peerUserId!.substring(0, 8)
          : peerUserId!;
      return '@$short';
    }
    return 'User';
  }

  ConversationItem copyWith({
    String? peerName,
    String? peerUsername,
    String? peerImage,
    String? lastMessage,
    DateTime? updatedAt,
    int? unreadCount,
    String? peerUserId,
    bool? isOnline,
    String? lastSeen,
  }) {
    return ConversationItem(
      id: id,
      peerName: peerName ?? this.peerName,
      peerUsername: peerUsername ?? this.peerUsername,
      peerImage: peerImage ?? this.peerImage,
      lastMessage: lastMessage ?? this.lastMessage,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      peerUserId: peerUserId ?? this.peerUserId,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  /// Backend shape: `{ id, other_user: { id, username, is_online }, last_message, ... }`
  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    // Primary: other_user from ConversationSerializer
    final otherRaw = json['other_user'] ?? json['peer'] ?? json['profile'];
    Map<String, dynamic>? other;
    if (otherRaw is Map) {
      other = Map<String, dynamic>.from(otherRaw);
    }

    String? peerUserId;
    String? peerUsername;
    String? peerName;
    String? peerImage;
    var isOnline = false;
    String? lastSeen;

    if (other != null) {
      peerUserId = (other['id'] ?? other['user_id'])?.toString();
      peerUsername = other['username']?.toString();
      peerName = (other['username'] ??
              other['first_name'] ??
              other['name'] ??
              other['display_name'])
          ?.toString();
      isOnline = other['is_online'] == true;
      lastSeen = other['last_seen']?.toString();

      // Nested profile_card / profile on other_user (if present)
      final nested = other['profile_card'] ?? other['profile'];
      final nestMap = nested is Map
          ? Map<String, dynamic>.from(nested)
          : other;

      peerImage = resolveDisplayImageUrl(
        images: nestMap['images'] is List ? nestMap['images'] as List : null,
        avatarDetail: nestMap['avatar_detail'] is Map
            ? Map<String, dynamic>.from(nestMap['avatar_detail'] as Map)
            : (other['avatar_detail'] is Map
                ? Map<String, dynamic>.from(other['avatar_detail'] as Map)
                : null),
        photoStatus: (nestMap['photo_status'] ?? other['photo_status'])
            ?.toString(),
        avatarUrl: (nestMap['avatar_url'] ?? other['avatar_url'])?.toString(),
        imageUrl: (other['image_url'] ?? other['photo'])?.toString(),
      );

      if (peerUsername == null || peerUsername.isEmpty) {
        peerUsername = nestMap['username']?.toString();
      }
    }

    // Legacy participants[] shape
    final participants = json['participants'];
    if ((peerUserId == null || peerUserId.isEmpty) &&
        participants is List &&
        participants.isNotEmpty) {
      Map? peer;
      for (final p in participants) {
        if (p is Map && p['is_me'] != true) {
          peer = p;
          break;
        }
      }
      peer ??= participants.first is Map ? participants.first as Map : null;
      if (peer != null) {
        peerUserId = (peer['id'] ?? peer['user_id'])?.toString();
        peerUsername ??= peer['username']?.toString();
        peerName ??=
            (peer['username'] ?? peer['first_name'] ?? peer['name'])?.toString();
        peerImage ??= resolveDisplayImageUrl(
          images: peer['images'] is List ? peer['images'] as List : null,
          avatarDetail: peer['avatar_detail'] is Map
              ? Map<String, dynamic>.from(peer['avatar_detail'] as Map)
              : null,
          photoStatus: peer['photo_status']?.toString(),
          imageUrl: peer['image_url']?.toString(),
        );
      }
    }

    peerName ??= json['peer_name']?.toString();
    peerImage ??= json['peer_image']?.toString();

    final last = json['last_message'];
    String? lastText;
    if (last is Map) {
      final content = last['content'];
      if (content is Map) {
        lastText = content['text']?.toString();
      } else {
        lastText = last['text']?.toString() ?? last['content']?.toString();
      }
    } else if (last is String) {
      lastText = last;
    }

    DateTime? updatedAt;
    final raw = json['updated_at'] ?? json['last_message_at'] ?? json['created_at'];
    if (raw != null) updatedAt = DateTime.tryParse(raw.toString());

    return ConversationItem(
      id: (json['id'] ?? '').toString(),
      peerName: peerName,
      peerUsername: peerUsername,
      peerImage: peerImage,
      lastMessage: lastText,
      updatedAt: updatedAt,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      peerUserId: peerUserId,
      isOnline: isOnline,
      lastSeen: lastSeen,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    this.messageType = 'text',
    this.mediaUrl,
    this.createdAt,
    this.isMe = false,
    this.clientMessageId,
    this.isSeen = false,
    this.deliveredAt,
    this.isDeleted = false,
    this.localStatus = ChatSendStatus.sent,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final String messageType;
  /// Presigned / absolute media URL for image/video messages.
  final String? mediaUrl;
  final DateTime? createdAt;
  final bool isMe;
  final String? clientMessageId;
  final bool isSeen;
  final DateTime? deliveredAt;
  final bool isDeleted;
  /// Client-side send pipeline for optimistic UI (sending → sent).
  final ChatSendStatus localStatus;

  bool get isMedia =>
      messageType == 'image' ||
      messageType == 'video' ||
      messageType == 'view_once' ||
      messageType == 'view_once_video' ||
      messageType == 'audio';

  bool get isVideo =>
      messageType == 'video' || messageType == 'view_once_video';

  bool get isImage =>
      messageType == 'image' || messageType == 'view_once';

  /// Tick state for own messages: sending / sent / delivered / read.
  ChatDeliveryStatus get deliveryStatus {
    if (!isMe) return ChatDeliveryStatus.none;
    if (localStatus == ChatSendStatus.sending) {
      return ChatDeliveryStatus.sending;
    }
    if (localStatus == ChatSendStatus.failed) {
      return ChatDeliveryStatus.failed;
    }
    if (isSeen) return ChatDeliveryStatus.read;
    if (deliveredAt != null) return ChatDeliveryStatus.delivered;
    return ChatDeliveryStatus.sent;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? myId}) {
    final content = json['content'];
    String text = '';
    String? mediaUrl;
    if (content is Map) {
      text = (content['text'] ?? '').toString();
      mediaUrl = (content['url'] ?? content['media_url'] ?? content['image_url'])
          ?.toString();
      if (text.isEmpty && mediaUrl != null) {
        final mt = (json['message_type'] ?? 'text').toString().toLowerCase();
        if (mt.contains('video')) {
          text = '🎥 Video';
        } else if (mt.contains('image') || mt.contains('view_once')) {
          text = '📷 Photo';
        } else if (mt == 'audio') {
          text = '🎵 Audio';
        }
      }
    } else if (content is String) {
      text = content;
    } else {
      text = (json['text'] ?? '').toString();
    }
    mediaUrl ??= (json['media_url'] ?? json['url'])?.toString();
    if (mediaUrl != null && mediaUrl.isEmpty) mediaUrl = null;
    mediaUrl = resolveChatMediaUrl(mediaUrl);

    final sender = json['sender'];
    final senderId = (sender is Map
            ? sender['id']
            : json['sender_id'] ?? sender)
        ?.toString() ??
        '';

    DateTime? createdAt;
    final raw = json['created_at'];
    if (raw != null) createdAt = DateTime.tryParse(raw.toString());

    DateTime? deliveredAt;
    final dRaw = json['delivered_at'];
    if (dRaw != null) deliveredAt = DateTime.tryParse(dRaw.toString());

    final isMe = json['is_me'] == true ||
        (myId != null && myId.isNotEmpty && senderId == myId);

    final isDeleted = json['is_deleted'] == true ||
        text == '[Media Deleted]' ||
        text == '[Message Expired]';

    return ChatMessage(
      id: (json['id'] ?? json['client_message_id'] ?? '').toString(),
      conversationId:
          (json['conversation'] ?? json['conversation_id'] ?? '').toString(),
      senderId: senderId,
      text: text,
      messageType: (json['message_type'] ?? 'text').toString().toLowerCase(),
      mediaUrl: mediaUrl,
      createdAt: createdAt,
      isMe: isMe,
      clientMessageId: json['client_message_id']?.toString(),
      isSeen: json['is_seen'] == true,
      deliveredAt: deliveredAt,
      isDeleted: isDeleted,
      localStatus: ChatSendStatus.sent,
    );
  }

  ChatMessage copyWith({
    bool? isMe,
    bool? isSeen,
    DateTime? deliveredAt,
    ChatSendStatus? localStatus,
    String? text,
    String? mediaUrl,
    String? id,
    bool? isDeleted,
    String? messageType,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        conversationId: conversationId,
        senderId: senderId,
        text: text ?? this.text,
        messageType: messageType ?? this.messageType,
        mediaUrl: mediaUrl ?? this.mediaUrl,
        createdAt: createdAt,
        isMe: isMe ?? this.isMe,
        clientMessageId: clientMessageId,
        isSeen: isSeen ?? this.isSeen,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        isDeleted: isDeleted ?? this.isDeleted,
        localStatus: localStatus ?? this.localStatus,
      );
}

enum ChatSendStatus { sending, sent, failed }

enum ChatDeliveryStatus { none, sending, sent, delivered, read, failed }

class SubscriptionStatus {
  const SubscriptionStatus({
    this.hasAccess = true,
    this.requiresSubscription = false,
    this.isTrial = false,
    this.trialDaysRemaining,
    this.price,
    this.currency,
    this.durationDays,
    this.planName,
  });

  final bool hasAccess;
  final bool requiresSubscription;
  final bool isTrial;
  final int? trialDaysRemaining;
  final num? price;
  final String? currency;
  final int? durationDays;
  final String? planName;

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final hasAccess = json['has_access'] == true ||
        json['is_active'] == true ||
        json['subscribed'] == true ||
        (json['status']?.toString().toLowerCase() == 'active') ||
        (json['trial_days_remaining'] != null &&
            (json['trial_days_remaining'] as num) > 0);

    return SubscriptionStatus(
      hasAccess: hasAccess || json['has_access'] != false,
      requiresSubscription: json['requires_subscription'] == true ||
          json['code'] == 'subscription_required',
      isTrial: json['is_trial'] == true ||
          (json['trial_days_remaining'] != null &&
              (json['trial_days_remaining'] as num) > 0),
      trialDaysRemaining: (json['trial_days_remaining'] as num?)?.toInt(),
      price: json['price'] as num?,
      currency: json['currency']?.toString(),
      durationDays: (json['subscription_duration_days'] as num?)?.toInt(),
      planName: json['plan_name']?.toString(),
    );
  }
}

/// Nested original confession shown inside a Tumblr-style plain repost.
class OriginalConfessionMeta {
  const OriginalConfessionMeta({
    required this.id,
    required this.text,
    this.moodTag,
    this.gender,
    this.sexuality,
    this.age,
    this.createdAt,
  });

  final String id;
  final String text;
  final String? moodTag;
  final String? gender;
  final String? sexuality;
  final int? age;
  final DateTime? createdAt;

  String get anonMeta {
    final parts = <String>[
      if (gender != null && gender!.isNotEmpty) gender!,
      if (sexuality != null && sexuality!.isNotEmpty) sexuality!,
      if (age != null) '$age',
    ];
    return parts.isEmpty ? 'Anonymous' : parts.join(' · ');
  }

  factory OriginalConfessionMeta.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    final raw = json['created_at'];
    if (raw != null) createdAt = DateTime.tryParse(raw.toString());
    return OriginalConfessionMeta(
      id: (json['id'] ?? '').toString(),
      text: (json['text'] ?? json['content'] ?? '').toString(),
      moodTag: (json['mood_tag'] ?? json['mood'])?.toString(),
      gender: (json['user_gender'] ??
              (json['gender'] is Map
                  ? json['gender']['name']
                  : json['gender']))
          ?.toString(),
      sexuality: (json['user_sexuality'] ??
              (json['sexuality'] is Map
                  ? json['sexuality']['name']
                  : json['sexuality']))
          ?.toString(),
      age: (json['user_age'] as num?)?.toInt() ??
          (json['age'] as num?)?.toInt(),
      createdAt: createdAt,
    );
  }
}

/// Incoming anonymous note on one of the author's confessions.
class ConfessionNoteRequest {
  const ConfessionNoteRequest({
    required this.id,
    required this.message,
    required this.confessionId,
    required this.confessionText,
    this.gender,
    this.sexuality,
    this.age,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String message;
  final String confessionId;
  final String confessionText;
  final String? gender;
  final String? sexuality;
  final int? age;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  String get anonMeta {
    final parts = <String>[
      if (gender != null && gender!.isNotEmpty) gender!,
      if (sexuality != null && sexuality!.isNotEmpty) sexuality!,
      if (age != null) '$age',
    ];
    return parts.isEmpty ? 'Anonymous' : parts.join(' · ');
  }

  factory ConfessionNoteRequest.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    DateTime? expiresAt;
    final cRaw = json['created_at'];
    final eRaw = json['expires_at'];
    if (cRaw != null) createdAt = DateTime.tryParse(cRaw.toString());
    if (eRaw != null) expiresAt = DateTime.tryParse(eRaw.toString());

    String confessionId = '';
    String confessionText = (json['confession_text'] ?? '').toString();
    final conf = json['confession'];
    if (conf is Map) {
      confessionId = (conf['id'] ?? '').toString();
      final t = conf['text']?.toString();
      if (t != null && t.isNotEmpty) confessionText = t;
    } else {
      confessionId =
          (json['confession_id'] ?? json['confession'] ?? '').toString();
    }

    String? gender;
    String? sexuality;
    int? age;
    final meta = json['sender_meta'] ?? json['sender'];
    if (meta is Map) {
      gender = (meta['gender'] is Map
              ? meta['gender']['name']
              : meta['gender'] ?? meta['user_gender'])
          ?.toString();
      sexuality = (meta['sexuality'] is Map
              ? meta['sexuality']['name']
              : meta['sexuality'] ?? meta['user_sexuality'])
          ?.toString();
      age = (meta['age'] as num?)?.toInt() ??
          (meta['user_age'] as num?)?.toInt();
    }

    return ConfessionNoteRequest(
      id: (json['id'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      confessionId: confessionId,
      confessionText: confessionText,
      gender: gender,
      sexuality: sexuality,
      age: age,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }
}

class ConfessionPost {
  const ConfessionPost({
    required this.id,
    required this.text,
    this.moodTag,
    this.relateCount = 0,
    this.commentCount = 0,
    this.repostCount = 0,
    this.createdAt,
    this.hasRelated = false,
    this.distanceKm,
    this.gender,
    this.sexuality,
    this.age,
    this.hasRequestedChat = false,
    this.isAuthor = false,
    this.isRepost = false,
    this.parentId,
    this.original,
    this.hasReposted = false,
  });

  final String id;
  final String text;
  final String? moodTag;
  final int relateCount;
  final int commentCount;
  final int repostCount;
  final DateTime? createdAt;
  final bool hasRelated;
  final double? distanceKm;
  final String? gender;
  final String? sexuality;
  final int? age;
  final bool hasRequestedChat;
  /// True when current user wrote this confession (from API `is_author`).
  final bool isAuthor;
  /// Tumblr-style plain repost of another confession.
  final bool isRepost;
  final String? parentId;
  final OriginalConfessionMeta? original;
  /// Viewer already reposted this root original.
  final bool hasReposted;

  String get anonMeta {
    final parts = <String>[
      if (gender != null && gender!.isNotEmpty) gender!,
      if (sexuality != null && sexuality!.isNotEmpty) sexuality!,
      if (age != null) '$age',
    ];
    return parts.isEmpty ? 'Anonymous' : parts.join(' · ');
  }

  /// Body text preferred for display (nested original when present).
  String get displayText =>
      (isRepost && original != null && original!.text.isNotEmpty)
          ? original!.text
          : text;

  factory ConfessionPost.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    final raw = json['created_at'];
    if (raw != null) createdAt = DateTime.tryParse(raw.toString());

    final author = json['author_meta'] ?? json['anonymous_meta'] ?? json['user_meta'];
    String? gender;
    String? sexuality;
    int? age;
    if (author is Map) {
      gender = (author['gender'] is Map
              ? author['gender']['name']
              : author['gender'])
          ?.toString();
      sexuality = (author['sexuality'] is Map
              ? author['sexuality']['name']
              : author['sexuality'])
          ?.toString();
      age = (author['age'] as num?)?.toInt();
    } else {
      gender = (json['user_gender'] ??
              (json['gender'] is Map
                  ? json['gender']['name']
                  : json['gender']))
          ?.toString();
      sexuality = (json['user_sexuality'] ??
              (json['sexuality'] is Map
                  ? json['sexuality']['name']
                  : json['sexuality']))
          ?.toString();
      age = (json['user_age'] as num?)?.toInt() ??
          (json['age'] as num?)?.toInt();
    }

    OriginalConfessionMeta? original;
    final origRaw = json['original'];
    if (origRaw is Map) {
      original = OriginalConfessionMeta.fromJson(
        Map<String, dynamic>.from(origRaw),
      );
    }

    final parentId = json['parent_id']?.toString();
    final isRepost = json['is_repost'] == true ||
        (parentId != null && parentId.isNotEmpty && parentId != 'null');

    return ConfessionPost(
      id: (json['id'] ?? '').toString(),
      text: (json['text'] ?? json['content'] ?? '').toString(),
      moodTag: (json['mood_tag'] ?? json['mood'])?.toString(),
      relateCount: (json['relate_count'] as num?)?.toInt() ??
          (json['relates'] as num?)?.toInt() ??
          0,
      commentCount: (json['comment_count'] as num?)?.toInt() ??
          (json['whispers_count'] as num?)?.toInt() ??
          0,
      repostCount: (json['repost_count'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
      hasRelated: json['has_related'] == true || json['related'] == true,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      gender: gender,
      sexuality: sexuality,
      age: age,
      hasRequestedChat: json['has_requested_chat'] == true,
      isAuthor: json['is_author'] == true || json['is_mine'] == true,
      isRepost: isRepost,
      parentId: parentId,
      original: original,
      hasReposted: json['has_reposted'] == true,
    );
  }

  ConfessionPost copyWith({
    int? relateCount,
    int? repostCount,
    bool? hasRelated,
    bool? hasRequestedChat,
    bool? isAuthor,
    bool? isRepost,
    String? parentId,
    OriginalConfessionMeta? original,
    bool? hasReposted,
  }) {
    return ConfessionPost(
      id: id,
      text: text,
      moodTag: moodTag,
      relateCount: relateCount ?? this.relateCount,
      commentCount: commentCount,
      repostCount: repostCount ?? this.repostCount,
      createdAt: createdAt,
      hasRelated: hasRelated ?? this.hasRelated,
      distanceKm: distanceKm,
      gender: gender,
      sexuality: sexuality,
      age: age,
      hasRequestedChat: hasRequestedChat ?? this.hasRequestedChat,
      isAuthor: isAuthor ?? this.isAuthor,
      isRepost: isRepost ?? this.isRepost,
      parentId: parentId ?? this.parentId,
      original: original ?? this.original,
      hasReposted: hasReposted ?? this.hasReposted,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    this.username,
    this.name,
    this.firstName,
    this.bio,
    this.age,
    this.dateOfBirth,
    this.city,
    this.state,
    this.country,
    this.latitude,
    this.longitude,
    this.genderId,
    this.genderLabel,
    this.sexualityId,
    this.sexualityLabel,
    this.intentId,
    this.intentLabel,
    this.preferredGenderIds = const [],
    this.turnOnIds = const [],
    this.turnOnLabels = const [],
    this.languageIds = const [],
    this.languageLabels = const [],
    this.hottakes,
    this.agePreferenceMin,
    this.agePreferenceMax,
    this.distancePreferenceKm,
    this.discoveryRadiusType,
    this.isPaused = false,
    this.isHidden = false,
    this.hideAge = false,
    this.hideOnlineStatus = false,
    this.hideDistance = false,
    this.isDiscoverable = false,
    this.images = const [],
    this.layoutId,
    this.bgId,
    this.bgVariantId,
    this.canSeeIncomingLikes = false,
    this.avatarUrl,
    this.photoStatus,
    this.raw = const {},
  });

  final String id;
  final String? username;
  final String? name;
  final String? firstName;
  final String? bio;
  final int? age;
  final String? dateOfBirth;
  final String? city;
  final String? state;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? genderId;
  final String? genderLabel;
  final String? sexualityId;
  final String? sexualityLabel;
  final String? intentId;
  final String? intentLabel;
  final List<String> preferredGenderIds;
  final List<String> turnOnIds;
  final List<String> turnOnLabels;
  final List<String> languageIds;
  final List<String> languageLabels;
  final dynamic hottakes;
  final int? agePreferenceMin;
  final int? agePreferenceMax;
  /// null / 0 = Anywhere (worldwide). 1–1000 = max radius in km.
  final int? distancePreferenceKm;
  /// GLOBAL | DISTANCE | CITY | STATE | COUNTRY — default GLOBAL (Anywhere).
  final String? discoveryRadiusType;
  final bool isPaused;
  final bool isHidden;
  final bool hideAge;
  final bool hideOnlineStatus;
  final bool hideDistance;
  final bool isDiscoverable;
  final List<ProfileImage> images;
  final String? layoutId;
  final String? bgId;
  final String? bgVariantId;
  final bool canSeeIncomingLikes;
  final String? avatarUrl;
  final String? photoStatus;
  final Map<String, dynamic> raw;

  String get displayName =>
      username ?? name ?? firstName ?? 'you';

  String get locationSummary {
    final parts = <String>[
      if (city != null && city!.isNotEmpty) city!,
      if (state != null && state!.isNotEmpty) state!,
      if (country != null && country!.isNotEmpty) country!,
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    if (latitude != null && longitude != null) {
      return '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}';
    }
    return '—';
  }

  /// True when user has uploaded photos. First ordered image is the main/profile pic.
  bool get hasUserPhotos {
    return images.any((i) => i.imageUrl.isNotEmpty);
  }

  /// Profile discovery: no radius cap (worldwide). Default when unset.
  bool get isDiscoveryAnywhere {
    final rad = (discoveryRadiusType ?? 'GLOBAL').toUpperCase();
    if (rad == 'GLOBAL') return true;
    final d = distancePreferenceKm;
    return d == null || d <= 0;
  }

  /// Effective max km for feed (null = unlimited Anywhere).
  int? get effectiveDistanceKm {
    if (isDiscoveryAnywhere) return null;
    final d = distancePreferenceKm;
    if (d == null || d <= 0) return null;
    return d.clamp(1, 1000);
  }

  /// UI label for profile / filters.
  String get discoveryDistanceLabel {
    if (isDiscoveryAnywhere) return 'Anywhere · Worldwide';
    final d = effectiveDistanceKm;
    if (d == null) return 'Anywhere · Worldwide';
    if (d >= 1000) return 'Up to 1000 km';
    return 'Up to $d km';
  }

  /// Profile / list display: first photo (main) else admin pool avatar.
  String? get displayImageUrl {
    if (hasUserPhotos) {
      final u = images.first.imageUrl.trim();
      if (u.isNotEmpty) return u;
    }
    if (avatarUrl != null && avatarUrl!.isNotEmpty) return avatarUrl;
    for (final img in images) {
      final u = img.imageUrl.trim();
      if (u.isNotEmpty) return u;
    }
    return null;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final images = <ProfileImage>[];
    final rawImgs = json['images'];
    if (rawImgs is List) {
      for (final i in rawImgs) {
        if (i is Map) {
          final map = Map<String, dynamic>.from(i);
          // Skip soft-deleted when API includes inactive rows
          if (map['is_active'] == false) continue;
          final img = ProfileImage.fromJson(map);
          if (img.id.isNotEmpty || img.imageUrl.isNotEmpty) {
            images.add(img);
          }
        }
      }
      images.sort((a, b) => a.order.compareTo(b.order));
    }

    final themeMap = json['theme'] is Map
        ? Map<String, dynamic>.from(json['theme'] as Map)
        : <String, dynamic>{};

    List<String> stringListForProfile(dynamic raw) {
      if (raw is! List) return const [];
      final out = <String>[];
      for (final t in raw) {
        if (t is Map) {
          final s = (t['name'] ?? t['label'] ?? t['id'] ?? '').toString();
          if (s.isNotEmpty) out.add(s);
        } else {
          final s = t.toString();
          if (s.isNotEmpty) out.add(s);
        }
      }
      return out;
    }

    String? idOf(dynamic v) {
      if (v == null) return null;
      if (v is Map) return (v['id'] ?? '').toString();
      return v.toString();
    }

    String? labelOf(dynamic v) {
      if (v == null) return null;
      if (v is Map) return (v['name'] ?? v['label'])?.toString();
      return v.toString();
    }

    List<String> idList(dynamic v) {
      if (v is! List) return const [];
      return v
          .map((e) => e is Map ? (e['id'] ?? '').toString() : e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    List<String> labelList(dynamic v) {
      if (v is! List) return const [];
      return v
          .map((e) => e is Map
              ? (e['name'] ?? e['label'] ?? '').toString()
              : e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return UserProfile(
      id: (json['id'] ?? json['user_id'] ?? '').toString(),
      username: json['username']?.toString(),
      name: json['name']?.toString(),
      firstName: json['first_name']?.toString(),
      bio: json['bio']?.toString(),
      age: _parseInt(json['age']),
      dateOfBirth: json['date_of_birth']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      country: json['country']?.toString(),
      // API may return lat/lon as string → never cast as num
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      genderId: idOf(json['gender']),
      genderLabel: labelOf(json['gender_detail'] ?? json['gender']),
      sexualityId: idOf(json['sexuality']),
      sexualityLabel: labelOf(json['sexuality_detail'] ?? json['sexuality']),
      intentId: idOf(json['intent']),
      intentLabel: labelOf(json['intent_detail'] ?? json['intent']),
      preferredGenderIds: idList(
        json['preferred_genders'] ?? json['preferred_genders_detail'],
      ),
      turnOnIds: idList(json['turn_ons'] ?? json['turn_ons_detail']),
      turnOnLabels: labelList(json['turn_ons_detail'] ?? json['turn_ons']),
      languageIds: idList(json['languages'] ?? json['languages_detail']),
      // Prefer display names when available; UUIDs resolved after catalog load
      languageLabels: () {
        final raw = json['languages_detail'] ?? json['languages'] ?? const [];
        final resolved = LanguageLabels.resolveAll(raw);
        if (resolved.isNotEmpty) return resolved;
        // Fallback: keep raw tokens so UI can re-resolve after catalog loads
        return stringListForProfile(raw);
      }(),
      hottakes: json['hottakes'],
      agePreferenceMin: (json['age_preference_min'] as num?)?.toInt(),
      agePreferenceMax: (json['age_preference_max'] as num?)?.toInt(),
      distancePreferenceKm: (json['distance_preference_km'] as num?)?.toInt(),
      discoveryRadiusType: json['discovery_radius_type']?.toString(),
      isPaused: json['is_paused'] == true,
      isHidden: json['is_hidden'] == true,
      hideAge: json['hide_age'] == true,
      hideOnlineStatus: json['hide_online_status'] == true,
      hideDistance: json['hide_distance'] == true,
      isDiscoverable: json['is_discoverable'] == true,
      images: images,
      layoutId: (json['layout_id'] ?? themeMap['layout_id'])?.toString(),
      bgId: (json['bg_id'] ?? themeMap['bg_id'])?.toString(),
      bgVariantId:
          (json['bg_variant_id'] ?? themeMap['bg_variant_id'])?.toString(),
      canSeeIncomingLikes: json['can_see_incoming_likes'] == true ||
          json['can_view_likes'] == true,
      avatarUrl: () {
        final ad = json['avatar_detail'] ?? json['avatar'];
        if (ad is Map) {
          return (ad['image'] ?? ad['image_url'] ?? ad['url'])?.toString();
        }
        return json['avatar_url']?.toString();
      }(),
      photoStatus: json['photo_status']?.toString(),
      raw: Map<String, dynamic>.from(json),
    );
  }

  UserProfile copyWith({
    String? layoutId,
    String? bgId,
    String? bgVariantId,
    List<String>? languageIds,
    List<String>? languageLabels,
    List<ProfileImage>? images,
    String? photoStatus,
    String? avatarUrl,
    String? city,
    String? state,
    String? country,
    double? latitude,
    double? longitude,
    bool clearLayoutId = false,
    bool clearBgId = false,
    bool clearBgVariantId = false,
  }) {
    return UserProfile(
      id: id,
      username: username,
      name: name,
      firstName: firstName,
      bio: bio,
      age: age,
      dateOfBirth: dateOfBirth,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      genderId: genderId,
      genderLabel: genderLabel,
      sexualityId: sexualityId,
      sexualityLabel: sexualityLabel,
      intentId: intentId,
      intentLabel: intentLabel,
      preferredGenderIds: preferredGenderIds,
      turnOnIds: turnOnIds,
      turnOnLabels: turnOnLabels,
      languageIds: languageIds ?? this.languageIds,
      languageLabels: languageLabels ?? this.languageLabels,
      hottakes: hottakes,
      agePreferenceMin: agePreferenceMin,
      agePreferenceMax: agePreferenceMax,
      distancePreferenceKm: distancePreferenceKm,
      discoveryRadiusType: discoveryRadiusType,
      isPaused: isPaused,
      isHidden: isHidden,
      hideAge: hideAge,
      hideOnlineStatus: hideOnlineStatus,
      hideDistance: hideDistance,
      isDiscoverable: isDiscoverable,
      images: images ?? this.images,
      layoutId: clearLayoutId ? null : (layoutId ?? this.layoutId),
      bgId: clearBgId ? null : (bgId ?? this.bgId),
      bgVariantId:
          clearBgVariantId ? null : (bgVariantId ?? this.bgVariantId),
      canSeeIncomingLikes: canSeeIncomingLikes,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      photoStatus: photoStatus ?? this.photoStatus,
      raw: raw,
    );
  }
}

/// Shared display image resolver for any profile-like map from the API.
/// First ordered uploaded image wins (main profile photo); else admin avatar.
String? resolveDisplayImageUrl({
  List<dynamic>? images,
  Map<String, dynamic>? avatarDetail,
  String? avatarUrl,
  String? photoStatus,
  String? imageUrl,
}) {
  // Prefer real uploads even if photo_status is stale AVATAR
  if (images != null) {
    for (final item in images) {
      if (item is Map) {
        final u = (item['image_url'] ?? item['url'] ?? item['image'])?.toString();
        if (u != null && u.isNotEmpty) return u;
      }
    }
  }
  if (avatarDetail != null) {
    final u = (avatarDetail['image'] ??
            avatarDetail['image_url'] ??
            avatarDetail['url'])
        ?.toString();
    if (u != null && u.isNotEmpty) return u;
  }
  if (avatarUrl != null && avatarUrl.isNotEmpty) return avatarUrl;
  if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
  return null;
}

class IncomingLike {
  const IncomingLike({
    required this.id,
    this.username,
    this.imageUrl,
    this.age,
    this.blurred = true,
  });

  final String id;
  final String? username;
  final String? imageUrl;
  final int? age;
  final bool blurred;

  factory IncomingLike.fromJson(Map<String, dynamic> json) {
    final imageUrl = resolveDisplayImageUrl(
      images: json['images'] is List ? json['images'] as List : null,
      avatarDetail: json['avatar_detail'] is Map
          ? Map<String, dynamic>.from(json['avatar_detail'] as Map)
          : null,
      photoStatus: json['photo_status']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      imageUrl: json['image_url']?.toString(),
    );
    return IncomingLike(
      id: (json['id'] ?? json['user_id'] ?? '').toString(),
      username: json['username']?.toString(),
      imageUrl: imageUrl,
      age: (json['age'] as num?)?.toInt(),
      blurred: json['blurred'] == true || json['is_blurred'] == true,
    );
  }
}
