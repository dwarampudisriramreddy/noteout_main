import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryItem {
  final String url;
  _GalleryItem(this.url);
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<_GalleryItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await StorageService.getAllNotes();
    final urls = <String>{};
    for (final note in notes) {
      urls.addAll(_extractImages(note.content));
    }
    setState(() {
      _items = urls.map((u) => _GalleryItem(u)).toList();
      _loading = false;
    });
  }

  List<String> _extractImages(String content) {
    final out = <String>[];
    final md = RegExp(r'!\[[^\]]*\]\((.*?)\)');
    for (final m in md.allMatches(content)) {
      final url = m.group(1)?.trim() ?? '';
      if (_isImageUrl(url)) out.add(url);
    }
    final html = RegExp(r'<img[^>]+src="([^"]+)"');
    for (final m in html.allMatches(content)) {
      final url = m.group(1)?.trim() ?? '';
      if (_isImageUrl(url)) out.add(url);
    }
    return out;
  }

  bool _isImageUrl(String url) =>
      url.startsWith('http://') || url.startsWith('https://');

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
                    'no images yet',
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
                      onTap: () => _showImage(context, item.url),
                      child: Container(
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
                      ),
                    );
                  },
                ),
    );
  }

  void _showImage(BuildContext context, String url) {
    showDialog(
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
              Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => Container(
                  height: 120,
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_outlined,
                      size: 32, color: context.nFaint),
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                url,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: context.nMuted,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(ctx);
                  await Clipboard.setData(ClipboardData(text: url));
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
                child: const Text('copy url'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
