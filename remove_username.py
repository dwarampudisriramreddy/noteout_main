import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    old_text = "SettingsService.userName.isEmpty ? 'get your thoughts out' : 'get your thoughts out, ${SettingsService.userName}'"
    new_text = "'get your thoughts out'"
    
    content = content.replace(old_text, new_text)

    with open(path, 'w') as f:
        f.write(content)

process_file('lib/screens/note_list_screen.dart')
print("Patched.")
