import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    content = content.replace(
        "<div>made with noteout</div>",
        "<div>made with noteout - get your thoughts out</div>"
    )

    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
print("Patched footer.")
