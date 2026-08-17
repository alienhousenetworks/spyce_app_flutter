import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'confession_themes.dart';

/// Segment types parsed from a raw confession text.
enum ConfessionBlockType {
  paragraph,
  numberedItem,
  divider,
  quote,
  poeticStanza,
  salutation,
}

class ConfessionBlock {
  const ConfessionBlock({
    required this.type,
    required this.content,
    this.numberLabel,
    this.dividerSymbol,
  });

  final ConfessionBlockType type;
  final String content;
  final String? numberLabel;
  final String? dividerSymbol;
}

/// Rich parser for creative confession layouts.
class ConfessionParser {
  static final RegExp _dividerRegex = RegExp(
    r'^(?:[─\-=~*_·•\s]{2,}[✦❦❖☾⚡⭐◈◊◆◇][─\-=~*_·•\s]{2,}|[─\-=~*_]{3,}|[✦❦❖☾⚡⭐◈◊◆◇]{1,3})$',
  );

  static final RegExp _numberedItemRegex = RegExp(
    r'^(?:(?:(\d+)[\.\)]|\[(\d+)\]|\((\d+)\))\s+(.*)|(?:([•\-\*])\s+(.*)))$',
  );

  static List<ConfessionBlock> parse(String text, ConfessionStyleType style) {
    if (text.trim().isEmpty) return [];

    final rawLines = text.split('\n');
    final blocks = <ConfessionBlock>[];
    final currentStanza = <String>[];

    void flushStanza() {
      if (currentStanza.isNotEmpty) {
        final joined = currentStanza.join('\n').trim();
        if (joined.isNotEmpty) {
          blocks.add(
            ConfessionBlock(
              type: style == ConfessionStyleType.poetry
                  ? ConfessionBlockType.poeticStanza
                  : ConfessionBlockType.paragraph,
              content: joined,
            ),
          );
        }
        currentStanza.clear();
      }
    }

    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];
      final trimmed = line.trim();

      // Empty line -> breaks stanzas
      if (trimmed.isEmpty) {
        flushStanza();
        continue;
      }

      // Check for ornamental dividers
      if (_dividerRegex.hasMatch(trimmed) || _isKnownDivider(trimmed)) {
        flushStanza();
        blocks.add(
          ConfessionBlock(
            type: ConfessionBlockType.divider,
            content: trimmed,
            dividerSymbol: _extractDividerSymbol(trimmed),
          ),
        );
        continue;
      }

      // Check for numbered items
      final numberMatch = _numberedItemRegex.firstMatch(trimmed);
      if (numberMatch != null) {
        flushStanza();
        final numLabel = numberMatch.group(1) ??
            numberMatch.group(2) ??
            numberMatch.group(3) ??
            numberMatch.group(5) ??
            '•';
        final content = numberMatch.group(4) ?? numberMatch.group(6) ?? '';
        blocks.add(
          ConfessionBlock(
            type: ConfessionBlockType.numberedItem,
            content: content.trim(),
            numberLabel: numLabel,
          ),
        );
        continue;
      }

      // Check for quotes / callouts
      if (trimmed.startsWith('>') ||
          (trimmed.startsWith('“') && trimmed.endsWith('”')) ||
          (trimmed.startsWith('"') && trimmed.endsWith('"') && trimmed.length > 4)) {
        flushStanza();
        final qText = trimmed.startsWith('>')
            ? trimmed.substring(1).trim()
            : trimmed;
        blocks.add(
          ConfessionBlock(
            type: ConfessionBlockType.quote,
            content: qText,
          ),
        );
        continue;
      }

      // Check for letter salutations
      if (style == ConfessionStyleType.letter &&
          (trimmed.toLowerCase().startsWith('dear ') ||
              trimmed.toLowerCase().startsWith('to ') ||
              trimmed.toLowerCase().startsWith('yours,') ||
              trimmed.toLowerCase().startsWith('sincerely,'))) {
        flushStanza();
        blocks.add(
          ConfessionBlock(
            type: ConfessionBlockType.salutation,
            content: trimmed,
          ),
        );
        continue;
      }

      // Collect as part of current verse/stanza or paragraph
      currentStanza.add(line);
    }

    flushStanza();
    return blocks;
  }

  static bool _isKnownDivider(String text) {
    for (final d in ConfessionDividerPreset.all) {
      if (text.trim() == d.pattern.trim()) return true;
    }
    return false;
  }

  static String _extractDividerSymbol(String text) {
    for (final d in ConfessionDividerPreset.all) {
      if (text.contains(d.symbol)) return d.symbol;
    }
    if (text.contains('✦')) return '✦';
    if (text.contains('❦')) return '❦';
    if (text.contains('❖')) return '❖';
    if (text.contains('☾')) return '☾';
    if (text.contains('⚡')) return '⚡';
    if (text.contains('⭐')) return '⭐';
    return '✦';
  }
}

/// Rich renderer for formatted confession content.
class ConfessionFormattedBody extends StatelessWidget {
  const ConfessionFormattedBody({
    super.key,
    required this.text,
    required this.styleType,
    required this.theme,
    this.maxLines,
    this.isCompact = false,
  });

  final String text;
  final ConfessionStyleType styleType;
  final ConfessionThemeConfig theme;
  final int? maxLines;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final blocks = ConfessionParser.parse(text, styleType);

