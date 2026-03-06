import 'package:flutter/material.dart';

/// A TextEditingController that visually highlights @file mentions
/// with blue text and a light blue background.
///
/// The underlying text is unchanged — this only affects rendering.
/// Pattern: `@` preceded by start-of-string or whitespace, followed by
/// non-whitespace characters.
class MentionTextEditingController extends TextEditingController {
  static final _mentionRe = RegExp(r'(?<=^|\s)@[^\s]+');

  static const _mentionStyle = TextStyle(
    color: Color(0xFF3B82F6),
    backgroundColor: Color(0xFFEFF6FF),
    fontFamily: 'JetBrains Mono',
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;
    if (text.isEmpty) {
      return TextSpan(style: style, text: text);
    }

    final matches = _mentionRe.allMatches(text).toList();
    if (matches.isEmpty) {
      return TextSpan(style: style, text: text);
    }

    final children = <InlineSpan>[];
    var lastEnd = 0;

    for (final match in matches) {
      // Text before this mention
      if (match.start > lastEnd) {
        children.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      // The mention itself — styled
      children.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: _mentionStyle,
      ));
      lastEnd = match.end;
    }

    // Remaining text after last mention
    if (lastEnd < text.length) {
      children.add(TextSpan(text: text.substring(lastEnd)));
    }

    return TextSpan(style: style, children: children);
  }
}
