import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/config/env.dart';
import '../../core/theme/spyce_colors.dart';

/// Cloudflare Turnstile challenge embedded via WebView.
///
/// Tokens are single-use and expire (~300s). After a successful OTP request,
/// call [reset] or remount with a new [resetKey] before the next verify call.
class TurnstileWidget extends StatefulWidget {
  const TurnstileWidget({
    super.key,
    required this.onTokenReceived,
    this.onExpired,
    this.onError,
    this.siteKey,
    this.baseUrl,
    this.resetKey = 0,
    this.height = 72,
  });

  final ValueChanged<String> onTokenReceived;
  final VoidCallback? onExpired;
  final VoidCallback? onError;

  /// Defaults to [Env.turnstileSiteKey].
  final String? siteKey;

  /// Defaults to [Env.turnstileBaseUrl] — must match Turnstile allowed domains.
  final String? baseUrl;

  /// Bump to force a full WebView remount (fresh token after use/expiry).
  final int resetKey;

  final double height;

  @override
  State<TurnstileWidget> createState() => _TurnstileWidgetState();
}

class _TurnstileWidgetState extends State<TurnstileWidget> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  String get _siteKey => (widget.siteKey ?? Env.turnstileSiteKey).trim();
  String get _baseUrl => (widget.baseUrl ?? Env.turnstileBaseUrl).trim();

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant TurnstileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetKey != widget.resetKey ||
        oldWidget.siteKey != widget.siteKey ||
        oldWidget.baseUrl != widget.baseUrl) {
      _initController();
    }
  }

  void _initController() {
    if (_siteKey.isEmpty) {
      setState(() {
        _controller = null;
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'TurnstileChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final msg = message.message.trim();
          if (msg == 'EXPIRED') {
            widget.onExpired?.call();
            return;
          }
          if (msg == 'ERROR') {
            if (mounted) {
              setState(() => _error = 'Captcha failed to load. Pull to retry.');
            }
            widget.onError?.call();
            return;
          }
          if (msg == 'READY') {
            if (mounted) setState(() => _loading = false);
            return;
          }
          if (msg.isNotEmpty) {
            if (mounted) setState(() => _loading = false);
            widget.onTokenReceived(msg);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = 'Captcha unavailable. Check network and try again.';
              });
            }
            widget.onError?.call();
          },
        ),
      )
      ..loadHtmlString(
        _buildHtml(_siteKey),
        baseUrl: _baseUrl.isEmpty ? null : _baseUrl,
      );

    setState(() => _controller = controller);
  }

  String _buildHtml(String siteKey) {
    // Escape for embedding in JS string literals.
    final key = siteKey
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('"', r'\"');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      background: transparent;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100%;
      overflow: hidden;
    }
    #cf-widget { min-height: 65px; }
  </style>
  <script src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit" async defer></script>
</head>
<body>
  <div id="cf-widget"></div>
  <script>
    function post(msg) {
      try { TurnstileChannel.postMessage(msg); } catch (e) {}
    }
    function renderWidget() {
      if (typeof turnstile === 'undefined') {
        setTimeout(renderWidget, 50);
        return;
      }
      try {
        turnstile.render('#cf-widget', {
          sitekey: '$key',
          theme: 'dark',
          size: 'normal',
          callback: function(token) { post(token); },
          'expired-callback': function() { post('EXPIRED'); },
          'error-callback': function() { post('ERROR'); },
          'timeout-callback': function() { post('EXPIRED'); }
        });
        post('READY');
      } catch (e) {
        post('ERROR');
      }
    }
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', renderWidget);
    } else {
      renderWidget();
    }
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    if (_siteKey.isEmpty) {
      return const SizedBox.shrink();
    }

    final controller = _controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (controller != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: WebViewWidget(controller: controller),
                ),
              if (_loading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SpyceColors.pinkSoft,
                  ),
                ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _initController,
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFF6B81),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
