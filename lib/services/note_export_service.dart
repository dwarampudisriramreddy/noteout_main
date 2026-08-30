import 'dart:convert';
import 'dart:typed_data';
import 'package:docs_gee/docs_gee.dart';
import 'package:markdown/markdown.dart' as md;

class NoteExportFile {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  NoteExportFile({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });
}

class NoteExportService {
  static NoteExportFile build({
    required String title,
    required String content,
    required String format,
  }) {
    final base = _slug(title);
    switch (format) {
      case 'markdown':
        return NoteExportFile(
          bytes: Uint8List.fromList(utf8.encode('# $title\n\n$content')),
          fileName: '$base.md',
          mimeType: 'text/markdown',
        );
      case 'html':
        return NoteExportFile(
          bytes: Uint8List.fromList(utf8.encode(_html(title, content))),
          fileName: '$base.html',
          mimeType: 'text/html',
        );
      case 'docx':
        return NoteExportFile(
          bytes: DocxGenerator().generate(_document(title, content)),
          fileName: '$base.docx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      case 'pdf':
        return NoteExportFile(
          bytes: PdfGenerator().generate(_document(title, content)),
          fileName: '$base.pdf',
          mimeType: 'application/pdf',
        );
      default:
        throw ArgumentError('unknown export format: $format');
    }
  }

  static String _slug(String title) {
    var name = title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\r|\n|\t'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) name = 'untitled';
    return name;
  }

  static String _html(String title, String content) {
    final body = md.markdownToHtml('# $title\n\n$content');
    return '<!DOCTYPE html>\n<html><head><meta charset="utf-8"><title>$title</title></head>\n<body>$body\n</body></html>';
  }

  static Document _document(String title, String content) {
    final doc = Document(title: title);
    doc.addParagraph(Paragraph.heading(title, level: 1));

    final lines = content.split('\n');
    var inCode = false;
    final codeLines = <String>[];

    void flushCode() {
      if (codeLines.isNotEmpty) {
        doc.addParagraph(Paragraph.codeBlock(codeLines.join('\n')));
        codeLines.clear();
      }
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.startsWith('```')) {
        if (inCode) {
          flushCode();
          inCode = false;
        } else {
          flushCode();
          inCode = true;
        }
        continue;
      }
      if (inCode) {
        codeLines.add(line);
        continue;
      }
      if (line.trim().isEmpty) {
        flushCode();
        continue;
      }
      final heading = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        doc.addParagraph(Paragraph.heading(
          heading.group(2)!,
          level: heading.group(1)!.length,
        ));
        continue;
      }
      if (line.startsWith('> ')) {
        doc.addParagraph(Paragraph.quote(line.substring(2)));
        continue;
      }
      final bullet = RegExp(r'^[-*]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        doc.addParagraph(Paragraph.bulletItem(bullet.group(1)!));
        continue;
      }
      final numbered = RegExp(r'^\d+\.\s+(.*)$').firstMatch(line);
      if (numbered != null) {
        doc.addParagraph(Paragraph.numberedItem(numbered.group(1)!));
        continue;
      }
      if (line.trim() == '---') continue;
      doc.addParagraph(Paragraph.text(line));
    }
    flushCode();
    return doc;
  }
}