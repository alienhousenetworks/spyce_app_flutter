import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/spyce_colors.dart';
import '../../core/utils/media_url.dart';

class SpyceLogo extends StatelessWidget {
  const SpyceLogo({super.key, this.size = 40, this.showTagline = false});

  final double size;
  final bool showTagline;

  static const assetPath = 'assets/images/spyce_logo.jpg';

  @override
  Widget build(BuildContext context) {
    // Clean "SPYCE" wordmark (ember Y) — wide asset.
    final height = size * 1.35;
    final width = height * 2.8;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          assetPath,
          height: height,
          width: width,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => Text.rich(
            TextSpan(
              style: GoogleFonts.syne(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: SpyceColors.white,
                letterSpacing: 1.2,
              ),
              children: const [
                TextSpan(text: 'SP'),
                TextSpan(
                  text: 'Y',
                  style: TextStyle(color: SpyceColors.pink),
                ),
                TextSpan(text: 'CE'),
              ],
            ),
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 8),
          Text(
            'no fake vibes. just real ones.',
            style: GoogleFonts.dmSans(
              color: SpyceColors.dark100,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }
}

class SpycePrimaryButton extends StatelessWidget {
  const SpycePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: SpyceColors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

class SpyceGradientScaffold extends StatelessWidget {
  const SpyceGradientScaffold({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              SpyceColors.blush,
              SpyceColors.dark950,
              SpyceColors.dark950,
            ],
          ),
        ),
        child: SafeArea(
          child: padding != null
              ? Padding(padding: padding!, child: child)
              : child,
        ),
      ),
    );
  }
}

class NetworkAvatar extends StatelessWidget {
  const NetworkAvatar({
    super.key,
    this.url,
    this.size = 48,
    this.name,
  });

  final String? url;
  final double size;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final letter = (name?.isNotEmpty == true ? name![0] : '?').toUpperCase();
    final resolved = resolveMediaUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: resolved != null && resolved.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: resolved,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, _) => _placeholder(letter),
              errorWidget: (_, failedUrl, err) {
                debugPrint('🔴 [NetworkAvatar] Failed to load "$failedUrl": $err');
                return _placeholder(letter);
              },
            )
          : _placeholder(letter),
    );
  }

  Widget _placeholder(String letter) {
    return Container(
      width: size,
      height: size,
      color: SpyceColors.dark600,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: SpyceColors.pinkSoft,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}

class FeedSvgBackground extends StatelessWidget {
  const FeedSvgBackground({
    super.key,
    required this.assetPath,
    this.accent,
    this.child,
  });

  final String assetPath;
  final Color? accent;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final a = accent ?? SpyceColors.pink;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: SpyceColors.dark900),
        SvgPicture.asset(
          assetPath,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          placeholderBuilder: (_) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [a.withValues(alpha: 0.35), SpyceColors.dark900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        // Accent wash so text stays readable over busy SVGs
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                a.withValues(alpha: 0.22),
                Colors.black.withValues(alpha: 0.15),
                Colors.black.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.syne(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: SpyceColors.white,
            ),
          ),
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: SpyceColors.dark300),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.syne(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: SpyceColors.white,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: SpyceColors.dark100, height: 1.4),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: SpyceColors.dark700,
      highlightColor: SpyceColors.dark500,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: count,
        itemBuilder: (_, __) => Container(
          height: 88,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: SpyceColors.dark700,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class PinkTag extends StatelessWidget {
  const PinkTag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: SpyceColors.pinkDim,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SpyceColors.pink.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: SpyceColors.pinkSoft,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class MatchToast extends StatelessWidget {
  const MatchToast({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: SpyceColors.dark600,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: SpyceColors.pink.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: SpyceColors.pink.withValues(alpha: 0.35),
              blurRadius: 24,
            ),
          ],
        ),
        child: Text(
          message,
          style: GoogleFonts.syne(
            color: SpyceColors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
