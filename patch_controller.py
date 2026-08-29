import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    old_build = """  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (text.isEmpty) {
      return const TextSpan();
    }"""
    
    new_build = """  bool enableHighlighting = true;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (text.isEmpty) {
      return const TextSpan();
    }
    if (!enableHighlighting) {
      return TextSpan(style: style, text: text);
    }"""

    content = content.replace(old_build, new_build)

    with open(path, 'w') as f:
        f.write(content)

process_file('lib/widgets/markdown_controller.dart')
print("Patched controller.")
