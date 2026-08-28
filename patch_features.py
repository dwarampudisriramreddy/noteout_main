import os

files = ['assets/site/build-site.py', 'scripts/build-site.py']
for f in files:
    with open(f, 'r') as file:
        content = file.read()
    
    # 1. Add theme toggle JS to head
    js_head = """
  <script>
    function toggleTheme() {
      const html = document.documentElement;
      const current = html.getAttribute('data-theme');
      const next = current === 'dark' ? 'light' : 'dark';
      html.setAttribute('data-theme', next);
      localStorage.setItem('theme', next);
    }
    const savedTheme = localStorage.getItem('theme');
    if (savedTheme) {
      document.documentElement.setAttribute('data-theme', savedTheme);
    } else if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
      document.documentElement.setAttribute('data-theme', 'dark');
    }
  </script>
"""
    content = content.replace("</head>", js_head + "</head>")
    
    # 2. Add theme-toggle CSS
    css = """
    .theme-toggle { background: transparent; border: none; color: var(--pico-muted-color); cursor: pointer; padding: 0.5rem; border-radius: 50%; transition: background 0.2s; display: inline-flex; align-items: center; justify-content: center; }
    .theme-toggle:hover { background: var(--pico-card-background-color); color: var(--pico-primary); }
    header.main-header { position: relative; }
    .header-actions { position: absolute; top: 0; right: 0; }
    .search-container { margin-bottom: 2rem; max-width: 400px; margin-left: auto; margin-right: auto; }
    .search-container input { border-radius: 99px; }
"""
    content = content.replace("  </style>", css + "  </style>")
    
    # 3. Add theme toggle button in header
    toggle_btn = """
    <div class="header-actions">
      <button onclick="toggleTheme()" class="theme-toggle" aria-label="Toggle Dark Mode" title="Toggle Dark Mode">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path></svg>
      </button>
    </div>
"""
    content = content.replace('<header class="main-header">', '<header class="main-header">' + toggle_btn)
    
    # 4. Add "Powered by noteout" branding
    footer_html = """<footer class="site">
    <div>Digital Garden</div>
    <div style="margin-top: 0.5rem; font-size: 0.8em; opacity: 0.7;">Powered by <strong>noteout</strong></div>
  </footer>"""
    content = content.replace('<footer class="site">Digital Garden</footer>', footer_html)
    
    # 5. Add search bar to index page
    search_html = """
    search_html = '''
<div class="search-container">
  <input type="search" id="searchBox" placeholder="Search notes..." onkeyup="filterNotes()">
</div>
<script>
function filterNotes() {
  const query = document.getElementById('searchBox').value.toLowerCase();
  const cards = document.querySelectorAll('.note-card');
  cards.forEach(card => {
    const text = card.textContent.toLowerCase();
    card.style.display = text.includes(query) ? '' : 'none';
  });
}
</script>
'''
    if regular or journal:
        parts.insert(0, search_html)
"""
    
    content = content.replace("    body = '\\n'.join(parts)", search_html + "    body = '\\n'.join(parts)")

    with open(f, 'w') as file:
        file.write(content)

print("Features added successfully!")
