import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/onboarding_theme.dart';
import '../../../data/models/user_models.dart';
import '../../../shared/widgets/onboarding_widgets.dart';

class BioPhotoStep extends StatelessWidget {
  const BioPhotoStep({
    super.key,
    required this.bioCtrl,
    required this.minBioLen,
    required this.photos,
    required this.isUploadingPhoto,
    required this.onBioChanged,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  final TextEditingController bioCtrl;
  final int minBioLen;
  final List<ProfileImage> photos;
  final bool isUploadingPhoto;
  final VoidCallback onBioChanged;
  final VoidCallback onAddPhoto;
  final ValueChanged<String> onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final bioLen = bioCtrl.text.trim().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OnboardingSectionTitle('YOUR BIO'),
        const SizedBox(height: 16),

        // Tell them your story.
        Center(
          child: Text(
            'Tell them your story.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            OnboardingTextField(
              controller: bioCtrl,
              hintText: 'I\'m the kind of person who...',
              maxLines: 5,
              maxLength: 200,
              onChanged: (_) => onBioChanged(),
            ),
            Positioned(
              bottom: 8,
              right: 12,
              child: Text(
                '$bioLen / 200',
                style: GoogleFonts.dmSans(
                  color: bioLen >= minBioLen
                      ? OnboardingColors.textSecondary
                      : OnboardingColors.sectionRed,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Add a Photo.
        Center(
          child: Text(
            'Add a Photo.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: OnboardingHelperText('Optional - You can add Pics later on Profile'),
        ),
        const SizedBox(height: 16),

        // Photo Upload Box / Grid
        Center(child: _buildPhotoArea()),
      ],
    );
  }

  Widget _buildPhotoArea() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        ...photos.map((photo) {
          final url = photo.imageUrl.trim();
          return Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: OnboardingColors.inputBorder),
                  color: OnboardingColors.inputFill,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: url.startsWith('http') || url.startsWith('file')
                      ? CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                          ),
                        )
                      : Image.file(
                          File(url),
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => onRemovePhoto(photo.id),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xB3000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),

        if (photos.length < 5)
          GestureDetector(
            onTap: isUploadingPhoto ? null : onAddPhoto,
            child: CustomPaint(
              painter: _DashedRectPainter(color: Colors.white54),
              child: Container(
                width: 90,
                height: 90,
                alignment: Alignment.center,
                child: isUploadingPhoto
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      )
                    : const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 32,
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 4.0;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final len = (distance + dashWidth < metric.length)
            ? dashWidth
            : metric.length - distance;
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}
