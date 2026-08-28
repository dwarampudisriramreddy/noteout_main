import os

files = ['assets/site/build-site.py', 'scripts/build-site.py']
for f in files:
    with open(f, 'r') as file:
        content = file.read()
    
    # 1. Add get_config function
    get_config_func = """
def get_config():
    config = {'name': ''}
    if Path('config.json').exists():
        try:
            config = json.loads(Path('config.json').read_text())
        except Exception:
            pass
    profile_img = ''
    for ext in ['jpg', 'jpeg', 'png', 'gif', 'webp']:
        if Path(f'profile.{ext}').exists():
            profile_img = f'profile.{ext}'
            # copy profile image to _site if it exists
            try:
                (SITE_DIR / profile_img).write_bytes(Path(profile_img).read_bytes())
            except Exception:
                pass
            break
    config['profile_img'] = profile_img
    return config
"""
    if "def get_config():" not in content:
        content = content.replace("def page_shell", get_config_func + "\n\ndef page_shell")

    # 2. Modify page_shell to use config
    if "config = get_config()" not in content:
        content = content.replace("def page_shell(title, nav_html, body_html, active=''):", """def page_shell(title, nav_html, body_html, active=''):
    config = get_config()
    site_title = f"{config['name']}'s Digital Garden" if config.get('name') else 'Digital Garden'
    profile_html = f'<img src="{config["profile_img"]}" class="profile-img" alt="Profile">' if config.get('profile_img') else ''
""")

    # 3. Replace fixed titles with variables
    content = content.replace("<title>{html.escape(title)} — Digital Garden</title>", "<title>{html.escape(title)} — {html.escape(site_title)}</title>")
    content = content.replace('<h1 class="site-title">Digital Garden</h1>', '{profile_html}\\n    <h1 class="site-title">{html.escape(site_title)}</h1>')
    content = content.replace('<footer class="site">\n    <div>Digital Garden</div>', '<footer class="site">\n    <div>{html.escape(site_title)}</div>')
    
    # 4. Add CSS for profile image
    if ".profile-img {" not in content:
        css = """
    .profile-img { width: 80px; height: 80px; border-radius: 50%; object-fit: cover; margin-bottom: 1rem; border: 2px solid var(--pico-primary); box-shadow: var(--card-shadow); }
"""
        content = content.replace("  </style>", css + "  </style>")

    with open(f, 'w') as file:
        file.write(content)

print("Name and profile patch applied!")
