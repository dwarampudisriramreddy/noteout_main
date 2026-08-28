with open('lib/screens/settings_screen.dart', 'r') as file:
    content = file.read()

profile_start_str = "          _buildSection(\n            'profile',"
profile_end_str = "          ),\n          _buildSection(\n            'theme',"
start_idx = content.find(profile_start_str)
end_idx = content.find(profile_end_str)

if start_idx != -1 and end_idx != -1:
    profile_section = content[start_idx:end_idx]
    # Remove from old location
    content = content[:start_idx] + content[end_idx:]
    
    # Find start of ListView
    listview_str = "      body: ListView(\n        children: [\n          const SizedBox(height: 16),\n"
    insert_idx = content.find(listview_str)
    
    if insert_idx != -1:
        insert_idx += len(listview_str)
        # Insert at top
        content = content[:insert_idx] + profile_section + content[insert_idx:]
    else:
        print("ListView not found")

with open('lib/screens/settings_screen.dart', 'w') as file:
    file.write(content)
print("Moved profile")
