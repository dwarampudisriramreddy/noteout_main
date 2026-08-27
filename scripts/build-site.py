#!/usr/bin/env python3
"""Build noteout site from markdown notes."""

import json
import os
import re
import html
from pathlib import Path
from datetime import datetime

NOTES_DIR = Path('notes')
SITE_DIR = Path('_site')
EMOJI_FILE = Path('emojis.json')

PICO_CDN = 'https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css'

MONTHS = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
]


def parse_frontmatter(content):
    """Parse YAML-ish frontmatter from markdown."""
    if not content.startswith('---'):
        return {}, content
    end = content.find('---', 3)
    if end == -1:
        return {}, content
    raw = content[3:end].strip()
    meta = {}
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, dict):
            meta = parsed
    except Exception:
        for line in raw.split('\n'):
            if ':' in line:
                key, val = line.split(':', 1)
                key = key.strip()
                val = val.strip()
                if val.startswith('[') and val.endswith(']'):
                    val = [v.strip().strip('"').strip("'") for v in val[1:-1].split(',') if v.strip()]
                elif val.startswith('"') and val.endswith('"'):
                    val = val[1:-1]
                elif val.startswith("'") and val.endswith("'"):
                    val = val[1:-1]
                meta[key] = val
    body = content[end + 3:].strip()
    return meta, body


def simple_md(text):
    """Minimal markdown to HTML conversion."""
    text = html.escape(text)
    # code blocks
    text = re.sub(r'```(\w*)\n(.*?)```', r'<pre><code>\2</code></pre>', text, flags=re.DOTALL)
    # inline code
    text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)
    # images ![](url)
    text = re.sub(
        r'!\[([^\]]*)\]\(([^)]+)\)',
        r'<img src="\2" alt="\1" class="note-img">',
        text,
    )
    # headers
    text = re.sub(r'^#### (.+)$', r'<h4>\1</h4>', text, flags=re.MULTILINE)
    text = re.sub(r'^### (.+)$', r'<h3>\1</h3>', text, flags=re.MULTILINE)
    text = re.sub(r'^## (.+)$', r'<h2>\1</h2>', text, flags=re.MULTILINE)
    text = re.sub(r'^# (.+)$', r'<h1>\1</h1>', text, flags=re.MULTILINE)
    # bold and italic
    text = re.sub(r'\*\*\*(.+?)\*\*\*', r'<strong><em>\1</em></strong>', text)
    text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
    text = re.sub(r'\*(.+?)\*', r'<em>\1</em>', text)
    # wiki links [[note]]
    text = re.sub(
        r'\[\[([^\]]+)\]\]',
        lambda m: f'<a href="{slug(m.group(1))}.html" class="wiki-link">[[{html.escape(m.group(1))}]]</a>',
        text
    )
    # tags #tag
    text = re.sub(
        r'(?:^|\s)#(\w+)',
        r' <span class="tag">#\1</span>',
        text
    )
    # blockquote
    text = re.sub(r'^> (.+)$', r'<blockquote>\1</blockquote>', text, flags=re.MULTILINE)
    # unordered list
    text = re.sub(r'^- (.+)$', r'<li>\1</li>', text, flags=re.MULTILINE)
    text = re.sub(r'(<li>.*</li>\n?)+', lambda m: f'<ul>{m.group(0)}</ul>', text)
    # horizontal rule
    text = re.sub(r'^---+$', r'<hr>', text, flags=re.MULTILINE)
    # paragraphs (double newline)
    text = re.sub(r'\n\n+', '</p><p>', text)
    text = '<p>' + text + '</p>'
    # single newline to br
    text = text.replace('\n', '<br>')
    # clean empty p tags
    text = re.sub(r'<p>\s*</p>', '', text)
    text = re.sub(r'<p>(<h[1-6])', r'\1', text)
    text = re.sub(r'(</h[1-6]>)</p>', r'\1', text)
    text = re.sub(r'<p>(<ul>)', r'\1', text)
    text = re.sub(r'(</ul>)</p>', r'\1', text)
    text = re.sub(r'<p>(<hr>)', r'\1', text)
    text = re.sub(r'(</?blockquote>)</p>', r'\1', text)
    text = re.sub(r'<p>\s*<br>\s*', '<p>', text)
    text = re.sub(r'<br>\s*</p>', '</p>', text)
    return text


