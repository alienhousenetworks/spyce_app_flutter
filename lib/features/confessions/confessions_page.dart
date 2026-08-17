import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/spyce_colors.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/api_repositories.dart';
import '../../shared/widgets/spyce_widgets.dart';
import 'confession_compose_sheet.dart';
import 'confession_formatter.dart';
import 'confession_notes_inbox.dart';
import 'confession_themes.dart';

/// Tumblr-style anonymous confessions.
/// - Feed: others only — like / plain repost (no quote note) / chat note
/// - Reposts show reposter strip + nested original author meta
/// - "My confessions": stats only (no self-interact)
class ConfessionsPage extends ConsumerStatefulWidget {
  const ConfessionsPage({super.key});

  @override
  ConsumerState<ConfessionsPage> createState() => _ConfessionsPageState();
}

class _ConfessionsPageState extends ConsumerState<ConfessionsPage> {
  List<ConfessionPost> feed = [];
  List<ConfessionPost> mine = [];
  bool loading = true;
  bool showMine = false;
  double lat = 19.076;
  double lon = 72.877;
  int incomingNotes = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _loadIncomingCount() async {
    try {
      final n =
          await ref.read(socialRepositoryProvider).countConfessionRequests();
      if (mounted) setState(() => incomingNotes = n);
    } catch (_) {}
  }

