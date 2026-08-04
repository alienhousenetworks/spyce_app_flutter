import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/spyce_colors.dart';
import '../../shared/widgets/spyce_widgets.dart';
import '../auth/auth_controller.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _pulse;
  late final AnimationController _load;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _load = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(parent: _enter, curve: Curves.easeOutBack),
    );
    _slide = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic),
    );
    _enter.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (!mounted) return;
    await Future.wait([
      ref.read(authControllerProvider.notifier).bootstrap(),
      Future.delayed(const Duration(milliseconds: 1800)),
    ]);
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    if (!auth.isLoggedIn) {
      context.go('/auth');
    } else if (auth.onboardingComplete != true) {
      context.go('/onboarding');
    } else {
      context.go('/app/discover');
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    _load.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Pattern layer
          SvgPicture.asset(
            'assets/backgrounds/FlameSpyce.svg',
            fit: BoxFit.cover,
          ),
          // Rich gradient mesh
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.15),
                radius: 1.15,
                colors: [
                  const Color(0xFF1A0A12).withValues(alpha: 0.55),
                  SpyceColors.dark950.withValues(alpha: 0.88),
                  SpyceColors.dark950,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          // Soft brand orbs
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = _pulse.value;
              return Stack(
                children: [
                  Positioned(
                    top: 80 + t * 12,
                    left: -40 + t * 10,
                    child: _GlowOrb(
                      size: 280,
                      color: SpyceColors.pink.withValues(alpha: 0.22),
                    ),
                  ),
                  Positioned(
                    bottom: 60 - t * 10,
                    right: -50,
                    child: _GlowOrb(
                      size: 240,
                      color: const Color(0xFFA855F7).withValues(alpha: 0.16),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.sizeOf(context).height * 0.55,
                    left: MediaQuery.sizeOf(context).width * 0.45,
                    child: _GlowOrb(
                      size: 140,
                      color: SpyceColors.teal.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              );
            },
          ),
          // Center content
          FadeTransition(
            opacity: _fade,
            child: AnimatedBuilder(
              animation: _enter,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slide.value),
                  child: Transform.scale(
                    scale: _scale.value,
                    child: child,
                  ),
                );
              },
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, child) {
                        final glow = 0.25 + _pulse.value * 0.2;
                        return Container(
                          width: 168,
                          height: 168,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                SpyceColors.pink.withValues(alpha: 0.4),
                                const Color(0xFFA855F7).withValues(alpha: 0.2),
                                SpyceColors.pink.withValues(alpha: 0.08),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: SpyceColors.pink.withValues(alpha: glow),
                                blurRadius: 32 + _pulse.value * 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(2),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: SpyceColors.dark900,
                              border: Border.all(
                                color: SpyceColors.pink.withValues(alpha: 0.3),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: child,
                          ),
                        );
                      },
                      child: const SpyceLogo(size: 28),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'no fake vibes. just real ones.',
                      style: GoogleFonts.dmSans(
                        color: SpyceColors.dark100,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: 48,
                      height: 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            SpyceColors.pink.withValues(alpha: 0.9),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'INTENT-FIRST DATING  ·  INDIA FIRST',
                      style: GoogleFonts.dmSans(
                        color: SpyceColors.dark300,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: AnimatedBuilder(
                          animation: _load,
                          builder: (context, _) {
                            return CustomPaint(
                              size: const Size(140, 3),
                              painter: _LoaderPainter(
                                progress: _load.value,
                                color: SpyceColors.pink,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 36,
            child: Text(
              'Spreading everywhere.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: SpyceColors.dark400,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _LoaderPainter extends CustomPainter {
  _LoaderPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(4),
      ),
      track,
    );

    final barW = size.width * 0.38;
    final x = (progress * (size.width + barW)) - barW;
    final rect = Rect.fromLTWH(x, 0, barW, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color,
          SpyceColors.pinkSoft,
          color.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LoaderPainter old) =>
      old.progress != progress || old.color != color;
}