def slug(title):
    """Create URL-safe slug from title."""
    name = title.lower()
    name = re.sub(r'[^\w\s-]', '', name)
    name = re.sub(r'\s+', '-', name)
    name = re.sub(r'-+', '-', name)
    name = re.sub(r'^-|-$', '', name)
    return name or 'untitled'


def load_emojis():
    """Load emoji data if available."""
    if EMOJI_FILE.exists():
        return json.loads(EMOJI_FILE.read_text())
    return {}


def page_shell(title, nav_html, body_html, active=''):
    """Wrap content in page template."""
    nav_items = [
        ('index.html', 'notes', 'notes'),
        ('tags.html', 'tags', 'tags'),
        ('calendar.html', 'calendar', 'calendar'),
    ]
    links = []
    for href, label, key in nav_items:
        if key == active:
            links.append(f'<a href="{href}"><strong>{label}</strong></a>')
        else:
            links.append(f'<a href="{href}">{label}</a>')
    nav = ' '.join(links)

    return f'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(title)} — noteout</title>
  <meta name="description" content="noteout — take your thoughts out">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="{PICO_CDN}">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js" onload="renderMathInElement(document.body,{{delimiters:[{{left:'$',right:'$',display:false}},{{left:'$$',right:'$$',display:true}}]}})"></script>
  <style>
    :root {{
      --pico-font-family: 'Inter', system-ui, sans-serif;
      --pico-font-family-monospace: 'JetBrains Mono', monospace;
      --pico-primary: #6366f1;
      --pico-primary-hover: #4f46e5;
      --pico-border-radius: 12px;
      --card-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1);
      --card-shadow-hover: 0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1);
    }}
    body {{ max-width: 800px; margin: 0 auto; padding: 2rem var(--pico-spacing); }}
    header.main-header {{ display: flex; flex-direction: column; align-items: center; text-align: center; margin-bottom: 3rem; }}
    h1.site-title {{ font-size: 2.5em; font-weight: 600; letter-spacing: -1px; margin-bottom: 0.2rem; color: var(--pico-primary); }}
    .tagline {{ color: var(--pico-muted-color); font-size: 1.1em; margin-bottom: 1.5rem; }}
    nav {{ display: flex; gap: 1rem; justify-content: center; font-size: 1em; background: var(--pico-card-background-color); padding: 0.75rem 1.5rem; border-radius: 99px; box-shadow: var(--card-shadow); margin-bottom: 3rem; }}
    nav a {{ color: var(--pico-h1-color); text-decoration: none; font-weight: 500; transition: color 0.2s; padding: 0.25rem 0.5rem; border-radius: 6px; }}
    nav a strong {{ color: var(--pico-primary); font-weight: 600; }}
    nav a:hover {{ color: var(--pico-primary-hover); }}
    .note-card {{ background: var(--pico-card-background-color); padding: 1.5rem; margin-bottom: 1.5rem; border-radius: var(--pico-border-radius); box-shadow: var(--card-shadow); transition: transform 0.2s, box-shadow 0.2s; border: 1px solid var(--pico-card-border-color); }}
    .note-card:hover {{ transform: translateY(-2px); box-shadow: var(--card-shadow-hover); }}
    .note-card header {{ font-weight: 600; font-size: 1.25em; margin-bottom: 0.5rem; padding-bottom: 0; color: var(--pico-h1-color); }}
    .note-card p {{ color: var(--pico-muted-color); font-size: 0.95em; margin-bottom: 1rem; line-height: 1.6; }}
    .note-card footer {{ font-size: 0.85em; color: var(--pico-muted-color); display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap; }}
    .note-card a {{ color: inherit; text-decoration: none; display: block; }}
    .tag {{ display: inline-block; padding: 0.2rem 0.6rem; background: var(--pico-primary); color: white !important; border-radius: 99px; font-size: 0.8em; text-decoration: none; transition: opacity 0.2s; font-weight: 500; margin-right: 0.25rem; }}
    .tag:hover {{ opacity: 0.9; }}
    .tag-count {{ font-size: 0.8em; opacity: 0.8; margin-left: 0.25rem; }}
    .tag-folder {{ margin: 0.5rem 0; background: var(--pico-card-background-color); padding: 1rem; border-radius: var(--pico-border-radius); box-shadow: var(--card-shadow); }}
    .tag-folder > summary {{ list-style: none; cursor: pointer; padding: 0; font-weight: 500; color: var(--pico-h1-color); }}
    .tag-folder > summary::-webkit-details-marker {{ display: none; }}
    .tag-folder > summary::before {{ content: '▸ '; color: var(--pico-primary); display: inline-block; width: 1.2em; }}
    .tag-folder[open] > summary::before {{ content: '▾ '; }}
    .tag-folder-link {{ color: inherit; text-decoration: none; }}
    .tag-folder-link:hover {{ color: var(--pico-primary); }}
    .tag-children {{ margin-left: 1.2em; margin-top: 0.75rem; padding-left: 1rem; border-left: 2px solid var(--pico-primary); opacity: 0.6; }}
    .tag-leaf {{ margin: 0.5rem 0; }}
    .journal-card header {{ font-family: var(--pico-font-family-monospace); }}
    h2 {{ font-size: 1.5em; margin-top: 2rem; margin-bottom: 1rem; color: var(--pico-h1-color); font-weight: 600; }}
    .empty {{ color: var(--pico-muted-color); text-align: center; margin-top: 4rem; font-size: 1.1em; }}
    .wiki-link {{ color: var(--pico-primary); text-decoration: underline; text-decoration-style: dotted; text-underline-offset: 4px; font-weight: 500; transition: opacity 0.2s; }}
    .wiki-link:hover {{ opacity: 0.8; }}
    .note-img {{ max-width: 100%; height: auto; border-radius: var(--pico-border-radius); margin: 1rem 0; box-shadow: var(--card-shadow); }}
    .katex-display {{ margin: 1.5rem 0; overflow-x: auto; overflow-y: hidden; }}
    .links {{ margin-top: 3rem; padding-top: 1.5rem; border-top: 2px dashed var(--pico-card-border-color); font-size: 0.9em; }}
    .cal-grid {{ display: grid; grid-template-columns: repeat(7, 1fr); gap: 0.5rem; margin-bottom: 2rem; }}
    .day {{ aspect-ratio: 1; display: flex; align-items: center; justify-content: center; font-size: 1em; border-radius: var(--pico-border-radius); font-variant-numeric: tabular-nums; background: var(--pico-card-background-color); box-shadow: var(--card-shadow); transition: transform 0.2s; }}
    .day.empty {{ visibility: hidden; box-shadow: none; }}
    .day.today {{ background: var(--pico-primary); color: white; font-weight: 600; box-shadow: 0 4px 14px 0 rgba(99, 102, 241, 0.39); border: none; }}
    .day.has-note {{ border: 2px solid var(--pico-primary); cursor: pointer; }}
    .day.has-note:hover {{ transform: scale(1.05); }}
    .day a {{ color: inherit; text-decoration: none; display: flex; align-items: center; justify-content: center; width: 100%; height: 100%; border-radius: inherit; }}
    .month {{ margin-bottom: 3rem; }}
    .month h3 {{ font-size: 1.25em; margin-bottom: 1rem; color: var(--pico-h1-color); font-weight: 600; }}
    footer.site {{ margin-top: 4rem; padding-top: 2rem; border-top: 1px solid var(--pico-card-border-color); font-size: 0.9em; color: var(--pico-muted-color); text-align: center; }}
    article > h1 {{ font-size: 2.5em; font-weight: 700; margin-bottom: 0.5rem; letter-spacing: -0.5px; line-height: 1.2; }}
    .meta {{ font-size: 0.9em; color: var(--pico-muted-color); margin-bottom: 2.5rem; display: flex; gap: 1rem; align-items: center; border-bottom: 1px solid var(--pico-card-border-color); padding-bottom: 1.5rem; }}
    article pre {{ border-radius: var(--pico-border-radius); padding: 1.25rem; font-family: var(--pico-font-family-monospace); box-shadow: inset 0 2px 4px 0 rgb(0 0 0 / 0.05); font-size: 0.9em; }}
    article blockquote {{ border-left: 4px solid var(--pico-primary); padding-left: 1rem; color: var(--pico-muted-color); font-style: italic; background: var(--pico-card-background-color); padding: 1rem; border-radius: 0 var(--pico-border-radius) var(--pico-border-radius) 0; }}
    article p {{ line-height: 1.8; font-size: 1.05em; }}
  </style>
