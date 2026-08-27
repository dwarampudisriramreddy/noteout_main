import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/github_auth_service.dart';
import '../services/github_sync_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSyncing = false;
  bool _isLoggedIn = false;
  String? _lastSyncResult;
  bool _isLoggingIn = false;
  TokenStatus _tokenStatus = TokenStatus.empty;
  final _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isLoggedIn = GitHubAuthService.isLoggedIn;
    _tokenStatus = GitHubAuthService.tokenStatus;
    GitHubAuthService.isLoggedInNotifier.addListener(_onAuthChanged);
    GitHubAuthService.tokenStatusNotifier.addListener(_onTokenStatusChanged);
  }

  @override
  void dispose() {
    GitHubAuthService.isLoggedInNotifier.removeListener(_onAuthChanged);
    GitHubAuthService.tokenStatusNotifier.removeListener(_onTokenStatusChanged);
    _tokenController.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() => _isLoggedIn = GitHubAuthService.isLoggedIn);
  }

  void _onTokenStatusChanged() {
    if (mounted) {
      setState(() => _tokenStatus = GitHubAuthService.tokenStatus);
    }
  }

  Future<void> _login() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('paste your personal access token',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isLoggingIn = true);
    final ok = await GitHubAuthService.signIn(token);
    if (mounted) {
      setState(() => _isLoggingIn = false);
      _tokenController.clear();
      final status = GitHubAuthService.tokenStatus;
      String msg;
      Color bg;
      if (ok) {
        msg = 'connected as ${GitHubAuthService.username} — syncing...';
        bg = Colors.black;
      } else if (status == TokenStatus.expired) {
        msg = 'token expired — generate a new one with "no expiration"';
        bg = Colors.red;
      } else {
        msg = 'invalid token';
        bg = Colors.red;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(msg, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          backgroundColor: ok ? null : bg,
        ),
      );
      if (ok) {
        SiteStatusMonitor.instance.start();
        _syncNow();
      }
    }
  }

  void _logout() {
    GitHubAuthService.logout();
    SiteStatusMonitor.instance.stop();
    setState(() {
      _isLoggedIn = false;
      _lastSyncResult = null;
    });
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    try {
      final result = await GitHubSyncService.syncAll();
      final count = result['count'] as int;
      final siteErr = result['error'] as String?;
      if (mounted) {
        final msg = siteErr != null
            ? '$count synced, site: $siteErr'
            : '$count note${count == 1 ? '' : 's'} synced';
        setState(() {
          _isSyncing = false;
          _lastSyncResult = msg;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            backgroundColor: siteErr != null ? Colors.orange : null,
          ),
        );
        SiteStatusMonitor.instance.refresh();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _lastSyncResult = 'Sync failed';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e',
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    }
  }

  Future<void> _exportAll() async {
    final notes = await StorageService.getAllNotes();
    final buffer = StringBuffer();
    for (final note in notes) {
      buffer.writeln('---');
      buffer.writeln('title: ${note.title}');
      buffer.writeln('created: ${note.createdAt.toIso8601String()}');
      buffer.writeln('tags: [${note.tags.join(', ')}]');
      buffer.writeln('---');
      buffer.writeln();
      buffer.writeln(note.content);
      buffer.writeln();
      buffer.writeln();
    }
    await Share.shareXFiles(
      [XFile.fromData(
        Uint8List.fromList(buffer.toString().codeUnits),
        mimeType: 'text/markdown',
        name: 'noteout-export.md',
      )],
    );
  }

  Future<void> _openTokenPage() async {
    final url = Uri.parse(
        'https://github.com/settings/tokens/new?scopes=repo,workflow&description=noteout%20(classic%20PAT)');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openLiveSite() async {
    final username = GitHubAuthService.username;
    final repo = SettingsService.githubRepo;
    final url = Uri.parse('https://$username.github.io/$repo/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'settings',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSection(
            'github',
            [
              if (!_isLoggedIn)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.nPanel2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'connect with github',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.nText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _openTokenPage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: context.nPanel2,
                              border: Border.all(color: context.nLine),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.open_in_new,
                                    size: 14, color: context.nMuted),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'generate a CLASSIC personal access token',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: context.nMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'select ALL scopes (at least repo + workflow), "no expiration"',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _tokenController,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12),
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'paste token here',
                            hintStyle: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: context.nFaint,
                            ),
                            filled: true,
                            fillColor: context.nPanel2,
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
                              borderSide: BorderSide(
                                  color: context.nText, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoggingIn ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoggingIn
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  )
                                : const Text(
                                    'connect',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                        ),
                        if (_tokenStatus == TokenStatus.expired) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    size: 14, color: Colors.red[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'token expired — generate a new one with "no expiration"',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else ...[
                _buildStatusTile(),
                _buildSiteStatusTile(),
                _buildActionTile(
                  'view site',
                  _siteStatusSubtitle(),
                  _openLiveSite,
                  false,
                ),
                _buildActionTile(
                  'sync now',
                  _lastSyncResult ?? 'push/pull all notes',
                  _isSyncing ? null : _syncNow,
                  _isSyncing,
                ),
                _buildActionTile(
                  'logout',
                  'disconnect github account',
                  _isSyncing ? null : _logout,
                  false,
                  destructive: true,
                ),
              ],
            ],
          ),
          _buildSection(
            'export',
            [
              _buildActionTile(
                'export all notes',
                'share as markdown file',
                _exportAll,
                false,
              ),
            ],
          ),
          _buildSection(
            'theme',
            [
              ValueListenableBuilder<ThemeMode>(
                valueListenable: SettingsService.themeNotifier,
                builder: (context, mode, _) => Column(
                  children: [
                    for (final (m, label) in [
                      (ThemeMode.light, 'light'),
                      (ThemeMode.dark, 'dark'),
                      (ThemeMode.system, 'system'),
                    ])
                      _themeTile(m, label, mode),
                  ],
                ),
              ),
            ],
          ),
          _buildSection(
            'about',
            [
              _buildInfoTile('version', '1.0.0'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        ),
        ...children,
        Divider(height: 1, color: context.nLine),
      ],
    );
  }

  Widget _buildStatusTile([String? title, String? subtitle]) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isLoggedIn ? Colors.green : context.nFaint,
        ),
      ),
      title: Text(
        title ?? 'connected as ${GitHubAuthService.username}',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: context.nText,
        ),
      ),
      subtitle: Text(
        subtitle ?? 'github/${SettingsService.githubRepo}',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: context.nMuted,
        ),
      ),
    );
  }

  Widget _buildSiteStatusTile() {
    return ValueListenableBuilder<SiteBuildStatus>(
      valueListenable: SiteStatusMonitor.instance.status,
      builder: (context, siteStatus, _) {
        Widget indicator;
        String text;
        Color color;
        switch (siteStatus) {
          case SiteBuildStatus.building:
            indicator = const SizedBox(
              width: 12,
              height: 12,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
            );
            text = 'building — publishing shortly';
            color = Colors.amber[800]!;
            break;
          case SiteBuildStatus.live:
            indicator = Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.green),
            );
            text = 'live — site is up';
            color = Colors.green[800]!;
            break;
          case SiteBuildStatus.error:
            indicator = Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.red),
            );
            text = 'last build failed — check actions';
            color = Colors.red[700]!;
            break;
          case SiteBuildStatus.unknown:
            indicator = Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: context.nFaint),
            );
            text = 'status unknown';
            color = context.nMuted;
            break;
        }
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: indicator,
          title: Text(
            text,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          subtitle: Text(
            'deployment status · auto-refreshes',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: context.nFaint,
            ),
          ),
        );
      },
    );
  }

  String _siteStatusSubtitle() {
    switch (SiteStatusMonitor.instance.status.value) {
      case SiteBuildStatus.building:
        return 'building — will go live shortly';
      case SiteBuildStatus.error:
        return 'last build failed — check actions tab';
      default:
        return 'open your github pages site';
    }
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    VoidCallback? onTap,
    bool isLoading, {
    bool destructive = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: destructive ? Colors.red : context.nText,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: context.nMuted,
        ),
      ),
      trailing: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: context.nText),
            )
          : Icon(
              destructive ? Icons.logout : Icons.chevron_right,
              size: 18,
              color: context.nFaint,
            ),
      onTap: onTap,
    );
  }

  Widget _themeTile(ThemeMode m, String label, ThemeMode current) {
    final selected = m == current;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: context.nText,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check, size: 16, color: context.nText)
          : Icon(Icons.chevron_right, size: 16, color: context.nFaint),
      onTap: () => SettingsService.themeMode = m,
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: context.nMuted,
        ),
      ),
    );
  }
}
