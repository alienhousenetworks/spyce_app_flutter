import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/spyce_colors.dart';
import '../../data/repositories/api_repositories.dart';
import '../onboarding/face_liveness_screen.dart';

class IdentityVerificationPage extends ConsumerStatefulWidget {
  const IdentityVerificationPage({super.key});

  @override
  ConsumerState<IdentityVerificationPage> createState() =>
      _IdentityVerificationPageState();
}

class _IdentityVerificationPageState
    extends ConsumerState<IdentityVerificationPage> {
  bool loading = true;
  String? error;
  FaceVerificationConfig? config;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final cfg = await ref.read(verificationRepositoryProvider).getConfig();
      if (!mounted) return;
      setState(() {
        config = cfg;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = '$e';
      });
    }
  }

  Future<void> _verify() async {
    final cfg = config;
    if (cfg == null) return;
    if (cfg.useRealAws) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const FaceLivenessScreen(),
        ),
      );
      if (ok == true) await _load();
      return;
    }
    try {
      await ref.read(verificationRepositoryProvider).mockComplete();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification complete')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final verified = config?.verified == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Icon(
                  verified ? Icons.verified_rounded : Icons.face_retouching_natural,
                  size: 56,
                  color: verified ? SpyceColors.success : SpyceColors.pinkSoft,
                ),
                const SizedBox(height: 16),
                Text(
                  verified ? 'You are verified' : 'Verify your face',
                  style: GoogleFonts.syne(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: SpyceColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  verified
                      ? 'Face liveness is complete. You can appear on Discover.'
                      : 'A short liveness check keeps SPYCE real. This is required to stay on Discover.',
                  style: const TextStyle(color: SpyceColors.dark100, height: 1.4),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: SpyceColors.error)),
                ],
                const SizedBox(height: 24),
                if (!verified)
                  ElevatedButton(
                    onPressed: _verify,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: SpyceColors.pink,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Start face verification'),
                  )
                else
                  OutlinedButton(
                    onPressed: _load,
                    child: const Text('Refresh status'),
                  ),
              ],
            ),
    );
  }
}
