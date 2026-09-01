import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/env.dart';
import '../../core/legal/legal_urls.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/spyce_colors.dart';
import '../../data/repositories/api_repositories.dart';

class DpdpConsentPage extends ConsumerStatefulWidget {
  const DpdpConsentPage({
    super.key,
    this.requiredToContinue = false,
  });

  final bool requiredToContinue;

  @override
  ConsumerState<DpdpConsentPage> createState() => _DpdpConsentPageState();
}

class _DpdpConsentPageState extends ConsumerState<DpdpConsentPage> {
  bool loading = true;
  bool saving = false;
  String? error;
  bool matchmaking = true;
  bool location = true;
  bool sensitive = true;
  bool marketing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(authRepositoryProvider).getDpdpConsent();
      if (!mounted) return;
      setState(() {
        loading = false;
        if (data['has_consented'] == true) {
          matchmaking = data['matchmaking_consent'] != false;
          location = data['location_processing_consent'] != false;
          sensitive = data['sensitive_data_consent'] != false;
          marketing = data['marketing_consent'] == true;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _submit() async {
    if (!matchmaking || !location || !sensitive) {
      setState(() {
        error =
            'Matchmaking, location, and sensitive-data consent are required to use SPYCE.';
      });
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref.read(authRepositoryProvider).submitDpdpConsent(
            matchmaking: matchmaking,
            location: location,
            sensitive: sensitive,
            marketing: marketing,
          );
      if (!mounted) return;
      if (widget.requiredToContinue) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consent saved')),
        );
        context.pop();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy consent'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () {
            if (widget.requiredToContinue) {
              Navigator.of(context).pop(false);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'DPDP Act, 2023',
                  style: GoogleFonts.syne(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: SpyceColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      color: SpyceColors.dark100,
                      height: 1.4,
                      fontSize: 14,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            'SPYCE needs your consent to process personal data for dating. Read our ',
                      ),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: const TextStyle(
                          color: SpyceColors.pinkSoft,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = openPrivacyPolicy,
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Terms',
                        style: const TextStyle(
                          color: SpyceColors.pinkSoft,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = openTermsOfService,
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _switch(
                  title: 'Matchmaking',
                  subtitle:
                      'Required. Profile, likes, matches, chat, and ranking.',
                  value: matchmaking,
                  onChanged: (v) => setState(() => matchmaking = v),
                ),
                _switch(
                  title: 'Location',
                  subtitle:
                      'Required. Nearby people and confessions. Exact GPS is never shown to others.',
                  value: location,
                  onChanged: (v) => setState(() => location = v),
                ),
                _switch(
                  title: 'Sensitive personal data',
                  subtitle:
                      'Required. Gender, sexuality, photos, and face verification.',
                  value: sensitive,
                  onChanged: (v) => setState(() => sensitive = v),
                ),
                _switch(
                  title: 'Product updates (optional)',
                  subtitle: 'Occasional emails or pushes about SPYCE. Off by default.',
                  value: marketing,
                  onChanged: (v) => setState(() => marketing = v),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: SpyceColors.error)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: SpyceColors.pink,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(saving ? 'Saving…' : 'I agree and continue'),
                ),
                const SizedBox(height: 10),
                Text(
                  'Consent version ${Env.dpdpConsentVersion}. Withdraw by deleting your account.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SpyceColors.dark300, fontSize: 11),
                ),
              ],
            ),
    );
  }

  Widget _switch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: SpyceColors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: SpyceColors.dark200, fontSize: 12)),
      value: value,
      activeThumbColor: SpyceColors.pink,
      onChanged: onChanged,
    );
  }
}
