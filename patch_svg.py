import re
def process_file(path):
    with open(path, 'r') as f:
        content = f.read()
    content = content.replace('.tblock .tb-ico{color:var(--primary);display:flex;align-items:center;width:16px;height:16px}', '.tblock .tb-ico{color:var(--primary);display:flex;align-items:center;width:16px;height:16px}\n.tblock .tb-ico svg{width:100%;height:100%}')
    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
