import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    # Remove from github sync section
    content = content.replace(
        "                _buildSiteStatusTile(),\n",
        ""
    )
    
    # We also need to remove view site tile
    # Let's find it exactly
    old_view_site = """                _buildActionTile(
                  'view site',
                  _siteStatusSubtitle(),
                  _openLiveSite,
                  false,
                ),
"""
    content = content.replace(old_view_site, "")

    # Now add to site section
    old_site_section = """          _buildSection(
            'site',
            [
              _buildActionTile(
                'site settings',
                'site layout, colors & home page',
                _openSiteSettings,
                false,
              ),
            ],
          ),"""
          
    new_site_section = """          _buildSection(
            'site',
            [
              if (_isConfigured) _buildSiteStatusTile(),
              if (_isConfigured)
                _buildActionTile(
                  'view site',
                  _siteStatusSubtitle(),
                  _openLiveSite,
                  false,
                ),
              _buildActionTile(
                'site settings',
                'site layout, colors & home page',
                _openSiteSettings,
                false,
              ),
            ],
          ),"""
          
    content = content.replace(old_site_section, new_site_section)

    with open(path, 'w') as f:
        f.write(content)

process_file('lib/screens/settings_screen.dart')
print("Patched.")