</head>
<body>
  <header class="main-header">
    <h1 class="site-title">noteout</h1>
    <p class="tagline">take your thoughts out</p>
    <nav>{nav}</nav>
  </header>
  <main>
    {body_html}
  </main>
  <footer class="site">noteout &mdash; take your thoughts out</footer>
</body>
</html>'''


def build_index(notes):
    """Generate index.html."""
    regular = [(m, c) for m, c in notes if not m.get('title', '').startswith('journal:')]
    journal = [(m, c) for m, c in notes if m.get('title', '').startswith('journal:')]

    parts = []
    if not regular and not journal:
        parts.append('<p class="empty">no notes yet</p>')
    else:
        for meta, content in regular:
            title = meta.get('title', 'untitled')
            s = slug(title)
            created = meta.get('created', '')[:10]
            tags = meta.get('tags', [])
            if isinstance(tags, str):
                tags = [tags] if tags else []
            tags_html = ' '.join(
                f'<a href="{tag_href(t)}" class="tag">#{html.escape(t)}</a>'
                for t in tags
            )
            excerpt = content[:120].replace('\n', ' ').strip()
            parts.append(f'''<article class="note-card">
  <a href="{s}.html">
    <header>{html.escape(title)}</header>
    <p>{html.escape(excerpt)}</p>
    <footer><time>{created}</time> {tags_html}</footer>
  </a>
