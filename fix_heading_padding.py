import re

def process_file(path):
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
    final text = element.textContent.trim();
    final key = keys.putIfAbsent(text, () => GlobalKey());
    return KeyedSubtree(
      key: key,
      child: SelectableText(text, style: preferredStyle),
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
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: SelectableText(text, style: preferredStyle),
      ),
    );
  }
}"""

    content = content.replace(old_builder, new_builder)

    with open(path, 'w') as f:
        f.write(content)

process_file('lib/widgets/markdown_renderer.dart')
print("Patched padding.")
