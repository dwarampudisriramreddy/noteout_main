import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:share_plus/share_plus.dart';
import '../models/note.dart';
import '../services/note_export_service.dart';
import '../services/storage_service.dart';
import '../services/github_sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/markdown_renderer.dart';

class EditorScreen extends StatefulWidget {
  final String noteId;

  const EditorScreen({super.key, required this.noteId});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  Note? _note;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _titleFocus = FocusNode();
  final _contentFocus = FocusNode();
  final _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isPreview = false;
  final _headingKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNote() async {
    final note = await StorageService.getNote(widget.noteId);
    if (note == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() {
      _note = note;
      _titleController.text = note.title;
      _contentController.text = note.content;
      _isLoading = false;
    });
  }

  void _insertMarkdown(String prefix, String suffix) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);

    final selectedText = text.substring(start, end);
    final newText =
        '${text.substring(0, start)}$prefix$selectedText$suffix${text.substring(end)}';

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.fromPosition(
        TextPosition(offset: start + prefix.length + selectedText.length),
      ),
    );
    _contentFocus.requestFocus();
    setState(() {});
  }

  void _insertAtCursor(String text) {
    final current = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start.clamp(0, current.length);

    final newText =
        '${current.substring(0, start)}$text${current.substring(start)}';
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.fromPosition(
        TextPosition(offset: start + text.length),
      ),
    );
    _contentFocus.requestFocus();
    setState(() {});
  }

  String _stripAllTagLines(String text) {
    return text
        .replaceAllMapped(
          RegExp(r'^\s*#[a-zA-Z0-9_]+(?:/[a-zA-Z0-9_]+)*\s*$',
              multiLine: true),
          (_) => '',
        )
        .trim();
  }

  Future<void> _saveNote() async {
    if (_note == null) return;
    // Tags live in note metadata, so keep them out of the body text.
    var content = _stripAllTagLines(_contentController.text);
    final title = _titleController.text.trim();
    final isJournal = title.toLowerCase().startsWith('journal:');
    final requiredTag = isJournal ? 'journal' : 'note';
    final tags = [..._note!.tags];
    if (!tags.contains(requiredTag)) tags.add(requiredTag);
    final updated = _note!.copyWith(
      title: title,
      content: content,
      tags: tags,
      updatedAt: DateTime.now().toUtc(),
    );
    await StorageService.saveNote(updated);
    _note = updated;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      );
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await _saveNote();
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () async {
              final nav = Navigator.of(context);
              await _saveNote();
              if (mounted) nav.pop();
            },
          ),
          title: _buildModeToggle(),
          actions: [
            IconButton(
              icon: const Icon(Icons.image, size: 18),
              onPressed: _showImageSourceSheet,
              tooltip: 'insert image',
            ),
            IconButton(
              icon: const Icon(Icons.toc, size: 18),
              onPressed: _showToc,
              tooltip: 'table of contents',
            ),
            IconButton(
              icon: Icon(
                _isPreview ? Icons.edit_outlined : Icons.visibility_outlined,
                size: 18,
              ),
              onPressed: () => setState(() => _isPreview = !_isPreview),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, size: 18),
              onSelected: (value) async {
                switch (value) {
                  case 'export':
                    await _exportNote();
                    break;
                  case 'links':
                    _showBacklinksDialog();
                    break;
                  case 'delete':
                    await _deleteNote();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export',
                  child: Text('export',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ),
                const PopupMenuItem(
                  value: 'links',
                  child: Text('backlinks',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('delete',
                      style: TextStyle(
                          fontFamily: 'monospace', fontSize: 12, color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _isPreview ? _buildPreview() : _buildEditor(),
            ),
            if (!_isPreview) _buildToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: context.nPanel2,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeButton('edit', !_isPreview),
          _modeButton('preview', _isPreview),
        ],
      ),
    );
  }

  Widget _modeButton(String label, bool selected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isPreview = label == 'preview';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : context.nMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    final tags = _note?.tags ?? const [];
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            focusNode: _titleFocus,
            enableInteractiveSelection: true,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: context.nText,
              height: 1.3,
            ),
            decoration: InputDecoration(
                hintText: 'title',
                hintStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: context.nFaint,
                ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _contentFocus.requestFocus(),
          ),
          const SizedBox(height: 4),
          Divider(height: 1, color: context.nLine),
          const SizedBox(height: 8),
          _buildTagsRow(tags),
          const SizedBox(height: 8),
          Divider(height: 1, color: context.nLine),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 300),
            child: TextField(
              controller: _contentController,
              focusNode: _contentFocus,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              enableInteractiveSelection: true,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: context.nText,
                height: 1.7,
              ),
              decoration: InputDecoration(
                hintText:
                    'start writing...\n\nuse [[link]] for wiki links\n#tag for tags\n\$x^2\$ for LaTeX',
                hintStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: context.nFaint,
                  height: 1.7,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTagsRow(List<String> tags) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final tag in tags)
          _tagChip(tag),
        GestureDetector(
          onTap: _showAddTagDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: context.nPanel2,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: context.nLine),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 12, color: context.nMuted),
                const SizedBox(width: 2),
                Text(
                  'tag',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: context.nMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tagChip(String tag) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$tag',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: scheme.onPrimary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _removeTag(tag),
            child: Icon(Icons.close, size: 12, color: scheme.onPrimary),
          ),
        ],
      ),
    );
  }

  void _removeTag(String tag) {
    setState(() {
      _note = _note!.copyWith(
        tags: _note!.tags.where((t) => t != tag).toList(),
      );
    });
  }

  Future<void> _showAddTagDialog() async {
    final allTags = await StorageService.getAllTags();
    final currentTags = _note!.tags;
    final availableTags = allTags.where((t) => !currentTags.contains(t)).toList();
    
    final controller = TextEditingController();
    
    if (!mounted) return;
    final tag = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('add tag',
            style: TextStyle(fontFamily: 'monospace', fontSize: 14)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'tag name',
                    hintStyle: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: context.nFaint,
                    ),
                    filled: true,
                    fillColor: context.nPanel2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
                ),
                if (availableTags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('existing tags:', 
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: context.nFaint)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableTags.map((t) {
                      return GestureDetector(
                        onTap: () => Navigator.pop(ctx, t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: context.nPanel2,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#$t',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: context.nMuted,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (tag != null && tag.isNotEmpty) _addTag(tag);
  }

  void _addTag(String rawTag) {
    var tag = rawTag
        .trim()
        .replaceAll(RegExp(r'\s+'), '/')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_/]'), '');
    while (tag.startsWith('/')) {
      tag = tag.substring(1);
    }
    while (tag.endsWith('/')) {
      tag = tag.substring(0, tag.length - 1);
    }
    tag = tag.replaceAll(RegExp(r'/+'), '/');
    if (tag.isEmpty) return;
    final current = _note?.tags ?? const [];
    if (current.contains(tag)) return;
    setState(() {
      _note = _note!.copyWith(tags: [...current, tag]);
    });
  }

  Widget _buildPreview() {
    final title = _titleController.text.trim();
    final content = _contentController.text;
    _headingKeys.clear();

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: context.nText,
                  height: 1.3,
                ),
              ),
            ),
          if (title.isNotEmpty)
            Divider(height: 1, color: context.nLine),
          const SizedBox(height: 12),
          MarkdownRenderer(content: content, headingKeys: _headingKeys),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: context.nSurface,
        border: Border(top: BorderSide(color: context.nLine, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _toolButton(Icons.content_copy, () => _copySelection(), 'copy'),
              _toolButton(
                  Icons.content_paste, () => _pasteFromClipboard(), 'paste'),
              const SizedBox(width: 4),
              Container(width: 1, height: 16, color: context.nLine),
              const SizedBox(width: 4),
              _toolButton(Icons.format_bold, () => _insertMarkdown('**', '**')),
              _toolButton(Icons.format_italic, () => _insertMarkdown('*', '*')),
              _toolButton(Icons.code, () => _insertMarkdown('`', '`')),
              _toolButton(Icons.title, () => _insertAtCursor('## ')),
              _toolButton(
                  Icons.format_list_bulleted, () => _insertAtCursor('- ')),
              _toolButton(Icons.format_quote, () => _insertAtCursor('> ')),
              _toolButton(Icons.functions, () => _insertMarkdown(r'$$', r'$$')),
              _toolButton(Icons.link, () => _insertMarkdown('[[', ']]')),
              _toolButton(Icons.tag, () => _insertAtCursor('#')),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copySelection() async {
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final selected = text.substring(
          selection.start.clamp(0, text.length),
          selection.end.clamp(0, text.length));
      await Clipboard.setData(ClipboardData(text: selected));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('copied',
                style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _insertAtCursor(data!.text!);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.nPanel,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: context.nText, size: 20),
              title: Text('camera',
                  style: TextStyle(
                      fontFamily: 'monospace', fontSize: 13, color: context.nText)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo, color: context.nText, size: 20),
              title: Text('gallery',
                  style: TextStyle(
                      fontFamily: 'monospace', fontSize: 13, color: context.nText)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.folder, color: context.nText, size: 20),
              title: Text('document',
                  style: TextStyle(
                      fontFamily: 'monospace', fontSize: 13, color: context.nText)),
              onTap: () {
                Navigator.pop(ctx);
                _pickDocument();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await _uploadAndInsert(bytes, file.name);
    } catch (e) {
      _showImageError('pick failed: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      final bytes = f.bytes ??
          (f.path != null ? await File(f.path!).readAsBytes() : null);
      if (bytes == null) {
        _showImageError('could not read file');
        return;
      }
      await _uploadAndInsert(bytes, f.name);
    } catch (e) {
      _showImageError('pick failed: $e');
    }
  }

  String _guessMime(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  // Compresses photos (downscale + re-encode) to keep size small while
  // staying visually near-lossless. Non-photo formats pass through.
  Future<Uint8List> _compress(Uint8List bytes, String mime) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1600,
        minHeight: 1600,
        quality: 85,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true,
      );
      if (result.isNotEmpty) return result;
    } catch (_) {}
    return bytes;
  }

  Future<void> _uploadAndInsert(Uint8List rawBytes, String fileName) async {
    if (!GitHubSyncService.isConfigured) {
      _showImageError('connect github to insert images');
      return;
    }
    _showUploadingDialog();
    try {
      final mime = _guessMime(fileName);
      final compressed = await _compress(rawBytes, mime);
      final url = await GitHubSyncService.uploadImage(compressed, fileName, mime);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _insertAtCursor('![]($url)');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('image inserted',
                style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _showImageError('upload failed: $e');
    }
  }

  void _showUploadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: context.nPanel,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.nText,
              ),
            ),
            const SizedBox(width: 16),
            Text('uploading image…',
                style: TextStyle(
                    fontFamily: 'monospace', fontSize: 12, color: context.nText)),
          ],
        ),
      ),
    );
  }

  void _showImageError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _toolButton(IconData icon, VoidCallback onPressed, [String? tooltip]) {
    return Tooltip(
      message: tooltip ?? '',
      child: SizedBox(
        width: 36,
        height: 36,
        child: IconButton(
          icon: Icon(icon, size: 16, color: context.nMuted),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  void _showBacklinksDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return FutureBuilder<List<Note>>(
            future: _getBacklinks(),
            builder: (context, snapshot) {
              final backlinks = snapshot.data ?? [];
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.nLine,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('backlinks',
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: backlinks.isEmpty
                            ? Center(
                                child: Text('no backlinks found',
                                    style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        color: context.nFaint)),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: backlinks.length,
                            separatorBuilder: (context, index) => Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                                color: context.nLine),
                            itemBuilder: (context, index) {
                              final backlink = backlinks[index];
                              return ListTile(
                                title: Text(
                                  backlink.title.isEmpty ? 'untitled' : backlink.title,
                                  style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  backlink.excerpt,
                                  style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: context.nMuted),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => EditorScreen(noteId: backlink.id)),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Note>> _getBacklinks() async {
    final allNotes = await StorageService.getAllNotes();
    final title = _titleController.text.trim();
    if (title.isEmpty) return [];
    return allNotes.where((note) {
      if (note.id == widget.noteId) return false;
      return note.outgoingLinks
          .any((link) => link.toLowerCase() == title.toLowerCase());
    }).toList();
  }

  List<({int level, String text})> _extractHeadings(String content) {
    final result = <({int level, String text})>[];
    for (final line in content.split('\n')) {
      final m = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(line);
      if (m != null) {
        result.add((level: m.group(1)!.length, text: m.group(2)!.trimRight()));
      }
    }
    return result;
  }

  void _showToc() {
    final title = _titleController.text.trim();
    final headings = _extractHeadings(_contentController.text);
    if (title.isEmpty && headings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('no headings yet',
              style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'table of contents',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (title.isNotEmpty)
                    ListTile(
                      dense: true,
                      title: buildTocTile('title', 0, Icons.title),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _jumpToTitle();
                      },
                    ),
                  for (final h in headings)
                    ListTile(
                      dense: true,
                      title: buildTocTile(h.text, h.level, Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _jumpToHeading(h.text);
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget buildTocTile(String text, int level, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(left: 8.0 + (level - 1) * 16),
      child: Row(
        children: [
          Icon(icon, size: 12, color: context.nFaint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: level <= 2 ? FontWeight.w600 : FontWeight.w400,
                color: context.nText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _jumpToTitle() {
    if (!_isPreview) setState(() => _isPreview = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _jumpToHeading(String text) {
    if (!_isPreview) setState(() => _isPreview = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _headingKeys[text]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.05,
        );
      }
    });
  }

  Future<void> _exportNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text;

    final format = await     showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'export as',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final f in ['markdown', 'html', 'docx', 'pdf'])
              ListTile(
                dense: true,
                onTap: () => Navigator.pop(context, f),
                title: Text(
                  f,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 13),
                ),
                trailing:
                    Icon(Icons.chevron_right, size: 16, color: context.nFaint),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (format == null) return;

    final file = NoteExportService.build(
      title: title.isEmpty ? 'untitled' : title,
      content: content,
      format: format,
    );
    await Share.shareXFiles([
      XFile.fromData(file.bytes, name: file.fileName, mimeType: file.mimeType),
    ]);
  }

  Future<void> _deleteNote() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note'),
        content: const Text('Move to trash?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await StorageService.deleteNote(widget.noteId);
      if (mounted) Navigator.pop(context);
    }
  }
}
