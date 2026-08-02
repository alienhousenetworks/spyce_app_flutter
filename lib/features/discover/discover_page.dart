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
  bool showPaywall = false;
  SubscriptionStatus? paywallStatus;

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
    });
    _load(0);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureLanguageCatalog() async {
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

  Future<void> _load(int cursor, {bool append = false}) async {
    if (cursor == 0) {
      setState(() {
        loading = true;
        error = null;
      });
    } else {
      setState(() => loadingMore = true);
    }

    try {
      // Always ensure catalog before parsing so UUIDs map to names
      await _ensureLanguageCatalog();

      final res = await ref.read(feedRepositoryProvider).getFeed(
            cursor: cursor,
            filters: filters,
          );
      if (!mounted) return;
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
        if (profiles.isEmpty && res.emptyReason != null) {
          error = res.emptyReason;
        }
      });
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
          if (!append) profiles = _demoProfiles();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!append) profiles = _demoProfiles();
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
      _showToast('Liked ${p.shortName}');
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
        var distance = (filters['distance'] as num?)?.toDouble() ?? 0;
        var online = filters['currently_online'] == true;
        var selectedCity = filters['city']?.toString() ?? '';
        var selectedIntent = filters['intent']?.toString() ?? '';

        final cityCtrl = TextEditingController(text: selectedCity);

        return StatefulBuilder(
          builder: (context, setModal) {
            final double screenMaxDist = 1000.0;
            final String distLabel = distance == 0
                ? 'Distance: Anywhere'
                : (distance >= screenMaxDist ? 'Distance: 1000+ km' : 'Distance: ${distance.round()} km');

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
                    Slider(
                      value: distance.clamp(0.0, screenMaxDist),
                      min: 0,
                      max: screenMaxDist,
                      divisions: 20,
                      activeColor: SpyceColors.pink,
                      onChanged: (v) => setModal(() => distance = v),
                    ),
                    const SizedBox(height: 10),
                    Text('Filter by City (Single City)',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: cityCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter city name (e.g. Mumbai, Delhi)',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        filled: true,
                        fillColor: Colors.black26,
                        prefixIcon: const Icon(Icons.location_city, color: SpyceColors.pinkSoft),
                        suffixIcon: cityCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54),
                                onPressed: () {
                                  cityCtrl.clear();
                                  setModal(() => selectedCity = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => setModal(() => selectedCity = v.trim()),
                    ),
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
                        Navigator.pop(context);
                        setState(() {
                          filters = {
                            ...filters,
                            'min_age': minAge.round(),
                            'max_age': maxAge.round(),
                            'distance': distance.round(),
                            'city': selectedCity,
                            'intent': selectedIntent,
                            'currently_online': online,
                          };
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
    );
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
            Expanded(
              child: loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: SpyceColors.pink),
                    )
                  : profiles.isEmpty
                      ? EmptyState(
                          icon: Icons.explore_outlined,
                          title: 'Feed is quiet',
                          subtitle: error ?? 'Try refreshing or widen filters.',
                          action: TextButton(
                            onPressed: () => _load(0),
                            child: const Text('Refresh',
                                style:
                                    TextStyle(color: SpyceColors.pinkSoft)),
                          ),
                        )
                      : PageView.builder(
                          controller: _pageCtrl,
                          scrollDirection: Axis.vertical,
                          itemCount: profiles.length,
                          onPageChanged: (i) {
                            if (hasMore &&
                                !loadingMore &&
                                i >= profiles.length - 3 &&
                                nextCursor != null) {
                              _load(nextCursor!, append: true);
                            }
                          },
                          itemBuilder: (context, index) {
                            final p = profiles[index];
                            return Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(10, 0, 10, 8),
                              child: FeedProfileCard(
                                profile: p,
                                liked: _isLiked(p),
                                onLike: () => _like(p),
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

  List<FeedProfile> _demoProfiles() {
    // Demo: one with "uploaded" look via network image, one with pool avatar only
    return [
      const FeedProfile(
        id: 'demo-1',
        username: 'Oopsis',
        age: 24,
        bio:
            'A soft - romantic girl who likes to move through life with love for all gentle beings',
        city: 'Pune',
        gender: 'Female',
        sexuality: 'Straight',
        pronouns: 'she/her',
        height: "5'8\"",
        photoStatus: 'CUSTOM',
        images: [
          ProfileImage(
            id: '1',
            imageUrl:
                'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=600',
          ),
        ],
        bgId: 'B01',
        bgVariantId: 'B01-coral',
        turnOns: ['Kissing', 'Cosplay', 'Cuddles', 'Music'],
        interests: ['film photography', 'lo-fi', 'slow mornings', 'poetry'],
        hotTakes: [
          HotTake(
              label: 'Currently obsessed with',
              text: 'late night train rides & old songs'),
          HotTake(
              label: 'Fact about me', text: 'replies fast when excited'),
        ],
        favouriteTrack: null,
        isOnline: true,
      ),
      const FeedProfile(
        id: 'demo-2',
        username: 'kai',
        age: 27,
        bio: 'Looking for intentional connections, not infinite swipes.',
        city: 'Bangalore',
        gender: 'Male',
        height: "5'11\"",
        // No uploads → admin pool avatar (gender+sexuality)
        photoStatus: 'AVATAR',
        avatarUrl:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600',
        bgId: 'B02',
        bgVariantId: 'B02-teal',
        turnOns: ['Deep chats', 'Gym', 'Films', 'Travel'],
        interests: ['climbing', 'espresso', 'sci-fi'],
        hotTakes: [
          HotTake(label: 'Hot take', text: 'Good coffee > good pickup lines'),
        ],
      ),
    ];
  }
}
