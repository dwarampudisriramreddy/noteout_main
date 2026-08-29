import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Add -webkit-touch-callout: none to body style
    content = content.replace(
        "    body {\n      margin: 0;\n      min-height: 100%;\n      background-color: #FFFFFF;\n          background-size: 100% 100%;\n    }",
        "    body {\n      margin: 0;\n      min-height: 100%;\n      background-color: #FFFFFF;\n          background-size: 100% 100%;\n      -webkit-touch-callout: none;\n    }"
    )

    # Add script to prevent context menu
    if "contextmenu" not in content:
        content = content.replace(
            "</body></html>",
            """  <script>
    document.addEventListener('contextmenu', event => event.preventDefault());
  </script>\n</body></html>"""
        )

    with open(path, 'w') as f:
        f.write(content)

process_file('web/index.html')
print("Patched web index.html.")
