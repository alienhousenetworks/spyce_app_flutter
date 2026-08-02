import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/spyce_colors.dart';
import '../../data/models/user_models.dart';
import '../../shared/widgets/spyce_widgets.dart';

class SubscriptionPaywall extends StatefulWidget {
  const SubscriptionPaywall({
    super.key,
    this.status,
    required this.onPurchase,
    this.allowClose = true,
    this.title = 'Unlock SPYCE Premium',
    this.subtitle =
        'Keep discovering, matching, and chatting without interruption.',
  });

  final SubscriptionStatus? status;
  final Future<void> Function() onPurchase;
  final bool allowClose;
  final String title;
  final String subtitle;

  @override
  State<SubscriptionPaywall> createState() => _SubscriptionPaywallState();
}

class _SubscriptionPaywallState extends State<SubscriptionPaywall> {
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    final price = s?.price;
    final currency = s?.currency ?? 'INR';
    final days = s?.durationDays ?? 30;

    return Scaffold(
      backgroundColor: SpyceColors.dark950.withValues(alpha: 0.96),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              if (widget.allowClose)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [SpyceColors.pink, SpyceColors.gold],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SpyceColors.pink.withValues(alpha: 0.4),
                      blurRadius: 32,
                    ),
                  ],
                ),
                child: const Icon(Icons.workspace_premium, size: 42),
              ),
              const SizedBox(height: 24),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.syne(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: SpyceColors.dark100,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              _Benefit('Unlimited scroll discovery'),
              _Benefit('See who liked you'),
              _Benefit('Priority in the feed'),
              _Benefit('Voice & video call minutes'),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: SpyceColors.dark800,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: SpyceColors.pink.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      price != null
                          ? '$currency ${price.toStringAsFixed(0)}'
                          : 'Premium plan',
                      style: GoogleFonts.syne(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: SpyceColors.gold,
                      ),
                    ),
                    Text(
                      'for $days days',
                      style: const TextStyle(color: SpyceColors.dark100),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SpycePrimaryButton(
                label: 'Subscribe now',
                loading: loading,
                icon: Icons.bolt,
                onPressed: () async {
                  setState(() => loading = true);
                  try {
                    await widget.onPurchase();
                  } finally {
                    if (mounted) setState(() => loading = false);
                  }
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Restore purchases from Settings if you already subscribed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SpyceColors.dark200,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: SpyceColors.teal, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
