import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # 1. Update build_journals_page
    old_code = """    if journal:
        cards = ''.join(card_html(m, c, '') for m, c in journal)
        body.append(f'<div class="group"><div class="cards">{cards}</div></div>')"""
    new_code = """    if journal:
        cards = ''.join(card_html(m, c, '', dd=True) for m, c in journal)
        body.append(f'<div class="group"><div class="notes dd">{cards}</div></div>')"""
    content = content.replace(old_code, new_code)

    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
print("Patched journals CSS classes.")
