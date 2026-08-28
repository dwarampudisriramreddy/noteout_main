import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # 1. Update nav_items
    nav_items_old = """    nav_items = [
        ('index.html', 'home', ICONS['home'], 'Home'),
        ('notes.html', 'notes', ICONS['notes'], 'Notes'),
        ('tags.html', 'tags', ICONS['tags'], 'Tags'),
            ]"""
    nav_items_new = """    nav_items = [
        ('index.html', 'home', ICONS['home'], 'Home'),
        ('notes.html', 'notes', ICONS['notes'], 'Notes'),
        ('journals.html', 'journals', ICONS['calendar'], 'Journals'),
        ('tags.html', 'tags', ICONS['tags'], 'Tags'),
            ]"""
    content = content.replace(nav_items_old, nav_items_new)

    # 2. Add build_journals_page function
    if "def build_journals_page" not in content:
        journals_func = """
def build_journals_page(notes, tree_html, emojis):
    journal = [(m, c) for m, c in notes if m.get('title', '').startswith('journal:')]
    journal.sort(key=lambda x: x[0].get('title', ''), reverse=True)
    
    body = [
        '<h1 class="doctitle">Journals</h1>',
        _journal_section(notes, emojis),
        '<div class="search-wrap" style="margin-top: 30px">',
        f'<div class="search">{ICONS["search"]}<input class="searchbox" type="search" placeholder="Search journals…" aria-label="Search journals"></div>',
    ]
    if journal:
        cards = ''.join(card_html(m, c, '') for m, c in journal)
        body.append(f'<div class="group"><div class="cards">{cards}</div></div>')
    else:
        body.append('<p class="empty">no journals yet</p>')
    body.append('<p class="empty-search">no matching notes</p></div>')
    return page_shell('Journals', '\\n'.join(body), 'journals', tree_html)

"""
        content = content.replace("def build_notes_page", journals_func + "def build_notes_page")

    # 3. Add to main() output
    build_main_old = """    (SITE_DIR / 'tags.html').write_text(build_tags_page(notes, tree_html), encoding='utf-8')"""
    build_main_new = """    (SITE_DIR / 'tags.html').write_text(build_tags_page(notes, tree_html), encoding='utf-8')
    (SITE_DIR / 'journals.html').write_text(build_journals_page(notes, tree_html, emojis), encoding='utf-8')"""
    content = content.replace(build_main_old, build_main_new)

    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
print("Patched journals.")
