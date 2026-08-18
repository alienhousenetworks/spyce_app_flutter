import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import '../../core/storage/chat_local_store.dart';
import '../../core/theme/spyce_colors.dart';
import '../../core/utils/presence_labels.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/api_repositories.dart';
import '../../shared/widgets/media_user_id_watermark.dart';
import '../../shared/widgets/spyce_widgets.dart';
import '../auth/auth_controller.dart';
import '../call/call_controller.dart';

/// Chat tab: WhatsApp-style horizontal matches on top + conversation list.
class ConversationsPage extends ConsumerStatefulWidget {
  const ConversationsPage({super.key});

  @override
  ConsumerState<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends ConsumerState<ConversationsPage> {
  List<ConversationItem> items = [];
  List<MatchItem> matches = [];
  List<IncomingLike> likes = [];
  int likesCount = 0;
  bool likesPremium = false;
  bool loading = true;
  /// True only for gender+sexuality combos allowed to see incoming likes.
  bool canSeeLikes = false;
  /// Admin matrix: clear faces + open full profile + like back to match.
  bool canViewFullLikeProfiles = false;
  bool canLikeBackIncoming = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final chat = ref.read(chatRepositoryProvider);
      final match = ref.read(matchRepositoryProvider);
      final feed = ref.read(feedRepositoryProvider);
      final profile = ref.read(profileRepositoryProvider);

      final results = await Future.wait([
        chat.getConversations().catchError((_) => <ConversationItem>[]),
        match.getMatches().catchError((_) => <MatchItem>[]),
        profile.getMyProfile().catchError(
              (_) => const UserProfile(id: 'me'),
            ),
      ]);

      var convos = results[0] as List<ConversationItem>;
      final m = results[1] as List<MatchItem>;
      final me = results[2] as UserProfile;

      // Merge match photos into chats by user id (fast path)
      if (convos.isNotEmpty && m.isNotEmpty) {
        final byUser = <String, MatchItem>{};
        for (final match in m) {
          if (match.userId != null) byUser[match.userId!] = match;
        }
        convos = convos.map((c) {
          final match = c.peerUserId != null ? byUser[c.peerUserId!] : null;
          if (match == null) return c;
          return c.copyWith(
            peerUsername: c.peerUsername ?? match.username,
            peerName: c.peerName ?? match.displayName,
            peerImage: (c.peerImage == null || c.peerImage!.isEmpty)
                ? match.imageUrl
                : c.peerImage,
          );
        }).toList();
      }

      // Enrich missing avatars from public profile (uploaded OR admin pool)
      convos = await _enrichConversationAvatars(convos, profile);

      // Permission: profile gender+sexuality flag AND /received/ API flag.
      // Button is hidden for combos that cannot see incoming likes.
      var seeLikes = me.canSeeIncomingLikes;
      List<IncomingLike> incoming = [];
      var count = 0;
      var premium = false;
      var viewFull = false;
      var likeBack = false;
      try {
        final likesRes = await feed.getIncomingLikes();
        seeLikes = likesRes.canSee;
        if (seeLikes) {
          incoming = likesRes.users;
          count = likesRes.count;
          premium = likesRes.isPremium;
          viewFull = likesRes.canViewFullProfiles ||
              incoming.any((u) => !u.blurred);
          likeBack = likesRes.canLikeBack || viewFull;
        }
      } catch (_) {
        // Keep profile flag if list fetch fails (still show button)
      }

      if (!mounted) return;
      setState(() {
        items = convos;
        matches = m;
        likes = incoming;
        likesCount = count > 0 ? count : incoming.length;
        likesPremium = premium;
        canSeeLikes = seeLikes;
        canViewFullLikeProfiles = viewFull;
        canLikeBackIncoming = likeBack;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        items = [];
        matches = [];
        likes = [];
        likesCount = 0;
        canSeeLikes = false;
        canViewFullLikeProfiles = false;
        canLikeBackIncoming = false;
        loading = false;
      });
    }
  }


  /// Load profile card for peers missing images → user photo or admin avatar pool.
  Future<List<ConversationItem>> _enrichConversationAvatars(
    List<ConversationItem> convos,
    ProfileRepository profileRepo,
  ) async {
    final need = convos
        .where((c) =>
            (c.peerImage == null || c.peerImage!.isEmpty) &&
            c.peerUserId != null &&
            c.peerUserId!.isNotEmpty)
        .take(12)
        .toList();
    if (need.isEmpty) return convos;

    final futures = need.map((c) async {
      try {
        final p = await profileRepo.getProfile(c.peerUserId!);
        return MapEntry(c.peerUserId!, p);
      } catch (_) {
        return null;
      }
    });
    final results = await Future.wait(futures);
    final byId = <String, UserProfile>{};
    for (final e in results) {
      if (e != null) byId[e.key] = e.value;
    }
    if (byId.isEmpty) return convos;

    return convos.map((c) {
      final p = c.peerUserId != null ? byId[c.peerUserId!] : null;
      if (p == null) return c;
      return c.copyWith(
        peerUsername: c.peerUsername ?? p.username,
        peerName: c.peerName ?? p.displayName,
        peerImage: (c.peerImage == null || c.peerImage!.isEmpty)
            ? p.displayImageUrl
            : c.peerImage,
      );
    }).toList();
  }

  void _openMatch(MatchItem m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SpyceColors.dark800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NetworkAvatar(
                url: m.imageUrl,
                name: m.shortOrName,
                size: 88,
              ),
              const SizedBox(height: 12),
              Text(
                m.displayName,
                style: GoogleFonts.syne(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (m.isOnline)
                const Text('Online',
                    style: TextStyle(color: SpyceColors.teal, fontSize: 13)),
              const SizedBox(height: 8),
              const Text(
                'You matched! Say hi — first message starts the conversation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SpyceColors.dark100),
              ),
              const SizedBox(height: 20),
              SpycePrimaryButton(
                label: 'Message',
                icon: Icons.chat_bubble_outline,
                onPressed: () {
                  Navigator.pop(ctx);
                  if (m.conversationId != null) {
                    context.push(
                      '/app/chat/${m.conversationId}',
                      extra: {
                        'title': m.displayName,
                        'peerUserId': m.userId,
                        'peerImage': m.imageUrl,
                      },
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Conversation opens after first message')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _likeBackIncoming(IncomingLike l) async {
    if (l.id.isEmpty || l.id.startsWith('stub_')) return;
    try {
      final res = await ref.read(feedRepositoryProvider).like(l.id);
      if (!mounted) return;
      final status =
          (res['status'] ?? res['result'] ?? '').toString().toLowerCase();
      final isMatch = status == 'match' ||
          res['is_match'] == true ||
          res['matched'] == true ||
          res['match'] != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMatch
                ? "It's a Match with ${l.username ?? 'them'}!"
                : 'Liked ${l.username ?? 'them'} back',
          ),
        ),
      );
      setState(() {
        likes = likes.where((x) => x.id != l.id).toList();
        likesCount = likes.length;
      });
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.fullDetail)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not like back: $e')),
      );
    }
  }

  void _openIncomingLikeProfile(IncomingLike l) {
    if (l.id.isEmpty || l.id.startsWith('stub_') || l.blurred) return;
    Navigator.of(context).pop(); // close likes sheet
    context
        .push(
      '/app/user/${l.id}',
      extra: {
        'title': l.username,
        'image': l.imageUrl,
        'allowLikeBack': canLikeBackIncoming || l.canLikeBack,
        'from_incoming_like': true,
      },
    )
        .then((matched) {
      if (matched == true && mounted) _load();
    });
  }

  void _showIncomingLikes() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SpyceColors.dark800,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final list = likes;
        final n = likesCount > 0 ? likesCount : list.length;
        final fullAccess =
            canViewFullLikeProfiles || list.any((u) => !u.blurred);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  'Who liked you',
                  style: GoogleFonts.syne(
                      fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    n == 0
                        ? 'No new likes yet — keep swiping.'
                        : fullAccess
                            ? '$n liked you · open profile · like back to match'
                            : '$n people liked you',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: SpyceColors.dark100, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: n == 0
                      ? const Center(
                          child: Text(
                            'When someone likes you, they show up here.',
                            style: TextStyle(color: SpyceColors.dark200),
                          ),
                        )
                      : GridView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.78,
                          ),
                          itemCount:
                              list.isNotEmpty ? list.length : n.clamp(0, 12),
                          itemBuilder: (_, i) {
                            final l = i < list.length
                                ? list[i]
                                : IncomingLike(
                                    id: 'stub_$i',
                                    blurred: true,
                                  );
                            return Material(
                              color: SpyceColors.dark700,
                              borderRadius: BorderRadius.circular(16),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: l.blurred
                                    ? null
                                    : () => _openIncomingLikeProfile(l),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (l.imageUrl != null &&
                                        l.imageUrl!.isNotEmpty)
                                      ImageFiltered(
                                        imageFilter: l.blurred
                                            ? ImageFilter.blur(
                                                sigmaX: 14, sigmaY: 14)
                                            : ImageFilter.blur(
                                                sigmaX: 0, sigmaY: 0),
                                        child: CachedNetworkImage(
                                          imageUrl: l.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, _, _) =>
                                              const ColoredBox(
                                                  color: SpyceColors.dark600),
                                        ),
                                      )
                                    else
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              SpyceColors.pink
                                                  .withValues(alpha: 0.35),
                                              SpyceColors.dark600,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                      ),
                                    if (l.blurred)
                                      const Center(
                                        child: Icon(Icons.lock_outline,
                                            color: Colors.white70, size: 32),
                                      ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.fromLTRB(
                                            8, 28, 8, 8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black
                                                  .withValues(alpha: 0.75),
                                            ],
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              l.blurred
                                                  ? 'Liked you'
                                                  : (l.username ?? 'Someone'),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (!l.blurred &&
                                                (canLikeBackIncoming ||
                                                    l.canLikeBack)) ...[
                                              const SizedBox(height: 6),
                                              SizedBox(
                                                height: 32,
                                                child: FilledButton.tonal(
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor: SpyceColors
                                                        .pink
                                                        .withValues(alpha: 0.9),
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 10,
                                                    ),
                                                    textStyle: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  onPressed: () =>
                                                      _likeBackIncoming(l),
                                                  child:
                                                      const Text('Like back'),
                                                ),
                                              ),
                                            ] else if (!l.blurred) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Tap for full profile',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.7),
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
            child: Row(
              children: [
                Text(
                  'Chat',
                  style: GoogleFonts.syne(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                // Only for gender+sexuality combos with can_see_incoming_likes
                if (canSeeLikes)
                  Material(
                    color: SpyceColors.pink.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: _showIncomingLikes,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.favorite,
                              size: 18,
                              color: SpyceColors.pinkSoft,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              likesCount > 0 ? 'Likes ($likesCount)' : 'Likes',
                              style: GoogleFonts.dmSans(
                                color: SpyceColors.pinkSoft,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Prominent likes entry under header (same permission gate)
        if (!loading && canSeeLikes)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Material(
              color: SpyceColors.dark800,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _showIncomingLikes,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              SpyceColors.pink.withValues(alpha: 0.9),
                              SpyceColors.gold.withValues(alpha: 0.75),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              likesCount > 0
                                  ? '$likesCount people liked you'
                                  : 'Who liked you',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              likesCount > 0
                                  ? (canViewFullLikeProfiles
                                      ? 'See full profiles · like back to match'
                                      : 'Tap to see them')
                                  : 'You’ll see likes here when you get them',
                              style: const TextStyle(
                                color: SpyceColors.dark100,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: SpyceColors.dark200,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // WhatsApp-style matches strip
        if (!loading && matches.isNotEmpty)
          SizedBox(
            height: 108,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              scrollDirection: Axis.horizontal,
              itemCount: matches.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final m = matches[i];
                return GestureDetector(
                  onTap: () => _openMatch(m),
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: m.isOnline
                                  ? const [
                                      SpyceColors.pink,
                                      SpyceColors.gold,
                                    ]
                                  : const [
                                      SpyceColors.dark400,
                                      SpyceColors.dark500,
                                    ],
                            ),
                          ),
                          child: NetworkAvatar(
                            url: m.imageUrl,
                            name: m.shortOrName,
                            size: 64,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          m.shortOrName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        const Divider(height: 1),

        Expanded(
          child: loading
              ? const ShimmerList()
              : items.isEmpty
                  ? const EmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'No conversations',
                      subtitle:
                          'Matches appear on top — tap one to say hi.',
                    )
                  : RefreshIndicator(
                      color: SpyceColors.pink,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final c = items[i];
                          final time = c.updatedAt != null
                              ? DateFormat.jm().format(c.updatedAt!)
                              : '';
                          // @username (never fallback letter "C" from "Chat")
                          final displayName = c.displayUsername;
                          return Material(
                            color: SpyceColors.dark800,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => context.push(
                                '/app/chat/${c.id}',
                                extra: {
                                  'title': displayName,
                                  'peerUserId': c.peerUserId,
                                  'peerImage': c.peerImage,
                                  'isOnline': c.isOnline,
                                  'lastSeen': c.lastSeen,
                                },
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // username  ·  [profile pic → open peer profile]
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  displayName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.dmSans(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              // Tap avatar → peer profile (does not open chat)
                                              GestureDetector(
                                                onTap: () {
                                                  final id = c.peerUserId;
                                                  if (id == null ||
                                                      id.isEmpty) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Profile unavailable for this chat',
                                                        ),
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                  context.push(
                                                    '/app/user/$id',
                                                    extra: {
                                                      'title': displayName,
                                                      'image': c.peerImage,
                                                    },
                                                  );
                                                },
                                                child: _ChatListAvatar(
                                                  url: c.peerImage,
                                                  name: displayName,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            c.lastMessage?.isNotEmpty == true
                                                ? c.lastMessage!
                                                : 'Say hi…',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: SpyceColors.dark100,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          time,
                                          style: const TextStyle(
                                            color: SpyceColors.dark200,
                                            fontSize: 11,
                                          ),
                                        ),
                                        if (c.unreadCount > 0) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: SpyceColors.pink,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '${c.unreadCount}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

/// Small avatar beside username — user upload or admin pool URL.
class _ChatListAvatar extends StatelessWidget {
  const _ChatListAvatar({this.url, this.name});

  final String? url;
  final String? name;

  @override
  Widget build(BuildContext context) {
    // Avoid "C" from "Chat" — strip @ for initial
    final raw = (name ?? '?').replaceFirst('@', '');
    final letter = raw.isNotEmpty ? raw[0].toUpperCase() : '?';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SpyceColors.dark400),
        color: SpyceColors.dark600,
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              placeholder: (_, _) => const ColoredBox(color: SpyceColors.dark600),
              errorWidget: (_, _, _) => Center(
                child: Text(
                  letter,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SpyceColors.pinkSoft,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                letter,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: SpyceColors.pinkSoft,
                ),
              ),
            ),
    );
  }
}

class ChatThreadPage extends ConsumerStatefulWidget {
  const ChatThreadPage({
    super.key,
    required this.conversationId,
    this.title,
    this.peerUserId,
    this.peerImage,
    this.isOnline = false,
    this.lastSeen,
  });

  final String conversationId;
  final String? title;
  final String? peerUserId;
  final String? peerImage;
  final bool isOnline;
  final String? lastSeen;

  @override
  ConsumerState<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends ConsumerState<ChatThreadPage> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();
  List<ChatMessage> messages = [];
  bool loading = true;
  bool sending = false;
  bool uploadingMedia = false;
  final Set<String> _markedSeen = {};
  late bool _isOnline;
  String? _lastSeen;

  @override
  void initState() {
    super.initState();
    _isOnline = widget.isOnline;
    _lastSeen = widget.lastSeen;
    _load();
    _refreshPeerPresence();
  }

  /// Re-fetch conversation list presence for this peer (fresh online/last_seen).
  Future<void> _refreshPeerPresence() async {
    final peerId = widget.peerUserId;
    if (peerId == null || peerId.isEmpty) return;
    try {
      final list = await ref.read(chatRepositoryProvider).getConversations();
      ConversationItem? match;
      for (final c in list) {
        if (c.id == widget.conversationId || c.peerUserId == peerId) {
          match = c;
          break;
        }
      }
      if (match == null || !mounted) return;
      setState(() {
        _isOnline = match!.isOnline;
        _lastSeen = match.lastSeen ?? _lastSeen;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final myId = ref.read(authControllerProvider).user?.id;
    final store = ChatLocalStore.instance;

    // 1) Instant from device storage (48h vanish filter applied)
    final cached = await store.load(widget.conversationId, myId: myId);
    if (mounted && cached.isNotEmpty) {
      setState(() {
        messages = cached;
        loading = false;
      });
      _jumpBottom();
    }

    // 2) Soft-sync with server for newer messages (like WhatsApp)
    try {
      final remote = await ref.read(chatRepositoryProvider).getMessages(
            widget.conversationId,
            myId: myId,
          );
      final merged = await store.mergeAndSave(
        conversationId: widget.conversationId,
        local: cached,
        remote: remote,
        myId: myId,
      );
      if (!mounted) return;
      setState(() {
        messages = merged;
        loading = false;
      });
      _jumpBottom();
      _markIncomingSeen(merged);
    } catch (_) {
      if (!mounted) return;
      if (cached.isEmpty) {
        setState(() {
          messages = [];
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    }
  }

  /// Mark unread *text* messages as seen.
  /// Media is only marked when the user opens it (view-once must not auto-delete).
  Future<void> _markIncomingSeen(List<ChatMessage> list) async {
    final chat = ref.read(chatRepositoryProvider);
    for (final m in list) {
      if (m.isMe || m.isSeen || m.id.isEmpty || m.id.startsWith('local-')) {
        continue;
      }
      // Never auto-open / auto-delete media
      if (m.isMedia) continue;
      if (_markedSeen.contains(m.id)) continue;
      _markedSeen.add(m.id);
      try {
        await chat.markSeen(m.id);
      } catch (_) {
        _markedSeen.remove(m.id);
      }
    }
  }

  void _openPeerProfile() {
    final id = widget.peerUserId;
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile unavailable for this chat')),
      );
      return;
    }
    context.push(
      '/app/user/$id',
      extra: {
        'title': widget.title,
        'image': widget.peerImage,
      },
    );
  }

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || sending) return;
    final myId = ref.read(authControllerProvider).user?.id ?? 'me';
    final optimistic = ChatMessage(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversationId,
      senderId: myId,
      text: text,
      createdAt: DateTime.now(),
      isMe: true,
      localStatus: ChatSendStatus.sending,
    );
    setState(() {
      messages = [...messages, optimistic];
      sending = true;
      _textCtrl.clear();
    });
    _jumpBottom();
    // Persist optimistic immediately (device-first like WhatsApp)
    await ChatLocalStore.instance.append(widget.conversationId, optimistic);
    try {
      final sent = await ref.read(chatRepositoryProvider).sendMessage(
            widget.conversationId,
            text,
            myId: myId,
          );
      if (!mounted) return;
      final confirmed = sent.copyWith(
        isMe: true,
        localStatus: ChatSendStatus.sent,
        deliveredAt: sent.deliveredAt ?? DateTime.now(),
      );
      setState(() {
        messages = [
          ...messages.where((m) => m.id != optimistic.id),
          confirmed,
        ];
        sending = false;
      });
      await ChatLocalStore.instance.save(widget.conversationId, messages);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        messages = messages
            .map(
              (m) => m.id == optimistic.id
                  ? m.copyWith(localStatus: ChatSendStatus.failed)
                  : m,
            )
            .toList();
        sending = false;
      });
      await ChatLocalStore.instance.save(widget.conversationId, messages);
    }
  }

  Future<bool> _ensureMediaPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is required')),
          );
        }
        return false;
      }
      return true;
    }
    // Gallery — photos/videos
    var status = await Permission.photos.request();
    if (status.isGranted || status.isLimited) return true;
    status = await Permission.storage.request();
    if (status.isGranted) return true;
    // Android 13+ video bucket
    final video = await Permission.videos.request();
    if (video.isGranted) return true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Media library permission is required')),
      );
    }
    return false;
  }

  Future<void> _pickAndSendMedia() async {
    if (uploadingMedia || sending) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SpyceColors.dark800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: SpyceColors.pinkSoft),
              title: const Text('Photo from gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'image_gallery'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_camera_outlined, color: SpyceColors.pinkSoft),
              title: const Text('Take photo',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'image_camera'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.videocam_outlined, color: SpyceColors.teal),
              title: const Text('Video from gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'video_gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: SpyceColors.teal),
              title: const Text('Record video',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'video_camera'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    final isVideo = choice.startsWith('video');
    final source =
        choice.endsWith('camera') ? ImageSource.camera : ImageSource.gallery;
    final allowed = await _ensureMediaPermission(source);
    if (!allowed || !mounted) return;

    XFile? file;
    try {
      if (isVideo) {
        file = await _picker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 2),
        );
      } else {
        file = await _picker.pickImage(
          source: source,
          imageQuality: 85,
          maxWidth: 1920,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open picker: $e')),
        );
      }
      return;
    }
    if (file == null || !mounted) return;
    await _uploadMedia(file.path, isVideo ? 'video' : 'image');
  }

  Future<void> _uploadMedia(String path, String messageType) async {
    final myId = ref.read(authControllerProvider).user?.id ?? 'me';
    final localId = 'local-media-${DateTime.now().millisecondsSinceEpoch}';
    // Keep local path so sender always sees media until server replaces it
    final optimistic = ChatMessage(
      id: localId,
      conversationId: widget.conversationId,
      senderId: myId,
      text: messageType == 'video' ? '🎥 Sending video…' : '📷 Sending photo…',
      messageType: messageType,
      mediaUrl: path,
      createdAt: DateTime.now(),
      isMe: true,
      localStatus: ChatSendStatus.sending,
    );
    setState(() {
      messages = [...messages, optimistic];
      uploadingMedia = true;
    });
    _jumpBottom();
    await ChatLocalStore.instance.append(widget.conversationId, optimistic);

    try {
      final uploadRes = await ref.read(chatRepositoryProvider).uploadMedia(
            widget.conversationId,
            path,
            messageType: messageType,
          );
      // Media is async (202 → Celery). Poll until remote media appears.
      // Keep optimistic row until a real media message is found.
      final myId2 = ref.read(authControllerProvider).user?.id;
      var list = messages;
      var foundMedia = false;
      ChatMessage? remoteMedia;
      for (var attempt = 0; attempt < 12; attempt++) {
        await Future.delayed(
          Duration(milliseconds: attempt == 0 ? 900 : 1400),
        );
        if (!mounted) return;
        try {
          final remote = await ref.read(chatRepositoryProvider).getMessages(
                widget.conversationId,
                myId: myId2,
              );
          // Prefer keeping optimistic until we find real media with URL
          final merged = await ChatLocalStore.instance.mergeAndSave(
            conversationId: widget.conversationId,
            local: messages,
            remote: remote,
            myId: myId2,
          );
          remoteMedia = null;
          for (final m in merged) {
            if (!m.isMedia || !m.isMe) continue;
            if (m.id == localId || m.id.startsWith('local-')) continue;
            final mu = m.mediaUrl;
            if (mu == null || mu.isEmpty) continue;
            if (!(mu.startsWith('http') || mu.startsWith('/media'))) continue;
            if (m.createdAt == null) continue;
            if (DateTime.now().difference(m.createdAt!).inMinutes >= 10) {
              continue;
            }
            remoteMedia = m;
            break;
          }
          foundMedia = remoteMedia != null;
          if (foundMedia) {
            // Drop optimistic local once server media is ready
            list = merged.where((m) => m.id != localId).toList();
            await ChatLocalStore.instance.save(widget.conversationId, list);
          } else {
            // Keep optimistic (with local path) so sender media never vanishes
            final stillHasLocal = merged.any((m) => m.id == localId);
            list = stillHasLocal
                ? merged
                : [
                    ...merged,
                    optimistic.copyWith(
                      localStatus: ChatSendStatus.sending,
                      text: messageType == 'video'
                          ? '🎥 Processing video…'
                          : '📷 Processing photo…',
                    ),
                  ];
          }
          if (mounted) {
            setState(() => messages = list);
            _jumpBottom();
          }
          if (foundMedia) break;
        } catch (e) {
          // surface last poll error only if never found
          if (attempt == 11 && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Poll error while waiting for media: ${ApiException.describe(e)}',
                ),
                duration: const Duration(seconds: 6),
              ),
            );
          }
        }
      }
      if (!mounted) return;
      if (foundMedia) {
        setState(() {
          messages = list;
          uploadingMedia = false;
        });
        _jumpBottom();
        _markIncomingSeen(list);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              messageType == 'video' ? 'Video sent ✓' : 'Photo sent ✓',
            ),
          ),
        );
      } else {
        // Upload accepted but processing never produced a message
        final status = uploadRes['status']?.toString() ?? 'unknown';
        setState(() {
          messages = messages
              .map(
                (m) => m.id == localId
                    ? m.copyWith(
                        localStatus: ChatSendStatus.failed,
                        text:
                            'Media stuck processing (status=$status). Pull to refresh. Server may not have finished Celery/storage.',
                      )
                    : m,
              )
              .toList();
          uploadingMedia = false;
        });
        await ChatLocalStore.instance.save(widget.conversationId, messages);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload response: $uploadRes — media not in chat yet. '
              'Check Celery worker (slow queue) / storage. Pull to refresh.',
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        messages = messages
            .map(
              (m) => m.id == localId
                  ? m.copyWith(
                      localStatus: ChatSendStatus.failed,
                      text: 'Failed: ${e.userMessage}',
                    )
                  : m,
            )
            .toList();
        uploadingMedia = false;
      });
      await ChatLocalStore.instance.save(widget.conversationId, messages);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.fullDetail),
          duration: const Duration(seconds: 8),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        messages = messages
            .map(
              (m) => m.id == localId
                  ? m.copyWith(
                      localStatus: ChatSendStatus.failed,
                      text: 'Failed: ${e.toString()}',
                    )
                  : m,
            )
            .toList();
        uploadingMedia = false;
      });
      await ChatLocalStore.instance.save(widget.conversationId, messages);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiException.describe(e)),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  bool _isNetworkMedia(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  bool _isLocalMedia(String? url) {
    if (url == null || url.isEmpty) return false;
    if (_isNetworkMedia(url) || url.startsWith('file://')) return false;
    // Device path (Android/iOS/macOS)
    return url.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(url);
  }

  /// One-time media: open with viewer-username watermark; after close, receiver
  /// marks seen (server deletes file + soft-deletes message) and bubble vanishes.
  Future<void> _openMedia(ChatMessage m) async {
    if (m.isDeleted && !m.isMe) return;
    final url = m.mediaUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            m.localStatus == ChatSendStatus.sending
                ? 'Still uploading…'
                : 'Media not available yet — pull to refresh',
          ),
        ),
      );
      return;
    }

    final stampName = ref.read(viewerUsernameProvider);

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (ctx) => _OneTimeMediaDialog(
        url: url,
        isVideo: m.isVideo,
        isLocal: _isLocalMedia(url),
        viewerUsername: stampName,
      ),
    );

    // Receiver only: vanish after close (one-time view)
    if (!m.isMe && !m.id.startsWith('local-')) {
      await _consumeOneTimeMedia(m);
    }
  }

  Future<void> _consumeOneTimeMedia(ChatMessage m) async {
    // Remove from UI immediately (one-time)
    if (mounted) {
      setState(() {
        messages = messages.where((x) => x.id != m.id).toList();
      });
      await ChatLocalStore.instance.save(widget.conversationId, messages);
    }
    if (m.isSeen) return;
    try {
      await ref.read(chatRepositoryProvider).markSeen(m.id);
      _markedSeen.add(m.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not finalize one-time view: ${ApiException.describe(e)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _startCall(CallKind kind) async {
    final peerId = widget.peerUserId;
    if (peerId == null || peerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Peer id unavailable for call on this conversation'),
        ),
      );
      return;
    }
    await ref.read(callControllerProvider.notifier).startCall(
          peerUserId: peerId,
          kind: kind,
          peerName: widget.title,
        );
  }

  Future<void> _onMenu(String value) async {
    final peerId = widget.peerUserId;
    final mod = ref.read(moderationRepositoryProvider);
    final chat = ref.read(chatRepositoryProvider);

    switch (value) {
      case 'leave':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Leave chat?'),
            content: const Text(
              'You will unmatch and this chat will be removed from your inbox.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Leave',
                  style: TextStyle(color: SpyceColors.pink),
                ),
              ),
            ],
          ),
        );
        if (ok != true) return;
        try {
          await chat.leaveConversation(widget.conversationId);
        } catch (_) {}
        if (mounted) context.pop();
      case 'block':
        if (peerId == null) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Block user?'),
            content: const Text(
              'They won’t be able to message or find you. You can unblock later in Settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Block',
                  style: TextStyle(color: SpyceColors.pink),
                ),
              ),
            ],
          ),
        );
        if (ok != true) return;
        try {
          await mod.blockUser(peerId);
          await chat.leaveConversation(widget.conversationId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User blocked')),
            );
            context.pop();
          }
        } on ApiException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(e.message)));
          }
        }
      case 'report':
        if (peerId == null) return;
        final reasonCtrl = TextEditingController();
        String reason = 'SPAM';
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setLocal) {
              return AlertDialog(
                title: const Text('Report user'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: reason,
                      items: const [
                        DropdownMenuItem(value: 'SPAM', child: Text('Spam')),
                        DropdownMenuItem(
                            value: 'HARASSMENT', child: Text('Harassment')),
                        DropdownMenuItem(
                            value: 'INAPPROPRIATE',
                            child: Text('Inappropriate')),
                        DropdownMenuItem(
                            value: 'FAKE_PROFILE', child: Text('Fake profile')),
                        DropdownMenuItem(
                            value: 'UNDERAGE_CSE',
                            child: Text('Underage sexual exploitation')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                      ],
                      onChanged: (v) => setLocal(() => reason = v ?? 'SPAM'),
                      decoration: const InputDecoration(labelText: 'Reason'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Details (optional)',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Submit'),
                  ),
                ],
              );
            },
          ),
        );
        if (ok != true) return;
        try {
          await mod.reportUser(
            reportedUserId: peerId,
            reason: reason,
            description: reasonCtrl.text.trim(),
            targetType: 'USER_PROFILE',
            targetId: peerId,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Report submitted. Thank you.')),
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
              const SnackBar(content: Text('Report submitted')),
            );
          }
        } finally {
          reasonCtrl.dispose();
        }
      case 'report_block':
        if (peerId == null) return;
        try {
          await mod.reportAndBlock(
            reportedUserId: peerId,
            reason: 'HARASSMENT',
            description: 'Reported and blocked from chat',
          );
          await chat.leaveConversation(widget.conversationId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reported and blocked')),
            );
            context.pop();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString())),
            );
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: _openPeerProfile,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Stack(
                children: [
                  NetworkAvatar(
                    url: widget.peerImage,
                    name: widget.title,
                    size: 36,
                  ),
                  if (_isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: SpyceColors.dark900,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title ?? 'Chat',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.syne(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      PresenceLabels.display(
                        isOnline: _isOnline,
                        lastSeenLabel: _lastSeen,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _isOnline
                            ? const Color(0xFF6EE7B7)
                            : SpyceColors.dark200,
                        fontSize: 12,
                        fontWeight:
                            _isOnline ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Voice call',
            onPressed: () => _startCall(CallKind.voice),
            icon: const Icon(Icons.call_outlined),
          ),
          IconButton(
            tooltip: 'Video call',
            onPressed: () => _startCall(CallKind.video),
            icon: const Icon(Icons.videocam_outlined),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: SpyceColors.dark800,
            onSelected: _onMenu,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'leave',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout, size: 20),
                  title: Text('Leave chat'),
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.block, size: 20),
                  title: Text('Block user'),
                ),
              ),
              PopupMenuItem(
                value: 'report',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.flag_outlined, size: 20),
                  title: Text('Report'),
                ),
              ),
              PopupMenuItem(
                value: 'report_block',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.gpp_bad_outlined, size: 20),
                  title: Text('Report & block'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: SpyceColors.pink))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      return _MessageBubble(
                        message: m,
                        onOpenMedia: () => _openMedia(m),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Send photo or video',
                    onPressed: (sending || uploadingMedia)
                        ? null
                        : _pickAndSendMedia,
                    icon: uploadingMedia
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: SpyceColors.pinkSoft,
                            ),
                          )
                        : const Icon(Icons.attach_file_rounded,
                            color: SpyceColors.pinkSoft),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      style: const TextStyle(color: SpyceColors.white),
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    onPressed: (sending || uploadingMedia) ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: SpyceColors.pink,
                      foregroundColor: SpyceColors.white,
                    ),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bubble with media support + WhatsApp-style delivery ticks.
