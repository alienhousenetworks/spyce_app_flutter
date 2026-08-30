import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/onboarding_theme.dart';
import '../../core/theme/spyce_colors.dart';

/// Organic wave painter — charcoal + ember atmosphere matching the flame.
class OnboardingWaveBackground extends StatelessWidget {
  const OnboardingWaveBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: OnboardingColors.bgDark),
        // Organic wave custom paint
        CustomPaint(size: Size.infinite, painter: _WaveBackgroundPainter()),
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
        Positioned.fill(child: child),
      ],
    );
  }
}

class _WaveBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final blushPaint = Paint()
      ..color = OnboardingColors.bgWaveTeal
      ..style = PaintingStyle.fill;

    final tealPath = Path()
      ..moveTo(0, h * 0.15)
      ..cubicTo(w * 0.3, h * 0.05, w * 0.6, h * 0.25, w, h * 0.18)
      ..lineTo(w, h * 0.7)
      ..cubicTo(w * 0.5, h * 0.85, w * 0.2, h * 0.6, 0, h * 0.75)
      ..close();
    canvas.drawPath(tealPath, blushPaint);

    final winePaint = Paint()
      ..color = OnboardingColors.bgWaveOrange
      ..style = PaintingStyle.fill;

    final orangePath = Path()
      ..moveTo(w * 0.85, h * 0.25)
      ..cubicTo(w * 0.6, h * 0.35, w * 0.65, h * 0.55, w * 0.8, h * 0.7)
      ..cubicTo(w * 0.95, h * 0.82, w * 0.75, h * 0.92, w, h * 0.88)
      ..lineTo(w, h * 0.25)
      ..close();
    canvas.drawPath(orangePath, winePaint);

    final wineLeftPaint = Paint()
      ..color = OnboardingColors.bgWaveOrangeDark.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final orangeLeftPath = Path()
      ..moveTo(0, h * 0.65)
      ..cubicTo(w * 0.4, h * 0.6, w * 0.45, h * 0.85, 0, h * 0.95)
      ..close();
    canvas.drawPath(orangeLeftPath, wineLeftPaint);
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
        border: Border.all(color: OnboardingColors.cardBorder, width: 1.2),
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
    return Row(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: onBack != null
              ? IconButton(
                  onPressed: onBack,
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Row(
            children: List.generate(totalSteps, (i) {
              final filled = i < step;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 4,
                  margin: EdgeInsets.only(right: i == totalSteps - 1 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: filled
                        ? SpyceColors.pink
                        : Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$step/$totalSteps',
          style: GoogleFonts.dmSans(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Full-screen onboarding chrome: wave background, progress, large title,
/// scrollable body, and a pinned bottom CTA. Keyboard-aware.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.body,
    this.step,
    this.totalSteps = 5,
    this.onBack,
    this.title,
    this.subtitle,
    this.primaryLabel,
    this.onPrimary,
    this.primaryLoading = false,
    this.secondaryLabel,
    this.onSecondary,
    this.error,
    this.footer,
    this.showProgress = false,
    this.bodyPadding = const EdgeInsets.fromLTRB(24, 8, 24, 12),
  });

  final Widget body;
  final int? step;
  final int totalSteps;
  final VoidCallback? onBack;
  final String? title;
  final String? subtitle;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryLoading;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? error;
  final Widget? footer;
  final bool showProgress;
  final EdgeInsetsGeometry bodyPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: OnboardingColors.bgDark,
      body: OnboardingWaveBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                child: showProgress && step != null
                    ? OnboardingProgressHeader(
                        step: step!,
                        totalSteps: totalSteps,
                        onBack: onBack,
                      )
                    : Row(
                        children: [
                          if (onBack != null)
                            IconButton(
                              onPressed: onBack,
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            )
                          else
                            const SizedBox(height: 40),
                        ],
                      ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: bodyPadding,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null) ...[
                        Text(
                          title!,
                          style: GoogleFonts.syne(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.15,
                            letterSpacing: -0.4,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            subtitle!,
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              height: 1.4,
                              color: OnboardingColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                      ],
                      body,
                    ],
                  ),
                ),
              ),
              if (error != null && error!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: SpyceColors.error,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              if (primaryLabel != null || footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child:
                      footer ??
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OnboardingPrimaryButton(
                            label: primaryLabel!,
                            onPressed: onPrimary,
                            loading: primaryLoading,
                          ),
                          if (secondaryLabel != null) ...[
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: onSecondary,
                              child: Text(
                                secondaryLabel!,
                                style: GoogleFonts.dmSans(
                                  color: OnboardingColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small uppercase / emphasis label above a field.
class OnboardingFieldLabel extends StatelessWidget {
  const OnboardingFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// Selectable pill used for gender, sexuality, intent, match prefs.
class OnboardingChoiceChip extends StatelessWidget {
  const OnboardingChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: selected
                ? SpyceColors.pink.withValues(alpha: 0.22)
                : OnboardingColors.inputFill.withValues(alpha: 0.85),
            border: Border.all(
              color: selected ? SpyceColors.pink : OnboardingColors.inputBorder,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (locked) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.lock_rounded,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ],
            ],
          ),
        ),
      ),
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
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: '✦  ',
            style: TextStyle(
              color: OnboardingColors.textSecondary,
              fontSize: 11,
            ),
          ),
          TextSpan(
            text: text,
            style: GoogleFonts.dmSans(
              color: OnboardingColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Input field styled with dark teal fill & thin light border.
class OnboardingTextField extends StatelessWidget {
  const OnboardingTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.keyboardType,
    this.textAlign = TextAlign.start,
    this.maxLength,
    this.maxLines = 1,
    this.onChanged,
    this.readOnly = false,
    this.obscureText = false,
    this.suffixIcon,
    this.onTap,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final TextInputType? keyboardType;
  final TextAlign textAlign;
  final int? maxLength;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final bool obscureText;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textAlign: textAlign,
      maxLength: maxLength,
      maxLines: obscureText ? 1 : maxLines,
      obscureText: obscureText,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
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
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: OnboardingColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
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
          borderSide: const BorderSide(color: SpyceColors.pink, width: 1.5),
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

/// Primary CTA — always brand flame (matches the fire loader).
class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: SpyceColors.pink,
          disabledBackgroundColor: OnboardingColors.buttonDisabled,
          foregroundColor: SpyceColors.white,
          elevation: 0,
          shadowColor: SpyceColors.pink.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
