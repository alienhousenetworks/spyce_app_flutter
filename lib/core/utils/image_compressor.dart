import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Utility to compress, resize, and convert user images to WebP format by target KB size.
class ImageCompressor {
  ImageCompressor._();

  /// Compresses [file] to WebP format, targeting [targetMaxKb] (default 200 KB).
  ///
  /// - Resizes dimensions to max [maxWidth] x [maxHeight] (default 1080 x 1350).
  /// - Automatically encodes to high-efficiency WebP format.
  /// - Iteratively reduces quality until file size is under [targetMaxKb] or [minQuality] is reached.
  static Future<File> compressToWebp(
    File file, {
    int targetMaxKb = 200,
    int maxWidth = 1080,
    int maxHeight = 1350,
    int initialQuality = 85,
    int minQuality = 35,
  }) async {
    try {
      final originalBytes = await file.length();
      final originalKb = (originalBytes / 1024.0).toStringAsFixed(1);

      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}_${file.path.hashCode.abs()}.webp';

      var quality = initialQuality;
      XFile? compressedXFile;

      while (quality >= minQuality) {
        compressedXFile = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          format: CompressFormat.webp,
          quality: quality,
          minWidth: maxWidth,
          minHeight: maxHeight,
          keepExif: false,
        );

        if (compressedXFile == null) break;

        final compressedBytes = await compressedXFile.length();
        final compressedKb = compressedBytes / 1024.0;

        debugPrint(
          '📸 [ImageCompressor] Quality $quality%: ${compressedKb.toStringAsFixed(1)} KB '
          '(target: <= $targetMaxKb KB)',
        );

        if (compressedKb <= targetMaxKb) {
          debugPrint(
            '✅ [ImageCompressor] Success: Reduced from ${originalKb} KB to '
            '${compressedKb.toStringAsFixed(1)} KB (WebP quality $quality%)',
          );
          return File(compressedXFile.path);
        }

        quality -= 15;
      }

      if (compressedXFile != null) {
        final finalBytes = await compressedXFile.length();
        debugPrint(
          'ℹ️ [ImageCompressor] Final result: ${(finalBytes / 1024.0).toStringAsFixed(1)} KB (WebP)',
        );
        return File(compressedXFile.path);
      }

      debugPrint('⚠️ [ImageCompressor] Compression returned null, falling back to original file.');
      return file;
    } catch (e, stack) {
      debugPrint('🔴 [ImageCompressor] Error during compression: $e\n$stack');
      return file;
    }
  }
}
