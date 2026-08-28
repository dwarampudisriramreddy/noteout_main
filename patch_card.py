import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Remove the excerpt paragraph from card_html
    content = content.replace(
        "  <p class=\"ex\">{html.escape(excerpt)}</p>\n",
        ""
    )

    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
print("Patched card_html.")