</article>''')

    if journal:
        parts.append('<h2>journal</h2>')
        for meta, content in journal:
            title = meta.get('title', '')
            date_str = title.replace('journal:', '')
            s = slug(title)
            excerpt = content[:120].replace('\n', ' ').strip() or 'daily note'
            parts.append(f'''<article class="note-card journal-card">
  <a href="{s}.html">
    <header>{html.escape(date_str)}</header>
    <p>{html.escape(excerpt)}</p>
  </a>
</article>''')

    body = '\n'.join(parts)
    return page_shell('noteout', '', body, active='notes')


def build_calendar(notes, emojis):
    """Generate calendar.html."""
    now = datetime.now()
    journal_dates = {}
    for meta, content in notes:
        title = meta.get('title', '')
        if title.startswith('journal:'):
            d = title.replace('journal:', '')
            journal_dates[d] = (meta, content)

    parts = []
    for m in range(1, 13):
        first = datetime(now.year, m, 1)
        if m == 12:
            last = datetime(now.year + 1, 1, 1)
        else:
            last = datetime(now.year, m + 1, 1)
        total_days = (last - first).days
        start_weekday = first.weekday()  # 0=Mon

        grid = []
        for _ in range(start_weekday):
            grid.append('<div class="day empty"></div>')
        for d in range(1, total_days + 1):
            date_key = f'{now.year}-{m:02d}-{d:02d}'
            emoji = emojis.get(date_key, '')
            has_note = date_key in journal_dates
            is_today = d == now.day and m == now.month
            classes = ['day']
            if has_note:
                classes.append('has-note')
            if is_today:
                classes.append('today')
            cls = ' '.join(classes)
            if has_note:
                s = slug(f'journal:{date_key}')
                cell = f'<a href="{s}.html">{emoji}{d}</a>'
            else:
                cell = f'{emoji}{d}'
            grid.append(f'<div class="{cls}">{cell}</div>')

        grid_html = '\n      '.join(grid)
        parts.append(f'''<div class="month">
  <h3>{MONTHS[m - 1]}</h3>
  <div class="cal-grid">
    {grid_html}
  </div>
