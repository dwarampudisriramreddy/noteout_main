import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Remove calendar from nav_items
    content = re.sub(
        r"\(\s*'calendar\.html',\s*'calendar',\s*ICONS\['calendar'\],\s*'Journal'\s*\),?\s*\n",
        "",
        content,
        flags=re.MULTILINE
    )

    # Remove _journal_section definition
    content = re.sub(
        r"def _journal_section\(notes, emojis\):.*?(?=\n\n\ndef )",
        "",
        content,
        flags=re.DOTALL
    )

    # Remove calendar body and build_calendar
    content = re.sub(
        r"def calendar_body\(notes, emojis\):.*?(?=\n\n\ndef )",
        "",
        content,
        flags=re.DOTALL
    )
    content = re.sub(
        r"def build_calendar\(notes, emojis, tree_html\):.*?(?=\n\n\ndef )",
        "",
        content,
        flags=re.DOTALL
    )

    # Remove from _stats_html
    content = re.sub(
        r'<a class="stat" href="calendar\.html"><b>\{len\(journal\)\}</b><span>journal days</span></a>\n\s*',
        "",
        content
    )

    # Remove from _build_index_personal
    content = re.sub(
        r"\s*if cfg\.get\('show_calendar', True\):\s*body\.append\(_journal_section\(notes, emojis\)\)",
        "",
        content
    )

    # Remove calendar.html generation in main
    content = re.sub(
        r"\s*\(SITE_DIR / 'calendar\.html'\)\.write_text\(build_calendar\(notes, emojis, tree_html\), encoding='utf-8'\)\n",
        "\n",
        content
    )

    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
print("Patched.")
