import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/spyce_colors.dart';

/// Zero-Cost Community Photo Guidelines Sheet
/// Mandatory Store Compliance check before photo upload
class PhotoGuidelinesSheet {
  static const String _prefKey = 'photo_guidelines_accepted_v1';

  static Future<bool> ensureAccepted(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool(_prefKey) ?? false;
    if (accepted) return true;

    if (!context.mounted) return false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: SpyceColors.dark900,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _GuidelinesContent(),
    );

    if (result == true) {
      await prefs.setBool(_prefKey, true);
      return true;
    }
    return false;
  }
}

class _GuidelinesContent extends StatelessWidget {
  const _GuidelinesContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SpyceColors.pink.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: SpyceColors.pink,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Community Photo Rules',
                  style: GoogleFonts.syne(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'To keep our community safe, verified, and welcoming, all photos must follow these rules:',
              style: TextStyle(color: SpyceColors.dark100, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            _buildRuleItem(
              icon: Icons.no_adult_content,
              title: 'No Explicit or Nude Content',
              desc: 'No nudity, suggestive underwear, or sexually explicit photos.',
            ),
            const SizedBox(height: 12),
            _buildRuleItem(
              icon: Icons.face,
              title: 'Must Show Your Face Clearly',
              desc: 'Photos should be of you. No celebrities, memes, or stock photos.',
            ),
            const SizedBox(height: 12),
            _buildRuleItem(
              icon: Icons.shield,
              title: 'No Violence or Weapons',
              desc: 'No weapons, gore, drugs, or hate symbols.',
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: SpyceColors.pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'I Understand & Agree',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: SpyceColors.dark100),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildRuleItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: SpyceColors.teal, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  color: SpyceColors.dark100,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
