import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/onboarding_theme.dart';

class FaceVerifyStep extends StatelessWidget {
  const FaceVerifyStep({
    super.key,
    required this.verifying,
    required this.verified,
    required this.realMode,
    required this.onVerify,
  });

  final bool verifying;
  final bool verified;
  final bool realMode;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          SizedBox(
            width: 200,
            height: 200,
            child: CustomPaint(
              painter: _CornerBracketsPainter(
                color: Colors.white.withValues(alpha: 0.8),
              ),
              child: Center(
                child: CustomPaint(
                  painter: _DashedCirclePainter(
                    color: OnboardingColors.sectionRed,
                  ),
                  child: Container(
                    width: 112,
                    height: 112,
                    alignment: Alignment.center,
                    child: verifying
                        ? const SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: OnboardingColors.sectionRed,
                            ),
                          )
                        : Icon(
                            verified
                                ? Icons.verified_rounded
                                : Icons.sentiment_satisfied_alt_outlined,
                            size: 52,
                            color: verified
                                ? OnboardingColors.successGreen
                                : OnboardingColors.sectionRed,
                          ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),
          Text(
            realMode
                ? 'Hold your face in frame. We run a short liveness check so profiles stay real.'
                : 'Hold your face in frame. We use a short check so profiles stay real.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: OnboardingColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerBracketsPainter extends CustomPainter {
  _CornerBracketsPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 22.0;

    // Top-Left
    canvas.drawLine(Offset.zero, const Offset(len, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, len), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);

    // Bottom-Left
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - len),
      paint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - len, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter old) =>
      old.color != color;
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const radius = 64.0;
    final center = Offset(size.width / 2, size.height / 2);

    const dashWidth = 6.0;
    const dashSpace = 4.0;

    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final len = (distance + dashWidth < metric.length)
            ? dashWidth
            : metric.length - distance;
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) => old.color != color;
}
