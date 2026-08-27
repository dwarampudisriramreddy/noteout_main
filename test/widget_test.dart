import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'package:noteout/main.dart';
import 'package:noteout/services/settings_service.dart';
import 'package:noteout/services/storage_service.dart';

void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('noteout_test');
    Hive.init(dir.path);
    await StorageService.init();
    await SettingsService.init();
  });

  testWidgets('App renders note list', (WidgetTester tester) async {
    await tester.pumpWidget(const NoteoutApp());
    await tester.pumpAndSettle();

    expect(find.text('noteout'), findsOneWidget);
  });
}
