import urllib.request
import json
import os

url = "https://raw.githubusercontent.com/github/gemoji/master/db/emoji.json"
req = urllib.request.urlopen(url)
data = json.loads(req.read().decode('utf-8'))

categories = {}
search_map = {}

for item in data:
    if 'emoji' not in item or 'category' not in item: continue
    cat = item['category']
    if cat not in categories:
        categories[cat] = []
    categories[cat].append(item['emoji'])
    
    # search terms
    terms = []
    if 'description' in item:
        terms.extend(item['description'].lower().split())
    if 'aliases' in item:
        for alias in item['aliases']:
            terms.extend(alias.replace('_', ' ').replace('-', ' ').lower().split())
    if 'tags' in item:
        for tag in item['tags']:
            terms.extend(tag.lower().split())
            
    # filter out empty
    terms = list(set([t for t in terms if t]))
    for t in terms:
        if t not in search_map:
            search_map[t] = []
        if item['emoji'] not in search_map[t]:
            search_map[t].append(item['emoji'])

# Generate dart code
dart = """// GENERATED CODE
class EmojiData {
  static const Map<String, List<String>> categories = {
"""
for cat, emojis in categories.items():
    emojis_str = "['" + "','".join(emojis) + "']"
    dart += f"    '{cat}': {emojis_str},\n"

dart += "  };\n\n  static const Map<String, List<String>> searchMap = {\n"
for term, emojis in search_map.items():
    # escape quotes and backslashes in term just in case
    safe_term = term.replace("'", "\\'").replace('"', '\\"')
    emojis_str = "['" + "','".join(emojis) + "']"
    dart += f"    '{safe_term}': {emojis_str},\n"

dart += "  };\n}\n"

with open('lib/utils/emoji_data.dart', 'w') as f:
    f.write(dart)

print("Generated emoji_data.dart")
