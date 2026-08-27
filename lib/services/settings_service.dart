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
    _box.put('githubToken', value);
  }

  static String get githubUsername => _box.get('githubUsername') ?? '';

  static set githubUsername(String value) {
    _box.put('githubUsername', value);
  }

  static String get githubRepo => _box.get('githubRepo') ?? 'noteout';

  static set githubRepo(String value) {
    _box.put('githubRepo', value);
  }

  static bool get hasSkippedOnboarding => onboardedNotifier.value;

  static set hasSkippedOnboarding(bool value) {
    onboardedNotifier.value = value;
    _box.put('onboardedSkipped', value ? '1' : '0');
  }

  static String getEmoji(String date) => _emojiBox.get(date) ?? '';

  static void setEmoji(String date, String emoji) {
    _emojiBox.put(date, emoji);
  }

  static Map<String, String> get allEmojis =>
      Map<String, String>.from(_emojiBox.toMap());
}
