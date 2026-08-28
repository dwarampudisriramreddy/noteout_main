files = ['assets/site/build-site.py', 'scripts/build-site.py']
for f in files:
    with open(f, 'r') as file:
        content = file.read()
    
    # We need to escape { and } in the CSS and JS blocks in page_shell
    # CSS:
    content = content.replace('.theme-toggle { background:', '.theme-toggle {{ background:')
    content = content.replace('justify-content: center; }', 'justify-content: center; }}')
    content = content.replace('.theme-toggle:hover { background:', '.theme-toggle:hover {{ background:')
    content = content.replace('color: var(--pico-primary); }', 'color: var(--pico-primary); }}')
    content = content.replace('header.main-header { position: relative; }', 'header.main-header {{ position: relative; }}')
    content = content.replace('.header-actions { position: absolute; top: 0; right: 0; }', '.header-actions {{ position: absolute; top: 0; right: 0; }}')
    content = content.replace('.search-container { margin-bottom:', '.search-container {{ margin-bottom:')
    content = content.replace('margin-right: auto; }', 'margin-right: auto; }}')
    content = content.replace('.search-container input { border-radius: 99px; }', '.search-container input {{ border-radius: 99px; }}')
    content = content.replace('.profile-img { width: 80px;', '.profile-img {{ width: 80px;')
    content = content.replace('box-shadow: var(--card-shadow); }', 'box-shadow: var(--card-shadow); }}')

    # JS:
    content = content.replace('function toggleTheme() {', 'function toggleTheme() {{')
    content = content.replace('localStorage.setItem(\'theme\', next);\n    }', 'localStorage.setItem(\'theme\', next);\n    }}')
    content = content.replace('if (savedTheme) {', 'if (savedTheme) {{')
    content = content.replace('document.documentElement.setAttribute(\'data-theme\', savedTheme);\n    } else if', 'document.documentElement.setAttribute(\'data-theme\', savedTheme);\n    }} else if')
    content = content.replace('window.matchMedia(\'(prefers-color-scheme: dark)\').matches) {', 'window.matchMedia(\'(prefers-color-scheme: dark)\').matches) {{')
    content = content.replace('document.documentElement.setAttribute(\'data-theme\', \'dark\');\n    }', 'document.documentElement.setAttribute(\'data-theme\', \'dark\');\n    }}')

    with open(f, 'w') as file:
        file.write(content)

print("Syntax fixed!")
