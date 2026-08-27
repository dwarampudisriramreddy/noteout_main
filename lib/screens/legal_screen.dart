import 'package:flutter/material.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String body;

  const LegalScreen({
    super.key,
    required this.title,
    this.body =
        'This is a minimal note-taking app. Your notes are stored locally on '
        'your device and, when connected, synced to your own private GitHub '
        'repository. We do not collect or transmit your notes to any third '
        'party. Your GitHub token is stored only on this device.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          body,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.8,
          ),
        ),
      ),
    );
  }
}