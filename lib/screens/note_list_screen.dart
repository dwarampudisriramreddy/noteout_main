import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/storage_service.dart';
import '../services/github_sync_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'editor_screen.dart';
import 'graph_screen.dart';
import 'settings_screen.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  List<Note> _notes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedTag = '';
  List<String> _allTags = [];
  final _searchController = TextEditingController();
  bool _isSyncing = false;
  _SortField _sortField = _SortField.modified;
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    final notes = await StorageService.getAllNotes();
    final tags = await StorageService.getAllTags();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _allTags = tags;
      _isLoading = false;
    });
  }

  List<Note> get _filteredNotes {
    return _notes.where((note) {
      final matchesTag = _selectedTag.isEmpty ||
          note.tags.contains(_selectedTag) ||
          note.tags.any((t) => t.startsWith('$_selectedTag/'));
      final matchesSearch = _searchQuery.isEmpty ||
          note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          note.content.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesTag && matchesSearch;
    }).toList()
      ..sort(_compareNotes);
  }

  int _compareNotes(Note a, Note b) {
    final dir = _sortAscending ? 1 : -1;
    final int cmp;
    switch (_sortField) {
      case _SortField.title:
        cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case _SortField.created:
        cmp = a.createdAt.compareTo(b.createdAt);
      case _SortField.size:
        cmp = a.content.length.compareTo(b.content.length);
      case _SortField.modified:
        cmp = a.updatedAt.compareTo(b.updatedAt);
    }
    return dir * cmp;
  }

  void _showSortMenu() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('sort by', style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              )),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _sortDirChip('ascending', true),
                  const SizedBox(width: 8),
                  _sortDirChip('descending', false),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final (field, label) in [
              (_SortField.title, 'alphabetical'),
              (_SortField.created, 'numbering (created)'),
              (_SortField.size, 'size'),
              (_SortField.modified, 'modified'),
            ])
              ListTile(
                dense: true,
                onTap: () {
                  setState(() => _sortField = field);
                  Navigator.pop(sheetContext);
                },
                title: Text(
                  label,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 13),
                ),
                trailing: _sortField == field
                    ? Icon(Icons.check, size: 16, color: context.nText)
                    : Icon(Icons.chevron_right, size: 16, color: context.nFaint),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sortDirChip(String label, bool ascending) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _sortAscending == ascending;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _sortAscending = ascending),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : context.nPanel,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: selected ? scheme.onPrimary : context.nMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 20),
      tooltip: isDark ? 'light mode' : 'dark mode',
      onPressed: () {
        SettingsService.themeMode =
            isDark ? ThemeMode.light : ThemeMode.dark;
      },
    );
  }

  Future<void> _syncNow() async {
    if (_isSyncing || !GitHubSyncService.isConfigured) return;
    setState(() {
      _isSyncing = true;
    });
    try {
      final result = await GitHubSyncService.syncAll();
      if (!mounted) return;
      final siteErr = result['error'] as String?;
      setState(() {
        _isSyncing = false;
      });
      if (siteErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('site: $siteErr',
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 11)),
            backgroundColor: Colors.orange.shade900,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('sync failed: $e',
              style:
                  const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          backgroundColor: Colors.red.shade900,
        ),
      );
    }
    await _loadNotes();
  }

  Future<void> _createNote() async {
    final note = Note(title: '', content: '');
    await StorageService.saveNote(note);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(noteId: note.id)),
    );
    final current = await StorageService.getNote(note.id);
    if (current != null && current.content.trim().isEmpty && current.title.isEmpty) {
      await StorageService.permanentDeleteNote(note.id);
    }
    await _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'noteout',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 20,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.5,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              SettingsService.userName.isEmpty ? 'get your thoughts out' : 'get your thoughts out, ${SettingsService.userName}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
                letterSpacing: 0.5,
                height: 1.0,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: _isSyncing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: context.nText),
                  )
                : const Icon(Icons.sync, size: 20),
            onPressed: _isSyncing ? null : _syncNow,
            tooltip: 'sync',
          ),
          _buildThemeToggle(),

          IconButton(
            icon: const Icon(Icons.sort, size: 20),
            onPressed: _showSortMenu,
            tooltip: 'sort',
          ),
          IconButton(
            icon: const Icon(Icons.account_tree_outlined, size: 20),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GraphScreen()),
              );
              await _loadNotes();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_allTags.isNotEmpty) _buildTagBar(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: context.nText,
                    ),
                  )
                : _filteredNotes.isEmpty
                    ? _buildEmptyState()
                    : _buildIndex(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNote,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 1,
        child: const Icon(Icons.add, size: 20),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: InputDecoration(
          hintText: 'search...',
          hintStyle: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: context.nFaint,
          ),
          prefixIcon: Icon(Icons.search, size: 16, color: context.nFaint),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: context.nPanel2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  List<String> _directChildren(String tag) {
    final prefix = '$tag/';
    final segs = <String>{};
    for (final t in _allTags) {
      if (t.startsWith(prefix)) {
        final seg = t.substring(prefix.length).split('/').first;
        segs.add('$tag/$seg');
      }
    }
    return segs.toList()..sort();
  }

  Widget _buildTagBar() {
    final subTags =
        _selectedTag.isEmpty ? const <String>[] : _directChildren(_selectedTag);
    return Column(
      children: [
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _tagChip('all', _selectedTag.isEmpty),
              ..._allTags.map((t) => _tagChip(t, _selectedTag == t)),
            ],
          ),
        ),
        if (subTags.isNotEmpty)
          Container(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerLow
                .withValues(alpha: 0.5),
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Center(
                    child: Icon(Icons.subdirectory_arrow_right,
                        size: 14, color: context.nFaint),
                  ),
                ),
                ...subTags.map((t) => _tagChip(t, _selectedTag == t)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tagChip(String tag, bool selected) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedTag = tag == 'all' ? '' : tag;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : context.nPanel,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            tag == 'all' ? 'all' : '#$tag',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: selected ? scheme.onPrimary : context.nMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _loadNotes,
      color: Theme.of(context).colorScheme.primary,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              height: constraints.maxHeight,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_add_outlined, size: 48, color: context.nSubtle),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isNotEmpty || _selectedTag.isNotEmpty
                        ? 'no matching notes'
                        : 'no notes yet',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: context.nFaint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_searchQuery.isEmpty && _selectedTag.isEmpty)
                    Text(
                      'tap + to create one',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: context.nSubtle,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndex() {
    final filtered = _filteredNotes;
    final children = <Widget>[];

    if (_selectedTag.isNotEmpty) {
      for (final note in filtered) {
        children.add(_buildNoteTile(note));
      }
    } else {
      final grouped = _groupByTag(filtered);
      grouped.forEach((tag, notes) {
        if (notes.isEmpty) return;
        children.add(_groupHeader(tag, notes.length));
        for (final note in notes) {
          children.add(_buildNoteTile(note));
        }
      });
    }

    return RefreshIndicator(
      onRefresh: _loadNotes,
      color: Theme.of(context).colorScheme.primary,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: children,
      ),
    );
  }

  Map<String, List<Note>> _groupByTag(List<Note> notes) {
    const untagged = '(untagged)';
    final map = <String, List<Note>>{};
    for (final note in notes) {
      final key = note.tags.isNotEmpty ? note.tags.first : untagged;
      map.putIfAbsent(key, () => []).add(note);
    }
    final sortedKeys = map.keys.toList()
      ..sort((a, b) {
        if (a == untagged) return 1;
        if (b == untagged) return -1;
        return a.compareTo(b);
      });
    return {for (final k in sortedKeys) k: map[k]!};
  }

  Widget _groupHeader(String tag, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Row(
        children: [
          Text(
            tag == '(untagged)' ? tag : '#$tag',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.nText,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(height: 1, color: context.nLine)),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: context.nFaint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteTile(Note note) {
    final title = note.title.isEmpty ? 'untitled' : note.title;
    final timeAgo = _formatTimeAgo(note.updatedAt);
    final tags = note.tags;
    final links = note.outgoingLinks;

    return Dismissible(
      key: Key(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Theme.of(context).colorScheme.primary,
        child: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.onPrimary, size: 18),
      ),
      confirmDismiss: (_) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete note',
                style: TextStyle(fontFamily: 'monospace')),
            content: const Text('Move to trash?',
                style: TextStyle(fontFamily: 'monospace')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await StorageService.deleteNote(note.id);
          await _loadNotes();
        }
        return false;
      },
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.nText,
            decoration: TextDecoration.underline,
            decorationColor: context.nSubtle,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              if (tags.isNotEmpty) ...[
                Text(
                  tags.take(3).map((t) => '#$t').join('  '),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: context.nMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 8),
              ],
              if (links.isNotEmpty) ...[
                Icon(Icons.link, size: 10, color: context.nFaint),
                Text(
                  '${links.length}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: context.nFaint,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              Text(
                timeAgo,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: context.nFaint,
                ),
              ),
            ],
          ),
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditorScreen(noteId: note.id),
            ),
          );
          await _loadNotes();
        },
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}

enum _SortField { title, created, size, modified }