    if (blocks.isEmpty) {
      return Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 16,
          height: 1.55,
          color: theme.textColor,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < blocks.length; i++) ...[
          if (i > 0)
            SizedBox(
              height: _getSpacingForBlock(blocks[i - 1], blocks[i], isCompact),
            ),
          _buildBlock(context, blocks[i]),
        ],
      ],
    );
  }

  double _getSpacingForBlock(
    ConfessionBlock prev,
    ConfessionBlock next,
    bool compact,
  ) {
    if (prev.type == ConfessionBlockType.divider ||
        next.type == ConfessionBlockType.divider) {
      return compact ? 6 : 10;
    }
    if (prev.type == ConfessionBlockType.poeticStanza) {
      return compact ? 10 : 14;
    }
    if (prev.type == ConfessionBlockType.numberedItem) {
      return compact ? 6 : 8;
    }
    return compact ? 8 : 10;
  }

  Widget _buildBlock(BuildContext context, ConfessionBlock block) {
    switch (block.type) {
      case ConfessionBlockType.divider:
        return ConfessionOrnamentalDivider(
          symbol: block.dividerSymbol ?? '✦',
          theme: theme,
          isCompact: isCompact,
        );

      case ConfessionBlockType.numberedItem:
        return ConfessionNumberedItemWidget(
          numberLabel: block.numberLabel ?? '•',
          content: block.content,
          theme: theme,
          isCompact: isCompact,
        );

      case ConfessionBlockType.quote:
        return ConfessionQuoteBlock(
          quote: block.content,
          theme: theme,
          isCompact: isCompact,
        );

      case ConfessionBlockType.poeticStanza:
        return ConfessionPoeticStanzaWidget(
          stanza: block.content,
          theme: theme,
          isCompact: isCompact,
        );

      case ConfessionBlockType.salutation:
        return Text(
          block.content,
          style: GoogleFonts.syne(
            fontSize: isCompact ? 15 : 17,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: theme.accentColor,
            letterSpacing: 0.2,
          ),
        );

      case ConfessionBlockType.paragraph:
      default:
        return Text(
          block.content,
          style: GoogleFonts.dmSans(
            fontSize: isCompact ? 15 : 16,
            height: 1.55,
            color: theme.textColor,
            letterSpacing: 0.1,
          ),
        );
    }
  }
}

/// Ornamental Divider Line with Glowing Accent and Decorative Symbol
class ConfessionOrnamentalDivider extends StatelessWidget {
  const ConfessionOrnamentalDivider({
    super.key,
    required this.symbol,
    required this.theme,
    this.isCompact = false,
  });

  final String symbol;
  final ConfessionThemeConfig theme;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 4 : 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    theme.accentColor.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.badgeColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.accentColor.withValues(alpha: 0.35),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.glowColor,
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                symbol,
                style: TextStyle(
                  color: theme.accentColor,
                  fontSize: isCompact ? 11 : 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.accentColor.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Numbered List Item with Glowing Number Chip
class ConfessionNumberedItemWidget extends StatelessWidget {
  const ConfessionNumberedItemWidget({
    super.key,
    required this.numberLabel,
    required this.content,
    required this.theme,
    this.isCompact = false,
  });

  final String numberLabel;
  final String content;
  final ConfessionThemeConfig theme;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final isDigit = int.tryParse(numberLabel) != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2, right: 10),
          padding: EdgeInsets.symmetric(
            horizontal: isDigit ? 7 : 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: theme.badgeColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.accentColor.withValues(alpha: 0.4),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.glowColor,
                blurRadius: 6,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Text(
            numberLabel,
            style: GoogleFonts.syne(
              color: theme.accentColor,
              fontSize: isCompact ? 12 : 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            content,
            style: GoogleFonts.dmSans(
              fontSize: isCompact ? 15 : 16,
              height: 1.5,
              color: theme.textColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

/// Poetic Stanza with Poetic Typography & Verse Flow
class ConfessionPoeticStanzaWidget extends StatelessWidget {
  const ConfessionPoeticStanzaWidget({
    super.key,
    required this.stanza,
    required this.theme,
    this.isCompact = false,
  });

  final String stanza;
  final ConfessionThemeConfig theme;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: theme.badgeColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: theme.accentColor.withValues(alpha: 0.5),
            width: 2.5,
          ),
        ),
      ),
      child: Text(
        stanza,
        style: GoogleFonts.cormorantGaramond(
          fontSize: isCompact ? 17 : 19,
          height: 1.6,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          color: theme.textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Quote / Deep Remark Block
class ConfessionQuoteBlock extends StatelessWidget {
  const ConfessionQuoteBlock({
    super.key,
    required this.quote,
    required this.theme,
    this.isCompact = false,
  });

  final String quote;
  final ConfessionThemeConfig theme;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isCompact ? 10 : 14,
        isCompact ? 8 : 10,
        isCompact ? 10 : 14,
        isCompact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: theme.badgeColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.accentColor.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.format_quote_rounded,
            size: isCompact ? 18 : 22,
            color: theme.accentColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              quote,
              style: GoogleFonts.dmSans(
                fontSize: isCompact ? 15 : 16,
                fontStyle: FontStyle.italic,
                height: 1.5,
                color: theme.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
