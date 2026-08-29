import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Import the new controller
    if "import '../widgets/markdown_controller.dart';" not in content:
        content = content.replace(
            "import '../widgets/markdown_renderer.dart';",
            "import '../widgets/markdown_renderer.dart';\nimport '../widgets/markdown_controller.dart';"
        )

    # Change _contentController type
    content = content.replace(
        "final _contentController = TextEditingController();",
        "final _contentController = MarkdownController();"
    )

    with open(path, 'w') as f:
        f.write(content)

process_file('lib/screens/editor_screen.dart')
print("Patched editor.")
