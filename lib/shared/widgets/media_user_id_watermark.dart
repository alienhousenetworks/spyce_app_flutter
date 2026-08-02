import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Light media watermark: stamps the **viewer's username** only (never UUID),
/// with a few diagonal stamps — anti-leak without a heavy overlay.
/// Always pass the logged-in user's username, not the media owner.
class MediaUserIdWatermark extends StatelessWidget {
  const MediaUserIdWatermark({
    super.key,
    required this.child,
    this.username,
    this.dense = false,
    /// Kept for API compatibility; unused — never stamp raw user ids.
    @Deprecated('Do not pass user ids; watermark uses username only')
    this.userId,
  });

  /// Preferred stamp — display username without @. No id fallback.
  final String? username;

  /// Ignored (legacy). Watermark never shows user ids.
  @Deprecated('Do not pass user ids; watermark uses username only')
  final String? userId;

  final Widget child;
  final bool dense;

  /// Username only — strip leading @; empty → no stamp (never UUID).
  String get _stamp {
    final u = (username ?? '').trim().replaceFirst(RegExp(r'^@+'), '');
    return u;
  }

  @override
  Widget build(BuildContext context) {
    final stamp = _stamp;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        if (stamp.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SparseUsernameWatermarkPainter(
                  text: stamp,
                  dense: dense,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Only **3** diagonal stamps (or 2 when dense) — not a full tile grid.
class _SparseUsernameWatermarkPainter extends CustomPainter {
  _SparseUsernameWatermarkPainter({
    required this.text,
    required this.dense,
  });

  final String text;
  final bool dense;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || text.isEmpty) return;

    final fontSize = dense ? 12.0 : 15.0;
    // Stronger contrast so the stamp is readable on photos
    final style = TextStyle(
      color: Colors.white.withValues(alpha: dense ? 0.42 : 0.48),
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
    );
    final shadowStyle = style.copyWith(
      color: Colors.black.withValues(alpha: 0.45),
    );

    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final shadowTp = TextPainter(
      text: TextSpan(text: text, style: shadowStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    // Exactly 2–3 positions across the media
    final points = dense
        ? <Offset>[
            Offset(size.width * 0.28, size.height * 0.35),
            Offset(size.width * 0.62, size.height * 0.68),
          ]
        : <Offset>[
            Offset(size.width * 0.22, size.height * 0.28),
            Offset(size.width * 0.55, size.height * 0.52),
            Offset(size.width * 0.35, size.height * 0.78),
          ];

    canvas.save();
    for (final p in points) {
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(-math.pi / 7); // ~-25°
      shadowTp.paint(canvas, Offset(-tp.width / 2 + 1.5, -tp.height / 2 + 1.5));
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SparseUsernameWatermarkPainter old) {
    return old.text != text || old.dense != dense;
  }
}