/// Media never shows a thumbnail — only a distinct photo/video icon.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onOpenMedia,
  });

  final ChatMessage message;
  final VoidCallback onOpenMedia;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final time = m.createdAt != null
        ? DateFormat.jm().format(m.createdAt!.toLocal())
        : '';
    final maxW = MediaQuery.of(context).size.width * 0.75;
    final isMediaIcon = m.isMedia && !m.isDeleted;

    return Align(
      alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: maxW),
        child: Column(
          crossAxisAlignment:
              m.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: isMediaIcon
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: m.isMe ? SpyceColors.pink : SpyceColors.dark700,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(m.isMe ? 16 : 4),
                  bottomRight: Radius.circular(m.isMe ? 4 : 16),
                ),
              ),
              child: _buildBody(context),
            ),
            if (time.isNotEmpty || m.isMe)
              Padding(
                padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (time.isNotEmpty)
                      Text(
                        time,
                        style: const TextStyle(
                          color: SpyceColors.dark200,
                          fontSize: 10,
                        ),
                      ),
                    if (m.isMe) ...[
                      const SizedBox(width: 4),
                      _DeliveryTicks(status: m.deliveryStatus),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final m = message;

    // Opened / vanished (receiver or after server soft-delete)
    if (m.isDeleted && m.isMedia) {
      return Text(
        m.isVideo ? '🔒 Video opened' : '🔒 Photo opened',
        style: GoogleFonts.dmSans(
          color: SpyceColors.white.withValues(alpha: 0.7),
          fontStyle: FontStyle.italic,
          height: 1.35,
        ),
      );
    }

    // Icon-only one-time media (photo ≠ video icons)
    if (m.isMedia) {
      final sending = m.localStatus == ChatSendStatus.sending;
      final canOpen = !sending && m.mediaUrl != null && m.mediaUrl!.isNotEmpty;
      return GestureDetector(
        onTap: canOpen ? onOpenMedia : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.55),
                  width: 1.2,
                ),
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      m.isVideo
                          ? Icons.videocam_rounded
                          : Icons.image_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.isVideo ? 'Video' : 'Photo',
                    style: GoogleFonts.dmSans(
                      color: SpyceColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    sending
                        ? 'Uploading…'
                        : (m.isMe ? 'Tap to preview · one-time' : 'Tap once to view'),
                    style: GoogleFonts.dmSans(
                      color: SpyceColors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      m.text,
      style: GoogleFonts.dmSans(
        color: SpyceColors.white,
        height: 1.35,
      ),
    );
  }
}

/// Fullscreen one-time media viewer with viewer-username watermark only.
class _OneTimeMediaDialog extends StatelessWidget {
  const _OneTimeMediaDialog({
    required this.url,
    required this.isVideo,
    required this.isLocal,
    this.viewerUsername,
  });

  final String url;
  final bool isVideo;
  final bool isLocal;
  final String? viewerUsername;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          Positioned.fill(
            child: MediaUserIdWatermark(
              username: viewerUsername,
              child: Center(
                child: isVideo
                    ? _VideoOneTimeBody(url: url, isLocal: isLocal)
                    : InteractiveViewer(
                        child: isLocal
                            ? Image.file(
                                File(url),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Icon(Icons.broken_image,
                                      color: Colors.white54, size: 48),
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.contain,
                                placeholder: (_, __) => const SizedBox(
                                  height: 240,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: SpyceColors.pink,
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Icon(Icons.broken_image,
                                      color: Colors.white54, size: 48),
                                ),
                              ),
                      ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 12,
            child: Text(
              isVideo ? 'One-time video' : 'One-time photo',
              style: GoogleFonts.dmSans(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Close',
            ),
          ),
        ],
      ),
    );
  }
}

/// Video body: in-dialog preview with watermark; falls back to external open.
class _VideoOneTimeBody extends StatelessWidget {
  const _VideoOneTimeBody({required this.url, required this.isLocal});

  final String url;
  final bool isLocal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_rounded, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          Text(
            'Video is watermarked with your username.\nIt will vanish after you close this screen.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async {
              final uri = isLocal
                  ? Uri.file(url)
                  : Uri.tryParse(url);
              if (uri == null) return;
              final ok = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open video')),
                );
              }
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Play video'),
            style: FilledButton.styleFrom(
              backgroundColor: SpyceColors.pink,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryTicks extends StatelessWidget {
  const _DeliveryTicks({required this.status});

  final ChatDeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ChatDeliveryStatus.sending:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: SpyceColors.dark200,
          ),
        );
      case ChatDeliveryStatus.failed:
        return const Icon(Icons.error_outline, size: 14, color: Colors.orangeAccent);
      case ChatDeliveryStatus.read:
        return const Text(
          '✓✓',
          style: TextStyle(
            color: Color(0xFF5EEAD4), // teal read ticks
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        );
      case ChatDeliveryStatus.delivered:
        return const Text(
          '✓✓',
          style: TextStyle(
            color: SpyceColors.dark200,
            fontSize: 12,
            height: 1,
          ),
        );
      case ChatDeliveryStatus.sent:
        return const Text(
          '✓',
          style: TextStyle(
            color: SpyceColors.dark200,
            fontSize: 12,
            height: 1,
          ),
        );
      case ChatDeliveryStatus.none:
        return const SizedBox.shrink();
    }
  }
}
