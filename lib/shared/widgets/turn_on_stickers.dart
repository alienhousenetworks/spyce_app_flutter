import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/spyce_colors.dart';
import '../../core/utils/media_url.dart';
import '../../data/models/user_models.dart';

/// Cream sticker tile: R2 illustration + black name pill (feed / profile style).
class TurnOnStickerCard extends StatelessWidget {
  const TurnOnStickerCard({
    super.key,
    required this.item,
    this.selected = false,
    this.onTap,
    this.compact = false,
  });

  final TurnOnItem item;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(item.imageUrl);
    final radius = compact ? 14.0 : 18.0;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: SpyceColors.paper,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: selected
              ? SpyceColors.pink
              : Colors.black.withValues(alpha: 0.06),
          width: selected ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: selected ? 0.28 : 0.18),
            blurRadius: selected ? 14 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Illustration
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 10 : 14,
                compact ? 10 : 14,
                compact ? 10 : 14,
                compact ? 28 : 36,
              ),
              child: resolved != null && resolved.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: resolved,
                      fit: BoxFit.contain,
                      fadeInDuration: const Duration(milliseconds: 180),
                      placeholder: (_, _) => const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: SpyceColors.dark500,
                          ),
                        ),
                      ),
                      errorWidget: (_, _, _) => _FallbackIcon(name: item.name),
                    )
                  : _FallbackIcon(name: item.name),
            ),
          ),
          // Name pill (bottom, overlapping)
          Positioned(
            left: compact ? 8 : 12,
            right: compact ? 8 : 12,
            bottom: compact ? 8 : 10,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 12,
                vertical: compact ? 5 : 7,
              ),
              decoration: BoxDecoration(
                color: selected ? SpyceColors.pink : Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: compact ? 11 : 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (selected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: SpyceColors.pink,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        _iconFor(name),
        size: 48,
        color: SpyceColors.dark700.withValues(alpha: 0.75),
      ),
    );
  }

  static IconData _iconFor(String label) {
    final l = label.toLowerCase();
    if (l.contains('kiss')) return Icons.favorite;
    if (l.contains('cuddle')) return Icons.hotel;
    if (l.contains('cosplay') || l.contains('costume')) return Icons.theater_comedy;
    if (l.contains('spank')) return Icons.back_hand_outlined;
    if (l.contains('music')) return Icons.music_note;
    if (l.contains('food') || l.contains('cook')) return Icons.restaurant;
    if (l.contains('travel')) return Icons.flight;
    if (l.contains('read') || l.contains('book') || l.contains('talk')) {
      return Icons.menu_book;
    }
    if (l.contains('gym') || l.contains('fit')) return Icons.fitness_center;
    if (l.contains('humor') || l.contains('wit')) return Icons.emoji_emotions;
    if (l.contains('night')) return Icons.nights_stay;
    if (l.contains('confiden')) return Icons.auto_awesome;
    if (l.contains('empath')) return Icons.volunteer_activism;
    if (l.contains('intel')) return Icons.psychology;
    return Icons.local_fire_department_outlined;
  }
}

/// 2-column sticker grid used on feed turn-ons page & peer profile.
class TurnOnStickerGrid extends StatelessWidget {
  const TurnOnStickerGrid({
    super.key,
    required this.items,
    this.maxItems = 8,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
    this.aspectRatio = 1.05,
  });

  final List<TurnOnItem> items;
  final int maxItems;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final shown = items.take(maxItems).toList();
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: shown.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: aspectRatio,
      ),
      itemBuilder: (context, i) => TurnOnStickerCard(item: shown[i]),
    );
  }
}

/// Multi-select sticker picker (profile edit).
class TurnOnStickerPicker extends StatelessWidget {
  const TurnOnStickerPicker({
    super.key,
    required this.options,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<CatalogOption> options;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, i) {
        final o = options[i];
        final on = selectedIds.contains(o.id);
        return TurnOnStickerCard(
          item: o.toTurnOnItem(),
          selected: on,
          compact: true,
          onTap: () {
            final next = {...selectedIds};
            if (on) {
              next.remove(o.id);
            } else {
              next.add(o.id);
            }
            onChanged(next);
          },
        );
      },
    );
  }
}
