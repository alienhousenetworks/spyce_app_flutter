import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/spyce_colors.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/api_repositories.dart';
import '../../shared/widgets/spyce_widgets.dart';

class MatchesPage extends ConsumerStatefulWidget {
  const MatchesPage({super.key});

  @override
  ConsumerState<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends ConsumerState<MatchesPage> {
  List<MatchItem> matches = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final list = await ref.read(matchRepositoryProvider).getMatches();
      if (!mounted) return;
      setState(() {
        matches = list;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        matches = [];
        loading = false;
        error = 'Could not load matches. Pull to refresh.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Matches',
          action: IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ),
        Expanded(
          child: loading
              ? const ShimmerList()
              : matches.isEmpty
                  ? EmptyState(
                      icon: Icons.favorite_border,
                      title: error != null ? 'Could not load matches' : 'No matches yet',
                      subtitle: error ??
                          'Like people in Discover — when they like you back, they land here.',
                    )
                  : RefreshIndicator(
                      color: SpyceColors.pink,
                      onRefresh: _load,
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: matches.length,
                        itemBuilder: (context, i) {
                          final m = matches[i];
                          return _MatchTile(
                            match: m,
                            onTap: () {
                              if (m.conversationId != null) {
                                context.push(
                                  '/app/chat/${m.conversationId}',
                                  extra: m.displayName,
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Conversation not ready yet — open Chat tab.',
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match, required this.onTap});
  final MatchItem match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = match.matchedAt != null
        ? DateFormat.MMMd().format(match.matchedAt!)
        : '';
    return Material(
      color: SpyceColors.dark800,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SpyceColors.dark500),
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: match.imageUrl != null && match.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: match.imageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
                                color: SpyceColors.dark600,
                                alignment: Alignment.center,
                                child: Text(
                                  match.shortOrName[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    color: SpyceColors.pinkSoft,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: SpyceColors.dark600,
                              alignment: Alignment.center,
                              child: Text(
                                match.shortOrName[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 40,
                                  color: SpyceColors.pinkSoft,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                    ),
                    if (match.isOnline)
                      const Positioned(
                        top: 10,
                        right: 10,
                        child: Icon(Icons.circle,
                            size: 12, color: SpyceColors.teal),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(
                      match.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (date.isNotEmpty)
                      Text(
                        date,
                        style: const TextStyle(
                          color: SpyceColors.dark100,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on MatchItem {
  String get shortOrName {
    if (username != null && username!.isNotEmpty) return username!;
    if (firstName != null && firstName!.isNotEmpty) return firstName!;
    return 'M';
  }
}
