import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/services/iap_service.dart';
import '../../core/theme/spyce_colors.dart';
import '../../data/models/user_models.dart';
import '../../shared/widgets/spyce_widgets.dart';

class SubscriptionPaywall extends ConsumerStatefulWidget {
  const SubscriptionPaywall({
    super.key,
    this.status,
    this.onPurchase,
    this.allowClose = true,
    this.title = 'Unlock SPYCE Premium',
    this.subtitle =
        'Keep discovering, matching, and chatting without interruption.',
  });

  final SubscriptionStatus? status;
  final Future<void> Function()? onPurchase;
  final bool allowClose;
  final String title;
  final String subtitle;

  @override
  ConsumerState<SubscriptionPaywall> createState() => _SubscriptionPaywallState();
}

class _SubscriptionPaywallState extends ConsumerState<SubscriptionPaywall> {
  bool _loading = false;
  int _selectedPackageIndex = 0;
  List<ProductDetails> _products = [];

  // Default store SKUs configured for Apple StoreKit & Google Play
  static const _storeProductIds = {
    'spyce_premium_monthly',
    'spyce_call_pass_1hr',
    'spyce_call_pass_6hr',
  };

  @override
  void initState() {
    super.initState();
    _loadStoreProducts();
  }

  Future<void> _loadStoreProducts() async {
    setState(() => _loading = true);
    try {
      final iap = ref.read(iapServiceProvider);
      final products = await iap.loadProducts(_storeProductIds);
      if (mounted) {
        setState(() {
          _products = products;
        });
      }
    } catch (e) {
      debugPrint('[Paywall] Failed to load store products: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleStorePurchase() async {
    setState(() => _loading = true);
    try {
      final iap = ref.read(iapServiceProvider);
      if (_products.isNotEmpty && _selectedPackageIndex < _products.length) {
        final product = _products[_selectedPackageIndex];
        if (product.id.contains('pass') || product.id.contains('pkg')) {
          await iap.buyPass(product);
        } else {
          await iap.buySubscription(product);
        }
      } else if (widget.onPurchase != null) {
        await widget.onPurchase!();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
              const SizedBox(height: 12),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [SpyceColors.pink, SpyceColors.gold],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SpyceColors.pink.withValues(alpha: 0.4),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: const Icon(Icons.workspace_premium, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.syne(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: SpyceColors.dark100,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _Benefit('Unlimited scroll discovery & matches'),
              _Benefit('Direct Apple & Google Play Store billing'),
              _Benefit('Voice & video call access'),
              const SizedBox(height: 20),

              // Package selection cards
              if (_products.isNotEmpty) ...[
                Column(
                  children: List.generate(_products.length, (idx) {
                    final p = _products[idx];
                    final isSelected = _selectedPackageIndex == idx;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedPackageIndex = idx),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? SpyceColors.dark800 : SpyceColors.dark900,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? SpyceColors.pink : SpyceColors.dark700,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isSelected ? SpyceColors.pink : SpyceColors.dark400,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    p.description,
                                    style: TextStyle(
                                      color: SpyceColors.dark300,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              p.price,
                              style: GoogleFonts.syne(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: SpyceColors.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ] else ...[
                // Fallback display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SpyceColors.dark800,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: SpyceColors.pink.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        price != null
                            ? '$currency ${price.toStringAsFixed(0)}'
                            : '1-Month Pass',
                        style: GoogleFonts.syne(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: SpyceColors.gold,
                        ),
                      ),
                      Text(
                        'for $days days pass',
                        style: const TextStyle(color: SpyceColors.dark100, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),
              SpycePrimaryButton(
                label: Platform.isIOS
                    ? 'Purchase via Apple Store'
                    : 'Purchase via Google Play',
                loading: _loading,
                icon: Icons.lock_outline,
                onPressed: _handleStorePurchase,
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final iap = ref.read(iapServiceProvider);
                  await iap.restorePurchases();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Restoring previous purchases...')),
                    );
                  }
                },
                child: const Text(
                  'Restore purchases from Apple / Google Play',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: SpyceColors.pink,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: SpyceColors.teal, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
