import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    old = """  List<String> _filteredEmojis() {
    if (_query.isNotEmpty) {
      final queryLower = _query.toLowerCase();
      return Emoji.byKeyword(queryLower).map((e) => e.char).toList();
    }
    return Emoji.byGroup(_categories[_selectedCategory].group).map((e) => e.char).toList();
  }"""
    
    new = """  List<String> _filteredEmojis() {
    if (_query.isNotEmpty) {
      final queryLower = _query.toLowerCase();
      return Emoji.all()
          .where((e) => e.name.toLowerCase().contains(queryLower) || e.shortName.toLowerCase().contains(queryLower))
          .map((e) => e.char)
          .toList();
    }
    return Emoji.byGroup(_categories[_selectedCategory].group).map((e) => e.char).toList();
  }"""

    content = content.replace(old, new)
    
    with open(path, 'w') as f:
        f.write(content)

process_file('lib/widgets/emoji_picker.dart')
print("Fixed search.")
