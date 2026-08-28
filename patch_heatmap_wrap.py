import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    content = content.replace('.heatmap-wrap{overflow-x:auto;padding:10px 0 20px;scrollbar-width:none}', '.heatmap-wrap{padding:10px 0 20px}')
    content = content.replace('.heatmap-wrap::-webkit-scrollbar{display:none}\n', '')
    content = content.replace('.heatmap{display:grid;grid-template-rows:repeat(7,13px);grid-auto-flow:column;grid-auto-columns:13px;gap:4px}', '.heatmap{display:flex;flex-wrap:wrap;gap:4px}')

    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
print("Patched.")
