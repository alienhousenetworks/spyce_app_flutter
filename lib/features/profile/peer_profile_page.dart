import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/spyce_colors.dart';
import '../../core/utils/language_labels.dart';
import '../../core/utils/media_url.dart';
import '../../core/utils/presence_labels.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/api_repositories.dart';
import '../../shared/widgets/media_user_id_watermark.dart';
import '../../shared/widgets/turn_on_stickers.dart';
import '../auth/auth_controller.dart';
import '../discover/widgets/feed_profile_card.dart';

/// Full public profile from chat avatar — same details as Discover feed card.
class PeerProfilePage extends ConsumerStatefulWidget {
  const PeerProfilePage({
    super.key,
    required this.userId,
    this.initialName,
    this.initialImage,
    /// When true (Chat → Likes), heart likes back and can create a match.
    this.allowLikeBack = false,
  });

  final String userId;
  final String? initialName;
  final String? initialImage;
  final bool allowLikeBack;

  @override
  ConsumerState<PeerProfilePage> createState() => _PeerProfilePageState();
}

class _PeerProfilePageState extends ConsumerState<PeerProfilePage> {
  UserProfile? profile;
  bool loading = true;
  String? error;
  bool liked = false;
  bool liking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      // Language catalog so UUID language ids resolve to names
      try {
        final langs = await ref.read(optionsRepositoryProvider).languages();
        if (langs.isNotEmpty) LanguageLabels.setCatalog(langs);
      } catch (_) {}

