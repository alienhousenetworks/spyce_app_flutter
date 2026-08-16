import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/onboarding_theme.dart';
import '../../../shared/widgets/onboarding_widgets.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const OnboardingSectionTitle('FACE VERIFICATION'),
        const SizedBox(height: 16),

        Text(
          'Live face check',
          textAlign: TextAlign.center,
          style: GoogleFonts.syne(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'It helps SPYCE be a genuine & respectful space for everyone.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: OnboardingColors.textSecondary,
            fontSize: 12,
            height: 1.35,
          ),
        ),

        const SizedBox(height: 32),

        // Face Verification Target Box (Corner brackets + Dashed Red Circle with Smile Face)
        SizedBox(
          width: 170,
          height: 170,
          child: CustomPaint(
            painter: _CornerBracketsPainter(color: Colors.white.withValues(alpha: 0.8)),
            child: Center(
              child: CustomPaint(
                painter: _DashedCirclePainter(color: OnboardingColors.sectionRed),
                child: Container(
                  width: 100,
                  height: 100,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.sentiment_satisfied_alt_outlined,
                    size: 52,
                    color: OnboardingColors.sectionRed,
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        Text(
          'Hold your face in frame. We use a short liveness check so profiles stay real',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: OnboardingColors.textSecondary,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
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
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - len), paint);

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
  bool shouldRepaint(covariant _CornerBracketsPainter old) => old.color != color;
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

    const radius = 54.0;
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
