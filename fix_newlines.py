import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Normalize line endings
    content = content.replace(
        "final lines = text.split('\\n');",
        "final lines = text.replaceAll('\\r\\n', '\\n').replaceAll('\\r', '\\n').split('\\n');"
    )

    with open(path, 'w') as f:
        f.write(content)

process_file('lib/widgets/markdown_controller.dart')
print("Patched newlines.")