</div>''')

    body = '\n'.join(parts)
    return page_shell('calendar', '', body, active='calendar')


def build_note(meta, content, all_notes):
    """Generate individual note HTML."""
    title = meta.get('title', 'untitled')
    created = meta.get('created', '')[:10]
    tags = meta.get('tags', [])
    if isinstance(tags, str):
        tags = [tags] if tags else []
    tags_html = ' '.join(
        f'<a href="{tag_href(t)}" class="tag">#{html.escape(t)}</a>'
        for t in tags
    )
    body_html = simple_md(content)

    # wiki links
    outgoing = re.findall(r'\[\[([^\]]+)\]\]', content)
    links_html = ''
    if outgoing:
        link_items = ' '.join(
            f'<a href="{slug(link)}.html" class="wiki-link">[[{html.escape(link)}]]</a>'
            for link in outgoing
        )
        links_html = f'<div class="links">links: {link_items}</div>'

    is_journal = title.startswith('journal:')
    display_title = title.replace('journal:', '') if is_journal else title

    body = f'''<h1>{html.escape(display_title)}</h1>
<div class="meta"><time>{created}</time> {tags_html}</div>
<article>{body_html}</article>
{links_html}'''

    return page_shell(display_title, '', body)


def tag_href(tag):
    """URL for a tag page, using folders for nested tags (tag-a/b.html)."""
    return 'tag-' + '/'.join(slug(seg) for seg in tag.split('/')) + '.html'


def _tag_match(meta, tag):
    """True if the note has this tag or a descendant (nested) tag."""
    tags = _meta_tags(meta)
    return tag in tags or any(t.startswith(tag + '/') for t in tags)


def render_tag_tree(root, notes, prefix=''):
    """Render a nested tag tree as a collapsible folder menu."""
    items = []
    for seg in sorted(root.keys()):
        child = root[seg]
        full = f'{prefix}{seg}'
        count = sum(1 for meta, _ in notes if _tag_match(meta, full))
        if child:
            inner = render_tag_tree(child, notes, prefix=full + '/')
            items.append(
                f'<details class="tag-folder" open><summary>'
                f'<a href="{tag_href(full)}" class="tag-folder-link">'
                f'#{html.escape(full)} <span class="tag-count">{count}</span></a>'
                f'</summary><div class="tag-children">{inner}</div></details>'
            )
        else:
            items.append(
                f'<div class="tag-leaf"><a href="{tag_href(full)}" class="tag">'
                f'#{html.escape(full)} <span class="tag-count">{count}</span></a></div>'
            )
    return '\n'.join(items)


def build_tags_index(tags, notes):
    """Generate tags.html as a nested folder menu."""
    root = {}
    for tag in tags:
        node = root
        for seg in tag.split('/'):
            node = node.setdefault(seg, {})
    body = render_tag_tree(root, notes) if root else '<p class="empty">no tags yet</p>'
    return page_shell('tags', '', body, active='tags')


def build_tag_page(tag, notes):
    """Generate tag-<slug>.html listing notes that have this tag (or a child)."""
    parts = []
    for meta, content in notes:
        if not _tag_match(meta, tag):
            continue
        title = meta.get('title', 'untitled')
        link = slug(title)
        created = meta.get('created', '')[:10]
        excerpt = content[:120].replace('\n', ' ').strip()
        parts.append(f'''<article class="note-card">
  <a href="{link}.html">
    <header>{html.escape(title)}</header>
    <p>{html.escape(excerpt)}</p>
    <footer><time>{created}</time></footer>
  </a>
