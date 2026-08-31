import 'package:flutter/material.dart';
import '../services/github_auth_service.dart';
import '../services/github_sync_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class SiteSettingsScreen extends StatefulWidget {
  const SiteSettingsScreen({super.key});

  @override
  State<SiteSettingsScreen> createState() => _SiteSettingsScreenState();
}

class _SiteSettingsScreenState extends State<SiteSettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _aboutController;
  bool _isPublishing = false;

  static const _layouts = [
    ('personal', 'personal website', 'hero + stats + emoji calendar + category tiles'),
    ('docs', 'documentation', 'stats + search + notes grouped by category'),
  ];

  static const _accents = [
    ('indigo', Color(0xFF4F46E5)),
    ('violet', Color(0xFF7C3AED)),
    ('emerald', Color(0xFF059669)),
    ('rose', Color(0xFFE11D48)),
    ('sky', Color(0xFF0284C7)),
    ('amber', Color(0xFFD97706)),
  ];

  static const _themes = [
    ('modern', 'modern', 'bold cards, vivid gradient hero'),
    ('minimalist', 'minimalist', 'clean and airy, hairline edges, no shadows'),
    ('paper', 'paper', 'warm cream + serif headings, like a blog'),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: SettingsService.userName);
    _aboutController =
        TextEditingController(text: SettingsService.siteAbout);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  void _saveIdentity() {
    SettingsService.userName = _nameController.text.trim();
    SettingsService.siteAbout = _aboutController.text.trim();
  }

  Future<void> _publish() async {
    _saveIdentity();
    if (!GitHubAuthService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('connect github first to publish your site',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _isPublishing = true);
    try {
      final result = await GitHubSyncService.pushAll();
      final count = result['count'] as int;
      final siteErr = result['error'] as String?;
      final msg = siteErr != null
          ? 'site settings saved — site: $siteErr'
          : 'published — $count note${count == 1 ? '' : 's'} synced';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12)),
            backgroundColor: siteErr != null ? Colors.orange : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = SettingsService.siteLayout;
    final accent = SettingsService.siteAccent;
    final theme = SettingsService.siteTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () {
            _saveIdentity();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'site settings',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const SizedBox(height: 8),
          _section('identity'),
          _panel(
            children: [
              _label('name shown on the site'),
              TextField(
                controller: _nameController,
                onChanged: (_) => _saveIdentity(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: _input(
                  hint: 'your name',
                ),
              ),
              const SizedBox(height: 14),
              _label('about'),
              TextField(
                controller: _aboutController,
                onChanged: (_) => _saveIdentity(),
                maxLines: 2,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: _input(hint: 'one line about you'),
              ),
            ],
          ),
          _section('layout'),
          _panel(
            children: [
              for (final (key, label, desc) in _layouts)
                _choiceRow(
                  selected: layout == key,
                  title: label,
                  subtitle: desc,
                  onTap: () {
                    SettingsService.siteLayout = key;
                    setState(() {});
                  },
                ),
            ],
          ),
          _section('accent color'),
          _panel(
            children: [
              _label('pick a color for the site'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 12,
                  children: [
                    for (final (key, color) in _accents)
                      GestureDetector(
                        onTap: () {
                          SettingsService.siteAccent = key;
                          setState(() {});
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent == key
                                  ? Theme.of(context).colorScheme.primary
                                  : context.nLine,
                              width: accent == key ? 3 : 1,
                            ),
                          ),
                          child: accent == key
                              ? const Icon(Icons.check,
                                  size: 18, color: Colors.white)
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          _section('theme'),
          _panel(
            children: [
              for (final (key, label, desc) in _themes)
                _choiceRow(
                  selected: theme == key,
                  title: label,
                  subtitle: desc,
                  onTap: () {
                    SettingsService.siteTheme = key;
                    setState(() {});
                  },
                ),
            ],
          ),
          _section('home page'),

          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            value: SettingsService.siteShowCalendar,
            onChanged: (v) {
              SettingsService.siteShowCalendar = v;
              setState(() {});
            },
            title: _listTitle('show journal heatmap'),
            subtitle: _listSubtitle('embed activity heatmap on home page'),
          ),
          const Divider(height: 1, color: Colors.transparent),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            value: SettingsService.siteShowProfile,
            onChanged: (v) {
              SettingsService.siteShowProfile = v;
              setState(() {});
            },
            title: _listTitle('show profile photo'),
            subtitle: _listSubtitle('hero header with your avatar + name'),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isPublishing ? null : _publish,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: _isPublishing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : const Text(
                      'publish site',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'changes are stored on your device and pushed to config.json '
              'in your github repo on publish.',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.6,
                color: context.nFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.nFaint,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _panel({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.nPanel2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _label(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: context.nMuted,
          ),
        ),
      ),
    );
  }

  InputDecoration _input({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: context.nFaint,
      ),
      filled: true,
      fillColor: context.nPanel2,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: context.nLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: context.nLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide:
            BorderSide(color: context.nText, width: 1.5),
      ),
    );
  }

  Widget _choiceRow({
    required bool selected,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected
            ? Icons.radio_button_checked
            : Icons.radio_button_off,
        size: 18,
        color: selected ? Theme.of(context).colorScheme.primary : context.nFaint,
      ),
      title: _listTitle(title),
      subtitle: _listSubtitle(subtitle),
      onTap: onTap,
    );
  }

  Widget _listTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: context.nText,
      ),
    );
  }

  Widget _listSubtitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        color: context.nMuted,
      ),
    );
  }
}