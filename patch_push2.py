import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Refactor _pushEmojis
    new_emojis = """  static Future<void> _pushEmojis(String token, String repo) async {
    final emojis = SettingsService.allEmojis;
    final content = jsonEncode(emojis);
    await _pushFile(token, repo, 'emojis.json', content, message: 'update: emojis');
  }"""
    
    # Replace _pushEmojis using regex but escaping repl
    content = re.sub(
        r"  static Future<void> _pushEmojis.*?  }\n",
        new_emojis.replace('\\', '\\\\') + '\n',
        content,
        flags=re.DOTALL
    )

    new_note = """  static Future<void> _pushNote(String token, String repo, Note note,
      {String? sha}) async {
    final content = _noteToMarkdown(note);
    final path = _notePath(note);
    final title = note.title.isEmpty ? note.id : note.title;
    final safeTitle = title.replaceAll(RegExp(r'[^\\w\\s-]'), '').trim();
    final message = 'update: ${safeTitle.isEmpty ? note.id : safeTitle}';
    
    await _pushFile(token, repo, path, content, message: message);
  }"""

    content = re.sub(
        r"  static Future<void> _pushNote\(String token, String repo, Note note,[\s\S]*?(?=\n  static Future<List<Map<String, dynamic>>>)",
        new_note.replace('\\', '\\\\'),
        content
    )

    with open(path, 'w') as f:
        f.write(content)

process_file('lib/services/github_sync_service.dart')
print("Patched.")
