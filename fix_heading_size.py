import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    old_math = """      final fontSize = baseStyle.fontSize ?? 14.0;
      final headingSize = fontSize + (6 - level) * 1.5;"""
      
    new_math = """      double headingSize = 14.0;
      if (level == 1) headingSize = 22.0;
      else if (level == 2) headingSize = 19.0;
      else if (level == 3) headingSize = 17.0;
      else if (level == 4) headingSize = 15.0;
      else headingSize = 14.0;"""

    content = content.replace(old_math, new_math)

    with open(path, 'w') as f:
        f.write(content)

process_file('lib/widgets/markdown_controller.dart')
print("Patched heading sizes.")
