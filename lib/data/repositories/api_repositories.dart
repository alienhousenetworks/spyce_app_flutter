import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../models/user_models.dart';

// ── Providers ────────────────────────────────────────────────

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final sessionExpiredProvider = StateProvider<bool>((ref) => false);

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return ApiClient(
    tokenStorage: storage,
    onSessionExpired: () {
      ref.read(sessionExpiredProvider.notifier).state = true;
    },
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider));
});

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref.watch(apiClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return MatchRepository(ref.watch(apiClientProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(apiClientProvider));
});

final optionsRepositoryProvider = Provider<OptionsRepository>((ref) {
  return OptionsRepository(ref.watch(apiClientProvider));
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.watch(apiClientProvider));
});

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository(ref.watch(apiClientProvider));
});

final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepository(ref.watch(apiClientProvider));
});

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return ModerationRepository(ref.watch(apiClientProvider));
});

// ── Auth ─────────────────────────────────────────────────────

class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final TokenStorage _storage;

  Future<Map<String, dynamic>> requestOtp(
    String email, {
    String? intent,
    String? captchaToken,
  }) async {
    final deviceId = await _storage.getOrCreateDeviceId();
    final token = captchaToken?.trim();
    final data = await _api.post<dynamic>(
      '/auth/register/',
      data: {
        'email': email,
        'device_id': deviceId,
        if (intent != null) 'intent': intent,
        if (token != null && token.isNotEmpty) 'captcha_token': token,
      },
    );
    return _asMap(data);
  }

  Future<({bool ok, Map<String, dynamic> data})> verifyOtp(
    String email,
    String otp,
  ) async {
    final deviceId = await _storage.getOrCreateDeviceId();
    try {
      final data = await _api.post<dynamic>(
        '/auth/otp/verify/',
        data: {'email': email, 'otp': otp, 'device_id': deviceId},
      );
      final map = _asMap(data);
      final access = map['access']?.toString();
      final refresh = map['refresh']?.toString();
      if (access != null && refresh != null) {
        await _storage.saveTokens(access: access, refresh: refresh);
      }
      return (ok: access != null, data: map);
    } catch (e) {
      rethrow;
    }
  }

  Future<({bool ok, Map<String, dynamic> data})> firebaseLogin(
    String idToken, {
    String? intent,
  }) async {
    final deviceId = await _storage.getOrCreateDeviceId();
    try {
      final data = await _api.post<dynamic>(
        '/auth/firebase-login/',
        data: {
          'id_token': idToken,
          'device_id': deviceId,
          if (intent != null) 'intent': intent,
        },
      );
      final map = _asMap(data);
      final access = map['access']?.toString();
      final refresh = map['refresh']?.toString();
      if (access != null && refresh != null) {
        await _storage.saveTokens(access: access, refresh: refresh);
      }
      return (ok: access != null, data: map);
    } catch (e) {
      rethrow;
    }
  }

  Future<({bool ok, Map<String, dynamic> data})> registerWithPassword(
    String email,
    String password, {
    String? captchaToken,
  }) async {
    final deviceId = await _storage.getOrCreateDeviceId();
    final token = captchaToken?.trim();
    try {
      final data = await _api.post<dynamic>(
        '/auth/password/register/',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
          'device_id': deviceId,
          if (token != null && token.isNotEmpty) 'captcha_token': token,
        },
      );
      final map = _asMap(data);
      final access = map['access']?.toString();
      final refresh = map['refresh']?.toString();
      if (access != null && refresh != null) {
        await _storage.saveTokens(access: access, refresh: refresh);
      }
      return (ok: access != null, data: map);
    } catch (e) {
      rethrow;
    }
  }

  Future<({bool ok, Map<String, dynamic> data})> loginWithPassword(
    String email,
    String password, {
    String? captchaToken,
  }) async {
    final deviceId = await _storage.getOrCreateDeviceId();
    final token = captchaToken?.trim();
    try {
      final data = await _api.post<dynamic>(
        '/auth/password/login/',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
          'device_id': deviceId,
          if (token != null && token.isNotEmpty) 'captcha_token': token,
        },
      );
      final map = _asMap(data);
      final access = map['access']?.toString();
      final refresh = map['refresh']?.toString();
      if (access != null && refresh != null) {
        await _storage.saveTokens(access: access, refresh: refresh);
      }
      return (ok: access != null, data: map);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset(
    String email, {
    String? captchaToken,
  }) async {
    final deviceId = await _storage.getOrCreateDeviceId();
    final token = captchaToken?.trim();
    final data = await _api.post<dynamic>(
      '/auth/password/reset-request/',
      data: {
        'email': email.trim().toLowerCase(),
        'device_id': deviceId,
        if (token != null && token.isNotEmpty) 'captcha_token': token,
      },
    );
    return _asMap(data);
  }

  Future<({bool ok, Map<String, dynamic> data})> confirmPasswordReset(
    String email,
    String otp,
    String newPassword,
  ) async {
    final deviceId = await _storage.getOrCreateDeviceId();
    try {
      final data = await _api.post<dynamic>(
        '/auth/password/reset-confirm/',
        data: {
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
          'new_password': newPassword,
          'device_id': deviceId,
        },
      );
      final map = _asMap(data);
      final access = map['access']?.toString();
      final refresh = map['refresh']?.toString();
      if (access != null && refresh != null) {
        await _storage.saveTokens(access: access, refresh: refresh);
      }
      return (ok: access != null, data: map);
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> registerPushToken(String fcmToken, {String deviceType = 'ANDROID'}) async {
    try {
      await _api.post<dynamic>(
        '/notifications/devices/',
        data: {
          'fcm_token': fcmToken.trim(),
          'device_type': deviceType,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> resendOtp(
    String email, {
    String? intent,
    String? captchaToken,
  }) async {
    final deviceId = await _storage.getOrCreateDeviceId();
    final token = captchaToken?.trim();
    final data = await _api.post<dynamic>(
      '/auth/otp/resend/',
      data: {
        'email': email,
        'device_id': deviceId,
        if (intent != null) 'intent': intent,
        if (token != null && token.isNotEmpty) 'captcha_token': token,
      },
    );
    return _asMap(data);
  }

  Future<void> logout() async {
    final refresh = await _storage.getRefreshToken();
    try {
      if (refresh != null) {
        await _api.post('/auth/logout/', data: {'refresh': refresh});
      }
    } catch (_) {
      /* still clear local */
    }
    await _storage.clearTokens();
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      await _api.delete('/users/delete-account/');
      await _storage.clearTokens();
      return {'status': 'deleted'};
    } catch (e) {
      await _storage.clearTokens();
      rethrow;
    }
  }

  Future<AuthUser?> getMe() async {
    final token = await _storage.getAccessToken();
    if (token == null) return null;
    try {
      final data = await _api.get<dynamic>('/users/me/');
      final map = _asMap(data);
      if (map['id'] == null) return null;
      return AuthUser.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<AuthSession?> getSession() async {
    try {
      final data = await _api.get<dynamic>('/auth/session/');
      return AuthSession.fromJson(_asMap(data));
    } catch (_) {
      return null;
    }
  }

  Future<String?> getWsTicket() async {
    final data = await _api.post<dynamic>('/auth/ws-ticket/');
    return _asMap(data)['ticket']?.toString();
  }

  Future<void> heartbeat({double? lat, double? lon}) async {
    final body = <String, dynamic>{};
    if (lat != null) body['lat'] = lat;
    if (lon != null) body['lon'] = lon;
    await _api.post('/users/last-active/', data: body);
  }

  Future<Map<String, dynamic>> acceptUgcEula() async {
    final data = await _api.post<dynamic>('/users/accept-ugc-eula/');
    return _asMap(data);
  }
}

// ── Feed ─────────────────────────────────────────────────────

class FeedRepository {
  FeedRepository(this._api);
  final ApiClient _api;

  Future<FeedResponse> getFeed({
    int count = 20,
    int cursor = 0,
    bool refresh = false,
    Map<String, dynamic>? filters,
  }) async {
    final query = <String, dynamic>{
      'count': count,
      'cursor': cursor,
      if (refresh) 'refresh': true,
    };
    final f = filters ?? {};
    if (f['min_age'] != null && f['min_age'] != 18) {
      query['min_age'] = f['min_age'];
    }
    if (f['max_age'] != null && f['max_age'] != 100) {
      query['max_age'] = f['max_age'];
    }
    if (f['intent'] != null && '${f['intent']}'.isNotEmpty) {
      query['intent'] = f['intent'];
    }
    if (f['currently_online'] == true) query['currently_online'] = true;
    // When client relaxes filters for "more variety" / out-of-taste continue
    if (f['include_liked'] == true) query['include_liked'] = true;

    final locationMode = f['location_mode']?.toString() ?? 'distance';
    final city = (f['city'] ?? '').toString().trim();
    final state = (f['state'] ?? '').toString().trim();
    final country = (f['country'] ?? '').toString().trim();
    final usesRegion = locationMode == 'region' ||
        ((city.isNotEmpty || state.isNotEmpty || country.isNotEmpty) &&
            locationMode != 'distance');

    if (usesRegion) {
      query['location_mode'] = 'region';
      if (city.isNotEmpty) query['city'] = city;
      if (state.isNotEmpty) query['state'] = state;
      if (country.isNotEmpty) query['country'] = country;
      // GeoNames center from autocomplete — enables nearby users when city empty
      final clat = f['city_lat'] ?? f['lat'];
      final clon = f['city_lon'] ?? f['lon'] ?? f['lng'];
      if (clat != null && clat.toString().isNotEmpty) {
        query['city_lat'] = clat;
      }
      if (clon != null && clon.toString().isNotEmpty) {
        query['city_lon'] = clon;
      }
    } else {
      final dist = f['distance'];
      if (dist != null && dist != 0 && dist != '0' && dist != '') {
        query['location_mode'] = 'distance';
        query['distance'] = dist;
      }
    }

    final genders = f['gender'];
    if (genders is List && genders.isNotEmpty) {
      query['gender'] = genders;
    }

    // Discover feed is FastAPI-only (GET /api/v2/feed).
    final data = await _api.get<dynamic>(Env.feedUrl, query: query);
    return FeedResponse.fromJson(_asMap(data));
  }

  Future<Map<String, dynamic>> like(String targetUserId) async {
    final data = await _api.post<dynamic>(
      '/interaction/send/',
      data: {'target_user_id': targetUserId},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> pass(String targetUserId) async {
    final data = await _api.post<dynamic>(
      '/interaction/pass/',
      data: {'target_user_id': targetUserId},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> startConversation(
    String targetUserId,
    String message,
  ) async {
    final data = await _api.post<dynamic>(
      '/interaction/start_conversation/',
      data: {'target_user_id': targetUserId, 'message': message},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getReceivedLikes() async {
    final data = await _api.get<dynamic>('/interaction/received/');
    return _asMap(data);
  }

  Future<List<IncomingLike>> getIncomingLikesList() async {
    final r = await getIncomingLikes();
    return r.users;
  }

  /// Chat → Likes: only gender+sexuality combos with permission see data.
  Future<IncomingLikesResult> getIncomingLikes() async {
    final data = await _api.get<dynamic>('/interaction/received/');
    final map = _asMap(data);

    final bool canSee;
    if (map.containsKey('can_see_incoming_likes')) {
      canSee = map['can_see_incoming_likes'] == true;
    } else {
      // Older API: deny only on explicit permission error
      final err = map['error']?.toString().toLowerCase() ?? '';
      canSee = !err.contains('not permitted');
    }
    if (!canSee) {
      return const IncomingLikesResult(canSee: false);
    }

    final list = map['users'] ?? map['results'] ?? map['likes'];
    final users = list is List
        ? list
            .whereType<Map>()
            .map((e) => IncomingLike.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <IncomingLike>[];
    final count = (map['count'] as num?)?.toInt() ?? users.length;
    // Admin matrix path: full profiles + like-back (premium no longer required).
    final canViewFull = map['can_view_full_profiles'] == true ||
        (users.isNotEmpty && users.any((u) => !u.blurred));
    final canLikeBack = map['can_like_back'] == true || canViewFull;
    return IncomingLikesResult(
      canSee: true,
      count: count,
      isPremium: map['is_premium'] == true,
      canViewFullProfiles: canViewFull,
      canLikeBack: canLikeBack,
      users: users,
    );
  }
}

// ── Profile ──────────────────────────────────────────────────

class ProfileRepository {
  ProfileRepository(this._api);
  final ApiClient _api;

  Future<UserProfile> getMyProfile() async {
    final data = await _api.get<dynamic>('/profile/me/');
    return UserProfile.fromJson(_asMap(data));
  }

  /// Public profile for another user (images + avatar_detail pool).
  Future<UserProfile> getProfile(String userId) async {
    final data = await _api.get<dynamic>('/profile/$userId/');
    return UserProfile.fromJson(_asMap(data));
  }

  Future<UserProfile> updateMyProfile(Map<String, dynamic> fields) async {
    final data = await _api.patch<dynamic>('/profile/me/', data: fields);
    return UserProfile.fromJson(_asMap(data));
  }

  Future<bool> isUsernameAvailable(String username) async {
    final data = await _api.get<dynamic>(
      '/profile/username-available/',
      query: {'username': username},
    );
    final map = _asMap(data);
    return map['available'] == true;
  }

  /// GET /theme/options/ — layouts + backgrounds + variants from backend registry.
  Future<ThemeOptions> getThemeOptions() async {
    final data = await _api.get<dynamic>('/theme/options/');
    return ThemeOptions.fromJson(_asMap(data));
  }

  /// GET /theme/me/ — current user selection (`{ theme: { layout_id, bg_id, ... } }`).
  Future<DiscoveryTheme> getMyTheme() async {
    final data = await _api.get<dynamic>('/theme/me/');
    final map = _asMap(data);
    final theme = map['theme'];
    if (theme is Map) {
      return DiscoveryTheme.fromJson(Map<String, dynamic>.from(theme));
    }
    return DiscoveryTheme.fromJson(map);
  }

  /// PATCH /theme/me/ with `layout_id` / `bg_id` / `bg_variant_id` (API codes).
  Future<DiscoveryTheme> updateTheme(Map<String, dynamic> payload) async {
    final data = await _api.patch<dynamic>('/theme/me/', data: payload);
    final map = _asMap(data);
    final theme = map['theme'];
    if (theme is Map) {
      return DiscoveryTheme.fromJson(Map<String, dynamic>.from(theme));
    }
    return DiscoveryTheme.fromJson(map);
  }

  Future<List<CatalogOption>> getMoodOptions() async {
    final data = await _api.getPublic('/mood_options/');
    return _listOptions(data);
  }

  Future<void> setMoods(List<String> moodIds) async {
    await _api.post('/mood/', data: {'mood_ids': moodIds});
  }

  /// POST /images/upload/ multipart field `image`.
  /// Prefer sync 201 `{status: ok, id, image_url}`; async 202 returns `job_id`.
  Future<Map<String, dynamic>> uploadImage(String filePath) async {
    final name = filePath.split(RegExp(r'[/\\]')).last;
    final lower = name.toLowerCase();
    final contentType = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
            ? 'image/webp'
            : lower.endsWith('.heic') || lower.endsWith('.heif')
                ? 'image/heic'
                : 'image/jpeg';
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        filePath,
        filename: name.isEmpty ? 'photo.jpg' : name,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    final data = await _api.postMultipart('/images/upload/', formData: form);
    return _asMap(data);
  }

  /// GET /images/upload-status/?job_id= — poll async photo processing.
  Future<Map<String, dynamic>> getImageUploadStatus(String jobId) async {
    final data = await _api.get<dynamic>(
      '/images/upload-status/',
      query: {'job_id': jobId},
    );
    return _asMap(data);
  }

  /// DELETE /images/{id}/
  Future<void> deleteImage(String imageId) async {
    await _api.delete('/images/$imageId/');
  }

  /// PATCH /images/reorder/ body: `{ images: [{ id, order }, ...] }`
  Future<void> reorderImages(List<Map<String, dynamic>> images) async {
    await _api.patch('/images/reorder/', data: {'images': images});
  }

  /// GET `/geo/reverse/?lat=&lng=` → city/state/country from device coords.
  Future<Map<String, dynamic>> reverseGeocode(double lat, double lng) async {
    final data = await _api.get<dynamic>(
      '/geo/reverse/',
      query: {'lat': lat, 'lng': lng},
    );
    return _asMap(data);
  }

  /// GET `/geo/autocomplete/?q=` — city/state/country suggestions for Discover.
  /// Same package as web: profile cities + India seed list on the backend.
  Future<List<CitySuggestion>> autocompleteCity(
    String query, {
    int limit = 12,
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final data = await _api.get<dynamic>(
      '/geo/autocomplete/',
      query: {
        'q': q,
        'limit': limit.clamp(1, 25),
      },
    );
    return _extractList(data)
        .whereType<Map>()
        .map((e) => CitySuggestion.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.city.isNotEmpty)
        .toList();
  }
}

// ── Matches ──────────────────────────────────────────────────

class MatchRepository {
  MatchRepository(this._api);
  final ApiClient _api;

  Future<List<MatchItem>> getMatches() async {
    final data = await _api.get<dynamic>('/matches/');
    final list = _extractList(data);
    return list
        .whereType<Map>()
        .map((e) => MatchItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

// ── Chat ─────────────────────────────────────────────────────

class ChatRepository {
  ChatRepository(this._api);
  final ApiClient _api;

  Future<List<ConversationItem>> getConversations() async {
    final data = await _api.get<dynamic>('/conversations/');
    final list = _extractList(data);
    return list
        .whereType<Map>()
        .map((e) => ConversationItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    String? myId,
  }) async {
    final data = await _api.get<dynamic>(
      '/messages/',
      query: {'conversation_id': conversationId},
    );
    final list = _extractList(data);
    return list
        .whereType<Map>()
        .map(
          (e) => ChatMessage.fromJson(
            Map<String, dynamic>.from(e),
            myId: myId,
          ),
        )
        .toList();
  }

  Future<ChatMessage> sendMessage(
    String conversationId,
    String text, {
    String? myId,
  }) async {
    final data = await _api.post<dynamic>(
      '/messages/',
      data: {
        'conversation': conversationId,
        'content': {'text': text},
        'message_type': 'text',
      },
    );
    return ChatMessage.fromJson(_asMap(data), myId: myId);
  }

  /// POST multipart `/conversations/{id}/upload_media/` with `media` + `message_type`.
  /// Server processes async (202); UI should poll messages after a short delay.
  Future<Map<String, dynamic>> uploadMedia(
    String conversationId,
    String filePath, {
    required String messageType,
  }) async {
    final name = filePath.split(RegExp(r'[/\\]')).last;
    final lower = name.toLowerCase();
    final contentType = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
            ? 'image/webp'
            : lower.endsWith('.gif')
                ? 'image/gif'
                : lower.endsWith('.heic') || lower.endsWith('.heif')
                    ? 'image/heic'
                    : lower.endsWith('.mp4')
                        ? 'video/mp4'
                        : lower.endsWith('.mov')
                            ? 'video/quicktime'
                            : lower.endsWith('.webm')
                                ? 'video/webm'
                                : messageType.contains('video')
                                    ? 'video/mp4'
                                    : 'image/jpeg';
    final form = FormData.fromMap({
      'media': await MultipartFile.fromFile(
        filePath,
        filename: name.isEmpty
            ? (messageType.contains('video') ? 'video.mp4' : 'photo.jpg')
            : name,
        contentType: DioMediaType.parse(contentType),
      ),
      'message_type': messageType,
    });
    final data = await _api.postMultipart(
      '/conversations/$conversationId/upload_media/',
      formData: form,
    );
    return _asMap(data);
  }

  Future<void> markSeen(String messageId) async {
    await _api.post('/messages/$messageId/seen/');
  }

  Future<void> leaveConversation(String id) async {
    await _api.post('/conversations/$id/leave/');
  }
}

// ── Options ──────────────────────────────────────────────────

class OptionsRepository {
  OptionsRepository(this._api);
  final ApiClient _api;

  final Map<String, List<CatalogOption>> _cache = {};

  Future<List<CatalogOption>> _cached(String path, String key) async {
    if (_cache.containsKey(key)) return _cache[key]!;
    try {
      final data = await _api.getPublic(path);
      final list = _listOptions(data);
      _cache[key] = list;
      return list;
    } catch (_) {
      try {
        final data = await _api.get<dynamic>(path);
        final list = _listOptions(data);
        _cache[key] = list;
        return list;
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<CatalogOption>> genders() =>
      _cached('/genders/', 'genders');
  Future<List<CatalogOption>> sexualities() =>
      _cached('/sexualities/', 'sexualities');
  Future<List<CatalogOption>> intents() => _cached('/intents/', 'intents');
  Future<List<CatalogOption>> turnOns() => _cached('/turn_ons/', 'turn_ons');
  Future<List<CatalogOption>> languages() =>
      _cached('/languages/', 'languages');
  Future<List<CatalogOption>> moods() =>
      _cached('/mood_options/', 'moods');
}

// ── Subscription ─────────────────────────────────────────────

class SubscriptionRepository {
  SubscriptionRepository(this._api);
  final ApiClient _api;

  Future<SubscriptionStatus> getStatus() async {
    final data = await _api.get<dynamic>('/subscription/me/');
    return SubscriptionStatus.fromJson(_asMap(data));
  }

  Future<UserEntitlements> getEntitlements() async {
    final data = await _api.get<dynamic>('/subscriptions/entitlements/');
    return UserEntitlements.fromJson(_asMap(data));
  }

  Future<Map<String, dynamic>> getRequiredPlan() async {
    final data = await _api.get<dynamic>('/subscriptions/required-plan/');
    return _asMap(data);
  }

  Future<List<SubscriptionTierPlan>> getAvailablePlans() async {
    final data = await _api.get<dynamic>('/subscriptions/required-plan/');
    final map = _asMap(data);
    final list = map['available_plans'] as List<dynamic>? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(SubscriptionTierPlan.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> purchase(String idempotencyKey) async {
    final data = await _api.post<dynamic>(
      '/subscription/purchase/',
      data: {'idempotency_key': idempotencyKey},
    );
    return _asMap(data);
  }

  /// Restore purchases (Play Billing / StoreKit receipt validation).
  /// Production: send store token + platform; placeholders OK until store setup.
  Future<Map<String, dynamic>> restorePurchases({
    required String platform,
    String? purchaseToken,
    String? receiptData,
    String? productId,
  }) async {
    final data = await _api.post<dynamic>(
      '/subscriptions/restore/',
      data: {
        'platform': platform,
        if (purchaseToken != null) 'purchase_token': purchaseToken,
        if (receiptData != null) 'receipt_data': receiptData,
        if (productId != null) 'product_id': productId,
      },
    );
    return _asMap(data);
  }
}

// ── Social / Confessions ─────────────────────────────────────

class SocialRepository {
  SocialRepository(this._api);
  final ApiClient _api;

  Future<List<ConfessionPost>> getFeed({
    required double lat,
    required double lon,
  }) async {
    final data = await _api.get<dynamic>(
      '/social/feed/',
      query: {'lat': lat, 'lon': lon},
    );
    final list = _extractList(data);
    return list
        .whereType<Map>()
        .map((e) => ConfessionPost.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ConfessionPost> post({
    required String text,
    String? moodTag,
    String? stylePreset,
    String? bgTheme,
    double? lat,
    double? lon,
    bool acceptUgcEula = false,
  }) async {
    final data = await _api.post<dynamic>(
      '/social/',
      data: {
        'text': text,
        if (moodTag != null) 'mood_tag': moodTag,
        if (stylePreset != null) 'style_preset': stylePreset,
        if (bgTheme != null) 'bg_theme': bgTheme,
        'language': 'en',
        if (lat != null) 'latitude': lat,
        if (lon != null) 'longitude': lon,
        if (acceptUgcEula) 'accept_ugc_eula': true,
      },
    );
    return ConfessionPost.fromJson(_asMap(data));
  }

  Future<Map<String, dynamic>> acceptUgcEula() async {
    final data = await _api.post<dynamic>('/users/accept-ugc-eula/');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> relate(String id) async {
    final data = await _api.post<dynamic>('/social/$id/relate/');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> chatRequest(String id, String message) async {
    final data = await _api.post<dynamic>(
      '/social/$id/chat-request/',
      data: {'message': message},
    );
    return _asMap(data);
  }

  /// Tumblr-style plain repost (no note/thought).
  Future<Map<String, dynamic>> repost(String id) async {
    final data = await _api.post<dynamic>(
      '/social/$id/repost/',
      data: {'type': 'REPOST'},
    );
    return _asMap(data);
  }

  /// Report a confession: `POST /social/{id}/report/`
  /// [reason] is SPAM | HARASSMENT | FAKE_PROFILE | UNDERAGE_CSE | OTHER
  Future<Map<String, dynamic>> reportConfession(
    String id, {
    required String reason,
    String? description,
  }) async {
    final data = await _api.post<dynamic>(
      '/social/$id/report/',
      data: {
        'reason': reason,
        'description': description ?? '',
      },
    );
    return _asMap(data);
  }

  /// Incoming notes on my confessions (anonymous senders).
  Future<List<ConfessionNoteRequest>> listConfessionRequests() async {
    final data = await _api.get<dynamic>('/confession-requests/');
    return _extractList(data)
        .whereType<Map>()
        .map((e) => ConfessionNoteRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<int> countConfessionRequests() async {
    try {
      final data = await _api.get<dynamic>('/confession-requests/count/');
      final map = _asMap(data);
      return (map['count'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, dynamic>> acceptConfessionRequest(String id) async {
    final data =
        await _api.post<dynamic>('/confession-requests/$id/accept/');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> rejectConfessionRequest(String id) async {
    final data =
        await _api.post<dynamic>('/confession-requests/$id/reject/');
    return _asMap(data);
  }
}

// ── Calls (ICE / P2P intelligence) ───────────────────────────

class IceConfig {
  IceConfig({
    required this.iceServers,
    this.iceTransportPolicy = 'all',
    this.iceCandidatePoolSize = 8,
    this.p2pFirst = true,
    this.delayedTurnMs = 3500,
    this.userP2pScore = 50,
    this.preferIpv6 = false,
  });

  final List<Map<String, dynamic>> iceServers;
  final String iceTransportPolicy;
  final int iceCandidatePoolSize;
  final bool p2pFirst;
  final int delayedTurnMs;
  final double userP2pScore;
  final bool preferIpv6;

  factory IceConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['iceServers'] ?? json['ice_servers'] ?? [];
    final servers = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final s in raw) {
        if (s is Map) {
          servers.add(Map<String, dynamic>.from(s));
        }
      }
    }
    return IceConfig(
      iceServers: servers,
      iceTransportPolicy:
          (json['iceTransportPolicy'] ?? json['ice_transport_policy'] ?? 'all')
              .toString(),
      iceCandidatePoolSize:
          (json['iceCandidatePoolSize'] as num?)?.toInt() ?? 8,
      p2pFirst: json['p2p_first'] != false,
      delayedTurnMs: (json['delayed_turn_ms'] as num?)?.toInt() ?? 3500,
      userP2pScore: (json['user_p2p_score'] as num?)?.toDouble() ?? 50,
      preferIpv6: json['prefer_ipv6'] == true || json['ipv6_available'] == true,
    );
  }
}

class CallRepository {
  CallRepository(this._api);
  final ApiClient _api;

  /// Hybrid P2P strategy:
  /// - stunOnly=true → STUN only (host/srflx first) for max P2P ratio
  /// - stunOnly=false → full STUN+TURN (CoTURN credentials)
  Future<IceConfig> getIceServers({
    bool forceTurn = false,
    bool stunOnly = false,
  }) async {
    final data = await _api.get<dynamic>(
      '/call/ice-servers/',
      query: {
        'force_turn': forceTurn ? 'true' : 'false',
        'stun_only': stunOnly ? 'true' : 'false',
      },
    );
    return IceConfig.fromJson(_asMap(data));
  }

  Future<Map<String, dynamic>> submitNetworkProfile(
    Map<String, dynamic> body,
  ) async {
    final data = await _api.post<dynamic>('/call/network-profile/', data: body);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> connectionPrediction(String calleeId) async {
    final data = await _api.get<dynamic>(
      '/call/connection-prediction/',
      query: {'callee_id': calleeId},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> submitIceState(Map<String, dynamic> body) async {
    final data = await _api.post<dynamic>('/call/ice-state/', data: body);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> submitMetrics(Map<String, dynamic> body) async {
    final data = await _api.post<dynamic>('/call/metrics/', data: body);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getQuota() async {
    final data = await _api.get<dynamic>('/call/quota/');
    return _asMap(data);
  }
}

// ── Moderation ───────────────────────────────────────────────

class ModerationRepository {
  ModerationRepository(this._api);
  final ApiClient _api;

  Future<void> blockUser(String userId) async {
    await _api.post(
      '/moderation/moderation/block/',
      data: {'user_id': userId},
    );
  }

  Future<void> reportUser({
    required String reportedUserId,
    required String reason,
    String? description,
    String targetType = 'USER_PROFILE',
    String? targetId,
  }) async {
    await _api.post(
      '/moderation/moderation/report/',
      data: {
        'reported_user_id': reportedUserId,
        'reason': reason,
        'description': description ?? '',
        'target_type': targetType,
        'target_id': targetId ?? reportedUserId,
      },
    );
  }

  Future<void> reportAndBlock({
    required String reportedUserId,
    required String reason,
    String? description,
  }) async {
    await _api.post(
      '/moderation/moderation/report_and_block/',
      data: {
        'reported_user_id': reportedUserId,
        'reason': reason,
        'description': description ?? '',
        'target_type': 'USER_PROFILE',
        'target_id': reportedUserId,
      },
    );
  }
}

// ── Verification (face / identity) ───────────────────────────

/// Config + status from GET /verification/status/
class FaceVerificationConfig {
  const FaceVerificationConfig({
    required this.verified,
    required this.faceVerification,
    required this.mockMode,
    required this.provider,
    required this.region,
    required this.retryLeft,
    this.status,
    this.livenessThreshold,
    this.cognitoRegion,
    this.cognitoIdentityPoolId,
    this.cognitoUserPoolId,
    this.cognitoAppClientId,
    this.cognitoConfigured = false,
    this.raw = const {},
  });

  final bool verified;
  /// True → real AWS Rekognition Face Liveness
  final bool faceVerification;
  /// True → POST /mock-complete/ is allowed
  final bool mockMode;
  final String provider;
  final String region;
  final int retryLeft;
  final String? status;
  final double? livenessThreshold;
  final String? cognitoRegion;
  final String? cognitoIdentityPoolId;
  final String? cognitoUserPoolId;
  final String? cognitoAppClientId;
  final bool cognitoConfigured;
  final Map<String, dynamic> raw;

  bool get useRealAws => faceVerification && !mockMode;

  factory FaceVerificationConfig.fromJson(Map<String, dynamic> json) {
    return FaceVerificationConfig(
      verified: json['verified'] == true || json['is_identity_verified'] == true,
      faceVerification: json['face_verification'] == true,
      mockMode: json['mock_mode'] != false && json['face_verification'] != true,
      provider: (json['provider'] ?? 'mock').toString(),
      region: (json['region'] ?? 'us-east-1').toString(),
      retryLeft: (json['retry_left'] is num)
          ? (json['retry_left'] as num).toInt()
          : 3,
      status: json['status']?.toString(),
      livenessThreshold: json['liveness_threshold'] is num
          ? (json['liveness_threshold'] as num).toDouble()
          : null,
      cognitoRegion: json['cognito_region']?.toString(),
      cognitoIdentityPoolId: json['cognito_identity_pool_id']?.toString(),
      cognitoUserPoolId: json['cognito_user_pool_id']?.toString(),
      cognitoAppClientId: json['cognito_app_client_id']?.toString(),
      cognitoConfigured: json['cognito_configured'] == true,
      raw: Map<String, dynamic>.from(json),
    );
  }
}

class VerificationRepository {
  VerificationRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> getStatus() async {
    final data = await _api.get<dynamic>('/verification/status/');
    return _asMap(data);
  }

  Future<FaceVerificationConfig> getConfig() async {
    final data = await getStatus();
    return FaceVerificationConfig.fromJson(data);
  }

  /// Real mode: CreateFaceLivenessSession via backend.
  Future<Map<String, dynamic>> startSession() async {
    final data = await _api.post<dynamic>('/verification/start/');
    return _asMap(data);
  }

  /// Real mode: after Amplify detector finishes, backend fetches AWS results.
  Future<Map<String, dynamic>> completeSession(String sessionId) async {
    final data = await _api.post<dynamic>(
      '/verification/complete/',
      data: {'session_id': sessionId},
    );
    return _asMap(data);
  }

  /// Dev / staging mock — only when FACE_VERIFICATION=False on server.
  Future<Map<String, dynamic>> mockComplete() async {
    final data = await _api.post<dynamic>('/verification/mock-complete/');
    return _asMap(data);
  }
}

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  return VerificationRepository(ref.watch(apiClientProvider));
});

// ── helpers ──────────────────────────────────────────────────

Map<String, dynamic> _asMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) {
    return data.map((k, v) => MapEntry(k.toString(), v));
  }
  return {};
}

List<dynamic> _extractList(dynamic data) {
  if (data is List) return data;
  if (data is Map) {
    final map = _asMap(data);
    final results = map['results'] ?? map['data'] ?? map['items'];
    if (results is List) return results;
  }
  return const [];
}

List<CatalogOption> _listOptions(dynamic data) {
  return _extractList(data)
      .whereType<Map>()
      .map((e) => CatalogOption.fromJson(Map<String, dynamic>.from(e)))
      .where((o) => o.id.isNotEmpty)
      .toList();
}
