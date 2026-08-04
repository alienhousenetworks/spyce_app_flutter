import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/spyce_colors.dart';
import '../../data/models/user_models.dart';

/// India-first featured languages shown before search.
const kFeaturedLanguageNames = [
  'English',
  'Hindi',
  'Bengali',
  'Tamil',
  'Telugu',
];

/// Multi-select language picker: 4–5 popular chips + expandable search.
class LanguagePicker extends StatefulWidget {
  const LanguagePicker({
    super.key,
    required this.options,
    required this.selectedIds,
    required this.onChanged,
    this.maxFeatured = 5,
  });

  final List<CatalogOption> options;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  final int maxFeatured;

  @override
  State<LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends State<LanguagePicker> {
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CatalogOption> get _featured {
    if (widget.options.isEmpty) return const [];
    final byName = {
      for (final o in widget.options) o.name.toLowerCase(): o,
    };
    final picks = <CatalogOption>[];
    for (final name in kFeaturedLanguageNames) {
      final hit = byName[name.toLowerCase()];
      if (hit != null) picks.add(hit);
      if (picks.length >= widget.maxFeatured) break;
    }
    if (picks.length < 3) {
      for (final o in widget.options) {
        if (!picks.any((p) => p.id == o.id)) picks.add(o);
        if (picks.length >= widget.maxFeatured) break;
      }
    }
    return picks;
  }

  Set<String> get _featuredIds => _featured.map((e) => e.id).toSet();

  List<CatalogOption> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    Iterable<CatalogOption> base = widget.options;
    if (q.isEmpty) {
      base = base.where((o) => !_featuredIds.contains(o.id));
    } else {
      base = base.where((o) => o.name.toLowerCase().contains(q));
    }
    final list = base.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  void _toggle(String id) {
    final next = Set<String>.from(widget.selectedIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final featured = _featured;
    final selectedOutside = widget.options
        .where(
          (o) =>
              widget.selectedIds.contains(o.id) && !_featuredIds.contains(o.id),
        )
        .toList();

    if (widget.options.isEmpty) {
      return const Text(
        'Language options unavailable — reconnect and retry.',
        style: TextStyle(color: Color(0xFFFF6B81), fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'POPULAR',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: SpyceColors.dark300,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: featured.map((o) {
            final on = widget.selectedIds.contains(o.id);
            return _LangChip(
              label: o.name,
              selected: on,
              onTap: () => _toggle(o.id),
            );
          }).toList(),
        ),
        if (selectedOutside.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'SELECTED',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: SpyceColors.dark300,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedOutside.map((o) {
              return _LangChip(
                label: o.name,
                selected: true,
                onTap: () => _toggle(o.id),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _showSearch = !_showSearch),
          style: TextButton.styleFrom(
            foregroundColor: SpyceColors.pinkSoft,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            _showSearch
                ? 'Hide search'
                : "Don't see your language? Search all…",
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        if (_showSearch) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: SpyceColors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search languages (e.g. Assamese, Korean…)',
              prefixIcon: const Icon(
                Icons.search,
                color: SpyceColors.dark200,
                size: 20,
              ),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.35),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: SpyceColors.dark500),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: SpyceColors.pink.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: SpyceColors.pink),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: SpyceColors.pink.withValues(alpha: 0.15),
                ),
              ),
              child: _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _searchCtrl.text.trim().isEmpty
                            ? 'Type to search the full language list.'
                            : 'No languages match “${_searchCtrl.text.trim()}”.',
                        style: const TextStyle(
                          color: SpyceColors.dark200,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _filtered.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                      itemBuilder: (context, i) {
                        final o = _filtered[i];
                        final on = widget.selectedIds.contains(o.id);
                        return ListTile(
                          dense: true,
                          title: Text(
                            o.name,
                            style: TextStyle(
                              color: on
                                  ? SpyceColors.pinkSoft
                                  : SpyceColors.white,
                              fontWeight:
                                  on ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          trailing: on
                              ? const Icon(
                                  Icons.check,
                                  color: SpyceColors.pink,
                                  size: 18,
                                )
                              : null,
                          onTap: () => _toggle(o.id),
                        );
                      },
                    ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          widget.selectedIds.isEmpty
              ? 'Select at least one language'
              : '${widget.selectedIds.length} language${widget.selectedIds.length == 1 ? '' : 's'} selected',
          style: const TextStyle(color: SpyceColors.dark200, fontSize: 12),
        ),
      ],
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: selected
                ? SpyceColors.pink.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: selected
                  ? SpyceColors.pink
                  : SpyceColors.dark500,
            ),
          ),
          child: Text(
            selected ? '$label ✓' : label,
            style: TextStyle(
              color: selected ? SpyceColors.pinkSoft : SpyceColors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
