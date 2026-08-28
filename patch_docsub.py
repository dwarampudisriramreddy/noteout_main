import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Remove the <p class="docsub">... line in notes.html
    content = re.sub(r'<p class="docsub">organized by category — tags act like folders</p>\n', '', content)

    # Remove the <p class="docsub">... line in tags.html
    content = re.sub(r'<p class="docsub">a folder for every tag — click to explore \{count\} categorized note\{\'s\' if count != 1 else \'\'\}</p>\n', '', content)

    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
print("Patched docsub.")
