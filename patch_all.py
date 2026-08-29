import re

def process_file(path, replacements):
    with open(path, 'r') as f:
        content = f.read()

    for old, new in replacements:
        content = content.replace(old, new)

    with open(path, 'w') as f:
        f.write(content)

# 1. Update trash message
process_file('lib/screens/editor_screen.dart', [
    ("const Text('Move to trash?')", "const Text('do you want to delete?')")
])

process_file('lib/screens/note_list_screen.dart', [
    ("const Text('Move to trash?'", "const Text('do you want to delete?'")
])


# 2. Update SettingsService
settings_code = """
  static bool get hasCreatedReadme => _box.get('hasCreatedReadme') == '1';

  static set hasCreatedReadme(bool value) {
    _box.put('hasCreatedReadme', value ? '1' : '0');
  }

  static String getEmoji(String date) => _emojiBox.get(date) ?? '';
"""
process_file('lib/services/settings_service.dart', [
    ("  static String getEmoji(String date) => _emojiBox.get(date) ?? '';", settings_code.strip())
])


# 3. Update main.dart
main_old = """  try {
    await GitHubAuthService.init();
  } catch (_) {}"""

main_new = """  try {
    await GitHubAuthService.init();
  } catch (_) {}

  if (!SettingsService.hasCreatedReadme) {
    final readme = Note(
      title: 'Welcome to noteout!',
      content: '''# Welcome to noteout! 👋

noteout is your personal space to get your thoughts out. Here is a quick guide to getting started.

## 📝 Features

- **Markdown Support:** Write notes using standard Markdown formatting (bold, italics, lists, tables, etc.). Check the cheat sheet when creating a new blank note!
- **Categories & Tags:** Add `#tag` anywhere in your note to categorize it. Tags act like folders!
- **Wiki Links:** Type `[[` in any note to instantly search and link to your other notes.
- **Journaling:** Track your daily thoughts in the Journal tab. You can assign emojis to specific dates to track your mood or activity!
- **Graph View:** Tap the tree icon in the top right to visualize the connections between all your notes.
- **GitHub Sync:** Connect your GitHub account to safely backup your notes to a private repository and instantly deploy them as a beautiful, public (or private) website via GitHub Pages!

## 📸 Images

You can add images by tapping the image icon in the editor. Once uploaded to GitHub, you can manage your images in the Gallery tab.

## 🌐 Publishing

Head over to Settings -> GitHub Sync to set up your repository. Once connected, tap "sync now" anytime to push your notes and update your site.

Happy writing!
''',
      tags: ['noteout', 'guide'],
    );
    await StorageService.saveNote(readme);
    SettingsService.hasCreatedReadme = true;
  }"""
  
process_file('lib/main.dart', [
    (main_old, main_new)
])

# main.dart needs Note model imported!
process_file('lib/main.dart', [
    ("import 'services/github_sync_service.dart';", "import 'services/github_sync_service.dart';\nimport 'models/note.dart';")
])

print("Patched all.")
