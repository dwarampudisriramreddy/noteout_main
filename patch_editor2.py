import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # 1. Add Enum
    if "enum EditorMode" not in content:
        content = content.replace("class _EditorScreenState extends State<EditorScreen> {",
                                  "enum EditorMode { edit, live, preview }\n\nclass _EditorScreenState extends State<EditorScreen> {")

    # 2. Change state var
    content = content.replace("bool _isPreview = false;", "EditorMode _mode = EditorMode.live;")

    # 3. Action button - just remove the IconButton altogether since we have the segmented control
    action_btn = """            IconButton(
              icon: Icon(
                _isPreview ? Icons.edit_outlined : Icons.visibility_outlined,
                size: 18,
              ),
              onPressed: () => setState(() => _isPreview = !_isPreview),
            ),"""
    content = content.replace(action_btn, "")

    # 4. Body logic
    content = content.replace("_isPreview ? _buildPreview() : _buildEditor()",
                              "_mode == EditorMode.preview ? _buildPreview() : _buildEditor()")
    content = content.replace("if (!_isPreview) _buildToolbar()",
                              "if (_mode != EditorMode.preview) _buildToolbar()")

    # 5. Mode toggle buttons
    old_toggle = """        children: [
          _modeButton('edit', !_isPreview),
          _modeButton('preview', _isPreview),
        ],"""
    new_toggle = """        children: [
          _modeButton('edit', _mode == EditorMode.edit),
          _modeButton('live', _mode == EditorMode.live),
          _modeButton('preview', _mode == EditorMode.preview),
        ],"""
    content = content.replace(old_toggle, new_toggle)

    # 6. Mode button tap
    old_tap = """        setState(() {
          _isPreview = label == 'preview';
        });"""
    new_tap = """        setState(() {
          if (label == 'preview') _mode = EditorMode.preview;
          else if (label == 'live') _mode = EditorMode.live;
          else _mode = EditorMode.edit;
          
          _contentController.enableHighlighting = _mode == EditorMode.live;
        });"""
    content = content.replace(old_tap, new_tap)

    # 7. Jump logic
    content = content.replace("if (!_isPreview) setState(() => _isPreview = true);",
                              "if (_mode != EditorMode.preview) setState(() => _mode = EditorMode.preview);")

    with open(path, 'w') as f:
        f.write(content)

process_file('lib/screens/editor_screen.dart')
print("Patched editor modes.")
