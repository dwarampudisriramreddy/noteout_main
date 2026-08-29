import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # In editor_screen.dart, remove _headingKeys.clear()
    content = content.replace("    _headingKeys.clear();\n", "")

    with open(path, 'w') as f:
        f.write(content)

process_file('lib/screens/editor_screen.dart')

def process_markdown_renderer(path):
    with open(path, 'r') as f:
        content = f.read()

    old_builder = """class _KeyedHeadingBuilder extends MarkdownElementBuilder {
  final Map<String, GlobalKey> keys;
  _KeyedHeadingBuilder(this.keys);

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final key = keys[element.textContent.trim()];
    if (key == null) return null;
    return KeyedSubtree(
      key: key,
      child: SelectableText(element.textContent, style: preferredStyle),
    );
  }
}"""

    new_builder = """class _KeyedHeadingBuilder extends MarkdownElementBuilder {
  final Map<String, GlobalKey> keys;
  _KeyedHeadingBuilder(this.keys);

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final text = element.textContent.trim();
    final key = keys.putIfAbsent(text, () => GlobalKey());
    return KeyedSubtree(
      key: key,
      child: SelectableText(text, style: preferredStyle),
    );
  }
}"""

    content = content.replace(old_builder, new_builder)

    with open(path, 'w') as f:
        f.write(content)

process_markdown_renderer('lib/widgets/markdown_renderer.dart')
print("Patched headings.")
