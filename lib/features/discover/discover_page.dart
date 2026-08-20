import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/spyce_colors.dart';
import '../../core/utils/language_labels.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/api_repositories.dart';
import '../../shared/widgets/spyce_widgets.dart';
import '../auth/auth_controller.dart';
import '../premium/subscription_paywall.dart';
import 'widgets/feed_profile_card.dart';

class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  final _pageCtrl = PageController();
  final _liked = <String>{};

  List<FeedProfile> profiles = [];
  bool loading = true;
  bool loadingMore = false;
  int? nextCursor;
  bool hasMore = true;
  String? error;
  String? toast;
  String? locationBanner;
  bool showPaywall = false;
  SubscriptionStatus? paywallStatus;
  UserProfile? _myProfile;
  bool _isProfileIncomplete = false;
  String? _profileIncompleteMessage;
  List<String> _missingFields = [];
  /// True after we auto-relaxed filters to keep showing people.
  bool _varietyMode = false;
  bool _enteringVariety = false;
  /// One thin interstitial page (2 playful lines) before variety profiles.
  bool _showVarietyBridge = false;
  /// PageView index where the bridge sits (profiles after it are offset by 1).
  int _bridgePageIndex = 0;

  /// distance 0 = Anywhere (worldwide). 1–1000 = radius km. Default Anywhere.
  Map<String, dynamic> filters = {
    'min_age': 18,
    'max_age': 100,
    'distance': 0,
    'location_mode': 'distance',
    'currently_online': false,
  };

  @override
  void initState() {
    super.initState();
    // Ensure viewer username is available for media watermarks
    // (/users/me has no username — must load from profile).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final name = ref.read(viewerUsernameProvider);
      if (name == null || name.isEmpty) {
        ref.read(authControllerProvider.notifier).refreshViewerIdentity();
      }
      _seedFiltersFromProfile();
    });
    _load(0);
  }

  /// Seed age prefs from profile only.
  /// Distance always stays **Anywhere** (0) by default on feed — user can
  /// switch to Near me / city in filters; we do not apply profile radius here.
  Future<void> _seedFiltersFromProfile() async {
    try {
      final p = await ref.read(profileRepositoryProvider).getMyProfile();
      if (!mounted) return;
      _myProfile = p;
      final minAge = p.agePreferenceMin ?? 18;
      final maxAge = p.agePreferenceMax ?? 100;
      setState(() {
        filters = {
          ...filters,
          'min_age': minAge,
          'max_age': maxAge,
          // Always Anywhere on first open / reset
          'distance': 0,
          'location_mode': 'distance',
        };
        // Clear any city region so distance mode is Anywhere worldwide
        filters.remove('city');
        filters.remove('state');
        filters.remove('country');
        filters.remove('city_lat');
        filters.remove('city_lon');
      });
      if (minAge != 18 || maxAge != 100) {
        await _load(0);
      }
    } catch (_) {
      // Keep default Anywhere
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureLanguageCatalog() async {
    if (LanguageLabels.hasCatalog) return;
    try {
      final opts = await ref.read(optionsRepositoryProvider).languages();
      if (opts.isNotEmpty) LanguageLabels.setCatalog(opts);
    } catch (_) {
      // Feed still works; unresolved UUIDs are hidden by LanguageLabels
    }
  }

  List<FeedProfile> _withResolvedLanguages(List<FeedProfile> list) {
    return list
        .map(
          (p) => p.copyWith(
            languages: LanguageLabels.resolveAll(p.languages),
          ),
        )
        .toList();
  }

  /// Widen discovery so the feed does not stop — only informs the user.
  /// Keep the user's age slider bounds (do not force 18–100).
  void _applyRelaxedFilters() {
    filters = {
      ...filters,
      'distance': 0,
      'location_mode': 'distance',
      'currently_online': false,
      'include_liked': true,
      // Age range stays whatever the user set in filters
    };
    filters.remove('city');
    filters.remove('state');
    filters.remove('country');
    filters.remove('city_lat');
    filters.remove('city_lon');
  }

  /// Enter variety mode once: short 2-line bridge page, then more profiles.
  Future<void> _enterVarietyAndContinue({bool keepProfiles = true}) async {
    if (_varietyMode || _enteringVariety) return;
    _enteringVariety = true;
    final keep = keepProfiles && profiles.isNotEmpty;
    setState(() {
      _varietyMode = true;
      _showVarietyBridge = true;
      // Bridge sits right after current last profile (or at 0 if starting fresh)
      _bridgePageIndex = keep ? profiles.length : 0;
      _applyRelaxedFilters();
    });
    try {
      await _load(0, append: keep);
    } finally {
      _enteringVariety = false;
    }
  }

  int get _pageCount {
    final n = profiles.length;
    if (!_showVarietyBridge) return n;
    // Bridge is an extra page; still show it even if variety load is empty
    return n + 1;
  }

  /// Map PageView index → profile index (null = bridge page).
  int? _profileIndexForPage(int pageIndex) {
    if (!_showVarietyBridge) return pageIndex;
    if (pageIndex == _bridgePageIndex) return null;
    if (pageIndex < _bridgePageIndex) return pageIndex;
    return pageIndex - 1;
  }

  Future<void> _load(int cursor, {bool append = false, bool refresh = false}) async {
    if (cursor == 0 && !append) {
      setState(() {
        loading = true;
        error = null;
      });
    } else {
      setState(() => loadingMore = true);
    }

    try {
      if (!LanguageLabels.hasCatalog) {
        _ensureLanguageCatalog();
      }

      final res = await ref.read(feedRepositoryProvider).getFeed(
            cursor: cursor,
            refresh: refresh || (cursor == 0 && !append),
            filters: filters,
          );
      if (!mounted) return;

      if (res.profileIncomplete) {
        if (_myProfile == null) {
          try {
            _myProfile = await ref.read(profileRepositoryProvider).getMyProfile();
          } catch (_) {}
        }
        setState(() {
          _isProfileIncomplete = true;
          _profileIncompleteMessage = res.message;
          _missingFields = res.missingFields;
          loading = false;
          loadingMore = false;
          profiles = [];
        });
        return;
      } else {
        _isProfileIncomplete = false;
        _missingFields = [];
      }

      final resolved = _withResolvedLanguages(res.results);
      setState(() {
        showPaywall = false;
        if (!append) {
          _liked.clear();
          profiles = resolved;
        } else {
          // Dedupe when appending; keep already-liked cards in the stack
          final existing = profiles.map((p) => p.id).toSet();
          profiles = [
            ...profiles,
            ...resolved.where((p) => !existing.contains(p.id)),
          ];
        }
        // Seed liked set from API so already-liked stays visible until TTL
        for (final p in resolved) {
          if (p.isLiked) {
            _liked.add(p.id);
            final key = p.userId ?? p.id;
            if (key.isNotEmpty) _liked.add(key);
          }
        }
        nextCursor = res.nextCursor;
        hasMore = res.nextCursor != null;
        loading = false;
        loadingMore = false;
        locationBanner = res.locationMessage;
        if (profiles.isEmpty && res.emptyReason != null) {
          error = res.emptyReason;
        } else if (profiles.isEmpty) {
          error = null;
        } else {
          error = null;
        }
      });

      // Empty under current filters → relax once and keep the feed going
      if (profiles.isEmpty && !_varietyMode && !_enteringVariety) {
        await _enterVarietyAndContinue(keepProfiles: false);
        return;
      }
      // Page exhausted → relax once, append more people (don't stop)
      if (!hasMore &&
          profiles.isNotEmpty &&
          !_varietyMode &&
          !_enteringVariety) {
        await _enterVarietyAndContinue(keepProfiles: true);
        return;
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isSubscriptionRequired || e.isForbidden) {
        setState(() {
          showPaywall = true;
          paywallStatus = SubscriptionStatus(
            hasAccess: false,
            requiresSubscription: true,
            price: e.data?['price'] as num?,
            currency: e.data?['currency']?.toString(),
            durationDays:
                (e.data?['subscription_duration_days'] as num?)?.toInt(),
          );
          loading = false;
          loadingMore = false;
        });
      } else {
        setState(() {
          error = e.message;
          loading = false;
          loadingMore = false;
          if (!append) profiles = [];
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!append) {
          profiles = [];
          error = 'Could not load profiles. Pull to refresh.';
        }
        loading = false;
        loadingMore = false;
        hasMore = false;
      });
    }
  }

  bool _isLiked(FeedProfile p) {
    if (p.isLiked) return true;
    if (_liked.contains(p.id)) return true;
    final uid = p.userId;
    if (uid != null && uid.isNotEmpty && _liked.contains(uid)) return true;
    return false;
  }

  Future<void> _message(FeedProfile p) async {
    if (!p.canDirectMessage) {
      _showToast('Messaging not available for this profile');
      return;
    }
    final uid = p.userId ?? p.id;
    if (uid.isEmpty) return;

    final ctrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: SpyceColors.dark800,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Message ${p.shortName}',
                style: GoogleFonts.syne(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Direct message (your gender + sexuality can reach theirs). They must accept to chat.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                maxLines: 4,
                maxLength: 500,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Say hi (min 3 characters)…',
                ),
              ),
              const SizedBox(height: 12),
              SpycePrimaryButton(
                label: 'Send message',
                icon: Icons.chat_bubble_outline,
                onPressed: () {
                  if (ctrl.text.trim().length < 3) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Write at least 3 characters'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
              ),
            ],
          ),
        );
      },
    );
    if (ok != true || !mounted) {
      ctrl.dispose();
      return;
    }
    final text = ctrl.text.trim();
    ctrl.dispose();
    try {
      final res = await ref
          .read(feedRepositoryProvider)
          .startConversation(uid, text);
      if (!mounted) return;
      if (res['error'] != null) {
        _showToast(res['error']?.toString() ?? 'Could not send');
        return;
      }
      _showToast('Message sent to ${p.shortName}');
    } on ApiException catch (e) {
      if (mounted) _showToast(e.message);
    } catch (_) {
      if (mounted) _showToast('Could not send message');
    }
  }

  Future<void> _like(FeedProfile p) async {
    // Already liked within TTL — keep card, show status, do not remove
    if (_isLiked(p)) {
      _showToast('Already liked ${p.shortName}');
      return;
    }

    final id = p.id;
    final uid = p.userId ?? p.id;
    setState(() {
      _liked.add(id);
      if (uid.isNotEmpty) _liked.add(uid);
      // Keep profile in feed; mark as liked so UI shows "Already liked"
      final i = profiles.indexWhere((x) => x.id == id || x.userId == uid);
      if (i >= 0) {
        profiles = [
          ...profiles.sublist(0, i),
          profiles[i].copyWith(isLiked: true),
          ...profiles.sublist(i + 1),
        ];
      }
    });

    try {
      final res = await ref.read(feedRepositoryProvider).like(uid);
      final status = res['status']?.toString() ?? '';
      if (status == 'match') {
        _showToast("It's a match! 💖");
      } else if (status == 'cooldown' || status == 'already_liked') {
        // Still keep as liked until TTL expires — do not remove from feed
        _showToast(
          res['message']?.toString() ?? 'Already liked ${p.shortName}',
        );
      } else {
        _showToast('Liked ${p.shortName}');
      }
    } on ApiException catch (e) {
      if (e.isSubscriptionRequired) {
        // Revert optimistic like only for paywall
        setState(() {
          _liked.remove(id);
          _liked.remove(uid);
        });
        setState(() => showPaywall = true);
      } else {
        final msg = e.message.toLowerCase();
        if (msg.contains('already') || msg.contains('cooldown')) {
          // Keep liked state — profile stays in feed
          _showToast(e.message);
        } else {
          setState(() {
            _liked.remove(id);
            _liked.remove(uid);
          });
          _showToast(e.message);
        }
      }
    } catch (_) {
      setState(() {
        _liked.remove(id);
        _liked.remove(uid);
      });
      _showToast('Could not like. Try again.');
    }
  }

  void _showToast(String msg) {
    setState(() => toast = msg);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && toast == msg) setState(() => toast = null);
    });
  }

  Future<void> _purchase() async {
    try {
      await ref.read(subscriptionRepositoryProvider).purchase(const Uuid().v4());
      setState(() => showPaywall = false);
      await _load(0);
    } on ApiException catch (e) {
      _showToast(e.message);
    }
  }

  void _openFilters() async {
    List<CatalogOption> intentOptions = [];
    try {
      intentOptions = await ref.read(optionsRepositoryProvider).intents();
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: SpyceColors.dark800,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        var minAge = (filters['min_age'] as num?)?.toDouble() ?? 18;
        var maxAge = (filters['max_age'] as num?)?.toDouble() ?? 100;
        // 0 = Anywhere; 1–1000 = radius. Default Anywhere.
        var distance = (filters['distance'] as num?)?.toDouble() ?? 0;
        var anywhere = distance <= 0;
        if (!anywhere && distance < 1) distance = 50;
        if (!anywhere) distance = distance.clamp(1.0, 1000.0);
        var online = filters['currently_online'] == true;
        var selectedCity = filters['city']?.toString() ?? '';
        var selectedState = filters['state']?.toString() ?? '';
        var selectedCountry = filters['country']?.toString() ?? '';
        double? selectedCityLat = (filters['city_lat'] as num?)?.toDouble();
        double? selectedCityLon = (filters['city_lon'] as num?)?.toDouble();
        var selectedIntent = filters['intent']?.toString() ?? '';
        var citySuggestions = <CitySuggestion>[];
        var cityLoading = false;
        var showCitySuggest = false;
        Timer? cityDebounce;
        var cityRequestId = 0;

        final cityCtrl = TextEditingController(
          text: selectedCity.isEmpty
              ? ''
              : [
                  selectedCity,
                  if (selectedState.isNotEmpty) selectedState,
                  if (selectedCountry.isNotEmpty) selectedCountry,
                ].join(', '),
        );

        Future<void> runCitySearch(String raw, void Function(void Function()) setModal) async {
          final q = raw.trim();
          // If user is editing free text, strip display "City, State, Country" to first segment for API
          final queryForApi = q.contains(',') ? q.split(',').first.trim() : q;
          if (queryForApi.length < 2) {
            setModal(() {
              citySuggestions = [];
              cityLoading = false;
              showCitySuggest = false;
            });
            return;
          }
          final req = ++cityRequestId;
          setModal(() => cityLoading = true);
          try {
            final list = await ref
                .read(profileRepositoryProvider)
                .autocompleteCity(queryForApi);
            if (req != cityRequestId) return;
            setModal(() {
              citySuggestions = list;
              cityLoading = false;
              showCitySuggest = list.isNotEmpty;
            });
          } catch (_) {
            if (req != cityRequestId) return;
            setModal(() {
              citySuggestions = [];
              cityLoading = false;
              showCitySuggest = false;
            });
          }
        }

        void onCityTyped(String v, void Function(void Function()) setModal) {
          // Free-type: store first token as city until user picks a suggestion
          final trimmed = v.trim();
          final freeCity =
              trimmed.contains(',') ? trimmed.split(',').first.trim() : trimmed;
          setModal(() {
            selectedCity = freeCity;
            // Clear structured region / coords until a suggestion is picked
            selectedState = '';
            selectedCountry = '';
            selectedCityLat = null;
            selectedCityLon = null;
          });
          cityDebounce?.cancel();
          if (freeCity.length < 2) {
            setModal(() {
              citySuggestions = [];
              showCitySuggest = false;
              cityLoading = false;
            });
            return;
          }
          cityDebounce = Timer(const Duration(milliseconds: 280), () {
            runCitySearch(v, setModal);
          });
        }

        void pickCity(CitySuggestion s, void Function(void Function()) setModal) {
          cityDebounce?.cancel();
          cityCtrl.text = s.label;
          setModal(() {
            selectedCity = s.city;
            selectedState = s.state ?? '';
            selectedCountry = s.country ?? '';
            selectedCityLat = s.lat;
            selectedCityLon = s.lon;
            citySuggestions = [];
            showCitySuggest = false;
            cityLoading = false;
            // Region search is mutually exclusive with distance radius
            anywhere = true;
            distance = 0;
          });
        }

        return StatefulBuilder(
          builder: (context, setModal) {
            final double screenMaxDist = 1000.0;
            final String distLabel = anywhere
                ? 'Distance: Anywhere · Worldwide'
                : (distance >= screenMaxDist
                    ? 'Distance: Up to 1000 km'
                    : 'Distance: Up to ${distance.round()} km');

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Discovery Filters',
                        style: GoogleFonts.syne(
                            fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 16),
                    Text('Age Range: ${minAge.round()} – ${maxAge.round()} yrs',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    RangeSlider(
                      values: RangeValues(minAge, maxAge),
                      min: 18,
                      max: 80,
                      activeColor: SpyceColors.pink,
                      onChanged: (v) => setModal(() {
                        minAge = v.start;
                        maxAge = v.end;
                      }),
                    ),
                    const SizedBox(height: 10),
                    Text(distLabel, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Anywhere'),
                          avatar: Icon(
                            Icons.public,
                            size: 16,
                            color: anywhere ? Colors.white : Colors.white70,
                          ),
                          selected: anywhere,
                          selectedColor: SpyceColors.pink,
                          labelStyle: TextStyle(
                            color: anywhere ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => setModal(() {
                            anywhere = true;
                            distance = 0;
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('Near me'),
                          avatar: Icon(
                            Icons.near_me_outlined,
                            size: 16,
                            color: !anywhere ? Colors.white : Colors.white70,
                          ),
                          selected: !anywhere,
                          selectedColor: SpyceColors.pink,
                          labelStyle: TextStyle(
                            color: !anywhere ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => setModal(() {
                            anywhere = false;
                            if (distance < 1) distance = 50;
                            // Distance mode clears city region filter
                            selectedCity = '';
                            selectedState = '';
                            selectedCountry = '';
                            selectedCityLat = null;
                            selectedCityLon = null;
                            cityCtrl.clear();
                            citySuggestions = [];
                            showCitySuggest = false;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      anywhere
                          ? 'No distance limit — show people worldwide (default).'
                          : 'Only people within 1–1000 km of you.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                    if (!anywhere) ...[
                      const SizedBox(height: 8),
                      Slider(
                        value: distance.clamp(1.0, screenMaxDist),
                        min: 1,
                        max: screenMaxDist,
                        divisions: 999,
                        activeColor: SpyceColors.pink,
                        label: '${distance.round()} km',
                        onChanged: (v) => setModal(() {
                          anywhere = false;
                          distance = v;
                        }),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1 km',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11)),
                          Text('1000 km',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text('Filter by City',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'Type a city — pick from suggestions (city, state, country)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: cityCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search city…',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        filled: true,
                        fillColor: Colors.black26,
                        prefixIcon: const Icon(Icons.location_city, color: SpyceColors.pinkSoft),
                        suffixIcon: cityLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: SpyceColors.pinkSoft,
                                  ),
                                ),
                              )
                            : (cityCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.white54),
                                    onPressed: () {
                                      cityDebounce?.cancel();
                                      cityCtrl.clear();
                                      setModal(() {
                                        selectedCity = '';
                                        selectedState = '';
                                        selectedCountry = '';
                                        selectedCityLat = null;
                                        selectedCityLon = null;
                                        citySuggestions = [];
                                        showCitySuggest = false;
                                        cityLoading = false;
                                      });
                                    },
                                  )
                                : null),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => onCityTyped(v, setModal),
                      onTap: () {
                        if (citySuggestions.isNotEmpty) {
                          setModal(() => showCitySuggest = true);
                        } else if (cityCtrl.text.trim().length >= 2) {
                          runCitySearch(cityCtrl.text, setModal);
                        }
                      },
                    ),
                    if (showCitySuggest && citySuggestions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: SpyceColors.dark900,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: citySuggestions.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                          itemBuilder: (_, i) {
                            final s = citySuggestions[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.place_outlined,
                                color: SpyceColors.pinkSoft,
                                size: 20,
                              ),
                              title: Text(
                                s.city,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  if (s.state != null && s.state!.isNotEmpty) s.state!,
                                  if (s.country != null && s.country!.isNotEmpty)
                                    s.country!,
                                ].join(', '),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                              trailing: s.profileCount > 0
                                  ? Text(
                                      '${s.profileCount}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        fontSize: 11,
                                      ),
                                    )
                                  : null,
                              onTap: () => pickCity(s, setModal),
                            );
                          },
                        ),
                      ),
                    ] else if (cityLoading) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Searching cities…',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    ] else if (cityCtrl.text.trim().length >= 2 &&
                        !cityLoading &&
                        citySuggestions.isEmpty &&
                        showCitySuggest == false &&
                        selectedCity.isNotEmpty &&
                        selectedState.isEmpty) ...[
                      // After a failed search we leave showCitySuggest false; optional quiet hint
                    ],
                    if (selectedCity.isNotEmpty &&
                        (selectedState.isNotEmpty || selectedCountry.isNotEmpty)) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          avatar: const Icon(Icons.check_circle, size: 16, color: Colors.white),
                          label: Text(
                            [
                              selectedCity,
                              if (selectedState.isNotEmpty) selectedState,
                              if (selectedCountry.isNotEmpty) selectedCountry,
                            ].join(', '),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          backgroundColor: SpyceColors.pink.withValues(alpha: 0.35),
                          side: BorderSide.none,
                          deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white70),
                          onDeleted: () {
                            cityCtrl.clear();
                            setModal(() {
                              selectedCity = '';
                              selectedState = '';
                              selectedCountry = '';
                              selectedCityLat = null;
                              selectedCityLon = null;
                            });
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (intentOptions.isNotEmpty) ...[
                      Text('Filter by Intent',
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Any Intent'),
                            selected: selectedIntent.isEmpty,
                            selectedColor: SpyceColors.pink,
                            labelStyle: TextStyle(color: selectedIntent.isEmpty ? Colors.white : Colors.white70),
                            onSelected: (_) => setModal(() => selectedIntent = ''),
                          ),
                          ...intentOptions.map((opt) {
                            final isSel = selectedIntent == opt.id || selectedIntent == opt.name;
                            return ChoiceChip(
                              label: Text(opt.name),
                              selected: isSel,
                              selectedColor: SpyceColors.pink,
                              labelStyle: TextStyle(color: isSel ? Colors.white : Colors.white70),
                              onSelected: (sel) => setModal(() {
                                selectedIntent = sel ? opt.id : '';
                              }),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Currently online only', style: TextStyle(color: Colors.white)),
                      value: online,
                      activeThumbColor: SpyceColors.pink,
                      onChanged: (v) => setModal(() => online = v),
                    ),
                    const SizedBox(height: 16),
                    SpycePrimaryButton(
                      label: 'Apply Filters',
                      onPressed: () {
                        cityDebounce?.cancel();
                        final hasRegion = selectedCity.trim().isNotEmpty;
                        Navigator.pop(context);
                        setState(() {
                          // User chose filters again — leave variety mode
                          _varietyMode = false;
                          _showVarietyBridge = false;
                          _bridgePageIndex = 0;
                          filters = {
                            ...filters,
                            'min_age': minAge.round(),
                            'max_age': maxAge.round(),
                            // Region filter wins over distance (backend normalize)
                            'distance': hasRegion
                                ? 0
                                : (anywhere ? 0 : distance.round().clamp(1, 1000)),
                            'city': selectedCity.trim(),
                            'state': selectedState.trim(),
                            'country': selectedCountry.trim(),
                            'intent': selectedIntent,
                            'currently_online': online,
                            'location_mode': hasRegion ? 'region' : 'distance',
                            'include_liked': false,
                          };
                          if (hasRegion &&
                              selectedCityLat != null &&
                              selectedCityLon != null) {
                            filters['city_lat'] = selectedCityLat;
                            filters['city_lon'] = selectedCityLon;
                          } else {
                            filters.remove('city_lat');
                            filters.remove('city_lon');
                          }
                        });
                        _load(0);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // sheet closed
    });
  }


  @override
  Widget build(BuildContext context) {
    if (showPaywall) {
      return SubscriptionPaywall(
        status: paywallStatus,
        onPurchase: _purchase,
        allowClose: false,
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                child: Row(
                  children: [
                    Text.rich(
                      TextSpan(
                        style: GoogleFonts.syne(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: SpyceColors.white,
                        ),
                        children: const [
                          TextSpan(text: 'sp'),
                          TextSpan(
                              text: 'y',
                              style: TextStyle(color: SpyceColors.pink)),
                          TextSpan(text: 'ce'),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _openFilters,
                      icon: const Icon(Icons.tune_rounded),
                      color: SpyceColors.white,
                    ),
                    IconButton(
                      onPressed: () => _load(0),
                      icon: const Icon(Icons.refresh_rounded),
                      color: SpyceColors.white,
                    ),
                  ],
                ),
              ),
            ),
            if (locationBanner != null &&
                locationBanner!.isNotEmpty &&
                profiles.isNotEmpty)
              Material(
                color: SpyceColors.pink.withValues(alpha: 0.15),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          color: SpyceColors.pinkSoft, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          locationBanner!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => locationBanner = null),
                        icon: const Icon(Icons.close,
                            size: 16, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: SpyceColors.pink),
                    )
                  : (_isProfileIncomplete && profiles.isEmpty)
                      ? _ProfileIncompleteView(
                          profile: _myProfile,
                          message: _profileIncompleteMessage,
                          missingFields: _missingFields,
                          onRefresh: () {
                            setState(() {
                              _isProfileIncomplete = false;
                              loading = true;
                            });
                            _seedFiltersFromProfile();
                            _load(0, refresh: true);
                          },
                        )
                      : profiles.isEmpty && !_showVarietyBridge
                          ? EmptyState(
                              icon: Icons.explore_outlined,
                              title: (filters['city']?.toString().isNotEmpty == true)
                                  ? 'No one in ${filters['city']} yet'
                                  : 'No more people right now',
                              subtitle: error ??
                                  locationBanner ??
                                  'Pull to refresh or adjust filters — new people show up as they come online.',
                              action: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _varietyMode = false;
                                        _showVarietyBridge = false;
                                        filters.remove('include_liked');
                                      });
                                      _load(0);
                                    },
                                    child: const Text('Refresh',
                                        style: TextStyle(
                                            color: SpyceColors.pinkSoft)),
                                  ),
                                  TextButton(
                                    onPressed: _openFilters,
                                    child: const Text('Adjust filters',
                                        style: TextStyle(
                                            color: SpyceColors.pinkSoft)),
                                  ),
                                ],
                              ),
                            )
                          : PageView.builder(
                              controller: _pageCtrl,
                              scrollDirection: Axis.vertical,
                              itemCount: _pageCount,
                              onPageChanged: (i) {
                                final profIdx = _profileIndexForPage(i);
                                final nearEnd = profIdx != null &&
                                    profIdx >= profiles.length - 3;
                                if (hasMore &&
                                    !loadingMore &&
                                    nearEnd &&
                                    nextCursor != null) {
                                  _load(nextCursor!, append: true);
                                } else if (!hasMore &&
                                    !_varietyMode &&
                                    !_enteringVariety &&
                                    profiles.isNotEmpty &&
                                    (profIdx == null
                                        ? false
                                        : profIdx >= profiles.length - 2)) {
                                  // Near the end of filtered results → relax & keep going
                                  _enterVarietyAndContinue(keepProfiles: true);
                                }
                              },
                              itemBuilder: (context, index) {
                                final profIdx = _profileIndexForPage(index);
                                if (profIdx == null) {
                                  // Compact two-line bridge — not a full empty screen
                                  return const _VarietyBridgePage();
                                }
                                if (profIdx < 0 || profIdx >= profiles.length) {
                                  return const SizedBox.shrink();
                                }
                                final p = profiles[profIdx];
                                return Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(10, 0, 10, 8),
                                  child: FeedProfileCard(
                                    profile: p,
                                    liked: _isLiked(p),
                                    onLike: () => _like(p),
                                    onMessage: p.canDirectMessage
                                        ? () => _message(p)
                                        : null,
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
        if (toast != null)
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Center(child: MatchToast(message: toast!)),
          ),
      ],
    );
  }
}

/// Dedicated profile incomplete warning showing required missing fields.
class _ProfileIncompleteView extends StatelessWidget {
  const _ProfileIncompleteView({
    this.profile,
    this.message,
    this.missingFields = const [],
    required this.onRefresh,
  });

  final UserProfile? profile;
  final String? message;
  final List<String> missingFields;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final missing = missingFields.isNotEmpty
        ? missingFields
        : (profile?.missingFields.isNotEmpty == true
            ? profile!.missingFields
            : [
                'Username',
                'Date of Birth / Age (18+)',
                'Gender',
                'Sexuality',
                'Preferred Genders (Looking for)',
                'Bio (at least 20 characters)',
              ]);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SpyceColors.pink.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_late_outlined,
                color: SpyceColors.pinkSoft,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Profile Incomplete',
              textAlign: TextAlign.center,
              style: GoogleFonts.syne(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: SpyceColors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message ??
                  'Complete your profile setup to unlock the discovery feed and start matching.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SpyceColors.white.withValues(alpha: 0.7),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SpyceColors.dark900,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Required Fields (${missing.length} missing):',
                    style: const TextStyle(
                      color: SpyceColors.pinkSoft,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final item in missing)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.amberAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SpycePrimaryButton(
              label: 'Complete Profile',
              onPressed: () {
                context.go('/app/profile');
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onRefresh,
              child: const Text(
                'Check Again / Refresh',
                style: TextStyle(color: SpyceColors.dark100),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin interstitial: two playful lines, then swipe to next profile.
class _VarietyBridgePage extends StatelessWidget {
  const _VarietyBridgePage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "We're out of the Spyce you want…",
              textAlign: TextAlign.center,
              style: GoogleFonts.syne(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'but here are many more to try ✨',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: SpyceColors.pinkSoft,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 28),
            Icon(
              Icons.keyboard_arrow_up_rounded,
              color: Colors.white.withValues(alpha: 0.35),
              size: 28,
            ),
            Text(
              'swipe for more',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
