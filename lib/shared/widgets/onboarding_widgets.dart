import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/onboarding_theme.dart';

/// Organic wave painter rendering the target Figma background (burnt orange & navy waves).
class OnboardingWaveBackground extends StatelessWidget {
  const OnboardingWaveBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base dark navy fill
        const ColoredBox(color: OnboardingColors.bgDark),
        // Organic wave custom paint
        CustomPaint(
          size: Size.infinite,
          painter: _WaveBackgroundPainter(),
        ),
        // Dark vignette overlay for content readability
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                OnboardingColors.bgDark.withValues(alpha: 0.4),
                Colors.black.withValues(alpha: 0.2),
                OnboardingColors.bgDark.withValues(alpha: 0.6),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _WaveBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Dark teal wave layer
    final tealPaint = Paint()
      ..color = OnboardingColors.bgWaveTeal
      ..style = PaintingStyle.fill;

    final tealPath = Path()
      ..moveTo(0, h * 0.15)
      ..cubicTo(w * 0.3, h * 0.05, w * 0.6, h * 0.25, w, h * 0.18)
      ..lineTo(w, h * 0.7)
      ..cubicTo(w * 0.5, h * 0.85, w * 0.2, h * 0.6, 0, h * 0.75)
      ..close();
    canvas.drawPath(tealPath, tealPaint);

    // Burnt Orange right-side wave layer (Figma signature shape)
    final orangePaint = Paint()
      ..color = OnboardingColors.bgWaveOrange
      ..style = PaintingStyle.fill;

    final orangePath = Path()
      ..moveTo(w * 0.85, h * 0.25)
      ..cubicTo(w * 0.6, h * 0.35, w * 0.65, h * 0.55, w * 0.8, h * 0.7)
      ..cubicTo(w * 0.95, h * 0.82, w * 0.75, h * 0.92, w, h * 0.88)
      ..lineTo(w, h * 0.25)
      ..close();
    canvas.drawPath(orangePath, orangePaint);

    // Burnt Orange bottom-left wave accent
    final orangeLeftPaint = Paint()
      ..color = OnboardingColors.bgWaveOrangeDark.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final orangeLeftPath = Path()
      ..moveTo(0, h * 0.65)
      ..cubicTo(w * 0.4, h * 0.6, w * 0.45, h * 0.85, 0, h * 0.95)
      ..close();
    canvas.drawPath(orangeLeftPath, orangeLeftPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Glassmorphic translucent content card from Figma design.
class OnboardingGlassCard extends StatelessWidget {
  const OnboardingGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: OnboardingColors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: OnboardingColors.cardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 5-Segment top progress bar with back button for onboarding frames.
class OnboardingProgressHeader extends StatelessWidget {
  const OnboardingProgressHeader({
    super.key,
    required this.step,
    required this.totalSteps,
    this.onBack,
  });

  final int step;
  final int totalSteps;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            if (onBack != null)
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            else
              const SizedBox(width: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: List.generate(totalSteps, (i) {
                  final active = i < step;
                  return Expanded(
                    child: Container(
                      height: 5,
                      margin: EdgeInsets.only(right: i == totalSteps - 1 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Red/coral uppercase section heading (e.g. YOUR IDENTITY).
class OnboardingSectionTitle extends StatelessWidget {
  const OnboardingSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.syne(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: OnboardingColors.sectionRed,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

/// Muted helper text with diamond bullet (e.g. ✦ this is how you'll appear).
class OnboardingHelperText extends StatelessWidget {
  const OnboardingHelperText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '✦ ',
          style: TextStyle(
            color: OnboardingColors.textSecondary,
            fontSize: 11,
          ),
        ),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.dmSans(
              color: OnboardingColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Input field styled with dark teal fill & thin light border.
class OnboardingTextField extends StatelessWidget {
  const OnboardingTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.labelText,
    this.keyboardType,
    this.textAlign = TextAlign.start,
    this.maxLength,
    this.maxLines = 1,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String? hintText;
  final String? labelText;
  final TextInputType? keyboardType;
  final TextAlign textAlign;
  final int? maxLength;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textAlign: textAlign,
      maxLength: maxLength,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      style: GoogleFonts.dmSans(
        color: OnboardingColors.textPrimary,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        hintStyle: GoogleFonts.dmSans(
          color: OnboardingColors.textPlaceholder,
          fontSize: 14,
        ),
        filled: true,
        fillColor: OnboardingColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OnboardingColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OnboardingColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white, width: 1.5),
        ),
        counterText: '',
      ),
    );
  }
}

/// Dropdown selector control matching Figma (pill field with down arrow ∨).
class OnboardingDropdownField extends StatelessWidget {
  const OnboardingDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayText = (value != null && value!.isNotEmpty) ? value! : label;
    final isSelected = value != null && value!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: OnboardingColors.inputFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: OnboardingColors.inputBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayText,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: isSelected
                      ? OnboardingColors.textPrimary
                      : OnboardingColors.textPlaceholder,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white70,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Primary button control (Dark teal or Red CTA for Face Verification).
class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.isRedAccent = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool isRedAccent;

  @override
  Widget build(BuildContext context) {
    final bgColor = isRedAccent
        ? OnboardingColors.accentRed
        : OnboardingColors.inputFill;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          disabledBackgroundColor: OnboardingColors.buttonDisabled,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: onPressed != null
                  ? (isRedAccent
                      ? OnboardingColors.accentRed
                      : OnboardingColors.inputBorder)
                  : Colors.transparent,
            ),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
