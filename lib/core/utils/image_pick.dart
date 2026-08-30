import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/spyce_colors.dart';

/// Android 13+ / iOS 14+ system photo pickers do not need library permission.
/// Requesting [Permission.photos] and bailing on deny is what blocked uploads.
Future<bool> canUseSystemPhotoPicker() async {
  if (Platform.isIOS) return true;
  if (Platform.isAndroid) {
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt >= 33;
  }
  return true;
}

Future<bool> ensureCameraPermission(BuildContext context) async {
  final status = await Permission.camera.request();
  if (status.isGranted || status.isLimited) return true;
  if (!context.mounted) return false;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Camera permission is required to take a photo'),
      action: status.isPermanentlyDenied
          ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
          : null,
    ),
  );
  return false;
}

Future<bool> ensureGalleryPermission(BuildContext context) async {
  if (await canUseSystemPhotoPicker()) return true;

  PermissionStatus status = await Permission.photos.request();
  if (status.isGranted || status.isLimited) return true;
  status = await Permission.storage.request();
  if (status.isGranted || status.isLimited) return true;
  if (!context.mounted) return false;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Photo library permission is required'),
      action: status.isPermanentlyDenied
          ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
          : null,
    ),
  );
  return false;
}

Future<ImageSource?> chooseImageSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: SpyceColors.dark800,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: SpyceColors.dark500,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: SpyceColors.pinkSoft),
              title: const Text(
                'Take a photo',
                style: TextStyle(
                  color: SpyceColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: SpyceColors.pinkSoft),
              title: const Text(
                'Choose from gallery',
                style: TextStyle(
                  color: SpyceColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: SpyceColors.dark200),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<XFile?> pickProfileImage(
  BuildContext context, {
  ImageSource? source,
}) async {
  final chosen = source ?? await chooseImageSource(context);
  if (chosen == null || !context.mounted) return null;

  if (chosen == ImageSource.camera) {
    final ok = await ensureCameraPermission(context);
    if (!ok || !context.mounted) return null;
  } else {
    final ok = await ensureGalleryPermission(context);
    if (!ok || !context.mounted) return null;
  }

  try {
    return ImagePicker().pickImage(
      source: chosen,
      maxWidth: 1080,
      maxHeight: 1350,
      imageQuality: 78,
      preferredCameraDevice: CameraDevice.front,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open photos: $e')),
      );
    }
    return null;
  }
}
