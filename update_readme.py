import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    old_content = """      content: '''# Welcome to noteout! 👋

noteout is your personal space to get your thoughts out. Here is a quick guide to getting started.

## 📝 Features

- **Markdown Support:** Write notes using standard Markdown formatting (bold, italics, lists, tables, etc.). Check the cheat sheet when creating a new blank note!
- **Categories & Tags:** Add `#tag` anywhere in your note to categorize it. Tags act like folders!
- **Wiki Links:** Type `[[` in any note to instantly search and link to your other notes.
- **Journaling:** Track your daily thoughts in the Journal tab. You can assign emojis to specific dates to track your mood or activity!
- **Graph View:** Tap the tree icon in the top right to visualize the connections between all your notes.
- **GitHub Sync:** Connect your GitHub account to safely backup your notes to a private repository and instantly deploy them as a beautiful, public (or private) website via GitHub Pages!

## 📸 Images

You can add images by tapping the image icon in the editor. Once uploaded to GitHub, you can manage your images in the Gallery tab.

## 🌐 Publishing

Head over to Settings -> GitHub Sync to set up your repository. Once connected, tap "sync now" anytime to push your notes and update your site.

Happy writing!
''',"""

    new_content = """      content: '''# Welcome to noteout! 👋

noteout is your personal space to get your thoughts out. Here is a comprehensive guide to mastering the app.

## 📝 Features & Pro Tips

- **Markdown Support:** Write notes using standard Markdown formatting (bold, italics, lists, tables, math, etc.). Open a new blank note to see a quick syntax cheat sheet!
- **Categories & Tags:** Add `#tag` anywhere in your note to categorize it. Tags act like folders.
- **Wiki Links:** Type `[[` in any note to instantly search and link to your other notes via an autocomplete menu.
- **Swipe to Delete:** In your Notes list, simply **swipe left** on any note to permanently delete it.
- **Journaling & Mood Tracking:** Track your daily thoughts in the Journal tab. You can **long press** on any calendar date to assign a specific emoji to track your mood, progress, or daily activity!
- **Graph View:** Tap the tree icon in the top right to visualize the connections and links between all your notes.
- **GitHub Sync:** Connect your GitHub account to safely backup your notes to a private repository and instantly deploy them as a beautiful website via GitHub Pages!

## 📸 Images & Gallery

You can add images by tapping the image icon in the editor. Once uploaded to GitHub, you can manage your images in the Gallery tab. You can also delete images directly from the Gallery, which will safely scrub them from GitHub and your notes.

## 🌐 Publishing to the Web

Head over to Settings -> GitHub Sync to set up your repository. Once connected, tap "sync now" anytime to push your notes and update your live site. 

Happy writing!
''',"""
    
    content = content.replace(old_content, new_content)

    with open(path, 'w') as f:
        f.write(content)

process_file('lib/main.dart')
print("Patched.")
