import '../models/note.dart';

class ImportedNote {
  final String title;
  final String body;
  final List<String> tags;
  final DateTime? created;

  ImportedNote({
    required this.title,
    required this.body,
    this.tags = const [],
    this.created,
  });

  Note toNote() => Note(
        title: title,
        content: body,
        tags: tags,
        createdAt: created ?? DateTime.now().toUtc(),
      );
}

class MdImportService {
  static List<ImportedNote> parse(String raw, String fallbackTitle) {
    final notes = <ImportedNote>[];
    ImportedNote? pending;
    var piece = <String>[];
    final pieces = <List<String>>[];
    for (final line in raw.split('\n')) {
      if (line.trim() == '---') {
        pieces.add(piece);
        piece = <String>[];
      } else {
        piece.add(line);
      }
    }
    pieces.add(piece);
    for (final p in pieces) {
      final text = p.join('\n').trim();
      if (text.isEmpty) continue;
      final meta = _frontMatter(text);
      if (meta != null) {
        if (pending != null) notes.add(pending);
        pending = meta;
      } else if (pending case final p?) {
        pending = ImportedNote(
          title: p.title,
          body: p.body.isEmpty ? text : '${p.body}\n\n$text',
          tags: p.tags,
          created: p.created,
        );
      } else {
        notes.add(_descNote(text, fallbackTitle));
      }
    }
    if (pending != null) notes.add(pending);
    return notes;
  }

  static ImportedNote? _frontMatter(String text) {
    String? title;
    DateTime? created;
    final tags = <String>[];
    var foundTitle = false;
    for (final rawLine in text.split('\n')) {
      final l = rawLine.trim();
      if (l.isEmpty) continue;
      if (l.startsWith('title:')) {
        foundTitle = true;
        var value = l.substring(6).trim();
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.substring(1, value.length - 1);
        }
        title = value;
      } else if (l.startsWith('created:')) {
        created = DateTime.tryParse(l.substring(8).trim());
      } else if (l.startsWith('tags:')) {
        final inner =
            l.substring(5).replaceAll('[', '').replaceAll(']', '').trim();
        if (inner.isNotEmpty) {
          tags.addAll(inner
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty));
        }
      }
    }
    if (!foundTitle || title == null || title.isEmpty) return null;
    return ImportedNote(title: title, body: '', created: created, tags: tags);
  }

  static ImportedNote _descNote(String text, String fallbackTitle) {
    final lines = text.split('\n');
    final head =
        RegExp(r'^#\s+(.*)$').firstMatch(lines.isNotEmpty ? lines.first : '');
    if (head != null) {
      final title = head.group(1)!.trim();
      return ImportedNote(
        title: title.isEmpty ? fallbackTitle : title,
        body: lines.skip(1).join('\n').trim(),
      );
    }
    return ImportedNote(title: fallbackTitle, body: text.trim());
  }
}