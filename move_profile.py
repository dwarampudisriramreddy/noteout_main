with open('lib/screens/settings_screen.dart', 'r') as file:
    content = file.read()

# Extract profile section
profile_start_str = "          _buildSection(\n            'profile',"
profile_end_str = "          ),\n          _buildSection(\n            'theme',"
start_idx = content.find(profile_start_str)
end_idx = content.find(profile_end_str)
if start_idx != -1 and end_idx != -1:
    profile_section = content[start_idx:end_idx] + "          ),\n"
    # Remove from old location
    content = content[:start_idx] + content[end_idx + 12:] # +12 to skip '          )\n'
    
    # Find start of ListView
    listview_str = "        child: ListView(\n          padding: const EdgeInsets.symmetric(vertical: 16),\n          children: [\n"
    insert_idx = content.find(listview_str) + len(listview_str)
    
    # Insert at top
    content = content[:insert_idx] + profile_section + content[insert_idx:]

with open('lib/screens/settings_screen.dart', 'w') as file:
    file.write(content)
print("Moved profile")
