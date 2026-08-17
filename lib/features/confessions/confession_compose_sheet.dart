import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/spyce_colors.dart';
import 'confession_formatter.dart';
import 'confession_themes.dart';

class ConfessionComposeResult {
  const ConfessionComposeResult({
    required this.text,
    required this.stylePreset,
    required this.bgTheme,
    this.moodTag,
  });

  final String text;
  final String stylePreset;
  final String bgTheme;
  final String? moodTag;
}

/// Creative Confession Studio Launcher
class ConfessionComposeSheet {
  static Future<ConfessionComposeResult?> show(BuildContext context) {
    return Navigator.of(context).push<ConfessionComposeResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ConfessionComposePage(),
      ),
    );
  }
}

/// Full-screen Creative Confession Studio
class ConfessionComposePage extends StatefulWidget {
  const ConfessionComposePage({
    super.key,
    this.initialStyle = ConfessionStyleType.standard,
    this.initialTheme = 'OBSIDIAN',
  });

  final ConfessionStyleType initialStyle;
  final String initialTheme;

  @override
  State<ConfessionComposePage> createState() => _ConfessionComposePageState();
}

class _ConfessionComposePageState extends State<ConfessionComposePage> {
  late final TextEditingController _textCtrl;
  late final FocusNode _focusNode;

  late ConfessionStyleType _selectedStyle;
  late ConfessionThemeConfig _selectedTheme;
  String? _selectedMood;
  bool _showPreview = false;

  final List<String> _moodOptions = [
    'DARK_SECRET',
    'REGRET',
    'LONELY',
    'TABOO',
    'FANTASY',
    'CURIOUS',
    'HAPPY',
    'ANXIOUS',
    'GUILT',
    'GRATEFUL',
  ];

