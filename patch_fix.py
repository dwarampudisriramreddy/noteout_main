import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Re-insert build_tag_blocks
    build_tag_blocks_code = """
def build_tag_blocks(notes):
    \"\"\"Grid of tag blocks linking to each category's notes.\"\"\"
    tags = {}
    for meta, _ in notes:
        for t in _meta_tags(meta):
            if t in STRUCTURAL_TAGS:
                continue
            tags[t] = tags.get(t, 0) + 1
    if not tags:
        return '<p class="empty">no categories yet</p>'
    blocks = []
    regular_count = sum(1 for m, _ in notes if not m.get('title', '').startswith('journal:'))
    blocks.append(
        f'<a class="tblock" href="notes.html"><span class="tb-ico">{ICONS["notes"]}</span>'
        f'<span class="tb-name">All Notes</span>'
        f'<span class="tb-cnt">{regular_count} note{"s" if regular_count != 1 else ""}</span></a>'
    )
    for tag in sorted(tags.keys()):
        label = ' / '.join(__import__('html').escape(p) for p in tag.split('/'))
        n = tags[tag]
        blocks.append(
            f'<a class="tblock" href="{tag_href(tag)}"><span class="tb-ico">{ICONS["folder"]}</span>'
            f'<span class="tb-name">{label}</span>'
            f'<span class="tb-cnt">{n} note{"s" if n != 1 else ""}</span></a>'
        )
    return f'<div class="tblocks">{"".join(blocks)}</div>'
"""
    if "def build_tag_blocks(notes):" not in content:
        content = content.replace('def _build_index_personal(', build_tag_blocks_code + '\n\ndef _build_index_personal(')

    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
print("Fixed missing func.")
