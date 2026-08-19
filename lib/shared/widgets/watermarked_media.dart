import 'package:flutter/material.dart';
import 'media_user_id_watermark.dart';

/// Convenient widget to wrap any media with the viewer's client-side watermark.
/// Avoids server-side image processing CPU overhead while protecting against leaks.
class WatermarkedMedia extends StatelessWidget {
  const WatermarkedMedia({
    super.key,
    required this.child,
    required this.viewerUsername,
    this.dense = false,
  });

  final Widget child;
  final String? viewerUsername;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return MediaUserIdWatermark(
      username: viewerUsername,
      dense: dense,
      child: child,
    );
  }
}
