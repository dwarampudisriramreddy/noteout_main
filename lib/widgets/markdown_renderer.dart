import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import '../screens/editor_screen.dart';
import '../theme/app_theme.dart';

class MarkdownRenderer extends StatelessWidget {
  final String content;
  final Map<String, GlobalKey>? headingKeys;

  const MarkdownRenderer({
    super.key,
    required this.content,
    this.headingKeys,
  });

  static final _inlineLatexPattern =
      RegExp(r'(?<!\$)\$(?!\$)(.+?)(?<!\$)\$(?!\$)');

  @override
  Widget build(BuildContext context) {
    final segments = _parseSegments(content);

    if (segments.length == 1 && segments.first is _MarkdownSegment) {
      return _buildMarkdown(context, (segments.first as _MarkdownSegment).text);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments.map((segment) {
        if (segment is _MarkdownSegment) {
          if (segment.text.trim().isEmpty) return const SizedBox.shrink();
          return _buildMarkdown(context, segment.text);
        } else if (segment is _BlockLatexSegment) {
          return _buildBlockLatex(context, segment.latex);
        } else if (segment is _InlineLatexSegment) {
          return _buildInlineLatex(context, segment.latex);
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }

  Widget _buildMarkdown(BuildContext context, String text) {
    return MarkdownBody(
      data: text,
      selectable: true,
      shrinkWrap: true,
      styleSheet: _styleSheet(context),
      extensionSet: md.ExtensionSet.gitHubFlavored,
      builders: _headingBuilders(),
      onTapLink: (text, href, title) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EditorScreen(noteId: text)),
        );
      },
    );
  }

  Map<String, MarkdownElementBuilder> _headingBuilders() {
    if (headingKeys == null) return const {};
    final builders = <String, MarkdownElementBuilder>{};
    for (var i = 1; i <= 6; i++) {
      builders['h$i'] = _KeyedHeadingBuilder(headingKeys!);
    }
    return builders;
  }

  Widget _buildBlockLatex(BuildContext context, String latex) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Math.tex(
          latex,
          textStyle: TextStyle(fontSize: 16, color: context.nText),
        ),
      ),
    );
  }

  Widget _buildInlineLatex(BuildContext context, String latex) {
    try {
      return Math.tex(
        latex,
        textStyle: TextStyle(fontSize: 14, color: context.nText),
      );
    } catch (e) {
      return Text(
        '\$$latex\$',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Colors.red[400],
        ),
      );
    }
  }

  List<_Segment> _parseSegments(String input) {
    final segments = <_Segment>[];
    final lines = input.split('\n');
    final buffer = StringBuffer();
    bool inDisplayMath = false;
    final displayMathBuffer = StringBuffer();

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed == r'$$') {
        if (inDisplayMath) {
          if (buffer.isNotEmpty) {
            segments.add(_MarkdownSegment(buffer.toString()));
            buffer.clear();
          }
          segments.add(_BlockLatexSegment(displayMathBuffer.toString().trim()));
          displayMathBuffer.clear();
          inDisplayMath = false;
        } else {
          if (buffer.isNotEmpty) {
            segments.add(_MarkdownSegment(buffer.toString()));
            buffer.clear();
          }
          inDisplayMath = true;
        }
        continue;
      }

      if (inDisplayMath) {
        displayMathBuffer.writeln(line);
        continue;
      }

      if (_inlineLatexPattern.hasMatch(line)) {
        if (buffer.isNotEmpty) {
          segments.add(_MarkdownSegment(buffer.toString()));
          buffer.clear();
        }
        int lastEnd = 0;
        for (final match in _inlineLatexPattern.allMatches(line)) {
          if (match.start > lastEnd) {
            final before = line.substring(lastEnd, match.start);
            if (before.isNotEmpty) {
              segments.add(_InlineMarkdownSegment(before));
            }
          }
          segments.add(_InlineLatexSegment(match.group(1)!));
          lastEnd = match.end;
        }
        if (lastEnd < line.length) {
          buffer.writeln(line.substring(lastEnd));
        } else {
          buffer.writeln();
        }
      } else {
        buffer.writeln(line);
      }
    }

    if (buffer.isNotEmpty) {
      final remaining = buffer.toString();
      if (remaining.trim().isNotEmpty) {
        segments.add(_MarkdownSegment(remaining));
      }
    }

    if (segments.isEmpty) {
      segments.add(_MarkdownSegment(input));
    }

    return segments;
  }

  MarkdownStyleSheet _styleSheet(BuildContext context) {
    return MarkdownStyleSheet(
      p: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: context.nText,
        height: 1.7,
      ),
      h1: TextStyle(
        fontFamily: 'monospace',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: context.nText,
        height: 1.3,
      ),
      h2: TextStyle(
        fontFamily: 'monospace',
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: context.nText,
        height: 1.3,
      ),
      h3: TextStyle(
        fontFamily: 'monospace',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: context.nText,
        height: 1.3,
      ),
      h4: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.nText,
        height: 1.3,
      ),
      h5: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.nMuted,
        height: 1.3,
      ),
      h6: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.nMuted,
        height: 1.3,
      ),
      em: const TextStyle(
        fontFamily: 'monospace',
        fontStyle: FontStyle.italic,
      ),
      strong: const TextStyle(
        fontFamily: 'monospace',
        fontWeight: FontWeight.w700,
      ),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: context.nText,
        backgroundColor: context.nPanel2,
      ),
      codeblockDecoration: BoxDecoration(
        color: context.nPanel2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.nLine, width: 0.5),
      ),
      codeblockPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      blockquote: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: context.nMuted,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: context.nLine, width: 2),
        ),
      ),
      blockquotePadding:
          const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      listBullet: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: context.nMuted,
      ),
      listIndent: 20,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: context.nLine, width: 0.5),
        ),
      ),
      tableHead: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: context.nText,
      ),
      tableBody: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: context.nMuted,
      ),
      tableBorder: TableBorder.all(
        color: context.nLine,
        width: 0.5,
      ),
      tableCellsPadding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

sealed class _Segment {}

class _KeyedHeadingBuilder extends MarkdownElementBuilder {
  final Map<String, GlobalKey> keys;
  _KeyedHeadingBuilder(this.keys);

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final key = keys[element.textContent.trim()];
    if (key == null) return null;
    return KeyedSubtree(
      key: key,
      child: SelectableText(element.textContent, style: preferredStyle),
    );
  }
}

class _MarkdownSegment extends _Segment {
  final String text;
  _MarkdownSegment(this.text);
}

class _InlineMarkdownSegment extends _Segment {
  final String text;
  _InlineMarkdownSegment(this.text);
}

class _BlockLatexSegment extends _Segment {
  final String latex;
  _BlockLatexSegment(this.latex);
}

class _InlineLatexSegment extends _Segment {
  final String latex;
  _InlineLatexSegment(this.latex);
}
