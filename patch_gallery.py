import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Add import
    content = content.replace("import '../services/storage_service.dart';", "import '../services/storage_service.dart';\nimport '../services/github_sync_service.dart';")

    # Add delete button in Row
    old_row = """                  TextButton.icon(
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
                ],"""
                
    new_row = """                  TextButton.icon(
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
                        
                        // Confirm deletion
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (c) => AlertDialog(
                            backgroundColor: context.nPanel,
                            title: const Text('delete image?', style: TextStyle(fontFamily: 'monospace')),
                            content: const Text('this will permanently delete it from github and remove it from all your notes.', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('cancel', style: TextStyle(fontFamily: 'monospace')),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('delete', style: TextStyle(fontFamily: 'monospace', color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirm != true) return;
                        
                        // Show loading in a safe way if needed, or just let it hang for a sec
                        final success = await GitHubSyncService.deleteImage(item.url);
                        if (!success) {
                          if (nav.mounted) nav.pop();
                          messenger.showSnackBar(
                            const SnackBar(content: Text('failed to delete from github', style: TextStyle(fontFamily: 'monospace'))),
                          );
                          return;
                        }
                        
                        // Clean up notes
                        final notes = await StorageService.getAllNotes();
                        for (final note in notes) {
                          if (note.content.contains(item.url)) {
                            var newContent = note.content;
                            newContent = newContent.replaceAll(RegExp(r'!\\[[^\\]]*\\]\\(' + RegExp.escape(item.url) + r'\\)'), '');
                            newContent = newContent.replaceAll(RegExp(r'<img[^>]+src="' + RegExp.escape(item.url) + r'"[^>]*>'), '');
                            newContent = newContent.replaceAll(item.url, '');
                            await StorageService.saveNote(note.copyWith(content: newContent));
                          }
                        }
                        
                        if (nav.mounted) nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('image deleted successfully', style: TextStyle(fontFamily: 'monospace'))),
                        );
                        _load();
                      },
                      icon: const Icon(Icons.delete, size: 14, color: Colors.red),
                      label: const Text('delete',
                          style: TextStyle(
                              fontFamily: 'monospace', fontSize: 11, color: Colors.red)),
                    ),
                ],"""

    content = content.replace(old_row, new_row)
    
    with open(path, 'w') as f:
        f.write(content)

process_file('lib/screens/gallery_screen.dart')
print("Patched gallery screen.")
