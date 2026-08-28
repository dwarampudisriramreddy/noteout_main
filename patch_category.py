import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Update CSS
    content = content.replace(
        '.tblocks{display:grid;grid-template-columns:repeat(auto-fill,minmax(215px,1fr));gap:12px}',
        '.tblocks{display:flex;flex-wrap:wrap;gap:8px}'
    )
    content = content.replace(
        '.tblock{display:flex;flex-direction:column;gap:6px;background:var(--surface);border:1px solid var(--line);border-radius:var(--radius);padding:16px 18px;color:var(--text);transition:transform .15s ease,border-color .15s ease,box-shadow .15s ease;text-decoration:none;min-height:92px}',
        '.tblock{display:flex;flex-direction:row;align-items:center;gap:8px;background:var(--surface);border:1px solid var(--line);border-radius:24px;padding:6px 14px 6px 10px;color:var(--text);transition:transform .15s ease,border-color .15s ease,box-shadow .15s ease;text-decoration:none}'
    )
    content = content.replace(
        '.tblock:hover{transform:translateY(-2px);border-color:var(--primary);box-shadow:var(--shadow)}',
        '.tblock:hover{transform:translateY(-1px);border-color:var(--primary);box-shadow:var(--shadow-sm)}'
    )
    content = content.replace(
        '.tblock .tb-ico{color:var(--primary);display:flex;align-items:center}',
        '.tblock .tb-ico{color:var(--primary);display:flex;align-items:center;width:16px;height:16px}'
    )
    content = content.replace(
        '.tblock .tb-name{font-weight:700;font-size:.98em;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
        '.tblock .tb-name{font-weight:600;font-size:.85em;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}'
    )
    content = content.replace(
        '.tblock .tb-cnt{font-size:.78em;color:var(--muted)}',
        '.tblock .tb-cnt{font-size:.75em;color:var(--muted);background:var(--surface-2);padding:2px 6px;border-radius:12px;margin-left:2px}'
    )

    # Note: Ensure the SVGs inside tb-ico scale down if they don't already
    # Currently they might have a fixed 24x24 size, but setting width/height on tb-ico and adjusting svg CSS helps.
    
    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
print("Patched.")
