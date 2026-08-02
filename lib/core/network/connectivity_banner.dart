import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Offline / flaky network banner (production offline UX baseline).
class ConnectivityBannerHost extends StatefulWidget {
  const ConnectivityBannerHost({super.key, required this.child});

  final Widget child;

  @override
  State<ConnectivityBannerHost> createState() => _ConnectivityBannerHostState();
}

class _ConnectivityBannerHostState extends State<ConnectivityBannerHost> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.isEmpty ||
          results.every((r) => r == ConnectivityResult.none);
      if (mounted && offline != _offline) {
        setState(() => _offline = offline);
      }
    });
    Connectivity().checkConnectivity().then((results) {
      final offline = results.isEmpty ||
          results.every((r) => r == ConnectivityResult.none);
      if (mounted) setState(() => _offline = offline);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_offline)
          Material(
            color: const Color(0xFF7F1D1D),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You’re offline — some features need a connection.',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

/// Semantic wrapper helpers for a11y (production baseline).
class A11y {
  static Widget button({
    required String label,
    required Widget child,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: child,
    );
  }

  static Widget image({
    required String label,
    required Widget child,
  }) {
    return Semantics(
      image: true,
      label: label,
      child: child,
    );
  }
}
