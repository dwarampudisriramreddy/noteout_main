import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    old_text = """            Text(
              SettingsService.userName.isEmpty ? 'get your thoughts out' : 'get your thoughts out, ${SettingsService.userName}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
                letterSpacing: 0.5,
                height: 1.0,
              ),
            ),"""
            
    new_text = """            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                SettingsService.userName.isEmpty ? 'get your thoughts out' : 'get your thoughts out, ${SettingsService.userName}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 8.5,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey,
                  letterSpacing: 0,
                  height: 1.0,
                ),
              ),
            ),"""

    content = content.replace(old_text, new_text)

    with open(path, 'w') as f:
        f.write(content)

process_file('lib/screens/note_list_screen.dart')
print("Patched title.")
