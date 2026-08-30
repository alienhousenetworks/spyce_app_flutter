import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/spyce_colors.dart';
import '../../data/repositories/api_repositories.dart';
import 'call_controller.dart';

/// Full-screen call UI over the app when a call is live / incoming.
class CallOverlayHost extends ConsumerWidget {
  const CallOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(callControllerProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (call.isLive || call.phase == CallPhase.failed)
          const Positioned.fill(child: CallOverlay()),
      ],
    );
  }
}

class CallOverlay extends ConsumerWidget {
  const CallOverlay({super.key});

  String _fmt(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(callControllerProvider);
    final ctrl = ref.read(callControllerProvider.notifier);
    final isVideo = call.kind == CallKind.video;

    if (call.phase == CallPhase.failed) {
      return Material(
        color: Colors.black.withValues(alpha: 0.92),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.call_end, size: 56, color: SpyceColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Call failed',
                    style: GoogleFonts.syne(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    call.error ?? 'Something went wrong',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: SpyceColors.dark100),
                  ),
                  const SizedBox(height: 28),
                  TextButton(
                    onPressed: ctrl.dismissFailed,
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (call.phase == CallPhase.incoming) {
      return Material(
        color: Colors.black.withValues(alpha: 0.92),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isVideo ? Icons.videocam : Icons.call,
                size: 64,
                color: SpyceColors.pinkSoft,
              ),
              const SizedBox(height: 16),
              Text(
                isVideo ? 'Incoming video call' : 'Incoming voice call',
                style: GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                call.peerName ?? 'Someone',
                style: const TextStyle(color: SpyceColors.dark100, fontSize: 16),
              ),
              if (call.error != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    call.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: SpyceColors.warning, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CircleBtn(
                    color: Colors.red,
                    icon: Icons.call_end,
                    label: 'Decline',
                    onTap: ctrl.rejectIncoming,
                  ),
                  const SizedBox(width: 48),
                  _CircleBtn(
                    color: Colors.green,
                    icon: Icons.call,
                    label: 'Accept',
                    onTap: () => ctrl.acceptIncoming(),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final canShowVideo = isVideo && call.renderersReady;
    final d = call.diagnostics;

    return Material(
      color: SpyceColors.dark950,
      child: SafeArea(
        child: Stack(
          children: [
            // Always attach the remote renderer so flutter_webrtc starts
            // the audio pipeline — even on voice calls (1×1 offscreen).
            if (call.renderersReady)
              canShowVideo
                  ? Positioned.fill(
                      child: RTCVideoView(
                        ctrl.remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    )
                  : Positioned(
                      left: -2,
                      top: -2,
                      width: 2,
                      height: 2,
                      child: IgnorePointer(
                        child: RTCVideoView(ctrl.remoteRenderer),
                      ),
                    ),
            if (!canShowVideo)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: SpyceColors.dark600,
                      child: Text(
                        (call.peerName?.isNotEmpty == true
                                ? call.peerName![0]
                                : '?')
                            .toUpperCase(),
                        style: GoogleFonts.syne(
                          fontSize: 40,
                          color: SpyceColors.pinkSoft,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      call.peerName ?? 'Call',
                      style: GoogleFonts.syne(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: ctrl.toggleDiagnostics,
                      child: Text(
                        call.phase == CallPhase.active
                            ? _fmt(call.durationSec)
                            : (call.statusText ?? '…'),
                        style: const TextStyle(color: SpyceColors.dark100),
                      ),
                    ),
                    if (call.phase == CallPhase.connecting) ...[
                      const SizedBox(height: 16),
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SpyceColors.pinkSoft,
                        ),
                      ),
                    ],
                    if (call.isP2p != null || d.selectedLocalType != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: ctrl.toggleDiagnostics,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: call.isP2p == true
                                ? SpyceColors.teal.withValues(alpha: 0.2)
                                : SpyceColors.gold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            d.selectedLocalType != null
                                ? d.pathLabel
                                : (call.isP2p == true
                                    ? 'P2P direct'
                                    : 'Relay (TURN)'),
                            style: TextStyle(
                              color: call.isP2p == true
                                  ? SpyceColors.teal
                                  : SpyceColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Local PiP for video (only after renderer init)
            if (canShowVideo)
              Positioned(
                right: 16,
                top: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 110,
                    height: 150,
                    child: RTCVideoView(
                      ctrl.localRenderer,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),

            if (isVideo)
              Positioned(
                top: 24,
                left: 0,
                right: 0,
                child: GestureDetector(
                  onTap: ctrl.toggleDiagnostics,
                  child: Column(
                    children: [
                      Text(
                        call.peerName ?? 'Video call',
                        style: GoogleFonts.syne(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          shadows: const [Shadow(blurRadius: 8)],
                        ),
                      ),
                      Text(
                        call.phase == CallPhase.active
                            ? _fmt(call.durationSec)
                            : (call.statusText ?? ''),
                        style: const TextStyle(
                          color: Colors.white70,
                          shadows: [Shadow(blurRadius: 6)],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (call.showDiagnostics)
              Positioned(
                left: 16,
                right: 16,
                bottom: 120,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ICE ${d.iceState}  PC ${d.connectionState}'),
                          Text('gather ${d.gatheringState}  path ${d.pathLabel}'),
                          Text(
                            'cand local=${d.localCandidates} remote=${d.remoteCandidates}',
                          ),
                          Text(
                            'in audio=${d.inboundAudioBytes}B  video=${d.inboundVideoBytes}B',
                          ),
                          if (d.lastSignal != null) Text('last ${d.lastSignal}'),
                          const SizedBox(height: 6),
                          const Text(
                            'Tap status again to hide. Same data is sent to Admin → Call metrics / ICE state logs.',
                            style: TextStyle(fontSize: 11, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (call.error != null)
              Positioned(
                top: 80,
                left: 20,
                right: 20,
                child: Material(
                  color: Colors.red.shade900,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(call.error!, textAlign: TextAlign.center),
                  ),
                ),
              ),

            // Top Left Safety & Report Button (Always accessible during call)
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showSafetySheet(context, ref, call, ctrl),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.shield_outlined, color: SpyceColors.error, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Report / Block',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CircleBtn(
                    color: call.muted ? SpyceColors.pink : SpyceColors.dark600,
                    icon: call.muted ? Icons.mic_off : Icons.mic,
                    onTap: ctrl.toggleMute,
                  ),
                  if (isVideo)
                    _CircleBtn(
                      color: call.cameraOn
                          ? SpyceColors.dark600
                          : SpyceColors.pink,
                      icon: call.cameraOn
                          ? Icons.videocam
                          : Icons.videocam_off,
                      onTap: ctrl.toggleCamera,
                    ),
                  _CircleBtn(
                    color: Colors.red,
                    icon: Icons.call_end,
                    size: 68,
                    onTap: () => ctrl.hangup(),
                  ),
                  _CircleBtn(
                    color: Colors.red.shade900.withValues(alpha: 0.7),
                    icon: Icons.shield_outlined,
                    onTap: () => _showSafetySheet(context, ref, call, ctrl),
                  ),
                  _CircleBtn(
                    color: call.speakerOn
                        ? SpyceColors.teal.withValues(alpha: 0.4)
                        : SpyceColors.dark600,
                    icon: call.speakerOn
                        ? Icons.volume_up
                        : Icons.volume_off,
                    onTap: ctrl.toggleSpeaker,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSafetySheet(
    BuildContext context,
    WidgetRef ref,
    CallUiState call,
    CallController ctrl,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SpyceColors.dark900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: const [
                    Icon(Icons.shield, color: SpyceColors.error, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Call Safety & Moderation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'If this person is violating community rules or making you uncomfortable, you can instantly end the call, report, and block them.',
                  style: TextStyle(color: SpyceColors.dark100, fontSize: 13),
                ),
                const SizedBox(height: 16),
                _buildReportOption(
                  ctx,
                  ref,
                  call,
                  ctrl,
                  'INAPPROPRIATE_CONTENT',
                  'Inappropriate or NSFW Video / Behavior',
                ),
                _buildReportOption(
                  ctx,
                  ref,
                  call,
                  ctrl,
                  'HARASSMENT',
                  'Harassment, Hate Speech or Threats',
                ),
                _buildReportOption(
                  ctx,
                  ref,
                  call,
                  ctrl,
                  'UNDERAGE_CSE',
                  'Underage or Exploitative Behavior',
                ),
                _buildReportOption(
                  ctx,
                  ref,
                  call,
                  ctrl,
                  'SPAM',
                  'Spam, Bot or Financial Solicitation',
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportOption(
    BuildContext context,
    WidgetRef ref,
    CallUiState call,
    CallController ctrl,
    String reason,
    String label,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.block, color: SpyceColors.error, size: 20),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      onTap: () async {
        Navigator.pop(context);
        final peerId = call.peerId;
        // 1. Immediately drop the call
        ctrl.hangup();
        // 2. Submit report & block
        if (peerId != null && peerId.isNotEmpty) {
          try {
            await ref.read(moderationRepositoryProvider).reportAndBlock(
                  reportedUserId: peerId,
                  reason: reason,
                  description: 'Reported during live call: $label',
                );
          } catch (_) {}
        }
      },
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({
    required this.color,
    required this.icon,
    required this.onTap,
    this.label,
    this.size = 56,
  });

  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.4),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(label!, style: const TextStyle(fontSize: 12)),
        ],
      ],
    );
  }
}
