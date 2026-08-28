import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Find the body list initialization and insert the if block after it
    replacement = r"\1    if cfg.get('show_calendar', True):\n        body.append(_journal_section(notes, emojis))\n"
    content = re.sub(
        r"(body = \[\s*_hero_html\(cfg\),\s*_stats_html\(regular, journal, len\(all_tags\)\),\s*\]\n)",
        replacement,
        content
    )

    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
print("Patched body.append")
