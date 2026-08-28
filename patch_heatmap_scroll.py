import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # 1. Update CSS
    content = content.replace(
        '.heatmap-wrap{padding:10px 0 20px}',
        '.heatmap-wrap{overflow-x:auto;padding:10px 0 20px;scrollbar-width:none}\n.heatmap-wrap::-webkit-scrollbar{display:none}'
    )
    content = content.replace(
        '.heatmap{display:flex;flex-wrap:wrap;gap:4px}',
        '.hm-months{display:flex;font-size:11px;color:var(--muted);margin-bottom:6px;font-weight:500}\n.hm-month{flex-shrink:0}\n.heatmap{display:grid;grid-template-rows:repeat(7,20px);grid-auto-flow:column;grid-auto-columns:20px;gap:4px}'
    )

    # 2. Update Python logic in _journal_section
    new_logic = """def _journal_section(notes, emojis):
    now = datetime.now()
    start = now - __import__('datetime').timedelta(days=364)
    start -= __import__('datetime').timedelta(days=(start.weekday() + 1) % 7)

    journal_dates = {}
    for meta, _c in notes:
        title = meta.get('title', '')
        if title.startswith('journal:'):
            d = title.replace('journal:', '')
            journal_dates[d] = meta

    cells = []
    months = []
    last_month = None
    curr = start
    
    while curr <= now:
        if curr.weekday() == 6 or last_month is None:
            if curr.month != last_month:
                months.append([curr.strftime('%b'), 1])
                last_month = curr.month
            else:
                if months:
                    months[-1][1] += 1

        date_key = f'{curr.year}-{curr.month:02d}-{curr.day:02d}'
        emoji = emojis.get(date_key, '')
        has_note = date_key in journal_dates
        cls = 'hm-day active' if has_note else 'hm-day'
        
        title_attr = f'{emoji} {date_key}'.strip() if has_note else date_key
        
        if has_note:
            s = slug(f'journal:{date_key}')
            cells.append(f'<a href="{s}.html" class="{cls}" data-title="{title_attr}">{emoji}</a>')
        else:
            cells.append(f'<div class="{cls}" data-title="{title_attr}">{emoji}</div>')
            
        curr += __import__('datetime').timedelta(days=1)

    month_html = '<div class="hm-months">'
    for m, span in months:
        width = span * 24
        month_html += f'<div style="width:{width}px" class="hm-month">{m}</div>'
    month_html += '</div>'

    grid = '<div class="heatmap">' + ''.join(cells) + '</div>'
    
    return f'''
<div class="section"><span class="fldr">{ICONS['calendar']}</span><span>activity</span></div>
<div class="heatmap-wrap">{month_html}{grid}</div>'''
"""
    # Replace the old _journal_section
    content = re.sub(
        r"def _journal_section\(notes, emojis\):.*?(?=\n\n\ndef )",
        new_logic.strip(),
        content,
        flags=re.DOTALL
    )

    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
print("Patched heatmap scroll and months.")
