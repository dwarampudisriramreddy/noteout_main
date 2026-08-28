files = ['assets/site/build-site.py', 'scripts/build-site.py']
for f in files:
    with open(f, 'r') as file:
        content = file.read()
    
    content = content.replace('}}}', '}}').replace('{{{', '{{')
    
    with open(f, 'w') as file:
        file.write(content)

print("Braces fixed!")
