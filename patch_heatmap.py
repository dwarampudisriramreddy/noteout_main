import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # 1. Add CSS
    css_to_add = """
.heatmap-wrap{overflow-x:auto;padding:10px 0 20px;scrollbar-width:none}
.heatmap-wrap::-webkit-scrollbar{display:none}
.heatmap{display:grid;grid-template-rows:repeat(7,13px);grid-auto-flow:column;grid-auto-columns:13px;gap:4px}
.hm-day{width:13px;height:13px;border-radius:3px;background:var(--surface-2);position:relative;text-decoration:none;display:block;transition:transform 0.1s}
.hm-day.active{background:var(--primary)}
.hm-day:hover{transform:scale(1.2);z-index:2}
.hm-day::after{content:attr(data-title);position:absolute;bottom:100%;left:50%;transform:translate(-50%, -4px);background:var(--text);color:var(--surface);padding:4px 8px;border-radius:4px;font-size:11px;white-space:nowrap;opacity:0;pointer-events:none;transition:opacity 0.2s;z-index:10;font-weight:600}
.hm-day:hover::after{opacity:1}
"""
    if '.heatmap-wrap{' not in content:
        content = content.replace('.empty-search{display:none', css_to_add + '\n.empty-search{display:none')

    # 2. Add python function
    python_to_add = """
def _journal_section(notes, emojis):
    now = datetime.now()
    # Past 365 days
    start = now - __import__('datetime').timedelta(days=364)
    
    # Adjust start to Sunday
    start -= __import__('datetime').timedelta(days=(start.weekday() + 1) % 7)

    journal_dates = {}
    for meta, _c in notes:
        title = meta.get('title', '')
        if title.startswith('journal:'):
            d = title.replace('journal:', '')
            journal_dates[d] = meta

    cells = []
    curr = start
    while curr <= now:
        date_key = f'{curr.year}-{curr.month:02d}-{curr.day:02d}'
        emoji = emojis.get(date_key, '')
        has_note = date_key in journal_dates
        cls = 'hm-day active' if has_note else 'hm-day'
        
        title_attr = f'{emoji} {date_key}'.strip() if has_note else date_key
        
        if has_note:
            s = slug(f'journal:{date_key}')
            cells.append(f'<a href="{s}.html" class="{cls}" data-title="{title_attr}"></a>')
        else:
            cells.append(f'<div class="{cls}" data-title="{title_attr}"></div>')
            
        curr += __import__('datetime').timedelta(days=1)

    grid = '<div class="heatmap">' + ''.join(cells) + '</div>'
    
    return f'''
<div class="section"><span class="fldr">{ICONS['calendar']}</span><span>activity</span></div>
<div class="heatmap-wrap">{grid}</div>'''
"""
    if 'def _journal_section(' not in content:
        content = content.replace('def build_tag_blocks(notes):', python_to_add + '\ndef build_tag_blocks(notes):')

    # 3. Add to _build_index_personal
    if "_journal_section(notes, emojis)" not in content:
        content = re.sub(
            r"(body\.append\(\s*_stats_html\(.*?\)[\s\S]*?\n)",
            r"\1    if cfg.get('show_calendar', True):\n        body.append(_journal_section(notes, emojis))\n",
            content
        )

    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
print("Heatmap added.")
