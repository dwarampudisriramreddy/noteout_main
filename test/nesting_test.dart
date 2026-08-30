import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'package:noteout/models/note.dart';
import 'package:noteout/screens/editor_screen.dart';
import 'package:noteout/services/settings_service.dart';
import 'package:noteout/services/storage_service.dart';
import 'package:noteout/widgets/markdown_controller.dart';

TextEditingValue fmt(TextEditingValue oldV, TextEditingValue newV) {
  return NestedListInputFormatter().formatEditUpdate(oldV, newV);
}

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('noteout_test');
    Hive.init(dir.path);
    await StorageService.init();
    await SettingsService.init();
  });

  group('NestedListInputFormatter', () {
    test('enter continues bullet at same level', () {
      var oldV = const TextEditingValue(text: '- item', selection: TextSelection.collapsed(offset: 6));
      var newV = const TextEditingValue(text: '- item\n', selection: TextSelection.collapsed(offset: 7));
      newV = fmt(oldV, newV);
      expect(newV.text, '- item\n- ');
      expect(newV.selection.baseOffset, 9);
    });

    test('enter keeps deep nesting', () {
      var oldV = const TextEditingValue(text: '  - child', selection: TextSelection.collapsed(offset: 9));
      var newV = const TextEditingValue(text: '  - child\n', selection: TextSelection.collapsed(offset: 10));
      newV = fmt(oldV, newV);
      expect(newV.text, '  - child\n  - ');
    });

    test('enter continues numbered lists incrementing', () {
      var oldV = const TextEditingValue(text: '1. one', selection: TextSelection.collapsed(offset: 5));
      var newV = const TextEditingValue(text: '1. one\n', selection: TextSelection.collapsed(offset: 6));
      newV = fmt(oldV, newV);
      expect(newV.text, '1. one\n2. ');
    });

    test('enter on empty top-level item ends the list', () {
      var oldV = const TextEditingValue(text: '- ', selection: TextSelection.collapsed(offset: 2));
      var newV = const TextEditingValue(text: '- \n', selection: TextSelection.collapsed(offset: 3));
      newV = fmt(oldV, newV);
      expect(newV.text, '- \n');
    });

    test('enter on empty nested item moves up one level', () {
      var oldV = const TextEditingValue(text: '    - ', selection: TextSelection.collapsed(offset: 6));
      var newV = const TextEditingValue(text: '    - \n', selection: TextSelection.collapsed(offset: 7));
      newV = fmt(oldV, newV);
      expect(newV.text, '    - \n  - ');
    });

    test('plain paragraph newline is untouched', () {
      var oldV = const TextEditingValue(text: 'hello', selection: TextSelection.collapsed(offset: 5));
      var newV = const TextEditingValue(text: 'hello\n', selection: TextSelection.collapsed(offset: 6));
      newV = fmt(oldV, newV);
      expect(newV.text, 'hello\n');
    });
  });

  group('editor tab/dedent', () {
    Future<void> pumpEditor(WidgetTester tester, String id) async {
      await tester.pumpWidget(
        MaterialApp(home: EditorScreen(noteId: id)),
      );
      await tester.pumpAndSettle();
    }

    TextField contentField(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField).last);

    testWidgets('tab indents the current line', (tester) async {
      final note = Note(title: 't', content: '');
      await tester.runAsync(() => StorageService.saveNote(note));

      await pumpEditor(tester, note.id);
      final field = find.byType(TextField).last;
      await tester.showKeyboard(field);
      await tester.enterText(field, '- item');
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(contentField(tester).controller!.text, '  - item');
    });

    testWidgets('tab keeps caret after the marker, not before it',
        (tester) async {
      final note = Note(title: 't', content: '');
      await tester.runAsync(() => StorageService.saveNote(note));

      await pumpEditor(tester, note.id);
      final field = find.byType(TextField).last;
      await tester.showKeyboard(field);
      await tester.enterText(field, '- item');
      await tester.pump();

      final fieldW = tester.widget<TextField>(field);
      fieldW.controller!.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final c = contentField(tester).controller!;
      expect(c.text, '  - item');
      expect(c.selection.baseOffset, 4);
      expect(c.text.substring(0, c.selection.baseOffset), '  - ');
    });

    testWidgets('shift+tab outdents the current line', (tester) async {
      final note = Note(title: 't', content: '');
      await tester.runAsync(() => StorageService.saveNote(note));

      await pumpEditor(tester, note.id);
      final field = find.byType(TextField).last;
      await tester.showKeyboard(field);
      await tester.enterText(field, '    - deep');
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(contentField(tester).controller!.text, '  - deep');
    });

    testWidgets('multiline selection indents every line', (tester) async {
      final note = Note(title: 't', content: '');
      await tester.runAsync(() => StorageService.saveNote(note));

      await pumpEditor(tester, note.id);
      final field = find.byType(TextField).last;
      await tester.showKeyboard(field);
      await tester.enterText(field, '- a\n- b\n- c');
      await tester.pump();

      final fieldW = tester.widget<TextField>(field);
      fieldW.controller!.selection =
          const TextSelection(baseOffset: 0, extentOffset: 7);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(contentField(tester).controller!.text, '  - a\n  - b\n- c');
    });

    testWidgets('enter continues the list inside the editor', (tester) async {
      final note = Note(title: 't', content: '');
      await tester.runAsync(() => StorageService.saveNote(note));

      await pumpEditor(tester, note.id);
      final field = find.byType(TextField).last;
      await tester.showKeyboard(field);
      await tester.enterText(field, '- item');
      await tester.pump();

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '- item\n',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      await tester.pump();

      expect(contentField(tester).controller!.text, '- item\n- ');
    });
  });
}