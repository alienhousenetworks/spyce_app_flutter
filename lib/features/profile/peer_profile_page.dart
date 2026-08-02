import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/spyce_colors.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/api_repositories.dart';
import '../../shared/widgets/media_user_id_watermark.dart';
import '../../shared/widgets/spyce_widgets.dart';
import '../auth/auth_controller.dart';

/// Read-only public profile opened from chat avatar / username.
class PeerProfilePage extends ConsumerStatefulWidget {
  const PeerProfilePage({
    super.key,
    required this.userId,
    this.initialName,
    this.initialImage,
  });

  final String userId;
  final String? initialName;
  final String? initialImage;

  @override
  ConsumerState<PeerProfilePage> createState() => _PeerProfilePageState();
}

class _PeerProfilePageState extends ConsumerState<PeerProfilePage> {
  UserProfile? profile;
  bool loading = true;
  String? error;

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
      final p = await ref
          .read(profileRepositoryProvider)
          .getProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        profile = p;
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.fullDetail;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  void _openImage(String url) {
    final stamp = ref.read(viewerUsernameProvider);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: MediaUserIdWatermark(
                username: stamp,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const SizedBox(
                    height: 240,
                    child: Center(
                      child: CircularProgressIndicator(color: SpyceColors.pink),
                    ),
                  ),
                  errorWidget: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Icon(Icons.broken_image,
                        color: Colors.white54, size: 48),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final title = p?.displayName ??
        widget.initialName ??
        'Profile';
    final hero = p?.displayImageUrl ?? widget.initialImage;

    return Scaffold(
      backgroundColor: SpyceColors.dark900,
      appBar: AppBar(
        backgroundColor: SpyceColors.dark900,
        title: Text(
          title.startsWith('@') ? title : '@$title',
          style: GoogleFonts.syne(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: SpyceColors.pink),
            )
          : error != null && p == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_off_outlined,
                            size: 48, color: Colors.white38),
                        const SizedBox(height: 12),
                        Text(
                          'Could not load profile',
                          style: GoogleFonts.syne(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry',
                              style: TextStyle(color: SpyceColors.pinkSoft)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: SpyceColors.pink,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: hero != null && hero.isNotEmpty
                              ? () => _openImage(hero)
                              : null,
                          child: NetworkAvatar(
                            url: hero,
                            name: title,
                            size: 112,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        p?.age != null
                            ? '${p!.displayName}, ${p.age}'
                            : (p?.displayName ?? title),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (p?.locationSummary != null &&
                          p!.locationSummary != '—') ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_on,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.75)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                p.locationSummary,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (p?.bio != null && p!.bio!.trim().isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            p.bio!,
                            style: GoogleFonts.dmSans(
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.4,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                      if (p != null) ...[
                        const SizedBox(height: 16),
                        _InfoRow(
                          label: 'Gender',
                          value: p.genderLabel ?? '—',
                        ),
                        _InfoRow(
                          label: 'Sexuality',
                          value: p.sexualityLabel ?? '—',
                        ),
                        if (p.languageLabels.isNotEmpty)
                          _InfoRow(
                            label: 'Languages',
                            value: p.languageLabels.join(', '),
                          ),
                        if (p.turnOnLabels.isNotEmpty)
                          _InfoRow(
                            label: 'Turn-ons',
                            value: p.turnOnLabels.join(', '),
                          ),
                      ],
                      if (p != null && p.images.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Photos',
                          style: GoogleFonts.syne(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: p.images.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.78,
                          ),
                          itemBuilder: (context, i) {
                            final img = p.images[i];
                            if (img.imageUrl.isEmpty) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: SpyceColors.dark700,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              );
                            }
                            return GestureDetector(
                              onTap: () => _openImage(img.imageUrl),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: MediaUserIdWatermark(
                                  username:
                                      ref.read(viewerUsernameProvider),
                                  dense: true,
                                  child: CachedNetworkImage(
                                    imageUrl: img.imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => const ColoredBox(
                                      color: SpyceColors.dark700,
                                    ),
                                    errorWidget: (_, __, ___) =>
                                        const ColoredBox(
                                      color: SpyceColors.dark600,
                                      child: Icon(Icons.broken_image,
                                          color: Colors.white38),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: SpyceColors.dark800,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: SpyceColors.dark200,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
