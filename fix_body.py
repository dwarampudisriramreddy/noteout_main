import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    body_column = """        body: Column(
          children: [
            Expanded(
              child: _isPreview ? _buildPreview() : _buildEditor(),
            ),
            if (_linkQuery != null) _buildLinkSuggestions(),
            if (!_isPreview) _buildToolbar(),
          ],
        ),"""
    content = re.sub(
        r"        body: Column\(\n          children: \[\n            Expanded\(\n              child: _isPreview \? _buildPreview\(\) : _buildEditor\(\),\n            \),\n            if \(!_isPreview\) _buildToolbar\(\),\n          \],\n        \),",
        body_column,
        content
    )

    with open(path, 'w') as f:
        f.write(content)

process_file('lib/screens/editor_screen.dart')
print("Fixed body.")
