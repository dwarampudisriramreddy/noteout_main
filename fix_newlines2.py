import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Normalize line endings more aggressively
    old_split = "final lines = text.replaceAll('\\r\\n', '\\n').replaceAll('\\r', '\\n').split('\\n');"
    new_split = "final lines = text.replaceAll('\\r\\n', '\\n').replaceAll('\\r', '\\n').replaceAll('\\u2028', '\\n').replaceAll('\\u2029', '\\n').split('\\n');"
    
    content = content.replace(old_split, new_split)

    with open(path, 'w') as f:
        f.write(content)

process_file('lib/widgets/markdown_controller.dart')
print("Patched newlines aggressively.")
