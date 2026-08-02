import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/spyce_colors.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/api_repositories.dart';
import '../../shared/widgets/spyce_widgets.dart';

/// Inbox of anonymous notes (chat requests) on the user's confessions.
/// Sender is never named — only gender · sexuality · age.
class ConfessionNotesInboxPage extends ConsumerStatefulWidget {
  const ConfessionNotesInboxPage({super.key});

  @override
  ConsumerState<ConfessionNotesInboxPage> createState() =>
      _ConfessionNotesInboxPageState();
}

class _ConfessionNotesInboxPageState
    extends ConsumerState<ConfessionNotesInboxPage> {
  List<ConfessionNoteRequest> items = [];
  bool loading = true;
  String? actingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final list =
          await ref.read(socialRepositoryProvider).listConfessionRequests();
      // Newest notes first
      list.sort((a, b) {
        final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
      if (!mounted) return;
      setState(() {
        items = list;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        items = [];
        loading = false;
      });
    }
  }

  Future<void> _accept(ConfessionNoteRequest r) async {
    if (actingId != null) return;
    setState(() => actingId = r.id);
    try {
      final res =
          await ref.read(socialRepositoryProvider).acceptConfessionRequest(r.id);
      final convId = res['conversation_id']?.toString();
      if (!mounted) return;
      setState(() {
        items = items.where((e) => e.id != r.id).toList();
        actingId = null;
      });
      if (convId != null && convId.isNotEmpty) {
        context.go('/app/chat/$convId');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Matched — open Chat to continue')),
        );
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => actingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => actingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not accept note')),
      );
    }
  }

  Future<void> _reject(ConfessionNoteRequest r) async {
    if (actingId != null) return;
    setState(() => actingId = r.id);
    try {
      await ref.read(socialRepositoryProvider).rejectConfessionRequest(r.id);
      if (!mounted) return;
      setState(() {
        items = items.where((e) => e.id != r.id).toList();
        actingId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note dismissed')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => actingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => actingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reject note')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpyceColors.dark950,
      appBar: AppBar(
        backgroundColor: SpyceColors.dark950,
        elevation: 0,
        title: Text(
          'Incoming notes',
          style: GoogleFonts.syne(fontWeight: FontWeight.w700),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: SpyceColors.pink),
            )
          : RefreshIndicator(
              color: SpyceColors.pink,
              onRefresh: _load,
              child: items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 100),
                        EmptyState(
                          icon: Icons.mail_outline,
                          title: 'No notes yet',
                          subtitle:
                              'When someone sends a note on your confession, it shows up here. You only see gender · sexuality · age — never their real identity until you accept.',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final r = items[i];
                        final busy = actingId == r.id;
                        return _NoteCard(
                          request: r,
                          busy: busy,
                          onAccept: () => _accept(r),
                          onReject: () => _reject(r),
                        );
                      },
                    ),
            ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.request,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  final ConfessionNoteRequest request;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpyceColors.dark800,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SpyceColors.dark500),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'On your confession',
            style: GoogleFonts.syne(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SpyceColors.pinkSoft,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            request.confessionText,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: SpyceColors.dark100,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: SpyceColors.dark600,
                child: Text(
                  (request.gender?.isNotEmpty == true
                          ? request.gender![0]
                          : '?')
                      .toUpperCase(),
                  style: const TextStyle(
                    color: SpyceColors.teal,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  request.anonMeta,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SpyceColors.dark700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              request.message,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                height: 1.45,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SpyceColors.dark100,
                    side: const BorderSide(color: SpyceColors.dark500),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpyceColors.pink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