</article>''')
    body = '\n'.join(parts) if parts else '<p class="empty">no notes with this tag</p>'
    return page_shell(f'#{tag}', '', body, active='tags')


def _meta_tags(meta):
    """Return the note's tags as a list (handles list or string forms)."""
    tags = meta.get('tags', [])
    if isinstance(tags, str):
        return [tags] if tags else []
    return list(tags)


def build_readme(notes, emojis):
    """Generate README.md."""
    regular = [(m, c) for m, c in notes if not m.get('title', '').startswith('journal:')]
    journal = [(m, c) for m, c in notes if m.get('title', '').startswith('journal:')]

    lines = [
        '# noteout',
        '',
        'take your thoughts out',
        '',
        '---',
        '',
        '## notes',
        '',
    ]

    if not regular:
        lines.append('_no notes yet_')
    else:
        for meta, content in regular:
            title = meta.get('title', 'untitled')
            s = slug(title)
            created = meta.get('created', '')[:10]
            tags = meta.get('tags', [])
            if isinstance(tags, str):
                tags = [tags] if tags else []
            tag_str = ' '.join(f'`#{t}`' for t in tags)
            if tag_str:
                tag_str = ' ' + tag_str
            lines.append(f'- [{title}]({s}.html) — {created}{tag_str}')

    if journal:
        lines.extend(['', '## journal', ''])
        for meta, content in journal:
            title = meta.get('title', '')
            date_str = title.replace('journal:', '')
            emoji = emojis.get(date_str, '')
            s = slug(title)
            lines.append(f'- [{emoji} {date_str}]({s}.html)')

    lines.extend([
        '',
        '---',
        '',
        '*generated by noteout — take your thoughts out*',
    ])
    return '\n'.join(lines)


def main():
    SITE_DIR.mkdir(exist_ok=True)
    (SITE_DIR / 'notes').mkdir(exist_ok=True)

    emojis = load_emojis()
    notes = []

    if NOTES_DIR.exists():
        for md_file in sorted(NOTES_DIR.glob('*.md')):
            raw = md_file.read_text(encoding='utf-8')
            meta, content = parse_frontmatter(raw)
            notes.append((meta, content))

            # copy markdown to _site/notes/ for reference
            (SITE_DIR / 'notes' / md_file.name).write_text(raw, encoding='utf-8')

    # sort by created date, newest first
    notes.sort(key=lambda x: x[0].get('created', ''), reverse=True)

    # generate pages
    (SITE_DIR / 'index.html').write_text(build_index(notes), encoding='utf-8')
    (SITE_DIR / 'tags.html').write_text(
        build_tags_index({t for meta, _ in notes for t in _meta_tags(meta)}, notes),
        encoding='utf-8',
    )
    (SITE_DIR / 'calendar.html').write_text(build_calendar(notes, emojis), encoding='utf-8')
    (SITE_DIR / 'README.md').write_text(build_readme(notes, emojis), encoding='utf-8')

    for meta, content in notes:
        title = meta.get('title', '')
        if not title:
            continue
        s = slug(title)
        html_content = build_note(meta, content, notes)
        (SITE_DIR / f'{s}.html').write_text(html_content, encoding='utf-8')

    # per-tag pages
    all_tags = {t for meta, _ in notes for t in _meta_tags(meta)}
    for tag in all_tags:
        page_path = SITE_DIR / tag_href(tag)
        page_path.parent.mkdir(parents=True, exist_ok=True)
        page_path.write_text(build_tag_page(tag, notes), encoding='utf-8')

    print(f' Built site: {len(notes)} notes -> {SITE_DIR}/')


if __name__ == '__main__':
    main()
