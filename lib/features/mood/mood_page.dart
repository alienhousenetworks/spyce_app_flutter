import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/spyce_colors.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/api_repositories.dart';
import '../../shared/widgets/spyce_widgets.dart';

class MoodPage extends ConsumerStatefulWidget {
  const MoodPage({super.key});

  @override
  ConsumerState<MoodPage> createState() => _MoodPageState();
}

class _MoodPageState extends ConsumerState<MoodPage> {
  List<CatalogOption> moods = [];
  final selected = <String>{};
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ref.read(optionsRepositoryProvider).moods();
    if (!mounted) return;
    setState(() {
      moods = list.isNotEmpty
          ? list
          : const [
              CatalogOption(id: '1', name: 'Soft', emoji: '🌸'),
              CatalogOption(id: '2', name: 'Chaotic', emoji: '⚡'),
              CatalogOption(id: '3', name: 'Flirty', emoji: '😏'),
              CatalogOption(id: '4', name: 'Deep', emoji: '🌊'),
              CatalogOption(id: '5', name: 'Chill', emoji: '😌'),
              CatalogOption(id: '6', name: 'Hot', emoji: '🔥'),
            ];
      loading = false;
    });
  }

  Future<void> _save() async {
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick up to 3 moods')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .setMoods(selected.take(3).toList());
    } catch (_) {}
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your mood'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: SpyceColors.pink))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'How are you showing up today?',
                    style: GoogleFonts.syne(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pick up to 3. Shown on your feed card.',
                    style: TextStyle(color: SpyceColors.dark100),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: moods.map((m) {
                          final on = selected.contains(m.id);
                          return FilterChip(
                            label: Text(
                              m.emoji != null ? '${m.emoji} ${m.name}' : m.name,
                            ),
                            selected: on,
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  if (selected.length >= 3) return;
                                  selected.add(m.id);
                                } else {
                                  selected.remove(m.id);
                                }
                              });
                            },
                            selectedColor: SpyceColors.pinkDim,
                            checkmarkColor: SpyceColors.pink,
                            labelStyle: TextStyle(
                              color: on ? SpyceColors.pinkSoft : SpyceColors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  SpycePrimaryButton(
                    label: 'Save mood',
                    loading: saving,
                    onPressed: _save,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(color: SpyceColors.dark100),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
