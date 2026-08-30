import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Makes Enter behave like an outliner when the previous line is a list item:
/// it starts a new item at the same nesting level. Pressing Enter on an empty
/// item walks back up one level (and ends the list at the top level).
class NestedListInputFormatter extends TextInputFormatter {
  static final _itemPattern = RegExp(r'^(\s*)([-*+]|\d+\.)\s+(.*)$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length != oldValue.text.length + 1) return newValue;

    int oldIdx = 0;
    int newIdx = 0;
    while (oldIdx < oldValue.text.length &&
        newIdx < newValue.text.length &&
        oldValue.text.codeUnitAt(oldIdx) == newValue.text.codeUnitAt(newIdx)) {
      oldIdx++;
      newIdx++;
    }
    final inserted = newValue.text.substring(newIdx);
    final rest = oldValue.text.substring(oldIdx);
    if (inserted.length != rest.length + 1 || !inserted.endsWith(rest)) {
      return newValue;
    }
    final addedChar = inserted.substring(0, inserted.length - rest.length);
    if (addedChar != '\n') return newValue;

    final before = newValue.text.substring(0, newIdx);
    final lineStart = before.lastIndexOf('\n') + 1;
    final prevLine = before.substring(lineStart);
    final match = _itemPattern.firstMatch(prevLine);
    if (match == null) return newValue;

    final indent = match.group(1)!;
    final marker = match.group(2)!;
    final afterText = match.group(3)!;

    String nextMarker;
    if (RegExp(r'^\d+\.$').hasMatch(marker)) {
      final number = int.parse(marker.substring(0, marker.length - 1));
      nextMarker = '${number + 1}.';
    } else {
      nextMarker = marker;
    }

    String insertion;
    if (afterText.trim().isEmpty) {
      final parentIndent =
          indent.length >= 2 ? indent.substring(0, indent.length - 2) : '';
      insertion = parentIndent.isEmpty ? '' : '$parentIndent$nextMarker ';
    } else {
      insertion = '$indent$nextMarker ';
    }

    final text = newValue.text;
    final reworked =
        text.substring(0, newIdx + 1) + insertion + text.substring(newIdx + 1);
    return TextEditingValue(
      text: reworked,
      selection: TextSelection.collapsed(offset: newIdx + 1 + insertion.length),
    );
  }
}

class MarkdownController extends TextEditingController {
  MarkdownController({String? text}) : super(text: text);

  bool enableHighlighting = true;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (text.isEmpty) {
      return const TextSpan();
    }
    if (!enableHighlighting) {
      return TextSpan(style: style, text: text);
    }
    
    // Fallback base style
    final baseStyle = style ?? const TextStyle(fontFamily: 'monospace');
    
    // We parse the text line by line to handle block elements easily (like headings)
    final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceAll('\u2028', '\n').replaceAll('\u2029', '\n').split('\n');
    final spans = <InlineSpan>[];
    
