import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # HTML replace
    old_html = """  <footer class="site">
    <div>© {datetime.now().year} <b>{html.escape(cfg['name'])}</b> — notes &amp; thoughts</div>
    <div>made with noteout - get your thoughts out</div>
  </footer>"""
    
    new_html = """  <footer class="site">
    <div>© {datetime.now().year} <b>{html.escape(cfg['name'])}</b> - made with noteout</div>
  </footer>"""
    
    content = content.replace(old_html, new_html)
    
    # CSS replaces (since build-site.py outputs CSS as well)
    content = content.replace(
        "body{margin:0;",
        "body{display:flex;flex-direction:column;min-height:100vh;margin:0;"
    )
    
    content = content.replace(
        ".layout{display:grid;",
        ".layout{flex:1;width:100%;display:grid;"
    )
    
    content = content.replace(
        "footer.site{max-width:1300px;margin:0 auto;border-top:1px solid var(--line);padding:22px 30px 40px;color:var(--muted);font-size:.84em;display:flex;flex-wrap:wrap;gap:10px;align-items:center;justify-content:space-between}",
        "footer.site{width:100%;box-sizing:border-box;max-width:1300px;margin:0 auto;border-top:1px solid var(--line);padding:22px 30px 30px;color:var(--muted);font-size:.78em;display:flex;justify-content:center;text-align:center;}"
    )

    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
print("Patched footer layout.")
