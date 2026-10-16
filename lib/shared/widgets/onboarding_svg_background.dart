import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Full-screen wallpaper behind onboarding / sign-up screens.
class OnboardingSvgBackground extends StatelessWidget {
  const OnboardingSvgBackground({
    super.key,
    required this.child,
    this.asset = 'assets/backgrounds/OnboardingFlowBg.svg',
  });

  final Widget child;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: SvgPicture.asset(
            asset,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        child,
      ],
    );
  }
}