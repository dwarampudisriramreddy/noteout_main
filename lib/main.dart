import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'services/storage_service.dart';
import 'services/settings_service.dart';
import 'services/github_auth_service.dart';
import 'services/github_sync_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/legal_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await StorageService.init();
  await SettingsService.init();

  try {
    await GitHubAuthService.init();
  } catch (_) {}

  if (GitHubAuthService.isLoggedIn) {
    SiteStatusMonitor.instance.start();
  }

  FlutterError.onError = (details) {
    debugPrint('Flutter error: ${details.exception}');
    debugPrintStack(stackTrace: details.stack);
  };

  runApp(const NoteoutApp());
}

class NoteoutApp extends StatelessWidget {
  const NoteoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: SettingsService.themeNotifier,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'noteout — take your thoughts out',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: themeMode,
        home: ValueListenableBuilder<bool>(
          valueListenable: SettingsService.onboardedNotifier,
          builder: (context, _, inner) => ValueListenableBuilder<bool>(
            valueListenable: GitHubAuthService.isLoggedInNotifier,
            builder: (context, _, _) {
              final showHome = GitHubAuthService.isLoggedIn ||
                  SettingsService.hasSkippedOnboarding;
              return showHome ? const HomeScreen() : const WelcomeScreen();
            },
          ),
        ),
      routes: {
        '/settings': (_) => const SettingsScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/privacy': (_) => const LegalScreen(
              title: 'privacy policy',
              body: 'Your notes are stored locally on your device and, when you '
                  'connect GitHub, synced to your own private repository. Your '
                  'GitHub personal access token is kept only on this device and '
                  'is never sent anywhere except to GitHub’s API. We do not '
                  'collect analytics or personal data.',
            ),
        '/terms': (_) => const LegalScreen(
              title: 'terms',
              body: 'By using this app you are responsible for the content you '
                  'store and for keeping your GitHub token secure. The app is '
                  'provided as-is without warranty.',
            ),
      },
      ),
    );
  }
}