      final p = await ref
          .read(profileRepositoryProvider)
          .getProfile(widget.userId);
      if (!mounted) return;
      // Resolve language labels if still raw
      final resolved = p.copyWith(
        languageLabels: LanguageLabels.resolveAll(
          p.languageLabels.isNotEmpty ? p.languageLabels : p.languageIds,
        ),
      );
      setState(() {
        profile = resolved;
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.fullDetail;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _likeBack() async {
    if (!widget.allowLikeBack || liked || liking) return;
    setState(() => liking = true);
    try {
      final res = await ref.read(feedRepositoryProvider).like(widget.userId);
      if (!mounted) return;
      final status = (res['status'] ?? res['result'] ?? '').toString().toLowerCase();
      final isMatch = status == 'match' ||
          res['is_match'] == true ||
          res['matched'] == true ||
          res['match'] != null;
      setState(() {
        liked = true;
        liking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMatch
                ? "It's a Match! You can chat now."
                : 'Liked back successfully',
          ),
          backgroundColor: isMatch ? SpyceColors.pink : SpyceColors.dark700,
        ),
      );
      if (isMatch) {
        // Return to chat with match so list can refresh
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (mounted) context.pop(true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => liking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.fullDetail)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => liking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not like: $e')),
      );
    }
  }

  void _openImage(String url) {
    final stamp = ref.read(viewerUsernameProvider);
    final resolved = resolveMediaUrl(url) ?? url;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: MediaUserIdWatermark(
                username: stamp,
                child: CachedNetworkImage(
                  imageUrl: resolved,
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const SizedBox(
                    height: 240,
                    child: Center(
                      child: CircularProgressIndicator(color: SpyceColors.pink),
                    ),
                  ),
                  errorWidget: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Icon(Icons.broken_image,
                        color: Colors.white54, size: 48),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final title = p?.displayName ?? widget.initialName ?? 'Profile';
    final feed = p?.toFeedProfile();

    return Scaffold(
      backgroundColor: SpyceColors.dark950,
      appBar: AppBar(
        backgroundColor: SpyceColors.dark950,
        title: Text(
          title.startsWith('@') ? title : '@$title',
          style: GoogleFonts.syne(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: SpyceColors.pink),
            )
          : error != null && p == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_off_outlined,
                            size: 48, color: Colors.white38),
                        const SizedBox(height: 12),
                        Text(
                          'Could not load profile',
                          style: GoogleFonts.syne(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _load,
                          child: const Text(
                            'Retry',
                            style: TextStyle(color: SpyceColors.pinkSoft),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : feed == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      color: SpyceColors.pink,
                      onRefresh: _load,
                      // Same multi-page card as Discover feed (hero → photos → details → turn-ons)
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: (constraints.maxHeight - 8)
                                    .clamp(480.0, 900.0),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      12, 4, 12, 12),
                                  child: FeedProfileCard(
                                    profile: feed,
                                    liked: liked,
                                    onLike: () {
                                      if (widget.allowLikeBack) {
                                        _likeBack();
                                        return;
                                      }
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Open Discover to like profiles',
                                          ),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              // Extra scroll sections for dense lists (same data as feed pages)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 40),
                                child: _PeerDetailExtras(
                                  profile: p!,
                                  feed: feed,
                                  onOpenImage: _openImage,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
    );
  }
}

/// Flat list under the card so nothing is “hidden” behind swipes only.
class _PeerDetailExtras extends StatelessWidget {
  const _PeerDetailExtras({
    required this.profile,
    required this.feed,
    required this.onOpenImage,
  });

  final UserProfile profile;
  final FeedProfile feed;
  final void Function(String url) onOpenImage;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final moods = p.moods;
    final langs = p.languageLabels.isNotEmpty
        ? p.languageLabels
        : feed.languages;
    final turnOnItems = p.turnOnItems.isNotEmpty
        ? p.turnOnItems
        : (feed.turnOnItems.isNotEmpty
            ? feed.turnOnItems
            : [
                for (final n in (p.turnOnLabels.isNotEmpty
                    ? p.turnOnLabels
                    : feed.turnOns))
                  TurnOnItem(id: n, name: n),
              ]);
    final hotTakes = p.hotTakeList;
    final photos = p.images
        .where((i) => i.imageUrl.isNotEmpty)
        .map((i) => resolveMediaUrl(i.imageUrl) ?? i.imageUrl)
        .where((u) => u.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Full profile',
          style: GoogleFonts.syne(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Same details as Discover — swipe the card above or scroll here.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),

        // Presence
        _section(
          title: 'Status',
          child: Text(
            PresenceLabels.display(
              isOnline: feed.isOnline,
              lastSeenLabel: feed.lastSeen,
              lastActiveAt: feed.lastActiveAt,
            ),
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),

        if (moods.isNotEmpty)
          _section(
            title: 'Mood',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: moods
                  .map(
                    (m) => Chip(
                      label: Text('✨ $m',
                          style: const TextStyle(color: Colors.white)),
                      backgroundColor:
                          SpyceColors.pink.withValues(alpha: 0.3),
                      side: BorderSide.none,
                    ),
                  )
                  .toList(),
            ),
          ),

        if (p.bio != null && p.bio!.trim().isNotEmpty)
          _section(
            title: 'Bio',
            child: Text(
              p.bio!.trim(),
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.92),
                height: 1.4,
                fontSize: 15,
              ),
            ),
          ),

        _section(
          title: 'Basics',
          child: Column(
            children: [
              _kv('Name', p.displayName),
              if (p.age != null && !p.hideAge) _kv('Age', '${p.age}'),
              _kv('Gender', p.genderLabel ?? '—'),
              _kv('Sexuality', p.sexualityLabel ?? '—'),
              if (p.intentLabel != null && p.intentLabel!.isNotEmpty)
                _kv('Intent', p.intentLabel!),
              if (p.locationSummary != '—')
                _kv('Location', p.locationSummary),
            ],
          ),
        ),

        if (langs.isNotEmpty)
          _section(
            title: 'Languages',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: langs
                  .map(
                    (l) => Chip(
                      label: Text(l,
                          style: const TextStyle(color: SpyceColors.white)),
                      backgroundColor: SpyceColors.pink.withValues(alpha: 0.3),
                      side: BorderSide.none,
                    ),
                  )
                  .toList(),
            ),
          ),

        if (hotTakes.isNotEmpty)
          _section(
            title: hotTakes.length == 1 ? 'Hot take' : 'Hot takes',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < hotTakes.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  Text(
                    hotTakes[i].label,
                    style: TextStyle(
                      color: SpyceColors.pinkSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hotTakes[i].text,
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),

        if (turnOnItems.isNotEmpty)
          _section(
            title: 'Turn-ons',
            child: TurnOnStickerGrid(items: turnOnItems, maxItems: 8),
          ),

        if (photos.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Photos (${photos.length})',
            style: GoogleFonts.syne(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, i) {
              final url = photos[i];
              return GestureDetector(
                onTap: () => onOpenImage(url),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        const ColoredBox(color: SpyceColors.dark700),
                    errorWidget: (_, _, _) => const ColoredBox(
                      color: SpyceColors.dark600,
                      child: Icon(Icons.broken_image, color: Colors.white38),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SpyceColors.dark800,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.syne(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: SpyceColors.pinkSoft,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              k,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
