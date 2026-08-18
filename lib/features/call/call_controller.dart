import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/env.dart';
import '../../data/repositories/api_repositories.dart';

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Mirrors frontend CallManager hybrid strategy:
/// 1) Start STUN-only (host / srflx / IPv6) to maximize P2P (~80% target)
/// 2) After delayed_turn_ms from backend (default 3500), inject CoTURN if not connected
/// 3) ICE restart after TURN inject so relay candidates gather
enum CallKind { voice, video }

enum CallPhase {
  idle,
  connecting,
  ringing,
  incoming,
  active,
  ending,
  failed,
}

class CallDiagnostics {
  const CallDiagnostics({
    this.iceState = 'new',
    this.connectionState = 'new',
    this.gatheringState = 'new',
    this.localCandidates = 0,
    this.remoteCandidates = 0,
    this.inboundAudioBytes = 0,
    this.inboundVideoBytes = 0,
    this.selectedLocalType,
    this.selectedRemoteType,
    this.lastSignal,
  });

  final String iceState;
  final String connectionState;
  final String gatheringState;
  final int localCandidates;
  final int remoteCandidates;
  final int inboundAudioBytes;
  final int inboundVideoBytes;
  final String? selectedLocalType;
  final String? selectedRemoteType;
  final String? lastSignal;

  bool get hasInboundMedia =>
      inboundAudioBytes > 0 || inboundVideoBytes > 0;

  String get pathLabel {
    final local = selectedLocalType ?? '';
    final remote = selectedRemoteType ?? '';
    if (local == 'relay' || remote == 'relay') return 'TURN relay';
    if (local.isNotEmpty || remote.isNotEmpty) {
      return 'P2P ${local.isEmpty ? '?' : local}↔${remote.isEmpty ? '?' : remote}';
    }
    return 'no selected pair';
  }

  CallDiagnostics copyWith({
    String? iceState,
    String? connectionState,
    String? gatheringState,
    int? localCandidates,
    int? remoteCandidates,
    int? inboundAudioBytes,
    int? inboundVideoBytes,
    String? selectedLocalType,
    String? selectedRemoteType,
    String? lastSignal,
  }) {
    return CallDiagnostics(
      iceState: iceState ?? this.iceState,
      connectionState: connectionState ?? this.connectionState,
      gatheringState: gatheringState ?? this.gatheringState,
      localCandidates: localCandidates ?? this.localCandidates,
      remoteCandidates: remoteCandidates ?? this.remoteCandidates,
      inboundAudioBytes: inboundAudioBytes ?? this.inboundAudioBytes,
      inboundVideoBytes: inboundVideoBytes ?? this.inboundVideoBytes,
      selectedLocalType: selectedLocalType ?? this.selectedLocalType,
      selectedRemoteType: selectedRemoteType ?? this.selectedRemoteType,
      lastSignal: lastSignal ?? this.lastSignal,
    );
  }
}

class CallUiState {
  const CallUiState({
    this.phase = CallPhase.idle,
    this.kind = CallKind.voice,
    this.callId,
    this.peerId,
    this.peerName,
    this.muted = false,
    this.cameraOn = true,
    this.speakerOn = true,
    this.durationSec = 0,
    this.isP2p,
    this.statusText,
    this.error,
    this.renderersReady = false,
    this.diagnostics = const CallDiagnostics(),
    this.showDiagnostics = false,
  });

  final CallPhase phase;
  final CallKind kind;
  final String? callId;
  final String? peerId;
  final String? peerName;
  final bool muted;
  final bool cameraOn;
  final bool speakerOn;
  final int durationSec;
  final bool? isP2p;
  final String? statusText;
  final String? error;
  final bool renderersReady;
  final CallDiagnostics diagnostics;
  final bool showDiagnostics;

  bool get isLive =>
      phase == CallPhase.active ||
      phase == CallPhase.ringing ||
      phase == CallPhase.incoming ||
      phase == CallPhase.connecting;

  CallUiState copyWith({
    CallPhase? phase,
    CallKind? kind,
    String? callId,
    String? peerId,
    String? peerName,
    bool? muted,
    bool? cameraOn,
    bool? speakerOn,
    int? durationSec,
    bool? isP2p,
    String? statusText,
    String? error,
    bool clearError = false,
    bool? renderersReady,
    CallDiagnostics? diagnostics,
    bool? showDiagnostics,
  }) {
    return CallUiState(
      phase: phase ?? this.phase,
      kind: kind ?? this.kind,
      callId: callId ?? this.callId,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      muted: muted ?? this.muted,
      cameraOn: cameraOn ?? this.cameraOn,
      speakerOn: speakerOn ?? this.speakerOn,
      durationSec: durationSec ?? this.durationSec,
      isP2p: isP2p ?? this.isP2p,
      statusText: statusText ?? this.statusText,
      error: clearError ? null : (error ?? this.error),
      renderersReady: renderersReady ?? this.renderersReady,
      diagnostics: diagnostics ?? this.diagnostics,
      showDiagnostics: showDiagnostics ?? this.showDiagnostics,
    );
  }
}

class CallController extends StateNotifier<CallUiState> {
  CallController(this._ref) : super(const CallUiState());

  final Ref _ref;

  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();

  bool _isInitiator = false;
  bool _turnEscalated = false;
  bool _mediaConnectedSent = false;
  bool _renderersReady = false;
  bool _acceptInFlight = false;
  bool _peerReady = false;
  bool _listening = false;
  bool _hasInboundMedia = false;
  bool _metricsSubmitted = false;
  bool _networkProfileSent = false;
  int _delayedTurnMs = 3500;
  int _setupGeneration = 0;
  int _iceRestartCount = 0;
  int _localCandidateCount = 0;
  int _remoteCandidateCount = 0;
  /// Matches backend RING_TIMEOUT_SECONDS — auto hang-up if no answer.
  static const ringTimeout = Duration(seconds: 90); // 1.5 minutes
  Timer? _turnTimer;
  Timer? _heartbeat;
  Timer? _durationTimer;
  Timer? _failedDismissTimer;
  Timer? _ringTimer;
  Timer? _mediaWatchdog;
  final _pendingRemoteCandidates = <RTCIceCandidate>[];
  final _pendingLocalCandidates = <Map<String, dynamic>>[];
  Map<String, dynamic>? _pendingOffer;
  DateTime? _connectedAt;
  DateTime? _callStartedAt;
  DateTime? _iceConnectedAt;
  String _lastIceState = 'new';
  Future<void> _signalChain = Future<void>.value();