    for (int i = 0; i < lines.length; i++) {
      spans.addAll(_parseLine(lines[i], baseStyle));
      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  List<InlineSpan> _parseLine(String line, TextStyle baseStyle) {
    if (line.isEmpty) return [TextSpan(text: '', style: baseStyle)];
    
    // Heading 1-6
    final headingMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
    if (headingMatch != null) {
      final hashes = headingMatch.group(1)!;
      final level = hashes.length;
      final rest = headingMatch.group(2)!;
      
      double headingSize = 14.0;
      if (level == 1) headingSize = 22.0;
      else if (level == 2) headingSize = 19.0;
      else if (level == 3) headingSize = 17.0;
      else if (level == 4) headingSize = 15.0;
      else headingSize = 14.0;
      
      return [
        TextSpan(
          text: '$hashes ',
          style: baseStyle.copyWith(color: Colors.grey.withOpacity(0.5)),
        ),
        TextSpan(
          text: rest,
          style: baseStyle.copyWith(
            fontSize: headingSize,
            fontWeight: level <= 3 ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ];
    }
    
    // Blockquote
    final quoteMatch = RegExp(r'^(\>\s)(.*)$').firstMatch(line);
    if (quoteMatch != null) {
      return [
        TextSpan(
          text: quoteMatch.group(1),
          style: baseStyle.copyWith(color: Colors.grey.withOpacity(0.5)),
        ),
        TextSpan(
          text: quoteMatch.group(2),
          style: baseStyle.copyWith(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ];
    }
    
    // List items (bullet or numbered)
    final listMatch = RegExp(r'^(\s*(?:[-*+]|\d+\.)\s)(.*)$').firstMatch(line);
    if (listMatch != null) {
      return [
        TextSpan(
          text: listMatch.group(1),
          style: baseStyle.copyWith(color: Colors.blueAccent.withOpacity(0.7)),
        ),
        ..._parseInline(listMatch.group(2)!, baseStyle)
      ];
    }
    
    return _parseInline(line, baseStyle);
  }
  
  List<InlineSpan> _parseInline(String text, TextStyle baseStyle) {
    // This is a simplified inline parser.
    // It finds the first match among inline patterns.
    final pattern = RegExp(r'(\*\*(.*?)\*\*)|(\*(.*?)\*)|(`(.*?)`)|(\[\[(.*?)\]\])|(!\[(.*?)\]\((.*?)\))|(\[(.*?)\]\((.*?)\))|(\$\$(.*?)\$\$)|(\$(.*?)\$)');
    
    final spans = <InlineSpan>[];
    int start = 0;
    
    for (final match in pattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start), style: baseStyle));
      }
      
      if (match.group(1) != null) { // Bold
        spans.add(TextSpan(text: '**', style: baseStyle.copyWith(color: Colors.grey.withOpacity(0.5))));
        spans.add(TextSpan(text: match.group(2), style: baseStyle.copyWith(fontWeight: FontWeight.bold)));
        spans.add(TextSpan(text: '**', style: baseStyle.copyWith(color: Colors.grey.withOpacity(0.5))));
      } else if (match.group(3) != null) { // Italic
        spans.add(TextSpan(text: '*', style: baseStyle.copyWith(color: Colors.grey.withOpacity(0.5))));
        spans.add(TextSpan(text: match.group(4), style: baseStyle.copyWith(fontStyle: FontStyle.italic)));
        spans.add(TextSpan(text: '*', style: baseStyle.copyWith(color: Colors.grey.withOpacity(0.5))));
      } else if (match.group(5) != null) { // Code
        spans.add(TextSpan(
          text: match.group(5),
          style: baseStyle.copyWith(color: Colors.pink, backgroundColor: Colors.grey.withOpacity(0.1)),
        ));
      } else if (match.group(7) != null) { // Wiki link
        spans.add(TextSpan(text: '[[', style: baseStyle.copyWith(color: Colors.grey.withOpacity(0.5))));
        spans.add(TextSpan(text: match.group(8), style: baseStyle.copyWith(color: Colors.blue, decoration: TextDecoration.underline)));
        spans.add(TextSpan(text: ']]', style: baseStyle.copyWith(color: Colors.grey.withOpacity(0.5))));
      } else if (match.group(9) != null) { // Image
        spans.add(TextSpan(text: '![${match.group(10)}](${match.group(11)})', style: baseStyle.copyWith(color: Colors.green)));
      } else if (match.group(12) != null) { // Link
        spans.add(TextSpan(text: '[', style: baseStyle.copyWith(color: Colors.grey.withOpacity(0.5))));
        spans.add(TextSpan(text: match.group(13), style: baseStyle.copyWith(color: Colors.blue)));
        spans.add(TextSpan(text: '](', style: baseStyle.copyWith(color: Colors.grey.withOpacity(0.5))));
        spans.add(TextSpan(text: match.group(14), style: baseStyle.copyWith(color: Colors.grey, fontStyle: FontStyle.italic)));
        spans.add(TextSpan(text: ')', style: baseStyle.copyWith(color: Colors.grey.withOpacity(0.5))));
      } else if (match.group(15) != null) { // Math block
        spans.add(TextSpan(text: match.group(15), style: baseStyle.copyWith(color: Colors.orange)));
      } else if (match.group(17) != null) { // Math inline
        spans.add(TextSpan(text: match.group(17), style: baseStyle.copyWith(color: Colors.orange)));
      }
      
      start = match.end;
    }
    
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }
    
    return spans;
  }
}
