import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryItem {
  final String url;
  final bool isImage;
  _GalleryItem(this.url, this.isImage);
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<_GalleryItem> _items = [];
  bool _loading = true;

  static const _imageExts = {
    '.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.avif', '.bmp', '.ico',
  };

  @override
  void initState() {
    super.initState();
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
          byUrl[item.url] = item;
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
      out.add(_GalleryItem(url, isImage || _isImageUrl(url)));
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
          : _items.isEmpty
              ? Center(
                  child: Text(
                    'no urls yet',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: context.nFaint,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return GestureDetector(
                      onTap: () => _showDetails(context, item),
                      child: item.isImage
                          ? Container(
                              decoration: BoxDecoration(
                                color: context.nPanel2,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                item.url,
                                fit: BoxFit.cover,
                                loadingBuilder: (ctx, child, progress) {
                                  if (progress == null) return child;
                                  return Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: context.nText,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (ctx, error, stack) => Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 20,
                                    color: context.nFaint,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: context.nPanel2,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.link,
                                    size: 18,
                                    color:
                                        Theme.of(context).colorScheme.primary,
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
                    );
                  },
                ),
    );
  }

  Future<void> _showDetails(BuildContext context, _GalleryItem item) async {
    final isHttp = item.url.startsWith('http');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}