  CallRepository get _calls => _ref.read(callRepositoryProvider);
  AuthRepository get _auth => _ref.read(authRepositoryProvider);

  /// Keep call signaling socket open so we can receive [call.incoming].
  Future<void> startListening() async {
    if (_listening) return;
    _listening = true;
    try {
      await _connectSignaling();
      debugPrint('[CALL] listening for incoming calls');
    } catch (e) {
      debugPrint('[CALL] startListening failed: $e');
      // Retry once later
      Future<void>.delayed(const Duration(seconds: 4), () {
        if (_listening && _ws == null) {
          unawaited(_connectSignaling().catchError((_) {}));
        }
      });
    }
  }

  Future<void> ensureRenderers() async {
    if (_renderersReady) {
      state = state.copyWith(renderersReady: true);
      return;
    }
    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      _renderersReady = true;
      state = state.copyWith(renderersReady: true);
    } catch (e) {
      debugPrint('[CALL] renderer init failed: $e');
      rethrow;
    }
  }

  Future<bool> _permissions(CallKind kind) async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted && !mic.isLimited) return false;
    if (kind == CallKind.video) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted && !cam.isLimited) return false;
    }
    return true;
  }

  /// Outbound call from chat.
  Future<void> startCall({
    required String peerUserId,
    required CallKind kind,
    String? peerName,
  }) async {
    if (state.isLive) return;
    final ok = await _permissions(kind);
    if (!ok) {
      _showFailed(
        'Microphone${kind == CallKind.video ? '/camera' : ''} permission required',
      );
      return;
    }

    try {
      await ensureRenderers();
    } catch (e) {
      _showFailed('Could not start video surface: $e');
      return;
    }

    _isInitiator = true;
    _acceptInFlight = false;
    _metricsSubmitted = false;
    _callStartedAt = DateTime.now();
    await _configureNativeAudio();
    state = state.copyWith(
      phase: CallPhase.connecting,
      kind: kind,
      peerId: peerUserId,
      peerName: peerName,
      statusText: 'Connecting…',
      clearError: true,
    );

    try {
      await _connectSignaling();
      // Join the signaling room before ICE gathering so early candidates
      // are not discarded ("no room") on the server.
      _wsSend({
        'action': 'initiate',
        'callee_id': peerUserId,
        'call_type': kind == CallKind.video ? 'VIDEO' : 'VOICE',
      });
      await _setupPeer(isInitiator: true, kind: kind);
      state = state.copyWith(phase: CallPhase.ringing, statusText: 'Ringing…');
      _startRingTimeout();
    } catch (e, st) {
      debugPrint('[CALL] start failed: $e\n$st');
      await _teardownMedia();
      _showFailed('Could not start call: $e');
    }
  }

  /// Accept inbound call — must not wipe UI on partial failure (felt like a crash).
  Future<void> acceptIncoming() async {
    if (_acceptInFlight) return;
    final callId = state.callId;
    if (callId == null || callId.isEmpty) {
      _showFailed('Missing call id — cannot accept');
      return;
    }
    _cancelRingTimeout();
    _acceptInFlight = true;
    final kind = state.kind;

    final ok = await _permissions(kind);
    if (!ok) {
      _acceptInFlight = false;
      state = state.copyWith(
        phase: CallPhase.incoming,
        error: 'Microphone${kind == CallKind.video ? '/camera' : ''} permission denied',
      );
      return;
    }

    try {
      await ensureRenderers();
    } catch (e) {
      _acceptInFlight = false;
      state = state.copyWith(
        phase: CallPhase.incoming,
        error: 'Video surface failed: $e',
      );
      return;
    }

    _isInitiator = false;
    _metricsSubmitted = false;
    _callStartedAt = DateTime.now();
    await _configureNativeAudio();
    state = state.copyWith(
      phase: CallPhase.connecting,
      statusText: 'Connecting…',
      clearError: true,
    );

    try {
      await _connectSignaling();
      // Accept first so the server adds this socket to call_<id> before ICE.
      _wsSend({'action': 'accept', 'call_id': callId});
      await _setupPeer(isInitiator: false, kind: kind);
      _flushLocalCandidates();
      state = state.copyWith(statusText: 'Accepted — waiting for peer…');

      // Process offer that may have arrived early
      if (_pendingOffer != null) {
        final offer = _pendingOffer!;
        _pendingOffer = null;
        await _handleSignal(offer);
      }
    } catch (e, st) {
      debugPrint('[CALL] accept failed: $e\n$st');
      await _teardownMedia();
      // Stay on failed screen (not idle) so it does not look like a crash
      _showFailed('Could not accept call: $e');
    } finally {
      _acceptInFlight = false;
    }
  }

  void rejectIncoming() {
    final callId = state.callId;
    if (callId != null) {
      try {
        _wsSend({'action': 'end', 'call_id': callId});
      } catch (_) {}
    }
    unawaited(hangup(reason: 'rejected', silent: true));
  }

  /// End call. Keeps signaling socket open for future incoming calls.
  Future<void> hangup({
    String reason = 'ended_by_user',
    bool silent = false,
  }) async {
    _failedDismissTimer?.cancel();
    _turnTimer?.cancel();
    _durationTimer?.cancel();
    _mediaWatchdog?.cancel();
    _cancelRingTimeout();
    _acceptInFlight = false;
    _pendingOffer = null;
    _pendingLocalCandidates.clear();

    if (state.callId != null && _ws != null) {
      try {
        _wsSend({'action': 'end', 'call_id': state.callId, 'reason': reason});
      } catch (_) {}
    }
    await _submitCallMetrics(reason);
    await _teardownMedia();
    // Keep call WS alive so next inbound ring works
    state = const CallUiState().copyWith(renderersReady: _renderersReady);
    if (!silent) {
      debugPrint('[CALL] hangup reason=$reason');
    }
  }

  void dismissFailed() {
    _failedDismissTimer?.cancel();
    state = const CallUiState().copyWith(renderersReady: _renderersReady);
  }

  void _cancelRingTimeout() {
    _ringTimer?.cancel();
    _ringTimer = null;
  }

  /// Auto hang-up if peer never answers within 1.5 minutes.
  void _startRingTimeout({Duration? duration}) {
    _cancelRingTimeout();
    final d = duration ?? ringTimeout;
    _ringTimer = Timer(d, () {
      _ringTimer = null;
      if (state.phase != CallPhase.ringing &&
          state.phase != CallPhase.incoming) {
        return;
      }
      final wasIncoming = state.phase == CallPhase.incoming;
      debugPrint('[CALL] ring timeout (1.5 min) — no answer');
      unawaited(() async {
        await hangup(reason: 'no_answer', silent: true);
        _showFailed(
          wasIncoming
              ? 'Missed call — ring timed out'
              : 'No answer after 1.5 minutes',
        );
      }());
    });
  }

  void _showFailed(String message) {
    state = state.copyWith(
      phase: CallPhase.failed,
      error: message,
      statusText: 'Call failed',
    );
    // Auto-dismiss failed UI after a few seconds (user can still read error)
    _failedDismissTimer?.cancel();
    _failedDismissTimer = Timer(const Duration(seconds: 5), () {
      if (state.phase == CallPhase.failed) {
        state = const CallUiState().copyWith(renderersReady: _renderersReady);
      }
    });
  }

  Future<void> toggleMute() async {
    final next = !state.muted;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !next);
    state = state.copyWith(muted: next);
  }

  Future<void> toggleCamera() async {
    final next = !state.cameraOn;
    _localStream?.getVideoTracks().forEach((t) => t.enabled = next);
    state = state.copyWith(cameraOn: next);
  }

  Future<void> toggleSpeaker() async {
    final next = !state.speakerOn;
    try {
      await Helper.setSpeakerphoneOn(next);
    } catch (e) {
      debugPrint('[CALL] setSpeakerphoneOn failed: $e');
    }
    state = state.copyWith(speakerOn: next);
  }

  void toggleDiagnostics() {
    state = state.copyWith(showDiagnostics: !state.showDiagnostics);
  }

  // ── Signaling ──────────────────────────────────────────────

  Future<void> _connectSignaling() async {
    if (_ws != null) return;
    final ticket = await _auth.getWsTicket();
    if (ticket == null || ticket.isEmpty) {
      throw Exception('Could not get WS ticket for calls');
    }
    final url = Env.callWs(ticket);
    final channel = WebSocketChannel.connect(Uri.parse(url));
    _ws = channel;
    await channel.ready.timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw Exception('Call signaling connection timeout'),
    );
    await _wsSub?.cancel();
    _wsSub = channel.stream.listen(
      _onWsMessage,
      onError: (e) {
        debugPrint('[CALL][WS] error $e');
        _ws = null;
        if (_listening) {
          Future<void>.delayed(const Duration(seconds: 3), () {
            if (_listening && _ws == null) {
              unawaited(_connectSignaling().catchError((_) {}));
            }
          });
        }
      },
      onDone: () {
        debugPrint('[CALL][WS] closed');
        _ws = null;
        _wsSub = null;
        if (_listening && state.isLive) {
          state = state.copyWith(
            statusText: 'Reconnecting signaling…',
          );
        }
        if (_listening) {
          Future<void>.delayed(const Duration(seconds: 2), () {
            if (_listening && _ws == null) {
              unawaited(_connectSignaling().catchError((_) {}));
            }
          });
        }
      },
      cancelOnError: false,
    );
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_ws == null) return;
      if (state.phase == CallPhase.active) {
        _wsSend({
          'action': 'heartbeat',
          'ts': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }

  void _wsSend(Map<String, dynamic> msg) {
    try {
      _ws?.sink.add(jsonEncode(msg));
    } catch (e) {
      debugPrint('[CALL][WS] send failed: $e');
    }
  }

  void _onWsMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      // call.signal is unwrapped by server to {action, sdp, ...}
      final type =
          data['type']?.toString() ?? data['action']?.toString() ?? '';
      debugPrint('[CALL][WS] $type');

      switch (type) {
        case 'call.ringing':
          state = state.copyWith(
            callId: data['call_id']?.toString() ?? state.callId,
            phase: CallPhase.ringing,
            statusText: 'Ringing…',
          );
          _flushLocalCandidates();
          final ringSec = int.tryParse(
            data['ring_timeout_seconds']?.toString() ?? '',
          );
          _startRingTimeout(
            duration: ringSec != null
                ? Duration(seconds: ringSec)
                : ringTimeout,
          );
        case 'call.incoming':
          final ct = (data['call_type'] ?? 'VOICE').toString().toUpperCase();
          // Don't interrupt an active call with a second ring
          if (state.isLive && state.phase != CallPhase.incoming) {
            debugPrint('[CALL] ignore incoming while busy');
            return;
          }
          state = state.copyWith(
            phase: CallPhase.incoming,
            callId: data['call_id']?.toString(),
            peerId: data['caller_id']?.toString(),
            peerName: data['caller_email']?.toString() ??
                data['caller_name']?.toString() ??
                'Incoming',
            kind: ct.contains('VIDEO') ? CallKind.video : CallKind.voice,
            statusText:
                'Incoming ${ct.contains('VIDEO') ? 'video' : 'voice'} call',
            clearError: true,
          );
          final inRingSec = int.tryParse(
            data['ring_timeout_seconds']?.toString() ?? '',
          );
          _startRingTimeout(
            duration: inRingSec != null
                ? Duration(seconds: inRingSec)
                : ringTimeout,
          );
          // Socket should already be open via startListening
          unawaited(_connectSignaling().catchError((e) {
            debugPrint('[CALL] ensure socket on incoming: $e');
          }));
        case 'call.accepted':
          _cancelRingTimeout();
          state = state.copyWith(
            callId: data['call_id']?.toString() ?? state.callId,
            statusText: 'Accepted — negotiating P2P…',
          );
          _flushLocalCandidates();
          if (_isInitiator && _peerReady) {
            unawaited(_createOffer());
          } else if (_isInitiator && !_peerReady) {
            // Offer after peer finishes setup
            unawaited(() async {
              for (var i = 0; i < 20 && !_peerReady; i++) {
                await Future<void>.delayed(const Duration(milliseconds: 100));
              }
              if (_isInitiator && _peerReady) await _createOffer();
            }());
          }
        case 'call.connected':
          if (_hasInboundMedia) {
            _onMediaActive();
          } else {
            state = state.copyWith(
              statusText: 'Peer ready — waiting for audio/video…',
            );
          }
        case 'call.ended':
          // Only end if this is our current call
          final endedId = data['call_id']?.toString();
          if (endedId == null ||
              state.callId == null ||
              endedId == state.callId) {
            final reason = data['reason']?.toString() ?? 'remote_end';
            final wasIncoming = state.phase == CallPhase.incoming;
            final wasRinging = state.phase == CallPhase.ringing;
            unawaited(() async {
              await hangup(reason: reason, silent: true);
              if (reason == 'no_answer' && (wasIncoming || wasRinging)) {
                _showFailed(
                  wasIncoming
                      ? 'Missed call — ring timed out'
                      : 'No answer after 1.5 minutes',
                );
              }
            }());
          }
        case 'call.signal':
          // Full wrapper (if not unwrapped)
          final inner = data['data'];
          if (inner is Map) {
            _enqueueSignal(Map<String, dynamic>.from(inner));
          } else {
            _enqueueSignal(data);
          }
        case 'error':
          final msg = data['message']?.toString() ?? 'Call error';
          debugPrint('[CALL] server error: $msg');
          // Don't hard-crash the UI mid-accept for non-fatal errors
          if (state.phase == CallPhase.connecting ||
              state.phase == CallPhase.ringing ||
              state.phase == CallPhase.incoming) {
            state = state.copyWith(error: msg, statusText: msg);
          } else if (state.phase == CallPhase.active) {
            state = state.copyWith(error: msg);
          } else {
            _showFailed(msg);
          }
        case 'ice_restart_approved':
          if (_isInitiator && _peerReady) {
            unawaited(_createOffer(iceRestart: true));
          }
        case 'ice_restart_pending':
          debugPrint('[CALL][ICE] restart pending votes=${data['restart_votes']}');
        case 'signaling_rejected':
          debugPrint('[CALL] signaling rejected ${data['reason']}');
        case 'offer':
        case 'answer':
        case 'ice_candidate':
          _enqueueSignal(data);
        default:
          final action = data['action']?.toString();
          if (action == 'offer' ||
              action == 'answer' ||
              action == 'ice_candidate') {
            _enqueueSignal(data);
          }
      }
    } catch (e, st) {
      debugPrint('[CALL][WS] parse error $e\n$st');
    }
  }

  void _enqueueSignal(Map<String, dynamic> data) {
    _signalChain = _signalChain.then((_) => _handleSignal(data));
  }

  Future<void> _handleSignal(Map<String, dynamic> data) async {
    try {
      final action =
          data['action']?.toString() ?? data['signal_type']?.toString();
      final payload = data['payload'] is Map
          ? Map<String, dynamic>.from(data['payload'] as Map)
          : data;

      final isOffer = action == 'offer' ||
          (payload['type']?.toString() == 'offer' && payload['sdp'] != null);
      final isAnswer = action == 'answer' ||
          (payload['type']?.toString() == 'answer' && payload['sdp'] != null);
      final isIce = action == 'ice_candidate' ||
          payload['candidate'] != null ||
          data['candidate'] != null;

      if (isOffer) {
        // Callee may get offer before accept finishes peer setup
        if (_pc == null || !_peerReady) {
          debugPrint('[CALL] queue offer until peer ready');
          _pendingOffer = data;
          return;
        }
        final sdp = (payload['sdp'] ?? data['sdp'])?.toString();
        if (sdp == null || sdp.isEmpty) return;
        debugPrint('[CALL] apply remote offer ice_restart=${data['ice_restart']}');
        await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
        await _flushCandidates();
        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        _flushLocalCandidates();
        _wsSend({
          'action': 'answer',
          'call_id': state.callId,
          'sdp': answer.sdp,
          'type': 'answer',
        });
        state = state.copyWith(
          diagnostics: state.diagnostics.copyWith(lastSignal: 'answer-sent'),
        );
      } else if (isAnswer) {
        if (_pc == null) return;
        final sdp = (payload['sdp'] ?? data['sdp'])?.toString();
        if (sdp == null || sdp.isEmpty) return;
        debugPrint('[CALL] apply remote answer');
        await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
        await _flushCandidates();
        state = state.copyWith(
          diagnostics: state.diagnostics.copyWith(lastSignal: 'answer-applied'),
        );
      } else if (isIce) {
        final candidate = _parseRemoteIceCandidate(payload, data);
        if (candidate == null) return;
        _remoteCandidateCount += 1;
        state = state.copyWith(
          diagnostics: state.diagnostics.copyWith(
            remoteCandidates: _remoteCandidateCount,
            lastSignal: 'ice-in',
          ),
        );
        if (_pc == null) {
          _pendingRemoteCandidates.add(candidate);
          return;
        }
        final remote = await _pc!.getRemoteDescription();
        if (remote == null) {
          _pendingRemoteCandidates.add(candidate);
        } else {
          await _pc!.addCandidate(candidate);
        }
      }
    } catch (e, st) {
      debugPrint('[CALL] signal handling error: $e\n$st');
      // Do not hangup — recoverable ICE glitches should not kill the UI
      state = state.copyWith(error: 'Signaling issue: $e');
    }
  }

  RTCIceCandidate? _parseRemoteIceCandidate(
    Map<String, dynamic> payload,
    Map<String, dynamic> data,
  ) {
    final raw = payload['candidate'] ?? data['candidate'];
    if (raw == null) return null;
    String? cand;
    String? mid;
    dynamic mline;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      cand = map['candidate']?.toString();
      mid = (map['sdpMid'] ?? payload['sdpMid'] ?? data['sdpMid'])?.toString();
      mline = map['sdpMLineIndex'] ?? payload['sdpMLineIndex'] ?? data['sdpMLineIndex'];
    } else {
      cand = raw.toString();
      mid = (payload['sdpMid'] ?? data['sdpMid'])?.toString();
      mline = payload['sdpMLineIndex'] ?? data['sdpMLineIndex'];
    }
    if (cand == null || cand.isEmpty || cand == 'null') return null;
    return RTCIceCandidate(
      cand,
      mid,
      mline is int ? mline : int.tryParse('$mline'),
    );
  }

  Future<void> _flushCandidates() async {
    if (_pc == null) return;
    for (final c in List<RTCIceCandidate>.from(_pendingRemoteCandidates)) {
      try {
        await _pc!.addCandidate(c);
      } catch (e) {
        debugPrint('[CALL] addCandidate failed: $e');
      }
    }
    _pendingRemoteCandidates.clear();
  }

  // ── WebRTC peer (hybrid P2P-first) ─────────────────────────

  Future<void> _setupPeer({
    required bool isInitiator,
    required CallKind kind,
  }) async {
    // Tear down previous PC/stream if any (prevents double getUserMedia crash)
    await _teardownMedia(keepRenderers: true);

    final generation = ++_setupGeneration;
    _turnEscalated = false;
    _mediaConnectedSent = false;
    _hasInboundMedia = false;
    _connectedAt = null;
    _iceConnectedAt = null;
    _peerReady = false;
    _pendingOffer = null;
    _pendingLocalCandidates.clear();
    _localCandidateCount = 0;
    _remoteCandidateCount = 0;
    _iceRestartCount = 0;
    _networkProfileSent = false;

    IceConfig ice;
    try {
      ice = await _calls.getIceServers(stunOnly: true);
      _delayedTurnMs = ice.delayedTurnMs;
      if (!ice.p2pFirst || ice.delayedTurnMs == 0) {
        ice = await _calls.getIceServers(stunOnly: false);
        _turnEscalated = true;
        _delayedTurnMs = 0;
      }
    } catch (_) {
      ice = IceConfig(
        iceServers: [
          {
            'urls': [
              'stun:stun.l.google.com:19302',
              'stun:stun1.l.google.com:19302',
            ]
          },
        ],
      );
      _delayedTurnMs = 3500;
    }

    if (generation != _setupGeneration) return;

    final config = <String, dynamic>{
      'iceServers':
          _normalizeIceServers(ice.iceServers, stunOnly: !_turnEscalated),
      'iceTransportPolicy':
          ice.iceTransportPolicy == 'relay' ? 'relay' : 'all',
      'iceCandidatePoolSize': ice.iceCandidatePoolSize.clamp(0, 8),
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    };

    debugPrint(
      '[CALL][ICE] hybrid PC p2pFirst=${ice.p2pFirst} delayedTurn=${_delayedTurnMs}ms '
      'turnNow=$_turnEscalated servers=${(config['iceServers'] as List).length}',
    );

    _pc = await createPeerConnection(config);
    if (generation != _setupGeneration) return;

    _pc!.onIceCandidate = (RTCIceCandidate c) {
      if (c.candidate == null || c.candidate!.isEmpty) return;
      _localCandidateCount += 1;
      _sendLocalIceCandidate(c);
      state = state.copyWith(
        diagnostics: state.diagnostics.copyWith(
          localCandidates: _localCandidateCount,
        ),
      );
    };

    _pc!.onIceGatheringState = (RTCIceGatheringState s) {
      final name = s.toString().split('.').last;
      debugPrint('[CALL][ICE] gathering=$name');
      state = state.copyWith(
        diagnostics: state.diagnostics.copyWith(gatheringState: name),
      );
      if (s == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        unawaited(_maybeSubmitNetworkProfile());
      }
    };

    _pc!.onIceConnectionState = (RTCIceConnectionState s) {
      final name = _iceStateName(s);
      debugPrint('[CALL][ICE] state=$name');
      _reportIceState(name);
      state = state.copyWith(
        diagnostics: state.diagnostics.copyWith(iceState: name),
      );
      if (s == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          s == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _iceConnectedAt = DateTime.now();
        state = state.copyWith(
          statusText: _hasInboundMedia
              ? (state.isP2p == false ? 'Connected · Relay' : 'Connected · P2P')
              : 'ICE up — waiting for audio/video…',
        );
        unawaited(_refreshSelectedPair());
      } else if (s == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          s == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        if (!_hasInboundMedia) {
          unawaited(_escalateToTurn());
        }
      }
    };

    _pc!.onConnectionState = (RTCPeerConnectionState s) {
      final name = s.toString().split('.').last;
      debugPrint('[CALL][PC] connection=$name');
      state = state.copyWith(
        diagnostics: state.diagnostics.copyWith(connectionState: name),
      );
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed &&
          !_hasInboundMedia) {
        unawaited(_escalateToTurn());
      }
    };

    _pc!.onTrack = (RTCTrackEvent e) {
      unawaited(_attachRemoteTrack(e));
    };

    // Local media with progressive fallback (prevents native crash on some devices)
    _localStream = await _acquireLocalMedia(kind);
    if (generation != _setupGeneration) return;
    try {
      localRenderer.srcObject = _localStream;
    } catch (e) {
      debugPrint('[CALL] localRenderer attach failed: $e');
    }
    for (final track in _localStream!.getTracks()) {
      track.enabled = true;
      await _pc!.addTrack(track, _localStream!);
    }
    try {
      await Helper.setSpeakerphoneOn(true);
    } catch (e) {
      debugPrint('[CALL] setSpeakerphoneOn failed: $e');
    }

    _peerReady = true;
    _startMediaWatchdog();

    if (!_turnEscalated && _delayedTurnMs > 0) {
      _turnTimer = Timer(Duration(milliseconds: _delayedTurnMs), () {
        if (_hasInboundMedia) {
          debugPrint('[CALL][ICE] media already flowing — skip TURN');
          return;
        }
        unawaited(_escalateToTurn());
      });
    }
  }

  Future<void> _attachRemoteTrack(RTCTrackEvent e) async {
    try {
      e.track.enabled = true;
      _remoteStream ??= await createLocalMediaStream('remote');
      final exists =
          _remoteStream!.getTracks().any((t) => t.id == e.track.id);
      if (!exists) {
        await _remoteStream!.addTrack(e.track);
      }
      if (e.streams.isNotEmpty) {
        for (final t in e.streams.first.getTracks()) {
          final already =
              _remoteStream!.getTracks().any((x) => x.id == t.id);
          if (!already) {
            await _remoteStream!.addTrack(t);
          }
        }
      }
      remoteRenderer.srcObject = _remoteStream;
      try {
        await Helper.setSpeakerphoneOn(state.speakerOn);
      } catch (_) {}
      debugPrint(
        '[CALL] remote ${e.track.kind} track attached '
        'streams=${e.streams.length} total=${_remoteStream!.getTracks().length}',
      );
    } catch (err) {
      debugPrint('[CALL] onTrack error: $err');
    }
  }

  Future<MediaStream> _acquireLocalMedia(CallKind kind) async {
    final attempts = <Map<String, dynamic>>[
      {
        'audio': true,
        'video': kind == CallKind.video
            ? {
                'facingMode': 'user',
                'width': 640,
                'height': 480,
              }
            : false,
      },
      {
        'audio': true,
        'video': kind == CallKind.video ? true : false,
      },
      {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
        },
        'video': false,
      },
    ];

    Object? lastErr;
    for (final constraints in attempts) {
      try {
        final stream =
            await navigator.mediaDevices.getUserMedia(constraints);
        // If video call but we fell back to audio-only, mark camera off
        if (kind == CallKind.video && stream.getVideoTracks().isEmpty) {
          state = state.copyWith(
            cameraOn: false,
            statusText: 'Camera unavailable — audio only',
          );
        }
        return stream;
      } catch (e) {
        lastErr = e;
        debugPrint('[CALL] getUserMedia failed ($constraints): $e');
      }
    }
    throw Exception('Camera/mic unavailable: $lastErr');
  }

  Future<void> _escalateToTurn() async {
    if (_pc == null) return;
    if (_hasInboundMedia) return;
    if (_turnEscalated) {
      if (_isInitiator) {
        _iceRestartCount += 1;
        await _createOffer(iceRestart: true);
      }
      return;
    }
    _turnEscalated = true;
    state = state.copyWith(
      statusText: 'P2P timed out — trying TURN relay…',
      isP2p: false,
    );
    debugPrint('[CALL][ICE] Escalating to TURN (no inbound media yet)');

    try {
      final full = await _calls.getIceServers(stunOnly: false);
      final servers = _normalizeIceServers(full.iceServers, stunOnly: false);
      await _pc!.setConfiguration({
        'iceServers': servers,
        'iceTransportPolicy': 'all',
        'sdpSemantics': 'unified-plan',
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
      });
      // Let both peers apply TURN before the restart offer is sent.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      _iceRestartCount += 1;
      if (_isInitiator) {
        await _createOffer(iceRestart: true);
      } else {
        _wsSend({
          'action': 'ice_restart_request',
          'call_id': state.callId,
        });
      }
    } catch (e) {
      debugPrint('[CALL][ICE] TURN escalate failed: $e');
    }
  }

  Future<void> _createOffer({bool iceRestart = false}) async {
    final pc = _pc;
    if (pc == null) return;
    try {
      final offer = await pc.createOffer(
        iceRestart ? {'iceRestart': true} : <String, dynamic>{},
      );
      await pc.setLocalDescription(offer);
      _wsSend({
        'action': 'offer',
        'call_id': state.callId,
        'sdp': offer.sdp,
        'type': 'offer',
        if (iceRestart) 'ice_restart': true,
      });
    } catch (e, st) {
      debugPrint('[CALL] createOffer failed: $e\n$st');
      state = state.copyWith(error: 'Offer failed: $e');
    }
  }

  Future<void> _refreshSelectedPair() async {
    final snap = await _readRtcStats();
    final relay = snap.localType == 'relay' || snap.remoteType == 'relay';
    state = state.copyWith(
      isP2p: !relay,
      diagnostics: state.diagnostics.copyWith(
        inboundAudioBytes: snap.audioBytes,
        inboundVideoBytes: snap.videoBytes,
        selectedLocalType: snap.localType,
        selectedRemoteType: snap.remoteType,
      ),
    );
  }

  void _sendMediaConnected() {
    if (_mediaConnectedSent || state.callId == null) return;
    if (!_hasInboundMedia) return;
    _mediaConnectedSent = true;
    _wsSend({'action': 'media_connected', 'call_id': state.callId});
  }

  void _onMediaActive() {
    if (!_hasInboundMedia) return;
    _connectedAt ??= DateTime.now();
    _sendMediaConnected();
    if (state.phase == CallPhase.active) {
      state = state.copyWith(
        statusText: state.isP2p == false ? 'Connected · Relay' : 'Connected · P2P',
        clearError: true,
      );
      return;
    }
    state = state.copyWith(
      phase: CallPhase.active,
      statusText: state.isP2p == false ? 'Connected · Relay' : 'Connected · P2P',
      clearError: true,
    );
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(durationSec: state.durationSec + 1);
    });
  }

  void _sendLocalIceCandidate(RTCIceCandidate c) {
    final payload = <String, dynamic>{
      'action': 'ice_candidate',
      'call_id': state.callId,
      'candidate': {
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      },
    };
    if (state.callId == null || state.callId!.isEmpty) {
      _pendingLocalCandidates.add(payload);
      debugPrint('[CALL][ICE] buffer local candidate until call_id');
      return;
    }
    final cand = c.candidate ?? '';
    final typ = cand.contains(' typ ')
        ? cand.split(' typ ').last.split(' ').first
        : '?';
    debugPrint('[CALL][ICE] send local $typ mid=${c.sdpMid}');
    _wsSend(payload);
  }

  void _flushLocalCandidates() {
    if (state.callId == null || state.callId!.isEmpty) return;
    if (_pendingLocalCandidates.isEmpty) return;
    debugPrint(
      '[CALL][ICE] flush ${_pendingLocalCandidates.length} buffered local candidates',
    );
    for (final payload in List<Map<String, dynamic>>.from(_pendingLocalCandidates)) {
      payload['call_id'] = state.callId;
      _wsSend(payload);
    }
    _pendingLocalCandidates.clear();
  }

  Future<void> _configureNativeAudio() async {
    try {
      if (_isAndroid) {
        await Helper.setAndroidAudioConfiguration(
          AndroidAudioConfiguration.communication,
        );
      } else if (_isIOS) {
        await Helper.setAppleAudioIOMode(
          AppleAudioIOMode.localAndRemote,
          preferSpeakerOutput: true,
        );
        await Helper.ensureAudioSession();
      }
    } catch (e) {
      debugPrint('[CALL] native audio config failed: $e');
    }
  }

  void _startMediaWatchdog() {
    _mediaWatchdog?.cancel();
    _mediaWatchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_pollMediaStats());
    });
  }

  Future<void> _pollMediaStats() async {
    if (_pc == null) return;
    if (state.phase != CallPhase.connecting &&
        state.phase != CallPhase.active &&
        state.phase != CallPhase.ringing) {
      return;
    }
    final snap = await _readRtcStats();
    final hadMedia = _hasInboundMedia;
    if (snap.audioBytes > 0 || snap.videoBytes > 0) {
      _hasInboundMedia = true;
    }
    final relay = snap.localType == 'relay' || snap.remoteType == 'relay';
    state = state.copyWith(
      isP2p: snap.localType == null ? state.isP2p : !relay,
      diagnostics: state.diagnostics.copyWith(
        inboundAudioBytes: snap.audioBytes,
        inboundVideoBytes: snap.videoBytes,
        selectedLocalType: snap.localType ?? state.diagnostics.selectedLocalType,
        selectedRemoteType: snap.remoteType ?? state.diagnostics.selectedRemoteType,
      ),
    );
    if (_hasInboundMedia && !hadMedia) {
      debugPrint(
        '[CALL] inbound media audio=${snap.audioBytes} video=${snap.videoBytes} '
        'pair=${snap.localType}↔${snap.remoteType}',
      );
      _onMediaActive();
    }
    final started = _callStartedAt;
    if (!_hasInboundMedia &&
        !_turnEscalated &&
        started != null &&
        DateTime.now().difference(started).inMilliseconds > _delayedTurnMs) {
      unawaited(_escalateToTurn());
    }
  }

  Future<_RtcStatsSnap> _readRtcStats() async {
    final snap = _RtcStatsSnap();
    try {
      final stats = await _pc?.getStats();
      if (stats == null) return snap;
      final byId = <String, Map<String, dynamic>>{};
      String? localId;
      String? remoteId;
      for (final r in stats) {
        final values = Map<String, dynamic>.from(r.values);
        byId[r.id] = values;
        final type = (values['type'] ?? r.type)?.toString();
        if (type == 'inbound-rtp') {
          final bytes = (values['bytesReceived'] as num?)?.toInt() ?? 0;
          final kind = values['kind']?.toString() ?? values['mediaType']?.toString();
          if (kind == 'audio') snap.audioBytes = bytes;
          if (kind == 'video') snap.videoBytes = bytes;
        }
        if (type == 'candidate-pair') {
          final nominated = values['nominated'] == true;
          final selected = values['selected'] == true;
          final pairState = values['state']?.toString();
          if ((nominated || selected || pairState == 'succeeded') &&
              values['bytesReceived'] != null) {
            localId = values['localCandidateId']?.toString();
            remoteId = values['remoteCandidateId']?.toString();
          }
        }
      }
      if (localId != null && byId[localId] != null) {
        snap.localType = byId[localId]!['candidateType']?.toString();
      }
      if (remoteId != null && byId[remoteId] != null) {
        snap.remoteType = byId[remoteId]!['candidateType']?.toString();
      }
    } catch (e) {
      debugPrint('[CALL] getStats failed: $e');
    }
    return snap;
  }

  String _iceStateName(RTCIceConnectionState s) {
    switch (s) {
      case RTCIceConnectionState.RTCIceConnectionStateNew:
        return 'new';
      case RTCIceConnectionState.RTCIceConnectionStateChecking:
        return 'checking';
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
        return 'connected';
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        return 'completed';
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        return 'failed';
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        return 'disconnected';
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
        return 'closed';
      case RTCIceConnectionState.RTCIceConnectionStateCount:
        return 'count';
    }
  }

  void _reportIceState(String name) {
    if (name == _lastIceState) return;
    final previous = _lastIceState;
    _lastIceState = name;
    final callId = state.callId;
    if (callId == null) return;
    final elapsed = _callStartedAt == null
        ? null
        : DateTime.now().difference(_callStartedAt!).inMilliseconds;
    _wsSend({
      'action': 'ice_state',
      'call_id': callId,
      'state': name,
      'previous_state': previous,
      'elapsed_ms': elapsed,
      'metadata': {
        'turn_escalated': _turnEscalated,
        'inbound_media': _hasInboundMedia,
        'local_candidates': _localCandidateCount,
        'remote_candidates': _remoteCandidateCount,
        'path': state.diagnostics.pathLabel,
      },
    });
    unawaited(
      _calls.submitIceState({
        'call_session_id': callId,
        'state': name,
        'previous_state': previous,
        'elapsed_ms': elapsed,
        'metadata': {
          'turn_escalated': _turnEscalated,
          'inbound_media': _hasInboundMedia,
          'local_candidates': _localCandidateCount,
          'remote_candidates': _remoteCandidateCount,
        },
      }).catchError((_) => <String, dynamic>{}),
    );
  }

  Future<void> _maybeSubmitNetworkProfile() async {
    if (_networkProfileSent) return;
    _networkProfileSent = true;
    try {
      final snap = await _readRtcStats();
      final stats = await _pc?.getStats();
      var host = 0;
      var srflx = 0;
      var relay = 0;
      var ipv6 = 0;
      if (stats != null) {
        for (final r in stats) {
          final values = r.values;
          if ((values['type'] ?? r.type)?.toString() != 'local-candidate') {
            continue;
          }
          final typ = values['candidateType']?.toString();
          if (typ == 'host') host += 1;
          if (typ == 'srflx') srflx += 1;
          if (typ == 'relay') relay += 1;
          final ip = '${values['address'] ?? values['ip'] ?? ''}';
          if (ip.contains(':')) ipv6 += 1;
        }
      }
      await _calls.submitNetworkProfile({
        'ipv4': true,
        'ipv6': ipv6 > 0,
        'has_ipv6': ipv6 > 0,
        'host_candidates': host,
        'srflx_candidates': srflx,
        'relay_candidates': relay,
        'gathering_time': _iceConnectedAt == null || _callStartedAt == null
            ? null
            : _iceConnectedAt!.difference(_callStartedAt!).inMilliseconds,
        'os': defaultTargetPlatform.name,
        'browser': 'flutter',
        'connection_type': 'unknown',
      });
      debugPrint(
        '[CALL] network profile host=$host srflx=$srflx relay=$relay pair=${snap.localType}',
      );
    } catch (e) {
      debugPrint('[CALL] network profile submit failed: $e');
    }
  }

  Future<void> _submitCallMetrics(String reason) async {
    final callId = state.callId;
    if (callId == null || _metricsSubmitted) return;
    _metricsSubmitted = true;
    try {
      final snap = await _readRtcStats();
      final relay = snap.localType == 'relay' || snap.remoteType == 'relay';
      final connectedMs = _connectedAt == null || _callStartedAt == null
          ? null
          : _connectedAt!.difference(_callStartedAt!).inMilliseconds.toDouble();
      await _calls.submitMetrics({
        'call_session_id': callId,
        'p2p_success': _hasInboundMedia && !relay,
        'turn_fallback_occurrence': _turnEscalated || relay,
        'fallback_used': _turnEscalated || relay,
        'selected_local_candidate_type': snap.localType,
        'selected_remote_candidate_type': snap.remoteType,
        'connection_type': relay ? 'relay' : (snap.localType ?? 'unknown'),
        'connection_establishment_ms': connectedMs,
        'ice_connected_at_ms': _iceConnectedAt == null || _callStartedAt == null
            ? null
            : _iceConnectedAt!.difference(_callStartedAt!).inMilliseconds.toDouble(),
        'first_media_received_at_ms': connectedMs,
        'ice_restart_count': _iceRestartCount,
        'failure_reason': _hasInboundMedia ? '' : reason,
        'local_candidate_types': {
          'sent': _localCandidateCount,
        },
        'remote_candidate_types': {
          'received': _remoteCandidateCount,
        },
        'caller_network_type': 'unknown',
      });
    } catch (e) {
      debugPrint('[CALL] metrics submit failed: $e');
    }
  }

  List<Map<String, dynamic>> _normalizeIceServers(
    List<Map<String, dynamic>> raw, {
    required bool stunOnly,
  }) {
    final out = <Map<String, dynamic>>[];
    for (final s in raw) {
      final urlsRaw = s['urls'] ?? s['url'];
      final urls = <String>[];
      if (urlsRaw is List) {
        urls.addAll(urlsRaw.map((e) => e.toString()));
      } else if (urlsRaw != null) {
        urls.add(urlsRaw.toString());
      }
      if (stunOnly) {
        urls.removeWhere(
          (u) => u.startsWith('turn:') || u.startsWith('turns:'),
        );
      }
      if (urls.isEmpty) continue;
      final entry = <String, dynamic>{
        'urls': urls.length == 1 ? urls.first : urls,
      };
      if (s['username'] != null) entry['username'] = s['username'];
      if (s['credential'] != null) entry['credential'] = s['credential'];
      out.add(entry);
    }
    if (out.isEmpty) {
      out.add({
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ],
      });
    }
    return out;
  }

  Future<void> _teardownMedia({bool keepRenderers = false}) async {
    _turnTimer?.cancel();
    _mediaWatchdog?.cancel();
    _peerReady = false;
    _hasInboundMedia = false;
    try {
      final tracks = _localStream?.getTracks() ?? [];
      for (final t in tracks) {
        try {
          await t.stop();
        } catch (_) {}
      }
    } catch (_) {}
    try {
      await _localStream?.dispose();
    } catch (_) {}
    try {
      await _remoteStream?.dispose();
    } catch (_) {}
    try {
      await _pc?.close();
    } catch (_) {}
    try {
      await _pc?.dispose();
    } catch (_) {}
    _localStream = null;
    _remoteStream = null;
    _pc = null;
    if (_renderersReady) {
      try {
        localRenderer.srcObject = null;
      } catch (_) {}
      try {
        remoteRenderer.srcObject = null;
      } catch (_) {}
    }
    _pendingRemoteCandidates.clear();
    _pendingLocalCandidates.clear();
    if (!keepRenderers) {
      // leave renderer instances for reuse
    }
  }

  @override
  void dispose() {
    _listening = false;
    _failedDismissTimer?.cancel();
    _heartbeat?.cancel();
    _durationTimer?.cancel();
    _turnTimer?.cancel();
    _mediaWatchdog?.cancel();
    _cancelRingTimeout();
    unawaited(_teardownMedia());
    unawaited(_wsSub?.cancel());
    try {
      _ws?.sink.close();
    } catch (_) {}
    _ws = null;
    if (_renderersReady) {
      try {
        localRenderer.dispose();
      } catch (_) {}
      try {
        remoteRenderer.dispose();
      } catch (_) {}
    }
    super.dispose();
  }
}

class _RtcStatsSnap {
  int audioBytes = 0;
  int videoBytes = 0;
  String? localType;
  String? remoteType;
}

final callControllerProvider =
    StateNotifierProvider<CallController, CallUiState>((ref) {
  final ctrl = CallController(ref);
  // Start listening as soon as provider is first read (app shell / chat)
  // Actual connect happens after login when shell mounts.
  return ctrl;
});
