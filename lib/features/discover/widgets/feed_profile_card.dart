import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/feed_backgrounds.dart';
import '../../../core/theme/spyce_colors.dart';
import '../../../core/utils/distance_display.dart';
import '../../../core/utils/presence_labels.dart';
import '../../../data/models/user_models.dart';
import '../../../shared/widgets/media_user_id_watermark.dart';
import '../../../shared/widgets/spyce_widgets.dart';
import '../../auth/auth_controller.dart';

/// Horizontal multi-page feed card matching SPYCE design screenshots:
/// 0 Hero · 1 Photos (only if user uploaded images) · 2 Details · 3 Turn-ons
class FeedProfileCard extends ConsumerStatefulWidget {
  const FeedProfileCard({
    super.key,
    required this.profile,
    required this.onLike,
    this.onPass,
    this.liked = false,
  });

  final FeedProfile profile;
  final VoidCallback onLike;
  final VoidCallback? onPass;
  final bool liked;

  @override
  ConsumerState<FeedProfileCard> createState() => _FeedProfileCardState();
}

class _FeedProfileCardState extends ConsumerState<FeedProfileCard> {
  late final PageController _pageCtrl;
  int _page = 0;
  int _photoIdx = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  List<_FeedPage> get _pages {
    final p = widget.profile;
    // Photos page only when user uploaded real photos (not admin pool avatar)
    final pages = <_FeedPage>[
      _FeedPage.hero,
      if (p.hasUserPhotos && p.galleryImages.isNotEmpty) _FeedPage.photos,
      _FeedPage.details,
      _FeedPage.turnOns,
    ];
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    // Anti-leak: stamp the *viewer username* only (never user id / @badge).
    // Username is loaded from profile into auth ( /users/me has no username ).
    final viewerUsername = ref.watch(viewerUsernameProvider);
    final accent = SpyceColors.accentForVariant(p.bgVariantId);
    final bgAsset = FeedBackgrounds.resolve(
      bgId: p.bgId,
      bgVariantId: p.bgVariantId,
      layoutId: p.layoutId,
      seed: p.id.hashCode,
    );
    final pages = _pages;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: FeedSvgBackground(
        assetPath: bgAsset,
        accent: accent,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, index) {
                  return switch (pages[index]) {
                    _FeedPage.hero => _HeroPage(
                        profile: p,
                        liked: widget.liked,
                        onLike: widget.onLike,
                        viewerUsername: viewerUsername,
                      ),
                    _FeedPage.photos => _PhotosPage(
                        images: p.galleryImages,
                        selected: _photoIdx,
                        onSelect: (i) => setState(() => _photoIdx = i),
                        username: viewerUsername,
                      ),
                    _FeedPage.details => _DetailsPage(profile: p),
                    _FeedPage.turnOns => _TurnOnsPage(profile: p),
                  };
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14, top: 4),
              child: _PageDots(count: pages.length, index: _page),
            ),
          ],
        ),
      ),
    );
  }
}

enum _FeedPage { hero, photos, details, turnOns }

/// Current mood pills for the feed hero (first page).
class _MoodChips extends StatelessWidget {
  const _MoodChips({required this.moods});

  final List<String> moods;

