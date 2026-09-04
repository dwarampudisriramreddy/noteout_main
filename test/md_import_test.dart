import 'package:flutter_test/flutter_test.dart';

import 'package:noteout/services/md_import_service.dart';
import 'package:noteout/services/note_export_service.dart';

void main() {
  group('MdImportService', () {
    test('single file with # heading uses heading title', () {
      final notes = MdImportService.parse(
          '# My Heading\n\nsome content\n', 'file.md');
      expect(notes.length, 1);
      expect(notes.first.title, 'My Heading');
      expect(notes.first.body, 'some content');
    });

    test('no heading falls back to file name as title', () {
      final notes = MdImportService.parse('just plain text\n', 'my file');
      expect(notes.length, 1);
      expect(notes.first.title, 'my file');
      expect(notes.first.body, 'just plain text');
    });

    test('yaml front matter exports a note', () {
      final raw = '---\n'
          'title: "Alpha"\n'
          'created: 2024-01-02T00:00:00.000Z\n'
          'tags: [one, two]\n'
          '---\n'
          '\n'
          'body text\n';
      final notes = MdImportService.parse(raw, 'file');
      expect(notes.length, 1);
      expect(notes.first.title, 'Alpha');
      expect(notes.first.tags, ['one', 'two']);
      expect(notes.first.created, DateTime.utc(2024, 1, 2));
      expect(notes.first.body, 'body text');
    });

    test('bulk export-all parses multiple notes', () {
      final raw = '---\n'
          'title: First\n'
          '---\n'
          '\n'
          'one\n'
          '---\n'
          'title: Second\n'
          'tags: [x]\n'
          '---\n'
          '\n'
          'two\n';
      final notes = MdImportService.parse(raw, 'file');
      expect(notes.length, 2);
      expect(notes[0].title, 'First');
      expect(notes[0].body, 'one');
      expect(notes[1].title, 'Second');
      expect(notes[1].body, 'two');
    });

    test('body content alone is skipped when trailing', () {
      final raw = '---\n'
          'title: Only\n'
          '---\n'
          '\n'
          'content here\n'
          '\n'
          'extra para\n';
      final notes = MdImportService.parse(raw, 'file');
      expect(notes.length, 1);
      expect(notes.first.body, contains('content here'));
      expect(notes.first.body, contains('extra para'));
    });

    test('single file with headings stays one note', () {
      final raw = '# Intro\n\n'
          'text one\n\n'
          '# Second\n\n'
          'text two\n';
      final notes = MdImportService.parse(raw, 'file');
      expect(notes.length, 1);
      expect(notes.first.title, 'Intro');
      expect(notes.first.body, contains('text one'));
      expect(notes.first.body, contains('# Second'));
      expect(notes.first.body, contains('text two'));
    });

    test('--- used as horizontal rule does not split the note', () {
      final raw = '# Title\n\n'
          'para one\n\n'
          '---\n\n'
          'para two\n';
      final notes = MdImportService.parse(raw, 'file');
      expect(notes.length, 1);
      expect(notes.first.title, 'Title');
      expect(notes.first.body, contains('para one'));
      expect(notes.first.body, contains('---'));
      expect(notes.first.body, contains('para two'));
    });
  });

  group('NoteExportService', () {
    test('markdown file is named after the title', () {
      final f = NoteExportService.build(
          title: 'My Note #1', content: 'hi', format: 'markdown');
      expect(f.fileName, 'My Note #1.md');
      expect(f.mimeType, 'text/markdown');
    });

    test('html and pdf keep the title name', () {
      final html = NoteExportService.build(
          title: 'Alpha/Beta', content: 'hi', format: 'html');
      expect(html.fileName, 'AlphaBeta.html');
      final pdf = NoteExportService.build(
          title: '   ', content: 'hi', format: 'pdf');
      expect(pdf.fileName, 'untitled.pdf');
    });
  });
}
