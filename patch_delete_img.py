import re

def process_file(path):
    with open(path, 'r') as f:
        content = f.read()

    delete_func = """
  // Deletes an image from the github repo if it exists.
  static Future<bool> deleteImage(String url) async {
    if (!isConfigured) return false;
    final token = GitHubAuthService.token;
    final repo = '${GitHubAuthService.username}/${SettingsService.githubRepo}';

    final idx = url.indexOf('/images/');
    if (idx == -1) return false; // not an image managed by us

    final filePath = url.substring(idx + 1); // e.g. "images/abc.jpg"
    final pathWithoutQuery = filePath.split('?').first;

    try {
      final getRes = await http.get(
        Uri.parse('$_apiBase/repos/$repo/contents/$pathWithoutQuery'),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      if (getRes.statusCode != 200) return false;
      final data = jsonDecode(getRes.body) as Map<String, dynamic>;
      final sha = data['sha'] as String?;
      if (sha == null) return false;

      final delRes = await http.delete(
        Uri.parse('$_apiBase/repos/$repo/contents/$pathWithoutQuery'),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': 'delete image',
          'sha': sha,
        }),
      );
      return delRes.statusCode == 200 || delRes.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
"""
    # Insert it before getRepoSizeKb
    content = content.replace("  // Returns the repository's git size", delete_func.strip('\n') + "\n\n  // Returns the repository's git size")

    with open(path, 'w') as f:
        f.write(content)

process_file('lib/services/github_sync_service.dart')
print("Patched service.")
