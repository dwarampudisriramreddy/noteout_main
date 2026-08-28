import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Remove {brand} from sidebar
    content = content.replace("      {brand}\n", "")

    # Remove _hero_html from _build_index_personal
    content = content.replace("        _hero_html(cfg),\n", "")

    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
print("Patched profile.")
