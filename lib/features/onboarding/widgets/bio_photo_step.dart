import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/onboarding_theme.dart';
import '../../../core/theme/spyce_colors.dart';
import '../../../data/models/user_models.dart';
import '../../../shared/widgets/onboarding_widgets.dart';
import '../../../shared/widgets/spyce_loaders.dart';
import '../../../shared/widgets/turn_on_stickers.dart';

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
    required this.locationLoading,
    required this.locationReady,
    this.locationCity,
    this.locationHint,
    required this.onDetectLocation,
    required this.turnOnOpts,
    required this.selectedTurnOns,
    required this.onTurnOnsChanged,
    this.minTurnOns = 3,
    required this.hotTakeCtrls,
    required this.onHotTakesChanged,
  });

  final TextEditingController bioCtrl;
  final int minBioLen;
  final List<ProfileImage> photos;
  final bool isUploadingPhoto;
  final VoidCallback onBioChanged;
  final VoidCallback onAddPhoto;
  final ValueChanged<String> onRemovePhoto;
  final bool locationLoading;
  final bool locationReady;
  final String? locationCity;
  final String? locationHint;
  final VoidCallback onDetectLocation;
  final List<CatalogOption> turnOnOpts;
  final Set<String> selectedTurnOns;
  final ValueChanged<Set<String>> onTurnOnsChanged;
  final int minTurnOns;
  final List<TextEditingController> hotTakeCtrls;
  final VoidCallback onHotTakesChanged;

  @override
  Widget build(BuildContext context) {
    final bioLen = bioCtrl.text.trim().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OnboardingFieldLabel('Your bio'),
        Stack(
          children: [
            OnboardingTextField(
              controller: bioCtrl,
              hintText: "I'm the kind of person who...",
              maxLines: 5,
              maxLength: 200,
              onChanged: (_) => onBioChanged(),
            ),
            Positioned(
              bottom: 10,
              right: 14,
              child: Text(
                '$bioLen / 200',
                style: GoogleFonts.dmSans(
                  color: bioLen >= minBioLen
                      ? OnboardingColors.textSecondary
                      : OnboardingColors.sectionRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        OnboardingHelperText(
          bioLen < minBioLen
              ? 'At least $minBioLen characters ($bioLen/$minBioLen)'
              : 'Looks good',
        ),

        const SizedBox(height: 28),
        const OnboardingFieldLabel('Your location'),
        const OnboardingHelperText('Required — so we can show people near you'),
        const SizedBox(height: 10),
        _LocationCard(
          loading: locationLoading,
          ready: locationReady,
          city: locationCity,
          hint: locationHint,
          onDetect: onDetectLocation,
        ),

        const SizedBox(height: 28),
        const OnboardingFieldLabel('Photos'),
        const OnboardingHelperText(
          'Optional — you can add more later on your profile',
        ),
        const SizedBox(height: 14),
        _PhotoGrid(
          photos: photos,
          isUploadingPhoto: isUploadingPhoto,
          onAddPhoto: onAddPhoto,
          onRemovePhoto: onRemovePhoto,
        ),

        const SizedBox(height: 28),
        const OnboardingFieldLabel('Turn-ons'),
        OnboardingHelperText(
          selectedTurnOns.length < minTurnOns
              ? 'Pick at least $minTurnOns (${selectedTurnOns.length}/$minTurnOns)'
              : '${selectedTurnOns.length} selected',
        ),
        const SizedBox(height: 12),
        if (turnOnOpts.isEmpty)
          Text(
            'Turn-ons unavailable — reconnect and retry.',
            style: GoogleFonts.dmSans(
              color: OnboardingColors.textMuted,
              fontSize: 13,
            ),
          )
        else
          TurnOnStickerPicker(
            options: turnOnOpts,
            selectedIds: selectedTurnOns,
            onChanged: onTurnOnsChanged,
          ),

        const SizedBox(height: 28),
        const OnboardingFieldLabel('Hot takes'),
        const OnboardingHelperText('Optional — up to 3 spicy opinions'),
        const SizedBox(height: 12),
        for (var i = 0; i < hotTakeCtrls.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          OnboardingTextField(
            controller: hotTakeCtrls[i],
            hintText: i == 0
                ? 'e.g. Pineapple belongs on pizza'
                : 'Hot take ${i + 1}',
            maxLines: 2,
            maxLength: 140,
            onChanged: (_) => onHotTakesChanged(),
          ),
        ],
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.loading,
    required this.ready,
    required this.onDetect,
    this.city,
    this.hint,
  });

  final bool loading;
  final bool ready;
  final String? city;
  final String? hint;
  final VoidCallback onDetect;

  @override
  Widget build(BuildContext context) {
    final label = loading
        ? 'Finding your location…'
        : ready
        ? (city != null && city!.isNotEmpty ? city! : 'Location saved')
        : 'Allow location access';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onDetect,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: OnboardingColors.inputFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: ready
                  ? OnboardingColors.successGreen.withValues(alpha: 0.7)
                  : OnboardingColors.inputBorder,
            ),
          ),
          child: Row(
            children: [
              if (loading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  ready
                      ? Icons.location_on_rounded
                      : Icons.location_searching_rounded,
                  color: ready
                      ? OnboardingColors.successGreen
                      : Colors.white.withValues(alpha: 0.85),
                  size: 22,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hint != null && hint!.isNotEmpty && !ready) ...[
                      const SizedBox(height: 2),
                      Text(
                        hint!,
                        style: GoogleFonts.dmSans(
                          color: OnboardingColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!loading)
                Text(
                  ready ? 'Change' : 'Enable',
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.isUploadingPhoto,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  final List<ProfileImage> photos;
  final bool isUploadingPhoto;
  final VoidCallback onAddPhoto;
  final ValueChanged<String> onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final tile = ((constraints.maxWidth - gap * 2) / 3).clamp(88.0, 140.0);
        final slots = <Widget>[
          ...photos.map(
            (photo) => _PhotoTile(
              size: tile,
              photo: photo,
              onRemove: () => onRemovePhoto(photo.id),
            ),
          ),
          if (photos.length < 5)
            _AddTile(
              size: tile,
              uploading: isUploadingPhoto,
              onAdd: onAddPhoto,
            ),
        ];
        return Wrap(spacing: gap, runSpacing: gap, children: slots);
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.size,
    required this.photo,
    required this.onRemove,
  });

  final double size;
  final ProfileImage photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final url = photo.imageUrl.trim();
    final isNetwork =
        url.startsWith('http://') || url.startsWith('https://');
    final filePath = url.startsWith('file:')
        ? Uri.parse(url).toFilePath()
        : url;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: size,
            height: size,
            child: isNetwork
                ? CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const ColoredBox(
                      color: OnboardingColors.inputFill,
                      child: Center(child: SpyceFlameLoader(height: 36)),
                    ),
                    errorWidget: (_, _, _) => const ColoredBox(
                      color: OnboardingColors.inputFill,
                      child: Icon(Icons.broken_image, color: Colors.white54),
                    ),
                  )
                : Image.file(File(filePath), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: SpyceColors.overlay,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.size,
    required this.uploading,
    required this.onAdd,
  });

  final double size;
  final bool uploading;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : onAdd,
      child: CustomPaint(
        painter: _DashedRectPainter(color: Colors.white54),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: uploading
                ? const SpyceFlameLoader(height: 36)
                : const Icon(Icons.add, color: Colors.white, size: 32),
          ),
        ),
      ),
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
