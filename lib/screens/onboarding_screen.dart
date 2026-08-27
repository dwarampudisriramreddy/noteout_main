import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/github_auth_service.dart';
import '../services/github_sync_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isConnecting = false;
  final _tokenController = TextEditingController();

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _openTokenPage() async {
    final url = Uri.parse(
        'https://github.com/settings/tokens/new?scopes=repo,workflow&description=noteout%20(classic%20PAT)');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _connect() async {
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
    setState(() => _isConnecting = true);
    final ok = await GitHubAuthService.signIn(token);
    if (!mounted) return;
    setState(() => _isConnecting = false);
    final status = GitHubAuthService.tokenStatus;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'connected as ${GitHubAuthService.username} — syncing...',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          backgroundColor: Colors.black,
        ),
      );
      SiteStatusMonitor.instance.start();
      unawaited(_syncAndGoHome());
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == TokenStatus.expired
                ? 'token expired — generate a new one with "no expiration"'
                : 'invalid token — use a classic PAT with ALL scopes',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _syncAndGoHome() async {
    try {
      await GitHubSyncService.syncAll();
    } catch (_) {}
  }

  void _skip() {
    SettingsService.hasSkippedOnboarding = true;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Text(
                'connect github',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Create a CLASSIC personal access token with ALL scopes '
                'ticked (or at least repo + workflow) and expiration set to '
                '\u201cno expiration\u201d. The token is stored only on your device.',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.7,
                  color: context.nMuted,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openTokenPage,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text(
                    'generate classic token',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.nLine),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _tokenController,
                obscureText: true,
                maxLines: 1,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'paste your token here',
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
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isConnecting ? null : _connect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    disabledBackgroundColor:
                        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  child: _isConnecting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary),
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    'skip for now — use locally',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: context.nMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}