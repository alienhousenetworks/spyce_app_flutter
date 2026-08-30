import 'package:face_liveness_detector/face_liveness_detector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

import '../../core/amplify/amplify_bootstrap.dart';
import '../../core/config/env.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/spyce_colors.dart';
import '../../data/repositories/api_repositories.dart';

/// Native Amazon Rekognition Face Liveness (Amplify UI via face_liveness_detector).
///
/// Industry flow (no WebView required):
/// 1. Amplify Auth → Cognito Identity Pool (guest temp AWS creds)
/// 2. POST /api/v1/verification/start/ → sessionId (Django + REKOGNITION_*)
/// 3. FaceLivenessDetector(sessionId, region) → streams natively to Rekognition
/// 4. POST /api/v1/verification/complete/ → server scores confidence / identity
///
/// Optional fallback: WebView if FACE_LIVENESS_CLIENT_MODE=webview + web URL set.
class FaceLivenessScreen extends ConsumerStatefulWidget {
  const FaceLivenessScreen({super.key});

  @override
  ConsumerState<FaceLivenessScreen> createState() => _FaceLivenessScreenState();
}

class _FaceLivenessScreenState extends ConsumerState<FaceLivenessScreen> {
  String? _sessionId;
  String _region = Env.cognitoRegion;
  String _phase = 'starting'; // starting | detector | completing | done | error
  String? _error;
  bool _completing = false;
  bool _useWebView = false;
  WebViewController? _webController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSession());
  }

  Future<void> _startSession() async {
    setState(() {
      _phase = 'starting';
      _error = null;
      _webController = null;
    });

    try {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) {
        throw ApiException(
          message: 'Camera permission is required for face verification.',
          statusCode: 403,
        );
      }

      final repo = ref.read(verificationRepositoryProvider);
      Map<String, dynamic> statusMap = {};
      try {
        statusMap = await repo.getStatus();
      } catch (_) {
        // Continue with dart-define / defaults if status fails
      }

      final region =
          (statusMap['region'] ??
                  statusMap['cognito_region'] ??
                  Env.cognitoRegion)
              .toString()
              .trim();
      final mode =
          (statusMap['liveness_client_mode'] ?? Env.faceLivenessClientMode)
              .toString()
              .toLowerCase()
              .trim();
      final serverWeb = (statusMap['liveness_web_url'] ?? '').toString().trim();
      final webBase = serverWeb.isNotEmpty
          ? serverWeb
          : Env.faceLivenessWebUrl.trim();

      // Native is default; WebView only when explicitly requested + URL present
      final preferWebView = mode == 'webview' && webBase.isNotEmpty;

      if (!preferWebView) {
        final amplifyOk = await AmplifyBootstrap.configureFromMaps(
          serverStatus: statusMap.isEmpty ? null : statusMap,
        );
        if (!amplifyOk) {
          throw ApiException(
            message:
                AmplifyBootstrap.lastError ??
                'Amplify/Cognito not configured. Set COGNITO_IDENTITY_POOL_ID '
                    'on the server or --dart-define=COGNITO_IDENTITY_POOL_ID=...',
            statusCode: 503,
          );
        }
      }

      // Create session via authenticated Django API (REKOGNITION keys stay server-side)
      final res = await repo.startSession();
      final sid = res['session_id']?.toString() ?? res['sessionId']?.toString();
      if (sid == null || sid.isEmpty) {
        throw ApiException(
          message:
              res['error']?.toString() ??
              'Could not create face liveness session.',
          statusCode: 400,
        );
      }

      if (!mounted) return;

      if (preferWebView) {
        final uri = Uri.parse(webBase).replace(
          queryParameters: {
            ...Uri.parse(webBase).queryParameters,
            'sessionId': sid,
            'region': region.isEmpty ? 'ap-south-1' : region,
          },
        );
        final controller =
            WebViewController(onPermissionRequest: (request) => request.grant())
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..setBackgroundColor(Colors.black)
              ..addJavaScriptChannel(
                'SpyceLiveness',
                onMessageReceived: (msg) => _onWebMessage(msg.message),
              )
              ..loadRequest(uri);

        setState(() {
          _sessionId = sid;
          _region = region.isEmpty ? 'ap-south-1' : region;
          _useWebView = true;
          _webController = controller;
          _phase = 'detector';
        });
      } else {
        setState(() {
          _sessionId = sid;
          _region = region.isEmpty ? 'ap-south-1' : region;
          _useWebView = false;
          _phase = 'detector';
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = 'error';
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = 'error';
        _error = 'Could not start face verification: $e';
      });
    }
  }

  void _onWebMessage(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return;
      final status = data['status']?.toString().toLowerCase();
      if (status == 'complete' || status == 'success' || status == 'done') {
        _onLivenessComplete();
      } else if (status == 'error' || status == 'failed') {
        setState(() {
          _phase = 'error';
          _error =
              data['message']?.toString() ??
              data['error']?.toString() ??
              'Liveness check failed.';
        });
      } else if (status == 'cancel' || status == 'cancelled') {
        Navigator.of(context).pop(false);
      }
    } catch (_) {
      if (raw.toLowerCase().contains('complete')) {
        _onLivenessComplete();
      }
    }
  }

  Future<void> _onLivenessComplete() async {
    if (_completing || _sessionId == null) return;
    _completing = true;
    setState(() => _phase = 'completing');

    try {
      final repo = ref.read(verificationRepositoryProvider);
      final res = await repo.completeSession(_sessionId!);
      final ok =
          res['verified'] == true ||
          res['status']?.toString().toUpperCase() == 'VERIFIED' ||
          res['isLive'] == true;

      if (!mounted) return;
      if (ok) {
        setState(() => _phase = 'done');
        Navigator.of(context).pop(true);
        return;
      }

      final conf = res['liveness'] ?? res['confidence'];
      final reason =
          res['failure_reason']?.toString() ??
          res['error']?.toString() ??
          (conf != null
              ? 'Liveness confidence too low ($conf). Please try again.'
              : 'Face verification failed. Please try again.');

      setState(() {
        _phase = 'error';
        _error = reason;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = 'error';
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = 'error';
        _error = 'Could not confirm verification: $e';
      });
    } finally {
      _completing = false;
    }
  }

  void _onNativeError(String code) {
    setState(() {
      _phase = 'error';
      _error =
          'Face liveness error ($code). Check camera permission, Cognito guest '
          'access, and IAM rekognition:StartFaceLivenessSession on the identity role.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          'Face verification',
          style: GoogleFonts.syne(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case 'starting':
      case 'completing':
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: SpyceColors.pink),
              const SizedBox(height: 16),
              Text(
                _phase == 'starting'
                    ? 'Starting secure face check…'
                    : 'Confirming with server…',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
              ),
            ],
          ),
        );

      case 'detector':
        if (_sessionId == null) {
          return const Center(
            child: Text(
              'Missing session',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        if (_useWebView && _webController != null) {
          return WebViewWidget(controller: _webController!);
        }

        // ✅ Native Amplify Face Liveness UI (Android / iOS)
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Center your face and follow the on-screen lights.\n'
                'This proves a real person is present.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  height: 1.35,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FaceLivenessDetector(
                  sessionId: _sessionId!,
                  region: _region,
                  onComplete: _onLivenessComplete,
                  onError: _onNativeError,
                ),
              ),
            ),
          ],
        );

      case 'error':
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: SpyceColors.error,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Something went wrong',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, height: 1.4),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 12),
                Text(
                  'region=$_region · session=${_sessionId ?? "-"}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _startSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpyceColors.pink,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try again'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
