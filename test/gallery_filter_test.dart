import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:noteout/models/note.dart';
import 'package:noteout/screens/gallery_screen.dart';
import 'package:noteout/services/settings_service.dart';
import 'package:noteout/services/storage_service.dart';

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('noteout_test');
    Hive.init(dir.path);
    await StorageService.init();
    await SettingsService.init();
  });

  String texts(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .toList()
      .toString();

  testWidgets('gallery filters by tag via the tag menu', (tester) async {
    // contents use plain links (no [!](image) markdown) so that no
    // Image.network real-async loading is triggered inside FakeAsync.
    await tester.runAsync(() async {
      await StorageService.saveNote(Note(
        title: 'one',
        tags: const ['work'],
        content: '[a](https://example.com/a)\n',
      ));
      await StorageService.saveNote(Note(
        title: 'two',
        tags: const ['therapy', 'work'],
        content: '[b](https://example.com/b)\n',
      ));
      await StorageService.saveNote(Note(
        title: 'three',
        content: '[c](https://example.com/c)\n',
      ));
    });

    await tester.pumpWidget(const MaterialApp(home: GalleryScreen()));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {});
    await tester.pumpAndSettle();

    String urlText() => texts(tester);

    // flat gallery: no tag section headers, all urls present
    expect(urlText(), contains('example.com/a'), reason: urlText());
    expect(urlText(), contains('example.com/c'), reason: urlText());
    expect(find.text('#work'), findsNothing);
    expect(find.text('#untagged'), findsNothing);

    Future<void> pick(String label) async {
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label), warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    // filter menu lists the tags
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    expect(find.text('#work'), findsOneWidget);
    expect(find.text('#therapy'), findsOneWidget);
    expect(find.text('untagged'), findsOneWidget);
    await tester.tap(find.text('all'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // #work narrows to work-tagged urls only
    await pick('#work');
    expect(urlText(), contains('example.com/a'), reason: urlText());
    expect(urlText(), contains('example.com/b'), reason: urlText());
    expect(urlText(), isNot(contains('example.com/c')), reason: urlText());

    // #therapy narrows to therapy-tagged urls
    await pick('#therapy');
    expect(urlText(), isNot(contains('example.com/a')), reason: urlText());
    expect(urlText(), contains('example.com/b'), reason: urlText());
    expect(urlText(), isNot(contains('example.com/c')), reason: urlText());

    // untagged -> notes with no tags
    await pick('untagged');
    expect(urlText(), isNot(contains('example.com/a')), reason: urlText());
    expect(urlText(), isNot(contains('example.com/b')), reason: urlText());
    expect(urlText(), contains('example.com/c'), reason: urlText());

    // all -> clears the filter
    await pick('all');
    expect(urlText(), contains('example.com/a'), reason: urlText());
    expect(urlText(), contains('example.com/c'), reason: urlText());

    SettingsService.galleryFavs = const [];
  });
}