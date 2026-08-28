import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Update CSS
    content = content.replace(
        '.hm-day{width:13px;height:13px;border-radius:3px;background:var(--surface-2);position:relative;text-decoration:none;display:block;transition:transform 0.1s}',
        '.hm-day{width:20px;height:20px;border-radius:4px;background:var(--surface-2);position:relative;text-decoration:none;display:flex;align-items:center;justify-content:center;transition:transform 0.1s;font-size:13px;line-height:1}'
    )

    # Update HTML generation
    content = content.replace(
        'cells.append(f\'<a href="{s}.html" class="{cls}" data-title="{title_attr}"></a>\')',
        'cells.append(f\'<a href="{s}.html" class="{cls}" data-title="{title_attr}">{emoji}</a>\')'
    )
    content = content.replace(
        'cells.append(f\'<div class="{cls}" data-title="{title_attr}"></div>\')',
        'cells.append(f\'<div class="{cls}" data-title="{title_attr}">{emoji}</div>\')'
    )

    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
print("Patched emoji display.")