  @override
  void initState() {
    super.initState();
    _selectedStyle = widget.initialStyle;
    _selectedTheme = ConfessionThemeConfig.fromId(widget.initialTheme);
    _textCtrl = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onStyleChanged(ConfessionStyleType newStyle) {
    setState(() {
      _selectedStyle = newStyle;
      if (_textCtrl.text.isEmpty) {
        if (newStyle == ConfessionStyleType.darkSecret) {
          _selectedTheme = ConfessionThemeConfig.crimson;
          _selectedMood = 'DARK_SECRET';
        } else if (newStyle == ConfessionStyleType.midnight) {
          _selectedTheme = ConfessionThemeConfig.midnight;
          _selectedMood = 'LONELY';
        } else if (newStyle == ConfessionStyleType.poetry) {
          _selectedTheme = ConfessionThemeConfig.charcoal;
        }
      }
    });
  }

  void _insertText(String snippet) {
    final text = _textCtrl.text;
    final selection = _textCtrl.selection;

    if (selection.start >= 0 && selection.end >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, snippet);
      _textCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + snippet.length,
        ),
      );
    } else {
      _textCtrl.value = TextEditingValue(
        text: text + snippet,
        selection: TextSelection.collapsed(
          offset: (text + snippet).length,
        ),
      );
    }
  }

  void _insertNextNumber() {
    final text = _textCtrl.text;
    final lines = text.split('\n');
    int highestNumber = 0;

    for (final l in lines) {
      final match = RegExp(r'^(\d+)[\.\)]').firstMatch(l.trim());
      if (match != null) {
        final val = int.tryParse(match.group(1)!) ?? 0;
        if (val > highestNumber) highestNumber = val;
      }
    }

    final next = highestNumber + 1;
    final prefix = text.isEmpty || text.endsWith('\n') ? '' : '\n';
    _insertText('$prefix$next. ');
  }

  void _openDividerSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SpyceColors.dark900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: SpyceColors.pinkSoft,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Insert Creative Divider',
                      style: GoogleFonts.syne(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: SpyceColors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                for (final d in ConfessionDividerPreset.all)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(ctx);
                        final prefix =
                            _textCtrl.text.endsWith('\n') ? '' : '\n';
                        _insertText('$prefix${d.pattern}');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: SpyceColors.dark800,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: SpyceColors.dark600),
                        ),
                        child: Row(
                          children: [
                            Icon(d.icon, size: 18, color: SpyceColors.pinkSoft),
                            const SizedBox(width: 12),
                            Text(
                              d.name,
                              style: GoogleFonts.dmSans(
                                color: SpyceColors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              d.pattern.trim(),
                              style: TextStyle(
                                color: SpyceColors.pinkSoft.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
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
        );
      },
    );
  }

  void _insertQuote() {
    final selection = _textCtrl.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final selected = _textCtrl.text.substring(selection.start, selection.end);
      _insertText('“$selected”');
    } else {
      _insertText('“ ”');
    }
  }

  void _insertPrompt() {
    final prompt = _selectedStyle.defaultPrompt;
    if (_textCtrl.text.isEmpty) {
      _textCtrl.text = prompt;
      _textCtrl.selection = TextSelection.collapsed(offset: prompt.length);
    } else {
      final prefix = _textCtrl.text.endsWith('\n') ? '' : '\n\n';
      _insertText('$prefix$prompt');
    }
    setState(() {});
  }

  void _submit() {
    final text = _textCtrl.text.trim();
    if (text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write at least 10 characters')),
      );
      return;
    }
    if (text.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 2,000 characters allowed')),
      );
      return;
    }

    Navigator.pop(
      context,
      ConfessionComposeResult(
        text: text,
        stylePreset: _selectedStyle.code,
        bgTheme: _selectedTheme.id,
        moodTag: _selectedMood,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final charCount = _textCtrl.text.length;

    return Scaffold(
      backgroundColor: SpyceColors.dark950,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: SpyceColors.dark950,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: SpyceColors.white, size: 22),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confession Studio',
              style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SpyceColors.white,
              ),
            ),
            Text(
              'Anonymous · encrypted · 24h',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: SpyceColors.dark200,
              ),
            ),
          ],
        ),
        actions: [
          // Live preview toggle
          TextButton.icon(
            onPressed: () => setState(() => _showPreview = !_showPreview),
            icon: Icon(
              _showPreview
                  ? Icons.edit_note_rounded
                  : Icons.visibility_outlined,
              size: 18,
              color: SpyceColors.pinkSoft,
            ),
            label: Text(
              _showPreview ? 'Edit' : 'Preview',
              style: GoogleFonts.dmSans(
                color: SpyceColors.pinkSoft,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Post Button
          Padding(
            padding: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: SpyceColors.pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Post',
                style: GoogleFonts.syne(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 4),
            // Style / Category Selector Chips
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final s in ConfessionStyleType.values) ...[
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _onStyleChanged(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedStyle == s
                              ? SpyceColors.pinkDim
                              : SpyceColors.dark800,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _selectedStyle == s
                                ? SpyceColors.pink
                                : SpyceColors.dark600,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              s.icon,
                              size: 14,
                              color: _selectedStyle == s
                                  ? SpyceColors.pinkSoft
                                  : SpyceColors.dark200,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              s.label,
                              style: GoogleFonts.syne(
                                fontSize: 12,
                                fontWeight: _selectedStyle == s
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _selectedStyle == s
                                    ? SpyceColors.pinkSoft
                                    : SpyceColors.dark100,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Main Editor or Live Preview
            Expanded(
              child: _showPreview ? _buildLivePreview() : _buildEditor(),
            ),

            // Creative Toolbar above Keyboard
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              decoration: const BoxDecoration(
                color: SpyceColors.dark900,
                border: Border(
                  top: BorderSide(color: Color(0xFF1E1E24), width: 0.8),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Formatting Tools Row
                  Row(
                    children: [
                      _ToolButton(
                        icon: Icons.format_list_numbered_rounded,
                        label: '+ 1.',
                        tooltip: 'Add Numbered Point',
                        onTap: _insertNextNumber,
                      ),
                      const SizedBox(width: 8),
                      _ToolButton(
                        icon: Icons.auto_awesome,
                        label: 'Divider',
                        tooltip: 'Ornamental Divider',
                        onTap: _openDividerSelector,
                      ),
                      const SizedBox(width: 8),
                      _ToolButton(
                        icon: Icons.format_quote_rounded,
                        label: 'Quote',
                        tooltip: 'Quote Block',
                        onTap: _insertQuote,
                      ),
                      const SizedBox(width: 8),
                      _ToolButton(
                        icon: Icons.lightbulb_outline_rounded,
                        label: 'Prompt',
                        tooltip: 'Inspiration Starter',
                        onTap: _insertPrompt,
                      ),
                      const Spacer(),
                      // Character Counter
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: SpyceColors.dark800,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$charCount/2000',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: charCount > 2000
                                ? Colors.red
                                : (charCount < 10
                                    ? SpyceColors.dark200
                                    : SpyceColors.pinkSoft),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Dark Aesthetics Theme Carousel
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8, top: 6),
                          child: Text(
                            'Theme:',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: SpyceColors.dark200,
                            ),
                          ),
                        ),
                        for (final t in ConfessionThemeConfig.allThemes) ...[
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() => _selectedTheme = t),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: t.gradient,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _selectedTheme.id == t.id
                                      ? t.accentColor
                                      : t.borderColor,
                                  width: _selectedTheme.id == t.id ? 1.5 : 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: t.accentColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    t.name,
                                    style: GoogleFonts.syne(
                                      fontSize: 11,
                                      fontWeight: _selectedTheme.id == t.id
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: _selectedTheme.id == t.id
                                          ? SpyceColors.white
                                          : SpyceColors.dark100,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _selectedTheme.gradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _selectedTheme.borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _selectedTheme.glowColor,
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top metadata inside card
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _selectedTheme.badgeColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedTheme.accentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _selectedStyle.icon,
                      size: 12,
                      color: _selectedTheme.accentColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _selectedStyle.label,
                      style: GoogleFonts.syne(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _selectedTheme.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Mood Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: SpyceColors.dark900,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SpyceColors.dark600),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedMood,
                    hint: Text(
                      'Mood',
                      style: TextStyle(
                        fontSize: 11,
                        color: SpyceColors.dark200,
                      ),
                    ),
                    isDense: true,
                    dropdownColor: SpyceColors.dark800,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: SpyceColors.dark200,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text(
                          'No Mood',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ),
                      for (final m in _moodOptions)
                        DropdownMenuItem(
                          value: m,
                          child: Text(
                            m.replaceAll('_', ' '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _selectedMood = v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _textCtrl,
              focusNode: _focusNode,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: _selectedStyle == ConfessionStyleType.poetry
                  ? GoogleFonts.cormorantGaramond(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      height: 1.55,
                      color: _selectedTheme.textColor,
                    )
                  : GoogleFonts.dmSans(
                      fontSize: 16,
                      height: 1.55,
                      color: _selectedTheme.textColor,
                    ),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: _selectedStyle.defaultPrompt,
                hintStyle: TextStyle(
                  color: _selectedTheme.metaColor.withValues(alpha: 0.6),
                  fontSize: _selectedStyle == ConfessionStyleType.poetry
                      ? 17
                      : 15,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview() {
    final text = _textCtrl.text.trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Text(
              'LIVE CARD PREVIEW',
              style: GoogleFonts.syne(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: SpyceColors.pinkSoft,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: _selectedTheme.gradient,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _selectedTheme.borderColor,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _selectedTheme.glowColor,
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _selectedTheme.badgeColor,
                      child: Icon(
                        _selectedStyle.icon,
                        size: 15,
                        color: _selectedTheme.accentColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You · ${_selectedStyle.label}',
                          style: GoogleFonts.syne(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: SpyceColors.white,
                          ),
                        ),
                        Text(
                          'Just now · ${_selectedTheme.name}',
                          style: TextStyle(
                            fontSize: 11,
                            color: _selectedTheme.metaColor,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (_selectedMood != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedTheme.badgeColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedTheme.accentColor
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _selectedMood!.replaceAll('_', ' '),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _selectedTheme.accentColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (text.isEmpty)
                  Text(
                    'Your formatted confession will appear here with styled numbered badges, glowing dividers, and poetic typography…',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: _selectedTheme.metaColor,
                      fontSize: 14,
                    ),
                  )
                else
                  ConfessionFormattedBody(
                    text: text,
                    styleType: _selectedStyle,
                    theme: _selectedTheme,
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 18,
                      color: _selectedTheme.metaColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '0',
                      style: TextStyle(
                        fontSize: 12,
                        color: _selectedTheme.metaColor,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Icon(
                      Icons.repeat_rounded,
                      size: 18,
                      color: _selectedTheme.metaColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '0',
                      style: TextStyle(
                        fontSize: 12,
                        color: _selectedTheme.metaColor,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Icon(
                      Icons.mail_outline_rounded,
                      size: 18,
                      color: _selectedTheme.metaColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Note',
                      style: TextStyle(
                        fontSize: 12,
                        color: _selectedTheme.metaColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: SpyceColors.dark800,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: SpyceColors.dark600, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: SpyceColors.pinkSoft),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.syne(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: SpyceColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
