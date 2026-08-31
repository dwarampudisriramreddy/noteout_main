import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:hive_ce/hive.dart';

class SettingsService {
  static late Box<String> _box;
  static late Box<String> _emojiBox;
  static final ValueNotifier<bool> onboardedNotifier =
      ValueNotifier<bool>(false);
  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> init() async {
    _box = await Hive.openBox<String>('settings');
    _emojiBox = await Hive.openBox<String>('emojis');
    onboardedNotifier.value = _box.get('onboardedSkipped') == '1';
    themeNotifier.value = _themeModeFromString(_box.get('theme') ?? 'system');
  }

  static ThemeMode get themeMode => themeNotifier.value;

  static set themeMode(ThemeMode value) {
    themeNotifier.value = value;
    _box.put('theme', _themeModeToString(value));
  }

  static ThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode value) {
    switch (value) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static String get githubToken => _box.get('githubToken') ?? '';

  static set githubToken(String value) {
    _box.put('githubToken', value.trim());
  }

  static String get githubUsername => _box.get('githubUsername') ?? '';

  static set githubUsername(String value) {
    _box.put('githubUsername', value);
  }

  static String get githubRepo => _box.get('githubRepo') ?? 'noteout';

  static set githubRepo(String value) {
    _box.put('githubRepo', value);
  }

  static String get userName => _box.get('userName') ?? '';

  static set userName(String value) {
    _box.put('userName', value);
  }

  static String get siteAbout => _box.get('siteAbout') ?? '';

  static set siteAbout(String value) {
    _box.put('siteAbout', value);
  }

  static String get siteLayout => _box.get('siteLayout') ?? 'personal';

  static set siteLayout(String value) {
    _box.put('siteLayout', value);
  }

  static String get siteAccent => _box.get('siteAccent') ?? 'indigo';

  static set siteAccent(String value) {
    _box.put('siteAccent', value);
  }

  static String get siteTheme => _box.get('siteTheme') ?? 'modern';

  static set siteTheme(String value) {
    _box.put('siteTheme', value);
  }

  static bool get siteShowCalendar =>
      _box.get('siteShowCalendar') != '0';

  static set siteShowCalendar(bool value) {
    _box.put('siteShowCalendar', value ? '1' : '0');
  }

  static bool get siteShowProfile => _box.get('siteShowProfile') != '0';

  static set siteShowProfile(bool value) {
    _box.put('siteShowProfile', value ? '1' : '0');
  }

  static String get profileImagePath => _box.get('profileImagePath') ?? '';

  static set profileImagePath(String value) {
    _box.put('profileImagePath', value);
  }

  static bool get hasSkippedOnboarding => onboardedNotifier.value;

  static set hasSkippedOnboarding(bool value) {
    onboardedNotifier.value = value;
    _box.put('onboardedSkipped', value ? '1' : '0');
  }

static bool get hasCreatedReadme => _box.get('hasCreatedReadme') == '1';

  static set hasCreatedReadme(bool value) {
    _box.put('hasCreatedReadme', value ? '1' : '0');
  }

  static String getEmoji(String date) => _emojiBox.get(date) ?? '';

  static void setEmoji(String date, String emoji) {
    _emojiBox.put(date, emoji);
  }

  static Map<String, String> get allEmojis =>
      Map<String, String>.from(_emojiBox.toMap());

  static List<String> get galleryFavs {
    final raw = _box.get('galleryFavs') ?? '';
    if (raw.isEmpty) return const [];
    try {
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return const [];
    }
  }

  static set galleryFavs(List<String> urls) {
    _box.put('galleryFavs', jsonEncode(urls));
  }
}
