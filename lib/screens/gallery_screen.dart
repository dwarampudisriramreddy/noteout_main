import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../services/github_sync_service.dart';
import '../theme/app_theme.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryItem {
  final String url;
  final bool isImage;
  final DateTime created;
  final DateTime updated;
  final List<String> tags;
  _GalleryItem(this.url, this.isImage, this.created, this.updated,
      [this.tags = const []]);
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<_GalleryItem> _items = [];
  List<String> _favs = [];
  bool _favsOnly = false;
  bool _loading = true;

  static const _imageExts = {
    '.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.avif', '.bmp', '.ico',
  };

  @override
  void initState() {
    super.initState();
    _favs = SettingsService.galleryFavs;
    _load();
  }

  Future<void> _load() async {
    final notes = await StorageService.getAllNotes();
    final byUrl = <String, _GalleryItem>{};
    for (final note in notes) {
      for (final item in _extractUrls(note.content)) {
        final existing = byUrl[item.url];
        if (existing == null ||
            (item.isImage && !existing.isImage)) {
          byUrl[item.url] = _GalleryItem(
              item.url, item.isImage, note.createdAt, note.updatedAt,
              note.tags);
        }
      }
    }
    setState(() {
      _items = byUrl.values.toList();
      _loading = false;
    });
  }

  List<_GalleryItem> _extractUrls(String content) {
    final out = <_GalleryItem>[];

    void add(String raw, bool isImage) {
      final url = _cleanUrl(raw);
      if (url.isEmpty) return;
      if (!_isHttpUrl(url)) return;
      out.add(_GalleryItem(
          url, isImage || _isImageUrl(url), DateTime.now(), DateTime.now()));
    }

    for (final m in RegExp(r'!\[[^\]]*\]\(([^)]+)\)').allMatches(content)) {
      add(m.group(1) ?? '', true);
    }
    for (final m in RegExp(r'<img[^>]+src="([^"]+)"').allMatches(content)) {
      add(m.group(1) ?? '', true);
    }
    for (final m in RegExp(r'\[[^\]]*\]\(([^)]+)\)').allMatches(content)) {
      final start = m.start;
      final isImageSyntax = start > 0 && content[start - 1] == '!';
      if (!isImageSyntax) add(m.group(1) ?? '', false);
    }
    for (final m in RegExp(r'https?://[^\s)\]]+').allMatches(content)) {
      add(m.group(0) ?? '', false);
    }
    return out;
  }

  String _cleanUrl(String raw) {
    var url = raw.trim();
    url = url.replaceAll(RegExp(r'[.,;:!?]+$'), '');
    url = url.replaceAll(RegExp(r'[*_]+$'), '');
    return url;
  }

  bool _isHttpUrl(String url) =>
      url.startsWith('http://') || url.startsWith('https://');

  bool _isImageUrl(String url) {
    final path = url.split('?').first.toLowerCase();
    return _imageExts.any((e) => path.endsWith(e));
  }

  String _displayText(String url) {
    final u = Uri.tryParse(url);
    if (u != null && u.host.isNotEmpty) {
      final path = u.path.replaceAll(RegExp(r'/$'), '');
      final tail = path.isNotEmpty ? path : '/';
      return '${u.host}$tail';
    }
    return url;
  }

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dateLabel(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = _day(local);
    if (day == today) return 'today';
    if (day == today.subtract(const Duration(days: 1))) return 'yesterday';
    return DateFormat('EEE, MMM d yyyy').format(local);
  }

  void _toggleFav(String url) {
    setState(() {
      if (_favs.contains(url)) {
        _favs = [..._favs]..remove(url);
      } else {
        _favs = [..._favs, url];
      }
      SettingsService.galleryFavs = _favs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.nSurface,
        title: Text(
          'gallery',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.nText,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _favsOnly ? Icons.star : Icons.star_border,
              size: 18,
            ),
            onPressed: () => setState(() => _favsOnly = !_favsOnly),
            color: _favsOnly ? context.nText : null,
            tooltip: 'favorites only',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
            tooltip: 'refresh',
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.nText,
                ),
              ),
            )
          : _body(),
    );
  }

  Widget _body() {
    final favs = _favs;
    final visible = _items.where(
        (item) => !_favsOnly || favs.contains(item.url)).toList();

    if (visible.isEmpty) {
      return Center(
        child: Text(
          _favsOnly ? 'no favorites yet' : 'no urls yet',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: context.nFaint,
          ),
        ),
      );
    }

    final rows = <Widget>[];

    final byTag = <String, List<_GalleryItem>>{};
    for (final item in visible) {
      final tags =
          item.tags.isEmpty ? const ['untagged'] : item.tags;
      for (final tag in tags) {
        (byTag[tag] ??= []).add(item);
      }
    }
    final tagOrder = byTag.keys.toList()..sort();
    for (var t = 0; t < tagOrder.length; t++) {
      final tag = tagOrder[t];
      final items = byTag[tag]!
        ..sort((a, b) => b.updated.compareTo(a.updated));
      rows.add(_tagHeader(tag, items.length));

      DateTime? groupDay;
      var group = <_GalleryItem>[];
      void flush() {
        if (group.isEmpty) return;
        rows.add(_dateHeader(_dateLabel(groupDay!), group.length));
        for (var i = 0; i < group.length; i += 3) {
          rows.add(_tileRow(group.sublist(
              i, i + 3 > group.length ? group.length : i + 3)));
        }
        rows.add(const SizedBox(height: 10));
        group = [];
      }

      for (final item in items) {
        final day = _day(item.created);
        if (groupDay != null && day != groupDay) flush();
        groupDay = day;
        group.add(item);
      }
      flush();
      if (t < tagOrder.length - 1) {
        rows.add(const SizedBox(height: 6));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      children: rows,
    );
  }

  Widget _tagHeader(String tag, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 4),
      child: Row(
        children: [
          Text(
            tag.startsWith('#') ? tag : '#$tag',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
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
              fontSize: 11,
              color: context.nFaint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateHeader(String label, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.nMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(height: 1, color: context.nLine)),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: context.nFaint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tileRow(List<_GalleryItem> items) {
    final children = <Widget>[];
    for (final item in items) {
      children.add(Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: _tile(item),
        ),
      ));
    }
    while (children.length < 3) {
      children.add(const Expanded(child: SizedBox()));
    }
    return SizedBox(
      height: 116,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _tile(_GalleryItem item) {
    final isFav = _favs.contains(item.url);
    return GestureDetector(
      onTap: () => _showDetails(context, item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.isImage)
              Image.network(
                item.url,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return ColoredBox(
                    color: context.nPanel2,
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.nText,
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (ctx, error, stack) => ColoredBox(
                  color: context.nPanel2,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 20,
                      color: context.nFaint,
                    ),
                  ),
                ),
              )
            else
              Container(
                color: context.nPanel2,
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.link,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _displayText(item.url),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        color: context.nMuted,
                      ),
                    ),
                  ],
                ),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: _favButton(item.url, isFav),
            ),
          ],
        ),
      ),
    );
  }

  Widget _favButton(String url, bool isFav) {
    return Material(
      color: Colors.black.withValues(alpha: 0.38),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _toggleFav(url),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            isFav ? Icons.star : Icons.star_border,
            size: 15,
            color: isFav ? Colors.amber : Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context, _GalleryItem item) async {
    final isHttp = item.url.startsWith('http');
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final fav = _favs.contains(item.url);
          return AlertDialog(
            backgroundColor: context.nPanel,
            contentPadding: const EdgeInsets.all(12),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.isImage)
                    Image.network(
                      item.url,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => Container(
                        height: 120,
                        alignment: Alignment.center,
                        child: Icon(Icons.broken_image_outlined,
                            size: 32, color: context.nFaint),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Icon(
                        Icons.link,
                        size: 36,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  const SizedBox(height: 12),
                  SelectableText(
                    item.url,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: context.nMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          _toggleFav(item.url);
                          setDialogState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _favs.contains(item.url)
                                    ? 'added to favorites'
                                    : 'removed from favorites',
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 11),
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: Icon(
                          fav ? Icons.star : Icons.star_border,
                          size: 14,
                          color: fav ? Colors.amber : context.nText,
                        ),
                        label: Text(fav ? 'favorited' : 'favorite',
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 11)),
                      ),
                      if (isHttp)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            try {
                              launchUrl(Uri.parse(item.url),
                                  mode: LaunchMode.externalApplication);
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: const Text('open',
                              style: TextStyle(
                                  fontFamily: 'monospace', fontSize: 11)),
                        ),
                      TextButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);
                          await Clipboard.setData(ClipboardData(text: item.url));
                          nav.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('url copied',
                                  style: TextStyle(
                                      fontFamily: 'monospace', fontSize: 11)),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('copy url',
                            style: TextStyle(
                                fontFamily: 'monospace', fontSize: 11)),
                      ),
                      if (item.isImage && item.url.contains('githubusercontent.com'))
                        TextButton.icon(
                          onPressed: () async {
                            final nav = Navigator.of(ctx);
                            final messenger = ScaffoldMessenger.of(context);

                            final confirm = await showDialog<bool>(
                              context: ctx,
                              builder: (c) => AlertDialog(
                                backgroundColor: context.nPanel,
                                title: const Text('delete image?',
                                    style: TextStyle(
                                        fontFamily: 'monospace')),
                                content: const Text(
                                    'this will permanently delete it from github and remove it from all your notes.',
                                    style: TextStyle(
                                        fontFamily: 'monospace', fontSize: 12)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('cancel',
                                        style: TextStyle(
                                            fontFamily: 'monospace')),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('delete',
                                        style: TextStyle(
                                            fontFamily: 'monospace',
                                            color: Colors.red)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm != true) return;

                            final success =
                                await GitHubSyncService.deleteImage(item.url);
                            if (!success) {
                              if (nav.mounted) nav.pop();
                              messenger.showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'failed to delete from github',
                                        style: TextStyle(
                                            fontFamily: 'monospace'))),
                              );
                              return;
                            }

                            final notes = await StorageService.getAllNotes();
                            for (final note in notes) {
                              if (note.content.contains(item.url)) {
                                var newContent = note.content;
                                newContent = newContent.replaceAll(
                                    RegExp(r'!\[[^\]]*\]\(' +
                                        RegExp.escape(item.url) +
                                        r'\)'),
                                    '');
                                newContent = newContent.replaceAll(
                                    RegExp(r'<img[^>]+src="' +
                                        RegExp.escape(item.url) +
                                        r'"[^>]*>'),
                                    '');
                                newContent =
                                    newContent.replaceAll(item.url, '');
                                await StorageService.saveNote(note
                                    .copyWith(content: newContent));
                              }
                            }

                            if (nav.mounted) nav.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                  content: Text('image deleted successfully',
                                      style: TextStyle(
                                          fontFamily: 'monospace'))),
                            );
                            _load();
                          },
                          icon: const Icon(Icons.delete,
                              size: 14, color: Colors.red),
                          label: const Text('delete',
                              style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Colors.red)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}