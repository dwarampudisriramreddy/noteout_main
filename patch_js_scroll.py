import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    js_to_add = """
document.addEventListener('DOMContentLoaded',function(){
  var hw=document.querySelector('.heatmap-wrap');
  if(hw) hw.scrollLeft=hw.scrollWidth;
});"""
    if "hw.scrollLeft=hw.scrollWidth" not in content:
        # Just append it at the end of the JS string.
        # Find where JS = """ ends
        content = re.sub(
            r"(JS = \"\"\"[\s\S]*?)(\"\"\")",
            rf"\1{js_to_add}\n\2",
            content
        )

    with open(path, 'w') as f:
        f.write(content)

process_file('scripts/build-site.py')
process_file('assets/site/build-site.py')
print("Patched JS.")
