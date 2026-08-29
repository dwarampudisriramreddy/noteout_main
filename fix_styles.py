import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Fix newline span
    content = content.replace(
        "spans.add(const TextSpan(text: '\\n'));",
        "spans.add(TextSpan(text: '\\n', style: baseStyle));"
    )

    # Fix inline fallback spans
    content = content.replace(
        "spans.add(TextSpan(text: text.substring(start, match.start)));",
        "spans.add(TextSpan(text: text.substring(start, match.start), style: baseStyle));"
    )
    content = content.replace(
        "spans.add(TextSpan(text: text.substring(start)));",
        "spans.add(TextSpan(text: text.substring(start), style: baseStyle));"
    )

    with open(path, 'w') as f:
        f.write(content)

process_file('lib/widgets/markdown_controller.dart')
print("Patched styles.")
