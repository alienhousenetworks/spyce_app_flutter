import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/spyce_colors.dart';

/// 8-frame SPYCE flame cycle (f1–f8), matching the native loading animation.
class SpyceFlameLoader extends StatefulWidget {
  const SpyceFlameLoader({
    super.key,
    this.height = 160,
    this.frameDuration = const Duration(milliseconds: 90),
  });

  final double height;
  final Duration frameDuration;

  static const int frameCount = 8;
  static const List<String> frames = [
    'assets/animations/flame/f1.png',
    'assets/animations/flame/f2.png',
    'assets/animations/flame/f3.png',
    'assets/animations/flame/f4.png',
    'assets/animations/flame/f5.png',
    'assets/animations/flame/f6.png',
    'assets/animations/flame/f7.png',
    'assets/animations/flame/f8.png',
  ];

  static Future<void> precache(BuildContext context) {
    return Future.wait([
      for (final path in frames) precacheImage(AssetImage(path), context),
    ]);
  }

  @override
  State<SpyceFlameLoader> createState() => _SpyceFlameLoaderState();
}

class _SpyceFlameLoaderState extends State<SpyceFlameLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.frameDuration * SpyceFlameLoader.frameCount,
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    SpyceFlameLoader.precache(context);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    final w = h * (145 / 200);
    return SizedBox(
      width: w,
      height: h,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final frame =
              (_ctrl.value * SpyceFlameLoader.frameCount).floor() %
              SpyceFlameLoader.frameCount;
          return Image.asset(
            SpyceFlameLoader.frames[frame],
            width: w,
            height: h,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          );
        },
      ),
    );
  }
}

/// Centered flame + caption, used for full-screen / section loading.
class SpyceLoadingView extends StatelessWidget {
  const SpyceLoadingView({super.key, this.message, this.flameHeight = 140});

  final String? message;
  final double flameHeight;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpyceFlameLoader(height: flameHeight),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: SpyceColors.dark100,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chat-tab loader: flame + staggered message bubbles.
class SpyceChatLoader extends StatefulWidget {
  const SpyceChatLoader({super.key, this.message = 'Opening your chats…'});

  final String message;

  @override
  State<SpyceChatLoader> createState() => _SpyceChatLoaderState();
}

class _SpyceChatLoaderState extends State<SpyceChatLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SpyceFlameLoader(height: 96),
            const SizedBox(height: 22),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                return SizedBox(
                  width: 220,
                  child: Column(
                    children: [
                      _ChatBubbleBar(
                        alignEnd: false,
                        width: 150,
                        t: _wave(_ctrl.value, 0),
                      ),
                      const SizedBox(height: 10),
                      _ChatBubbleBar(
                        alignEnd: true,
                        width: 118,
                        t: _wave(_ctrl.value, 0.22),
                      ),
                      const SizedBox(height: 10),
                      _ChatBubbleBar(
                        alignEnd: false,
                        width: 168,
                        t: _wave(_ctrl.value, 0.44),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: SpyceColors.dark100,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _wave(double v, double offset) {
    final x = (v + offset) % 1.0;
    // ease in-out pulse 0.55–1.0
    final s = x < 0.5 ? x * 2 : (1 - x) * 2;
    return 0.55 + s * 0.45;
  }
}

class _ChatBubbleBar extends StatelessWidget {
  const _ChatBubbleBar({
    required this.alignEnd,
    required this.width,
    required this.t,
  });

  final bool alignEnd;
  final double width;
  final double t;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Opacity(
        opacity: t,
        child: Container(
          width: width,
          height: 28,
          decoration: BoxDecoration(
            color: alignEnd
                ? SpyceColors.pink.withValues(alpha: 0.28 + t * 0.22)
                : Colors.white.withValues(alpha: 0.08 + t * 0.08),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(alignEnd ? 14 : 4),
              bottomRight: Radius.circular(alignEnd ? 4 : 14),
            ),
          ),
        ),
      ),
    );
  }
}

/// Confession-tab loader: flame + floating note card.
class SpyceConfessionLoader extends StatefulWidget {
  const SpyceConfessionLoader({
    super.key,
    this.message = 'Gathering confessions…',
  });

  final String message;

  @override
  State<SpyceConfessionLoader> createState() => _SpyceConfessionLoaderState();
}

class _SpyceConfessionLoaderState extends State<SpyceConfessionLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SpyceFlameLoader(height: 96),
            const SizedBox(height: 22),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                final t = Curves.easeInOut.transform(
                  ((_ctrl.value < 0.5 ? _ctrl.value : 1 - _ctrl.value) * 2)
                      .clamp(0.0, 1.0),
                );
                return Transform.translate(
                  offset: Offset(0, -6 + t * 12),
                  child: child,
                );
              },
              child: Container(
                width: 180,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: SpyceColors.blush,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: SpyceColors.pink.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SpyceColors.pink.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      color: SpyceColors.pinkSoft.withValues(alpha: 0.9),
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 8,
                      width: 110,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: SpyceColors.dark100,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
