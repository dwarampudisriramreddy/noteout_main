with open('lib/screens/onboarding_screen.dart', 'r') as file:
    content = file.read()

# Replace popUntil with push replacement
import_stmt = "import '../services/settings_service.dart';"
content = content.replace(import_stmt, import_stmt + "\nimport 'profile_onboarding_screen.dart';")

# 1. In _connect
old_connect_nav = "      Navigator.of(context).popUntil((route) => route.isFirst);"
new_connect_nav = "      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileOnboardingScreen()));"
content = content.replace(old_connect_nav, new_connect_nav)

# 2. In _skip
old_skip_nav = "    Navigator.of(context).popUntil((route) => route.isFirst);"
new_skip_nav = "    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileOnboardingScreen()));"
content = content.replace(old_skip_nav, new_skip_nav)

# 3. Also remove `SettingsService.hasSkippedOnboarding = true;` from _skip, since it's done in profile
content = content.replace("SettingsService.hasSkippedOnboarding = true;", "")

with open('lib/screens/onboarding_screen.dart', 'w') as file:
    file.write(content)
print("Updated onboarding screen")
