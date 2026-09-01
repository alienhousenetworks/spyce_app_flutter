import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/spyce_colors.dart';
import '../../data/repositories/api_repositories.dart';

class SafetyBlocksPage extends ConsumerStatefulWidget {
  const SafetyBlocksPage({super.key});

  @override
  ConsumerState<SafetyBlocksPage> createState() => _SafetyBlocksPageState();
}

class _SafetyBlocksPageState extends ConsumerState<SafetyBlocksPage> {
  bool loading = true;
  String? error;
  List<BlockedUser> blocks = [];

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
      final list = await ref.read(moderationRepositoryProvider).listBlocks();
      if (!mounted) return;
      setState(() {
        blocks = list;
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = '$e';
      });
    }
  }

  Future<void> _unblock(BlockedUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpyceColors.dark800,
        title: const Text('Unblock?'),
        content: Text(
          'They may appear in Discover and can message you again.',
          style: TextStyle(color: SpyceColors.dark100),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(moderationRepositoryProvider).unblockUser(user.id);
      if (!mounted) return;
      setState(() => blocks.removeWhere((b) => b.id == user.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unblocked @${user.username ?? 'user'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not unblock: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety & blocks'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'Blocks are two-way for discovery. They cannot find you, and you will not see them.',
              style: GoogleFonts.dmSans(color: SpyceColors.dark100, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Report someone from chat or their profile. Underage sexual exploitation reports are reviewed by staff immediately.',
              style: const TextStyle(color: SpyceColors.dark200, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            Text(
              'BLOCKED PEOPLE',
              style: GoogleFonts.syne(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: SpyceColors.dark100,
              ),
            ),
            const SizedBox(height: 8),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              Text(error!, style: const TextStyle(color: SpyceColors.error))
            else if (blocks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'You have not blocked anyone.',
                  style: TextStyle(color: SpyceColors.dark200),
                ),
              )
            else
              ...blocks.map(
                (b) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: SpyceColors.dark600,
                    child: Text(
                      (b.username ?? '?').isEmpty
                          ? '?'
                          : b.username![0].toUpperCase(),
                    ),
                  ),
                  title: Text(
                    b.username != null ? '@${b.username}' : 'User',
                    style: const TextStyle(color: SpyceColors.white),
                  ),
                  trailing: TextButton(
                    onPressed: () => _unblock(b),
                    child: const Text('Unblock'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
