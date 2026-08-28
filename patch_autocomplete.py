import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Add state variables
    state_vars = """class _EditorScreenState extends State<EditorScreen> {
  Note? _note;
  List<Note> _allNotes = [];
  String? _linkQuery;"""
    content = content.replace("class _EditorScreenState extends State<EditorScreen> {\n  Note? _note;", state_vars)

    # Add _loadAllNotes in initState
    init_state = """  void initState() {
    super.initState();
    _loadNote();
    _loadAllNotes();
  }

  Future<void> _loadAllNotes() async {
    _allNotes = await StorageService.getAllNotes();
    if (mounted) setState(() {});
  }"""
    content = re.sub(
        r"  void initState\(\) \{\n    super\.initState\(\);\n    _loadNote\(\);\n  \}",
        init_state,
        content
    )

    # Add _checkLinkAutocomplete
    autocomplete_func = """  void _checkLinkAutocomplete(String text) {
    final selection = _contentController.selection;
    if (!selection.isValid || selection.baseOffset != selection.extentOffset) {
      _linkQuery = null;
      return;
    }
    
    final cursor = selection.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      _linkQuery = null;
      return;
    }
    
    final textBefore = text.substring(0, cursor);
    final lastOpen = textBefore.lastIndexOf('[[');
    final lastClose = textBefore.lastIndexOf(']]');
    
    if (lastOpen != -1 && lastOpen > lastClose) {
      _linkQuery = textBefore.substring(lastOpen + 2);
    } else {
      _linkQuery = null;
    }
  }

  Widget _buildLinkSuggestions() {
    if (_linkQuery == null) return const SizedBox.shrink();
    
    final query = _linkQuery!.toLowerCase();
    final matches = _allNotes
        .where((n) => n.id != _note?.id)
        .where((n) => n.title.toLowerCase().contains(query))
        .take(5)
        .toList();
        
    if (matches.isEmpty) return const SizedBox.shrink();
    
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ]
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final note = matches[index];
          return ListTile(
            dense: true,
            leading: Icon(Icons.article_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
            title: Text(note.title, style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color)),
            onTap: () {
              final text = _contentController.text;
              final selection = _contentController.selection;
              final cursor = selection.baseOffset;
              final textBefore = text.substring(0, cursor);
              final lastOpen = textBefore.lastIndexOf('[[');
              
              final newText = text.substring(0, lastOpen + 2) + note.title + ']]' + text.substring(cursor);
              
              _contentController.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(offset: lastOpen + 2 + note.title.length + 2),
              );
              
              setState(() {
                _linkQuery = null;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildEditor() {"""
    
    content = content.replace("  Widget _buildEditor() {", autocomplete_func)

    # Inject into body Column
    body_column = """        body: Column(
          children: [
            Expanded(
              child: _isPreview ? _buildPreview() : _buildEditor(),
            ),
            if (_linkQuery != null) _buildLinkSuggestions(),
            _buildTagsBar(),
          ],
        ),"""
    content = re.sub(
        r"        body: Column\(\n          children: \[\n            Expanded\(\n              child: _isPreview \? _buildPreview\(\) : _buildEditor\(\),\n            \),\n            _buildTagsBar\(\),\n          \],\n        \),",
        body_column,
        content
    )

    # Call _checkLinkAutocomplete in onChanged
    content = content.replace(
        "              onChanged: (_) => setState(() {}),\n            ),",
        """              onChanged: (text) {
                _checkLinkAutocomplete(text);
                setState(() {});
              },
            ),"""
    )

    with open(path, 'w') as f:
        f.write(content)

process_file('lib/screens/editor_screen.dart')
print("Patched.")