  Future<void> _openNotesInbox() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ConfessionNotesInboxPage()),
    );
    if (mounted) await _loadIncomingCount();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    _loadIncomingCount();
    try {
      final list = await ref
          .read(socialRepositoryProvider)
          .getFeed(lat: lat, lon: lon);
      if (!mounted) return;
      final all = list;
      // One slot per root original (backend dedupes; client belt-and-suspenders)
      final unique = _dedupeByRoot(all);
      setState(() {
        mine = unique.where((p) => p.isAuthor).toList();
        // Never show own posts in the interactive public feed
        feed = unique.where((p) => !p.isAuthor).toList();
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        feed = [];
        mine = [];
        loading = false;
      });
    }
  }

  /// Collapse original + any number of reposts of the same post into one card.
  /// Prefer the original; else keep the first-seen (usually newest) repost.
  static List<ConfessionPost> _dedupeByRoot(List<ConfessionPost> posts) {
    final firstIndex = <String, int>{};
    final byRoot = <String, ConfessionPost>{};

    String rootKey(ConfessionPost p) {
      if (p.parentId != null && p.parentId!.isNotEmpty && p.parentId != 'null') {
        return p.parentId!;
      }
      if (p.isRepost && p.original != null && p.original!.id.isNotEmpty) {
        return p.original!.id;
      }
      return p.id;
    }

    bool isOriginal(ConfessionPost p) =>
        !p.isRepost && (p.parentId == null || p.parentId!.isEmpty);

    for (var i = 0; i < posts.length; i++) {
      final p = posts[i];
      final key = rootKey(p);
      if (key.isEmpty) continue;
      firstIndex.putIfAbsent(key, () => i);
      final existing = byRoot[key];
      if (existing == null) {
        byRoot[key] = p;
        continue;
      }
      // Prefer original over any repost
      if (!isOriginal(existing) && isOriginal(p)) {
        byRoot[key] = p;
      }
    }

    final keys = byRoot.keys.toList()
      ..sort((a, b) => firstIndex[a]!.compareTo(firstIndex[b]!));
    return [for (final k in keys) byRoot[k]!];
  }

  Future<void> _relate(ConfessionPost p) async {
    if (p.isAuthor) return;
    try {
      await ref.read(socialRepositoryProvider).relate(p.id);
    } catch (_) {}
    setState(() {
      feed = feed
          .map((e) => e.id == p.id
              ? e.copyWith(
                  hasRelated: true,
                  relateCount: e.hasRelated ? e.relateCount : e.relateCount + 1,
                )
              : e)
          .toList();
    });
  }

  Future<void> _repost(ConfessionPost p) async {
    if (p.isAuthor) return;
    if (p.hasReposted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already reposted')),
        );
      }
      return;
    }
    try {
      final res = await ref.read(socialRepositoryProvider).repost(p.id);
      final serverCount = (res['parent_repost_count'] as num?)?.toInt();
      final already = res['status'] == 'already_reposted';
      if (!mounted) return;
      setState(() {
        feed = feed.map((e) {
          final sameRoot = e.id == p.id ||
              e.parentId == p.id ||
              (p.parentId != null &&
                  (e.id == p.parentId || e.parentId == p.parentId));
          if (!sameRoot && e.id != p.id) return e;
          final nextCount = serverCount ??
              (already || e.hasReposted ? e.repostCount : e.repostCount + 1);
          return e.copyWith(
            repostCount: nextCount,
            hasReposted: true,
          );
        }).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(already ? 'Already reposted' : 'Reposted'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : 'Could not repost';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  /// Report a confession: pick reason type + optional description.
  Future<void> _reportConfession(ConfessionPost p) async {
    if (p.isAuthor) return;

    const reasons = <({String value, String label})>[
      (value: 'SPAM', label: 'Spam'),
      (value: 'HARASSMENT', label: 'Harassment'),
      (value: 'FAKE_PROFILE', label: 'Fake / misleading'),
      (value: 'OTHER', label: 'Other'),
    ];

    String reason = 'SPAM';
    final descCtrl = TextEditingController();
    var submitting = false;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SpyceColors.dark800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: SpyceColors.dark500,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Text(
                    'Report confession',
                    style: GoogleFonts.syne(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose a reason. Add details if you want (required for Other).',
                    style: TextStyle(color: SpyceColors.dark100, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Type',
                    style: GoogleFonts.syne(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: reasons.map((r) {
                      final on = reason == r.value;
                      return ChoiceChip(
                        label: Text(r.label),
                        selected: on,
                        onSelected: submitting
                            ? null
                            : (_) => setLocal(() => reason = r.value),
                        selectedColor: SpyceColors.pinkDim,
                        checkmarkColor: SpyceColors.pink,
                        labelStyle: TextStyle(
                          color: on ? SpyceColors.pinkSoft : SpyceColors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: on
                              ? SpyceColors.pink.withValues(alpha: 0.5)
                              : SpyceColors.dark400,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    maxLines: 4,
                    maxLength: 500,
                    enabled: !submitting,
                    style: const TextStyle(color: SpyceColors.white),
                    decoration: InputDecoration(
                      labelText: reason == 'OTHER'
                          ? 'Description *'
                          : 'Description (optional)',
                      hintText: 'What is wrong with this confession?',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SpycePrimaryButton(
                    label: submitting ? 'Submitting…' : 'Submit report',
                    loading: submitting,
                    onPressed: submitting
                        ? null
                        : () {
                            final desc = descCtrl.text.trim();
                            if (reason == 'OTHER' && desc.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please describe the issue for “Other”.',
                                  ),
                                ),
                              );
                              return;
                            }
                            setLocal(() => submitting = true);
                            Navigator.pop(ctx, true);
                          },
                  ),
                  TextButton(
                    onPressed:
                        submitting ? null : () => Navigator.pop(ctx, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: SpyceColors.dark100),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    final description = descCtrl.text.trim();
    descCtrl.dispose();
    if (submitted != true) return;

    try {
      await ref.read(socialRepositoryProvider).reportConfession(
            p.id,
            reason: reason,
            description: description,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit report. Try again.')),
      );
    }
  }

  Future<void> _sendNote(ConfessionPost p) async {
    if (p.isAuthor) return;
    if (p.hasRequestedChat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already sent a note')),
      );
      return;
    }
    if (!p.canRequestChat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notes only when you both prefer each other\'s gender',
          ),
        ),
      );
      return;
    }
    final ctrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SpyceColors.dark800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Send a note',
                style: GoogleFonts.syne(
                    fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Only if you both prefer each other\'s gender. If they accept, you can chat. Profiles stay hidden until then.',
                style: TextStyle(color: SpyceColors.dark100, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                maxLines: 4,
                maxLength: 300,
                style: const TextStyle(color: SpyceColors.white),
                decoration: const InputDecoration(
                  hintText: 'Your note (10–300 chars)…',
                ),
              ),
              const SizedBox(height: 12),
              SpycePrimaryButton(
                label: 'Send request',
                onPressed: () {
                  if (ctrl.text.trim().length < 10) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text('Write at least 10 characters')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
              ),
            ],
          ),
        );
      },
    );
    if (ok == true) {
      try {
        await ref
            .read(socialRepositoryProvider)
            .chatRequest(p.id, ctrl.text.trim());
        setState(() {
          feed = feed
              .map(
                (e) => e.id == p.id
                    ? e.copyWith(
                        hasRequestedChat: true,
                        canRequestChat: false,
                      )
                    : e,
              )
              .toList();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Note sent — waiting for their accept')),
          );
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not send note. Try again.')),
          );
        }
      }
    }
    ctrl.dispose();
  }

  Future<void> _compose() async {
    final result = await ConfessionComposeSheet.show(context);
    if (result != null) {
      try {
        final created = await ref.read(socialRepositoryProvider).post(
              text: result.text,
              moodTag: result.moodTag,
              stylePreset: result.stylePreset,
              bgTheme: result.bgTheme,
              lat: lat,
              lon: lon,
            );
        setState(() {
          mine = [created.copyWith(isAuthor: true), ...mine];
          showMine = true;
        });
      } catch (_) {
        setState(() {
          mine = [
            ConfessionPost(
              id: 'local-${DateTime.now().millisecondsSinceEpoch}',
              text: result.text,
              moodTag: result.moodTag,
              stylePreset: result.stylePreset,
              bgTheme: result.bgTheme,
              isAuthor: true,
              relateCount: 0,
              repostCount: 0,
              createdAt: DateTime.now(),
            ),
            ...mine,
          ];
          showMine = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpyceColors.dark950,
      body: Stack(
        children: [
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                  child: Row(
                    children: [
                      Text(
                        showMine ? 'My confessions' : 'Confessions',
                        style: GoogleFonts.syne(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => showMine = !showMine),
                        child: Text(
                          showMine ? 'Feed' : 'My posts',
                          style: TextStyle(
                            color: showMine
                                ? SpyceColors.teal
                                : SpyceColors.pinkSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
              ),

              // Entry card into "My confessions"
              if (!showMine)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Material(
                    color: SpyceColors.dark800,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => showMine = true),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: SpyceColors.pinkDim,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.insights_outlined,
                                  color: SpyceColors.pinkSoft),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'My confessions',
                                    style: GoogleFonts.syne(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    mine.isEmpty
                                        ? 'Stats for posts you wrote'
                                        : '${mine.length} post${mine.length == 1 ? '' : 's'} · likes & reposts',
                                    style: const TextStyle(
                                      color: SpyceColors.dark100,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: SpyceColors.dark200),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              Expanded(
                child: loading
                    ? const ShimmerList(count: 3)
                    : RefreshIndicator(
                        color: SpyceColors.pink,
                        onRefresh: _load,
                        child: showMine
                            ? _MyConfessionsList(posts: mine)
                            : _FeedList(
                                posts: feed,
                                onRelate: _relate,
                                onRepost: _repost,
                                onNote: _sendNote,
                                onReport: _reportConfession,
                              ),
                      ),
              ),
            ],
          ),
          // Inbox notes (above pen) + compose pen (pen only on feed)
          Positioned(
            right: 18,
            bottom: 18,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Incoming notes badge — small mail over the pen
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openNotesInbox,
                      customBorder: const CircleBorder(),
                      child: Ink(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: SpyceColors.dark800,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: SpyceColors.teal.withValues(alpha: 0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.mail_outline_rounded,
                              color: SpyceColors.teal,
                              size: 22,
                            ),
                            if (incomingNotes > 0)
                              Positioned(
                                right: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SpyceColors.pink,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: SpyceColors.dark950,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    incomingNotes > 99
                                        ? '99+'
                                        : '$incomingNotes',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!showMine) ...[
                    const SizedBox(height: 10),
                    FloatingActionButton(
                      onPressed: _compose,
                      backgroundColor: SpyceColors.pink,
                      child: const Icon(Icons.edit, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Public feed (no own posts, full interactions) ────────────

class _FeedList extends StatelessWidget {
  const _FeedList({
    required this.posts,
    required this.onRelate,
    required this.onRepost,
    required this.onNote,
    required this.onReport,
  });

  final List<ConfessionPost> posts;
  final void Function(ConfessionPost) onRelate;
  final void Function(ConfessionPost) onRepost;
  final void Function(ConfessionPost) onNote;
  final void Function(ConfessionPost) onReport;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          EmptyState(
            icon: Icons.nightlight_outlined,
            title: 'Quiet feed',
            subtitle: 'No confessions nearby. Write one with the pen.',
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
      itemCount: posts.length,
      itemBuilder: (context, i) {
        final p = posts[i];
        final when = p.createdAt != null
            ? DateFormat.MMMd().add_jm().format(p.createdAt!)
            : '';
        final isRepost = p.isRepost;
        final original = p.original;
        final headerGender =
            isRepost && original != null ? original.gender : p.gender;
        final headerMeta = isRepost && original != null
            ? original.anonMeta
            : p.anonMeta;
        final avatarLetter =
            (headerGender?.isNotEmpty == true ? headerGender![0] : '?')
                .toUpperCase();

        final theme = ConfessionThemeConfig.fromId(p.effectiveBgTheme);
        final styleType =
            ConfessionStyleTypeExt.fromCode(p.effectiveStylePreset);
        final mood = isRepost && original != null
            ? original.moodTag
            : p.moodTag;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            gradient: theme.gradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.borderColor,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.glowColor,
                blurRadius: 12,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tumblr-style strip: who reposted
              if (isRepost) ...[
                Row(
                  children: [
                    Icon(
                      Icons.repeat,
                      size: 14,
                      color: SpyceColors.teal.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reposted · ${p.anonMeta}',
                        style: GoogleFonts.dmSans(
                          color: SpyceColors.teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      when,
                      style: const TextStyle(
                        color: SpyceColors.dark200,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Anonymous — profiles unlock only after both accept a note.',
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: theme.badgeColor,
                      child: Text(
                        avatarLetter,
                        style: TextStyle(
                          color: theme.accentColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                headerMeta,
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: theme.textColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Style Badge Chip
                              if (styleType != ConfessionStyleType.standard)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.badgeColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: theme.accentColor
                                          .withValues(alpha: 0.4),
                                      width: 0.6,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        styleType.icon,
                                        size: 10,
                                        color: theme.accentColor,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        styleType.label,
                                        style: GoogleFonts.syne(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: theme.accentColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              if (!isRepost)
                                Text(
                                  when,
                                  style: TextStyle(
                                    color: theme.metaColor,
                                    fontSize: 11,
                                  ),
                                )
                              else if (original?.createdAt != null)
                                Text(
                                  DateFormat.MMMd()
                                      .add_jm()
                                      .format(original!.createdAt!),
                                  style: TextStyle(
                                    color: theme.metaColor,
                                    fontSize: 11,
                                  ),
                                ),
                              if (mood != null && mood.isNotEmpty) ...[
                                Text(
                                  ' · ',
                                  style: TextStyle(
                                    color: theme.metaColor,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  mood.replaceAll('_', ' '),
                                  style: TextStyle(
                                    color: theme.accentColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!isRepost)
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_horiz,
                          size: 20,
                          color: theme.metaColor,
                        ),
                        color: SpyceColors.dark800,
                        onSelected: (v) {
                          if (v == 'report') onReport(p);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'report',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.flag_outlined, size: 20),
                              title: Text('Report confession'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Formatted confession body (supports Numbering, Dividers, Poetry, Quotes)
              ConfessionFormattedBody(
                text: p.displayText,
                styleType: styleType,
                theme: theme,
              ),

              const SizedBox(height: 12),

              // Action Buttons
              Row(
                children: [
                  _Action(
                    icon: p.hasRelated
                        ? Icons.favorite
                        : Icons.favorite_border,
                    label: '${p.relateCount}',
                    color: p.hasRelated
                        ? theme.accentColor
                        : theme.metaColor,
                    onTap: () => onRelate(p),
                  ),
                  const SizedBox(width: 18),
                  _Action(
                    icon: Icons.repeat,
                    label: '${p.repostCount}',
                    color: p.hasReposted
                        ? SpyceColors.teal
                        : theme.metaColor,
                    onTap: () => onRepost(p),
                  ),
                  const SizedBox(width: 18),
                  // Note only when mutual preferred genders (or already sent)
                  if (p.hasRequestedChat || p.canRequestChat)
                    _Action(
                      icon: p.hasRequestedChat
                          ? Icons.mark_email_read_outlined
                          : Icons.mail_outline,
                      label: p.hasRequestedChat ? 'Sent' : 'Note',
                      color: p.hasRequestedChat
                          ? SpyceColors.teal
                          : theme.metaColor,
                      onTap: p.hasRequestedChat ? null : () => onNote(p),
                    ),
                  const Spacer(),
                  _Action(
                    icon: Icons.flag_outlined,
                    label: 'Report',
                    color: theme.metaColor,
                    onTap: () => onReport(p),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Own confessions: stats only, no like/repost/note ─────────

class _MyConfessionsList extends StatelessWidget {
  const _MyConfessionsList({required this.posts});

  final List<ConfessionPost> posts;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          EmptyState(
            icon: Icons.edit_note,
            title: 'No confessions yet',
            subtitle:
                'Posts you write appear here with like & repost counts. You can\'t interact with your own posts.',
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
      itemCount: posts.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              'Stats only — you can\'t like, repost, or note your own confessions.',
              style: GoogleFonts.dmSans(
                color: SpyceColors.dark100,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          );
        }
        final p = posts[i - 1];
        final when = p.createdAt != null
            ? DateFormat.MMMd().add_jm().format(p.createdAt!)
            : '';
        final isRepost = p.isRepost;

        final theme = ConfessionThemeConfig.fromId(p.effectiveBgTheme);
        final styleType =
            ConfessionStyleTypeExt.fromCode(p.effectiveStylePreset);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: theme.gradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: theme.glowColor,
                blurRadius: 10,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isRepost
                          ? SpyceColors.teal.withValues(alpha: 0.2)
                          : theme.badgeColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (isRepost ? SpyceColors.teal : theme.accentColor)
                            .withValues(alpha: 0.4),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      isRepost
                          ? 'You reposted'
                          : 'Yours · ${styleType.label}',
                      style: TextStyle(
                        color: isRepost
                            ? SpyceColors.teal
                            : theme.accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    when,
                    style: TextStyle(
                      color: theme.metaColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              if (isRepost && p.original != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Original · ${p.original!.anonMeta}',
                  style: GoogleFonts.dmSans(
                    color: theme.metaColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Formatted body
              ConfessionFormattedBody(
                text: p.displayText,
                styleType: styleType,
                theme: theme,
                isCompact: true,
              ),
              const SizedBox(height: 14),
              // Stats row — display only
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.badgeColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.borderColor,
                    width: 0.6,
                  ),
                ),
                child: Row(
                  children: [
                    _Stat(
                      icon: Icons.favorite,
                      label: 'Likes',
                      value: '${p.relateCount}',
                      color: theme.accentColor,
                    ),
                    const SizedBox(width: 20),
                    _Stat(
                      icon: Icons.repeat,
                      label: 'Reposts',
                      value: '${p.repostCount}',
                      color: SpyceColors.teal,
                    ),
                    const SizedBox(width: 20),
                    _Stat(
                      icon: Icons.mail_outline,
                      label: 'Notes',
                      value: p.hasRequestedChat ? '1+' : '0',
                      color: SpyceColors.gold,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: SpyceColors.dark200,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = SpyceColors.dark100,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
