import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'services/storage_service.dart';
import 'services/settings_service.dart';
import 'services/github_auth_service.dart';
import 'services/github_sync_service.dart';
import 'models/note.dart';
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

  if (!SettingsService.hasCreatedReadme) {
    final readme = Note(
      title: 'Welcome to noteout!',
      content: '''# Welcome to noteout! 👋

noteout is your personal space to get your thoughts out. Here is a comprehensive guide to mastering the app.

## 📝 Features & Pro Tips

- **Markdown Support:** Write notes using standard Markdown formatting (bold, italics, lists, tables, math, etc.). Open a new blank note to see a quick syntax cheat sheet!
- **Categories & Tags:** Add `#tag` anywhere in your note to categorize it. Tags act like folders.
- **Wiki Links:** Type `[[` in any note to instantly search and link to your other notes via an autocomplete menu.
- **Search & Sort:** Use the search bar on the home screen to find notes instantly. Tap the sort icon in the top right to order your notes by date, title, or tags.
- **Swipe to Delete:** In your Notes list, simply **swipe left** on any note to permanently delete it.
- **Dark Mode:** Tap the moon icon in the top right to instantly toggle between light and dark themes.

## 📅 Journaling & Mood Tracking

- **Daily Notes:** Track your daily thoughts in the Journal tab.
- **Mood Tracking:** You can **long press** on any calendar date to assign a specific emoji to track your mood, progress, or daily activity!

## 🌳 Graph View

- Tap the tree icon in the top right of the home screen to visualize the connections and links between all your notes in an interactive graph.

## 📸 Images & Gallery

- You can add images by tapping the image icon in the editor. 
- Once uploaded to GitHub, you can manage your images in the Gallery tab. 
- You can also delete images directly from the Gallery, which will safely scrub them from GitHub and your notes.

## 🌐 Publishing to the Web

- Head over to Settings -> GitHub Sync to set up your repository. 
- Once connected, tap "sync now" anytime to push your notes and update your live site.
- The site automatically builds an activity heatmap and organizes your tags into folders!

Happy writing!
''',
      tags: ['noteout', 'guide'],
    );
    await StorageService.saveNote(readme);
    SettingsService.hasCreatedReadme = true;
  }

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
