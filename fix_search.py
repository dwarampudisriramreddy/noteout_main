files = ['assets/site/build-site.py', 'scripts/build-site.py']
for f in files:
    with open(f, 'r') as file:
        content = file.read()
    
    # We want search ONLY in build_index.
    # In build_calendar and others, we remove it.
    
    # Let's just remove the bad search block from EVERYWHERE and then put it only in build_index.
    bad_search_block = """
    search_html = '''
<div class="search-container">
  <input type="search" id="searchBox" placeholder="Search notes..." onkeyup="filterNotes()">
</div>
<script>
function filterNotes() {
  const query = document.getElementById('searchBox').value.toLowerCase();
  const cards = document.querySelectorAll('.note-card');
  cards.forEach(card => {
    const text = card.textContent.toLowerCase();
    card.style.display = text.includes(query) ? '' : 'none';
  });
}
</script>
'''
    if regular or journal:
        parts.insert(0, search_html)
"""
    
    content = content.replace(bad_search_block, "")
    
    # Now let's just manually insert it into build_index right before `body = '\n'.join(parts)`
    # build_index has:
    #     if journal:
    #         parts.append('<h2>journal</h2>')
    #         ...
    # 
    #     body = '\n'.join(parts)
    
    good_search = """
    if regular or journal:
        search_html = '''
<div class="search-container">
  <input type="search" id="searchBox" placeholder="Search notes..." onkeyup="filterNotes()">
</div>
<script>
function filterNotes() {
  const query = document.getElementById('searchBox').value.toLowerCase();
  const cards = document.querySelectorAll('.note-card');
  cards.forEach(card => {
    const text = card.textContent.toLowerCase();
    card.style.display = text.includes(query) ? '' : 'none';
  });
}
</script>
'''
        parts.insert(0, search_html)
    body = '\\n'.join(parts)"""

    content = content.replace("    body = '\\n'.join(parts)\n    return page_shell(site_title, '', body, active='notes')", good_search + "\n    return page_shell(site_title, '', body, active='notes')")

    with open(f, 'w') as file:
        file.write(content)

print("Search fixed!")
