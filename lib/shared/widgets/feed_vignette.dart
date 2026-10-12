import 'package:flutter/material.dart';

/// Dark fade at the top and bottom edges of the Discover feed.
class FeedVignette extends StatelessWidget {
  const FeedVignette({super.key, this.height = 90});

  final double height;

  @override
  Widget build(BuildContext context) {
    final solid = Colors.black;
    final clear = Colors.black.withValues(alpha: 0);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [solid, clear],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [solid, clear],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
