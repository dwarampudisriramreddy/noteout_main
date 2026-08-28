import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Move icobtn and add flex spacer
    old_topbar = """  <header class="topbar">
    <button class="burger" onclick="toggleNav()" aria-label="Menu">{ICONS['burger']}</button>
    <button class="icobtn" onclick="toggleTheme()" aria-label="Toggle theme">{ICONS['moon']}</button>
    <a class="logo" href="{prefix}index.html">{brand_avatar}<span>{html.escape(cfg['name'])}</span></a>
    <nav class="topnav">{topbar_links}</nav>
  </header>"""

    new_topbar = """  <header class="topbar">
    <button class="burger" onclick="toggleNav()" aria-label="Menu">{ICONS['burger']}</button>
    <a class="logo" href="{prefix}index.html">{brand_avatar}<span>{html.escape(cfg['name'])}</span></a>
    <div style="flex: 1"></div>
    <nav class="topnav">{topbar_links}</nav>
    <button class="icobtn" onclick="toggleTheme()" aria-label="Toggle theme">{ICONS['moon']}</button>
  </header>"""

    content = content.replace(old_topbar, new_topbar)

    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
print("Patched topbar.")
