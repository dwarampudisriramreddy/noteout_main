import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Remove FAVICON definition
    content = re.sub(
        r"FAVICON = \([\s\S]*?\)\n\n",
        "",
        content
    )

    # Remove the link tag
    content = content.replace(
        '  <link rel="icon" href="{FAVICON}">\n',
        ''
    )

    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
print("Patched favicon.")