  @override
  Widget build(BuildContext context) {
    final shown = moods.where((m) => m.trim().isNotEmpty).take(3).toList();
    if (shown.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final mood in shown)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: SpyceColors.pink.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: SpyceColors.pinkSoft.withValues(alpha: 0.55),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      mood,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: on ? 18 : 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: on ? SpyceColors.white : SpyceColors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

// ── Page 1: Hero ─────────────────────────────────────────────

class _HeroPage extends StatelessWidget {
  const _HeroPage({
    required this.profile,
    required this.liked,
    required this.onLike,
    this.viewerUsername,
  });

  final FeedProfile profile;
  final bool liked;
  final VoidCallback onLike;
  /// Logged-in viewer username for anti-leak watermark (not the profile owner).
  final String? viewerUsername;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final hero = p.heroImageUrl;
    final size = MediaQuery.sizeOf(context);
    final hasBio = p.bio != null && p.bio!.trim().isNotEmpty;
    // Adaptive photo: shrink slightly when bio is present so name/details/bio
    // sit higher and the like CTA never collides with the card bottom / bg.
    final photoH = size.height * (hasBio ? 0.34 : 0.40);
    final photoW = size.width * 0.78;
    final h = photoH.clamp(hasBio ? 200.0 : 220.0, hasBio ? 300.0 : 360.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Column(
        children: [
          // Scrollable identity block — photo, name, meta, bio.
          // Uses all remaining height; never steals space from the action row.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  // Scroll only when expanded bio / small screens overflow
                  physics: const ClampingScrollPhysics(),
                  primary: false,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Small top inset so content sits higher than before
                        SizedBox(height: hasBio ? 4 : 10),
                        // Frameless hero — fills box, transparent areas show feed bg
                        SizedBox(
                          width: photoW,
                          height: h,
                          child: Stack(
                            fit: StackFit.expand,
                            alignment: Alignment.center,
                            children: [
                              if (hero != null && hero.isNotEmpty)
                                MediaUserIdWatermark(
                                  username: viewerUsername,
                                  child: CachedNetworkImage(
                                    imageUrl: hero,
                                    fit: BoxFit.contain,
                                    alignment: Alignment.center,
                                    width: photoW,
                                    height: h,
                                    memCacheWidth:
                                        (photoW * MediaQuery.devicePixelRatioOf(context))
                                            .round()
                                            .clamp(200, 1600),
                                    fadeInDuration:
                                        const Duration(milliseconds: 150),
                                    placeholder: (_, _) => const Center(
                                      child: SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: SpyceColors.pinkSoft,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, _, _) =>
                                        _AvatarPlaceholder(name: p.shortName),
                                  ),
                                )
                              else
                                _AvatarPlaceholder(name: p.shortName),
                            ],
                          ),
                        ),
                        SizedBox(height: hasBio ? 12 : 16),
                        Text(
                          p.age != null
                              ? '${p.displayName}, ${p.age}'
                              : p.displayName,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: hasBio ? 30 : 34,
                            fontWeight: FontWeight.w600,
                            color: SpyceColors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _PresenceStatusChip(
                          isOnline: p.isOnline,
                          lastSeen: p.lastSeen,
                          lastActiveAt: p.lastActiveAt,
                        ),
                        // Active moods on first page (same as web feed mood badge)
                        if (p.moods.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _MoodChips(moods: p.moods),
                        ],
                        // Hero: city + privacy-bucketed distance (e.g. "Mumbai · ~15 km")
                        if ((p.city != null && p.city!.trim().isNotEmpty) ||
                            p.distanceKm != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: SpyceColors.white.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  () {
                                    final dist =
                                        generalizedDistanceLabel(p.distanceKm);
                                    final city = p.city?.trim();
                                    if (city != null &&
                                        city.isNotEmpty &&
                                        dist != null) {
                                      return '$city · $dist';
                                    }
                                    if (dist != null) return dist;
                                    return city ?? '';
                                  }(),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: SpyceColors.white
                                        .withValues(alpha: 0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (hasBio) ...[
                          const SizedBox(height: 10),
                          _HeroBioBlock(bio: p.bio!.trim()),
                        ],
                        // Breathing room above the pinned like button
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // ── Pinned action footer: always visible, never covered by bio/bg ──
          // Like stays on card until backend LIKE_TTL (~36h) expires
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (liked && !p.canDirectMessage) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: SpyceColors.pink.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: SpyceColors.pinkSoft.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      'Already liked',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundAction(
                      icon: p.canDirectMessage
                          ? Icons.chat_bubble_outline_rounded
                          : (liked ? Icons.favorite : Icons.favorite_border),
                      filled: liked,
                      onTap: onLike,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Expandable bio that never blows past the hero layout.
/// Short bios stay compact; long ones clamp then expand in-place.
class _HeroBioBlock extends StatefulWidget {
  const _HeroBioBlock({required this.bio});
  final String bio;

  @override
  State<_HeroBioBlock> createState() => _HeroBioBlockState();
}

class _HeroBioBlockState extends State<_HeroBioBlock> {
  static const int _collapsedLines = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Text(
              widget.bio,
              textAlign: TextAlign.center,
              maxLines: _expanded ? 12 : _collapsedLines,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: SpyceColors.white.withValues(alpha: 0.92),
                fontSize: 14,
                height: 1.35,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          // Show more only when bio is long enough to likely truncate
          if (widget.bio.length > 90) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              behavior: HitTestBehavior.opaque,
              child: Text(
                _expanded ? 'Show less' : 'Show more',
                style: GoogleFonts.dmSans(
                  color: SpyceColors.pinkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PresenceStatusChip extends StatelessWidget {
  const _PresenceStatusChip({
    required this.isOnline,
    this.lastSeen,
    this.lastActiveAt,
  });

  final bool isOnline;
  final String? lastSeen;
  final DateTime? lastActiveAt;

  @override
  Widget build(BuildContext context) {
    final label = PresenceLabels.display(
      isOnline: isOnline,
      lastSeenLabel: lastSeen,
      lastActiveAt: lastActiveAt,
    );
    final online = isOnline || label.toLowerCase() == 'online';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: online
              ? const Color(0xFF34D399).withValues(alpha: 0.55)
              : Colors.white24,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online
                  ? const Color(0xFF34D399)
                  : SpyceColors.white.withValues(alpha: 0.45),
              boxShadow: online
                  ? [
                      BoxShadow(
                        color: const Color(0xFF34D399).withValues(alpha: 0.55),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: online
                  ? const Color(0xFFA7F3D0)
                  : SpyceColors.white.withValues(alpha: 0.88),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFF5E6C8).withValues(alpha: 0.85),
            width: 1.5,
          ),
          color: filled
              ? SpyceColors.pink.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: const Color(0xFFF5E6C8),
          size: 30,
        ),
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SpyceColors.dark600,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: GoogleFonts.playfairDisplay(
          fontSize: 72,
          color: SpyceColors.pinkSoft,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Page 2: Photos ───────────────────────────────────────────

class _PhotosPage extends StatelessWidget {
  const _PhotosPage({
    required this.images,
    required this.selected,
    required this.onSelect,
    this.username,
  });

  final List<ProfileImage> images;
  final int selected;
  final ValueChanged<int> onSelect;
  final String? username;

  @override
  Widget build(BuildContext context) {
    final current = images[selected.clamp(0, images.length - 1)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: MediaUserIdWatermark(
                username: username,
                child: CachedNetworkImage(
                  imageUrl: current.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (_, _) =>
                      const ColoredBox(color: SpyceColors.dark700),
                  errorWidget: (_, _, _) =>
                      const ColoredBox(color: SpyceColors.dark600),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final on = i == selected;
                return GestureDetector(
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: on ? SpyceColors.white : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    // Thumbnails: no watermark (keep overlays only on main media)
                    child: CachedNetworkImage(
                      imageUrl: images[i].imageUrl,
                      fit: BoxFit.cover,
                      width: 72,
                      height: 72,
                      errorWidget: (_, _, _) =>
                          const ColoredBox(color: SpyceColors.dark600),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap a thumbnail to toggle',
            style: TextStyle(
              color: SpyceColors.white.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page 3: Details ──────────────────────────────────────────

class _DetailsPage extends StatelessWidget {
  const _DetailsPage({required this.profile});
  final FeedProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
      children: [
        _CreamCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p.gender ?? 'Someone'}${p.pronouns != null ? ' (${p.pronouns})' : ''}',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: SpyceColors.dark900,
                      ),
                    ),
                    if (p.height != null) ...[
                      const SizedBox(height: 6),
                      Text(p.height!,
                          style: const TextStyle(
                              color: SpyceColors.dark500, fontSize: 15)),
                    ],
                    if (p.locationSummary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        p.locationSummary,
                        style: const TextStyle(
                          color: SpyceColors.dark500,
                          fontSize: 15,
                        ),
                      ),
                    ],
                    if (p.sexuality != null) ...[
                      const SizedBox(height: 6),
                      Text(p.sexuality!,
                          style: const TextStyle(
                              color: SpyceColors.dark500, fontSize: 15)),
                    ],
                  ],
                ),
              ),
              Icon(Icons.inventory_2_outlined,
                  color: SpyceColors.dark300, size: 40),
            ],
          ),
        ),
        // Hot takes live on the last (turn-ons) page — not duplicated here.
        if (p.languages.isNotEmpty) ...[
          const SizedBox(height: 12),
          _CreamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Languages Spoken',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: SpyceColors.dark900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: p.languages
                      .map(
                        (lang) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F0C8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            lang,
                            style: const TextStyle(
                              color: Color(0xFF3D4A1C),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
        if (p.interests.isNotEmpty) ...[
          const SizedBox(height: 12),
          _CreamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Into',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: SpyceColors.dark900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: p.interests
                      .map(
                        (i) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8D0),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            i,
                            style: const TextStyle(
                              color: Color(0xFF4A3D1C),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Last page: Hot takes (0–3) + Turn-ons ─────────────────────

class _TurnOnsPage extends StatelessWidget {
  const _TurnOnsPage({required this.profile});
  final FeedProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    // Cap at 3 (backend max); empty list = no hot-take section
    final hotTakes = p.hotTakes.take(3).toList();
    final turnOns = p.turnOns;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
      children: [
        // ── Hot takes at top (only when 1–3 available) ────────
        if (hotTakes.isNotEmpty) ...[
          _CreamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🌶', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      hotTakes.length == 1 ? 'Hot take' : 'Hot takes',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: SpyceColors.dark900,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: SpyceColors.pink.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${hotTakes.length}/3',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: SpyceColors.pink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < hotTakes.length; i++) ...[
                  if (i > 0) ...[
                    const SizedBox(height: 10),
                    Divider(
                      height: 1,
                      color: SpyceColors.dark900.withValues(alpha: 0.08),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _HotTakeTile(
                    index: i + 1,
                    total: hotTakes.length,
                    take: hotTakes[i],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Turn-ons ──────────────────────────────────────────
        _CreamCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Turn ons',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: SpyceColors.dark900,
                ),
              ),
              if (turnOns.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'No turn-ons listed yet.',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: SpyceColors.dark500,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  turnOns.take(3).join(' · '),
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: SpyceColors.dark700,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),

        if (turnOns.isNotEmpty) ...[
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: turnOns.length.clamp(0, 6),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, i) {
              final label = turnOns[i];
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F1E3),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        _iconForTurnOn(label),
                        size: 48,
                        color: SpyceColors.dark700,
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  IconData _iconForTurnOn(String label) {
    final l = label.toLowerCase();
    if (l.contains('kiss')) return Icons.favorite;
    if (l.contains('cuddle')) return Icons.hotel;
    if (l.contains('music')) return Icons.music_note;
    if (l.contains('food') || l.contains('cook')) return Icons.restaurant;
    if (l.contains('travel')) return Icons.flight;
    if (l.contains('read') || l.contains('book')) return Icons.menu_book;
    if (l.contains('gym') || l.contains('fit')) return Icons.fitness_center;
    if (l.contains('humor') || l.contains('wit')) return Icons.emoji_emotions;
    if (l.contains('intel')) return Icons.psychology;
    if (l.contains('confiden')) return Icons.star;
    if (l.contains('empath')) return Icons.favorite_border;
    return Icons.auto_awesome;
  }
}

class _HotTakeTile extends StatelessWidget {
  const _HotTakeTile({
    required this.index,
    required this.total,
    required this.take,
  });

  final int index;
  final int total;
  final HotTake take;

  @override
  Widget build(BuildContext context) {
    final title = total == 1
        ? (take.label.startsWith('Hot take') ? 'Hot take' : take.label)
        : (take.label.startsWith('Hot take') ? 'Hot take #$index' : take.label);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: SpyceColors.pink.withValues(alpha: 0.9),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '"${take.text}"',
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontStyle: FontStyle.italic,
            color: SpyceColors.dark800,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CreamCard extends StatelessWidget {
  const _CreamCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F1E3),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
