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
  /// Parses a markdown file into one or more notes.
  ///
  /// A single plain markdown file — even one containing multiple `#` headings
  /// or `---` horizontal rules — is imported as ONE note. Multiple notes are
  /// only produced when the file uses titled front-matter blocks (the format
  /// this app writes on bulk export), e.g.:
  ///   ---
  ///   title: Alpha
  ///   ---
  ///   ...body...
  static List<ImportedNote> parse(String raw, String fallbackTitle) {
    final lines = raw.split('\n');
    return _parseSections(_splitByFrontMatter(lines), fallbackTitle);
  }

  /// Splits the input into section line-groups. A new section starts only at a
  /// titled front-matter block (`---` ... `title: ...` ... `---`), and the body
  /// lines that follow it stay in the same section. Everything else — including
  /// bare `---` horizontal rules — is kept as content.
  static List<List<String>> _splitByFrontMatter(List<String> lines) {
    final sections = <List<String>>[];
    var i = 0;
    while (i < lines.length) {
      if (lines[i].trim() == '---' &&
          _findFrontMatterEnd(lines, i + 1) != null) {
        final end = _findFrontMatterEnd(lines, i + 1)!;
        final section = <String>[];
        section.addAll(lines.sublist(i, end + 1));
        var j = end + 1;
        final body = <String>[];
        while (j < lines.length) {
          if (lines[j].trim() == '---' &&
              _findFrontMatterEnd(lines, j + 1) != null) {
            break;
          }
          body.add(lines[j]);
          j++;
        }
        section.addAll(body);
        sections.add(section);
        i = j;
        continue;
      }
      final section = <String>[];
      while (i < lines.length) {
        if (lines[i].trim() == '---' &&
            _findFrontMatterEnd(lines, i + 1) != null) {
          break;
        }
        section.add(lines[i]);
        i++;
      }
      sections.add(section);
    }
    return sections;
  }

  /// Given lines and the index right after an opening `---`, finds the index
  /// of the matching closing `---` if the block parses as *titled* front
  /// matter (contains a non-empty `title:`). Returns null otherwise.
  static int? _findFrontMatterEnd(List<String> lines, int start) {
    var foundTitle = false;
    for (var j = start; j < lines.length; j++) {
      final l = lines[j].trim();
      if (l == '---') {
        return foundTitle ? j : null;
      }
      if (l.startsWith('title:') && l.substring(6).trim().isNotEmpty) {
        foundTitle = true;
      }
    }
    return null;
  }

  static List<ImportedNote> _parseSections(
      List<List<String>> sections, String fallbackTitle) {
    final notes = <ImportedNote>[];
    for (final section in sections) {
      final lines = section;
      // Only the first section may be headed by front matter that sits at the
      // very top of the file; we handle both leading front matter and body.
      final meta = _frontMatter(lines);
      if (meta != null) {
        final bodyStart = _frontMatterBodyStart(lines);
        final body = bodyStart == null
            ? ''
            : lines.sublist(bodyStart).join('\n').trim();
        notes.add(ImportedNote(
          title: meta.title,
          body: body,
          tags: meta.tags,
          created: meta.created,
        ));
      } else {
        final text = lines.join('\n').trim();
        if (text.isNotEmpty) notes.add(_descNote(text, fallbackTitle));
      }
    }
    return notes;
  }

  static ImportedNote? _frontMatter(List<String> lines) {
    String? title;
    DateTime? created;
    final tags = <String>[];
    var foundTitle = false;
    // Front matter must start at the first line of the section.
    var i = 0;
    while (i < lines.length && lines[i].trim() == '') {
      i++;
    }
    if (i >= lines.length || lines[i].trim() != '---') return null;
    i++;
    var closed = false;
    for (; i < lines.length; i++) {
      final l = lines[i].trim();
      if (l == '---') {
        closed = true;
        break;
      }
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
    if (!closed || !foundTitle || title == null || title.isEmpty) return null;
    return ImportedNote(title: title, body: '', created: created, tags: tags);
  }

  /// Returns the first line index strictly after the front-matter block, or
  /// null if the section does not start with a titled front-matter block.
  static int? _frontMatterBodyStart(List<String> lines) {
    var i = 0;
    while (i < lines.length && lines[i].trim() == '') {
      i++;
    }
    if (i >= lines.length || lines[i].trim() != '---') return null;
    i++;
    var foundTitle = false;
    for (; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        return foundTitle ? i + 1 : null;
      }
      if (lines[i].trim().startsWith('title:')) foundTitle = true;
    }
    return null;
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
