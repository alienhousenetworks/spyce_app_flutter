import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/env.dart';
import '../../core/legal/legal_urls.dart';
import '../../core/theme/spyce_colors.dart';

enum LegalKind { privacy, terms, community }

class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.kind});

  final LegalKind kind;

  String get _title => switch (kind) {
        LegalKind.privacy => 'Privacy Policy',
        LegalKind.terms => 'Terms of Service',
        LegalKind.community => 'Community Guidelines',
      };

  String get _url => switch (kind) {
        LegalKind.privacy => Env.privacyPolicyUrl,
        LegalKind.terms => Env.termsOfServiceUrl,
        LegalKind.community => Env.communityGuidelinesUrl,
      };

  String get _body => switch (kind) {
        LegalKind.privacy => _privacy,
        LegalKind.terms => _terms,
        LegalKind.community => _community,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => openLegalUrl(_url),
            child: const Text('Open in browser'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Text(
            'SPYCE · 18+',
            style: GoogleFonts.syne(
              color: SpyceColors.pinkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Effective 1 September 2026 · Version 1.0',
            style: TextStyle(color: SpyceColors.dark200, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Text(
            _body,
            style: const TextStyle(
              color: SpyceColors.dark100,
              height: 1.45,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Full document: $_url\n${Env.legalEmail} · ${Env.safetyEmail}',
            style: const TextStyle(color: SpyceColors.dark200, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

const _privacy = '''
This Privacy Policy explains how SPYCE collects and uses personal data.

We collect account email, profile details (including gender, sexuality, photos, and intent), approximate location for nearby discovery, face-liveness results for identity checks, chats/calls metadata, reports, and purchase tokens.

Matchmaking, location, and sensitive-data processing require your DPDP consent. Marketing is optional.

We share data with processors (AWS Rekognition/Cognito/SES, Cloudflare R2, Firebase, Apple/Google stores) and with authorities when legally required, including underage sexual exploitation reports.

You can delete your account in Settings (30-day restore). Contact legal@spycenow.com. SPYCE is strictly 18+.
''';

const _terms = '''
By creating an account you agree to these Terms, the Privacy Policy, and Community Guidelines.

You must be 18+. One person, one account. Face verification is required to appear on Discover.

You grant SPYCE a licence to host and display content you post. Illegal content, CSAM, harassment, and scams are forbidden.

Premium and call packs are billed by Google Play or the App Store. You may delete your account at any time. Governed by the laws of India.
''';

const _community = '''
No minors. No sexual exploitation. No non-consensual intimate images. No hate, threats, spam, or scams.

Use Report and Block. Underage sexual exploitation reports are hidden immediately and reviewed by staff. Appeals: safety@spycenow.com.
''';
