import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/note.dart';
import 'github_auth_service.dart';
import 'settings_service.dart';
import 'storage_service.dart';

class GitHubSyncService {
  static const _apiBase = 'https://api.github.com';

  static bool get isConfigured => GitHubAuthService.isLoggedIn;

  static Future<Map<String, dynamic>> syncAll() async {
    if (!isConfigured) return {'count': 0, 'error': 'not configured'};

    final token = GitHubAuthService.token;
    final username = GitHubAuthService.username;
    final repoName = SettingsService.githubRepo;
    final repo = '$username/$repoName';
    String? siteError;

    try {
      await _ensureRepo(token, repo);
    } catch (e) {
      return {'count': 0, 'error': 'repo setup: $e'};
    }

    try {
      await _pushEmojis(token, repo);
    } catch (_) {}

    try {
      await _ensureSiteFiles(token, repo);
    } catch (e) {
      siteError = '$e';
    }

    final remoteFiles = await _listRemoteDir(token, repo, 'notes');
    final remoteBySha = <String, Map<String, dynamic>>{};
    final remoteByPath = <String, Map<String, dynamic>>{};
    for (final file in remoteFiles) {
      remoteBySha[file['sha'] as String] = file;
      remoteByPath[file['path'] as String] = file;
    }

    final localNotes = await StorageService.getAllNotes();
    final deletedNotes = await StorageService.getDeletedNotes();
    int synced = 0;

    for (final localNote in localNotes) {
      final remoteMatch = localNote.githubSha != null
          ? remoteBySha[localNote.githubSha]
          : null;

      // A note created on another device has a null githubSha even though a
      // file with the same path may already exist remotely (matched by slug).
      // Pass that file's sha so the contents API updates it instead of
      // failing with 422 "sha wasn't supplied".
      final path = _notePath(localNote);
      final sha = remoteMatch?['sha'] as String? ??
          remoteByPath[path]?['sha'] as String?;

      await _pushNote(token, repo, localNote, sha: sha);
      synced++;
      if (sha != null) remoteByPath.remove(path);
      if (remoteMatch != null) {
        remoteBySha.remove(localNote.githubSha);
      }
    }

    for (final entry in remoteBySha.entries) {
      final parsed = await _readNoteFile(token, repo, entry.value);
      if (parsed != null) {
        final existingLocal =
            await StorageService.getNote(parsed['id'] as String);
        if (existingLocal == null) {
          final note = Note(
            id: parsed['id'] as String,
            title: parsed['title'] as String? ?? '',
            content: parsed['content'] as String? ?? '',
            createdAt: parsed['created'] as DateTime?,
            githubSha: entry.key,
            githubModifiedAt: DateTime.now().toUtc(),
          );
          await StorageService.saveNote(note);
          synced++;
        }
      }
    }

    for (final deleted in deletedNotes) {
      if (deleted.githubSha != null) {
        final remoteFile = remoteBySha[deleted.githubSha];
        if (remoteFile != null) {
          await _deleteFile(token, repo, remoteFile);
          synced++;
        }
      }
    }

    SiteStatusMonitor.instance.refresh();
    return {'count': synced, 'error': siteError};
  }

  static Future<void> _ensureRepo(String token, String repo) async {
    final response = await http.get(
      Uri.parse('$_apiBase/repos/$repo'),
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
      },
    );
    if (response.statusCode == 200) return;
    if (response.statusCode == 404) {
      final createResponse = await http.post(
        Uri.parse('$_apiBase/user/repos'),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': repo.split('/').last,
          'private': false,
          'auto_init': true,
          'description': 'noteout — take your thoughts out',
        }),
      );
      if (createResponse.statusCode != 201) {
        final err = jsonDecode(createResponse.body) as Map<String, dynamic>;
        throw Exception(
            'create repo failed ${createResponse.statusCode}: ${err['message']}');
      }
      return;
    }
    throw Exception(
        'check repo failed ${response.statusCode}: github.com/$repo');
  }

  static Future<void> _ensureSiteFiles(String token, String repo) async {
    String workflow;
    String buildScript;
    try {
      workflow = await rootBundle.loadString('assets/site/deploy.yml');
      buildScript = await rootBundle.loadString('assets/site/build-site.py');
    } catch (_) {
      return;
    }

    await _pushFile(token, repo, 'scripts/build-site.py', buildScript,
        message: 'add site build script');
    await _pushFile(token, repo, '.github/workflows/deploy.yml', workflow,
        message: 'add github actions workflow');

    await _ensurePages(token, repo);
  }

  // Enables GitHub Pages with the "GitHub Actions" build source so the
  // deploy-pages step in the workflow can publish the site.
  static Future<void> _ensurePages(String token, String repo) async {
    final headers = {
      'Authorization': 'token $token',
      'Accept': 'application/vnd.github.v3+json',
      'Content-Type': 'application/json',
    };

    final checkRes = await http.get(
      Uri.parse('$_apiBase/repos/$repo/pages'),
      headers: headers,
    );
    if (checkRes.statusCode == 200) {
      final data = jsonDecode(checkRes.body) as Map<String, dynamic>;
      if ((data['build_type'] as String?) == 'workflow') return;
      final updateRes = await http.put(
        Uri.parse('$_apiBase/repos/$repo/pages'),
        headers: headers,
        body: jsonEncode({'build_type': 'workflow'}),
      );
      if (updateRes.statusCode != 200 && updateRes.statusCode != 204) {
        throw Exception(
            'update pages source ${updateRes.statusCode}: ${updateRes.body}');
      }
      return;
    }
    if (checkRes.statusCode == 404) {
      final createRes = await http.post(
        Uri.parse('$_apiBase/repos/$repo/pages'),
        headers: headers,
        body: jsonEncode({'build_type': 'workflow'}),
      );
      if (createRes.statusCode != 200 &&
          createRes.statusCode != 201 &&
          createRes.statusCode != 202) {
        throw Exception(
            'enable pages ${createRes.statusCode}: ${createRes.body}');
      }
      return;
    }
    throw Exception('check pages ${checkRes.statusCode}');
  }

  static String _sanitizeFilename(String title) {
    var name = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '')
        .trim();
    if (name.isEmpty) name = 'untitled';
    if (name.length > 80) name = name.substring(0, 80);
    return name;
  }

  static String _notePath(Note note) {
    return 'notes/${_sanitizeFilename(note.title)}.md';
  }

  static String _noteToMarkdown(Note note) {
    final frontmatter = jsonEncode({
      'id': note.id,
      'title': note.title,
      'tags': note.tags,
      'created': note.createdAt.toIso8601String(),
    });
    return '---\n$frontmatter\n---\n${note.content}';
  }

  static Map<String, dynamic> _parseNoteMarkdown(String raw) {
    if (raw.startsWith('---')) {
      final endIndex = raw.indexOf('---', 3);
      if (endIndex != -1) {
        final frontmatter = raw.substring(3, endIndex).trim();
        try {
          final metadata =
              jsonDecode(frontmatter) as Map<String, dynamic>;
          return {
            'id': metadata['id'] as String?,
            'title': metadata['title'] as String? ?? '',
            'content': raw.substring(endIndex + 3).trim(),
            'tags':
                (metadata['tags'] as List?)?.cast<String>() ?? const [],
            'created': metadata['created'] != null
                ? DateTime.tryParse(metadata['created'] as String)
                : null,
          };
        } catch (_) {}
      }
    }
    return {'title': '', 'content': raw};
  }

  static Future<void> _pushNote(String token, String repo, Note note,
      {String? sha}) async {
    final content = _noteToMarkdown(note);
    final encoded = base64.encode(utf8.encode(content));
    final path = _notePath(note);

    final title = note.title.isEmpty ? note.id : note.title;
    final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final body = <String, dynamic>{
      'message': 'update: ${safeTitle.isEmpty ? note.id : safeTitle}',
      'content': encoded,
    };
    if (sha != null) body['sha'] = sha;

    final response = await http.put(
      Uri.parse('$_apiBase/repos/$repo/contents/$path'),
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final commit = data['commit'] as Map<String, dynamic>?;
      final commitDate = commit?['committer']?['date'] as String?;
      final updated = note.copyWith(
        githubSha: data['content']?['sha'] as String? ?? sha,
        githubModifiedAt:
            commitDate != null ? DateTime.tryParse(commitDate) : null,
      );
      await StorageService.saveNote(updated);
    } else {
      final errBody =
          jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(
          'push failed ${response.statusCode}: ${errBody['message']}');
    }
  }

  static Future<List<Map<String, dynamic>>> _listRemoteDir(
      String token, String repo, String dir) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/repos/$repo/contents/$dir'),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      if (data is List) {
        return data
            .where((f) =>
                f['type'] == 'file' &&
                f['name'].toString().endsWith('.md'))
            .map<Map<String, dynamic>>((f) => {
                  'name': f['name'],
                  'sha': f['sha'],
                  'path': f['path'],
                })
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> _readNoteFile(
      String token, String repo, Map<String, dynamic> file) async {
    try {
      final path = file['path'] as String? ?? file['name'] as String;
      final response = await http.get(
        Uri.parse('$_apiBase/repos/$repo/contents/$path'),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final contentB64 = data['content'] as String? ?? '';
      final decoded = utf8.decode(base64.decode(contentB64));
      final parsed = _parseNoteMarkdown(decoded);

      if (parsed['id'] != null) {
        return {
          'id': parsed['id'],
          'title': parsed['title'],
          'content': parsed['content'],
          'created': parsed['created'],
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _deleteFile(
      String token, String repo, Map<String, dynamic> file) async {
    try {
      final path = file['path'] as String? ?? file['name'] as String;
      await http.delete(
        Uri.parse('$_apiBase/repos/$repo/contents/$path'),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': 'delete: ${file['name']}',
          'sha': file['sha'],
        }),
      );
    } catch (_) {}
  }

  static Future<void> _pushFile(
      String token, String repo, String path, String content,
      {String? message}) async {
    final contentsErr =
        await _pushFileContents(token, repo, path, content, message: message);
    if (contentsErr == null) return;

    try {
      await _pushFileViaTree(token, repo, path, content, message: message);
      return;
    } catch (treeError) {
      var hint = '';
      if (path.startsWith('.github/workflows/')) {
        hint = ' .github/workflows/ files need a CLASSIC token with both '
            '"repo" and "workflow" scopes selected';
      }
      throw Exception(
          '$contentsErr (git-data fallback also failed: $treeError).$hint');
    }
  }

  static Future<String?> _pushFileContents(String token, String repo,
      String path, String content,
      {String? message}) async {
    String? existingSha;
    try {
      final r = await http.get(
        Uri.parse('$_apiBase/repos/$repo/contents/$path'),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        existingSha = data['sha'] as String?;
      }
    } catch (_) {}

    final encoded = base64.encode(utf8.encode(content));
    final body = <String, dynamic>{
      'message': message ?? 'update: $path',
      'content': encoded,
    };
    if (existingSha != null) body['sha'] = existingSha;

    final response = await http.put(
      Uri.parse('$_apiBase/repos/$repo/contents/$path'),
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final errBody =
          jsonDecode(response.body) as Map<String, dynamic>;
      final msg = errBody['message'] as String? ?? 'unknown';
      return 'push $path failed ${response.statusCode}: $msg';
    }
    return null;
  }

  static Future<void> _pushFileViaTree(
      String token, String repo, String path, String content,
      {String? message}) async {
    // Get latest commit SHA
    final branchRes = await http.get(
      Uri.parse('$_apiBase/repos/$repo/git/ref/heads/main'),
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
      },
    );
    if (branchRes.statusCode != 200) {
      // try master
      final masterRes = await http.get(
        Uri.parse('$_apiBase/repos/$repo/git/ref/heads/master'),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      if (masterRes.statusCode != 200) {
        throw Exception('cannot find default branch');
      }
      final masterData = jsonDecode(masterRes.body) as Map<String, dynamic>;
      final commitSha =
          (masterData['object'] as Map<String, dynamic>)['sha'] as String;
      await _createTreeAndCommit(
          token, repo, commitSha, path, content, 'master', message: message);
      return;
    }
    final branchData = jsonDecode(branchRes.body) as Map<String, dynamic>;
    final commitSha =
        (branchData['object'] as Map<String, dynamic>)['sha'] as String;
    await _createTreeAndCommit(
        token, repo, commitSha, path, content, 'main', message: message);
  }

  static Future<void> _createTreeAndCommit(String token, String repo,
      String baseCommitSha, String path, String content, String branch,
      {String? message}) async {
    // Get base tree
    final commitRes = await http.get(
      Uri.parse('$_apiBase/repos/$repo/git/commits/$baseCommitSha'),
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
      },
    );
    if (commitRes.statusCode != 200) {
      throw Exception('get commit ${commitRes.statusCode}');
    }
    final commitData =
        jsonDecode(commitRes.body) as Map<String, dynamic>;
    final baseTree =
        (commitData['tree'] as Map<String, dynamic>)['sha'] as String;

    // Create blob
    final blobRes = await http.post(
      Uri.parse('$_apiBase/repos/$repo/git/blobs'),
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'content': content,
        'encoding': 'utf-8',
      }),
    );
    if (blobRes.statusCode != 201) {
      throw Exception('create blob ${blobRes.statusCode}: ${blobRes.body}');
    }
    final blobData = jsonDecode(blobRes.body) as Map<String, dynamic>;
    final blobSha = blobData['sha'] as String;

    // Create tree with new file
    final treeRes = await http.post(
      Uri.parse('$_apiBase/repos/$repo/git/trees'),
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'base_tree': baseTree,
        'tree': [
          {
            'path': path,
            'mode': '100644',
            'type': 'blob',
            'sha': blobSha,
          }
        ],
      }),
    );
    if (treeRes.statusCode != 201) {
      throw Exception('create tree ${treeRes.statusCode}: ${treeRes.body}');
    }
    final treeData = jsonDecode(treeRes.body) as Map<String, dynamic>;
    final newTreeSha = treeData['sha'] as String;

    // Create commit
    final createCommitRes = await http.post(
      Uri.parse('$_apiBase/repos/$repo/git/commits'),
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'message': message ?? 'update: $path',
        'tree': newTreeSha,
        'parents': [baseCommitSha],
      }),
    );
    if (createCommitRes.statusCode != 201) {
      throw Exception(
          'create commit ${createCommitRes.statusCode}: ${createCommitRes.body}');
    }
    final newCommitData =
        jsonDecode(createCommitRes.body) as Map<String, dynamic>;
    final newCommitSha = newCommitData['sha'] as String;

    // Update ref
    await http.patch(
      Uri.parse('$_apiBase/repos/$repo/git/refs/heads/$branch'),
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'sha': newCommitSha,
        'force': false,
      }),
    );
  }

  // Uploads a (compressed) image to the repo's images/ folder and returns a
  // publicly viewable URL suitable for embedding in markdown. Uses the
  // contents API so it works on the default branch without extra setup.
  static Future<String> uploadImage(
      Uint8List bytes, String fileName, String mime) async {
    if (!isConfigured) throw Exception('github not connected');
    final token = GitHubAuthService.token;
    final username = GitHubAuthService.username;
    final repoName = SettingsService.githubRepo;
    final repo = '$username/$repoName';

    final extension = (fileName.contains('.')
            ? fileName.split('.').last.toLowerCase()
            : (mime.contains('/')
                ? mime.split('/').last
                : 'jpg'))
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
    final base = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : 'image';
    final safeBase = base
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w-]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '')
        .trim();
    final name = '${safeBase.isEmpty ? 'image' : safeBase}-'
        '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final path = 'images/$name';

    String? existingSha;
    try {
      final r = await http.get(
        Uri.parse('$_apiBase/repos/$repo/contents/$path'),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      if (r.statusCode == 200) {
        existingSha =
            (jsonDecode(r.body) as Map<String, dynamic>)['sha'] as String?;
      }
    } catch (_) {}

    final body = <String, dynamic>{
      'message': 'add image $name',
      'content': base64.encode(bytes),
    };
    if (existingSha != null) body['sha'] = existingSha;

    final response = await http.put(
      Uri.parse('$_apiBase/repos/$repo/contents/$path'),
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final err =
          jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(
          'upload failed ${response.statusCode}: ${err['message']}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final downloadUrl =
        data['content']?['download_url'] as String?;
    if (downloadUrl != null && downloadUrl.isNotEmpty) return downloadUrl;
    return 'https://raw.githubusercontent.com/$repo/$path';
  }

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

  // Returns the repository's git size in KB via the GitHub API, or null if
  // it can't be fetched. This is the packed repo size, not raw file bytes.
  static Future<int?> getRepoSizeKb() async {
    if (!isConfigured) return null;
    final token = GitHubAuthService.token;
    final username = GitHubAuthService.username;
    final repoName = SettingsService.githubRepo;
    final repo = '$username/$repoName';
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/repos/$repo'),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['size'] as int?;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _pushEmojis(String token, String repo) async {
    final emojis = SettingsService.allEmojis;
    final content = jsonEncode(emojis);
    await _pushFile(token, repo, 'emojis.json', content, message: 'update: emojis');
  }
}

enum SiteBuildStatus { building, live, error, unknown }

// Global monitor that polls the deployment status in the background and
// exposes it via a ValueNotifier so any screen can show the indicator
// without needing to open settings.
class SiteStatusMonitor {
  SiteStatusMonitor._();

  static final SiteStatusMonitor instance = SiteStatusMonitor._();

  final ValueNotifier<SiteBuildStatus> status =
      ValueNotifier(SiteBuildStatus.unknown);
  Timer? _timer;
  bool _running = false;

  bool get isRunning => _running;

  void start() {
    if (_running) return;
    _running = true;
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  Future<void> refresh() async {
    status.value = await SiteStatusService.check();
  }
}

class SiteStatusService {
  static const _apiBase = 'https://api.github.com';

  // Checks GitHub Actions run status and the live site to report whether
  // the site is currently being published (building), live, or failed.
  static Future<SiteBuildStatus> check() async {
    if (!GitHubSyncService.isConfigured) return SiteBuildStatus.unknown;

    final token = GitHubAuthService.token;
    final username = GitHubAuthService.username;
    final repoName = SettingsService.githubRepo;
    final repo = '$username/$repoName';
    final headers = {
      'Authorization': 'token $token',
      'Accept': 'application/vnd.github.v3+json',
    };

    // Check the latest Actions workflow run.
    bool sawRun = false;
    String? runStatus;
    String? conclusion;
    try {
      final res = await http.get(
        Uri.parse('$_apiBase/repos/$repo/actions/runs?per_page=1'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final runs = data['workflow_runs'] as List? ?? [];
        if (runs.isNotEmpty) {
          sawRun = true;
          final run = runs.first as Map<String, dynamic>;
          runStatus = run['status'] as String?;
          conclusion = run['conclusion'] as String?;
        }
      }
    } catch (_) {}

    // The site is live only once the deploy finishes, so we also try to
    // fetch it directly. A running build still serves a 404/loading page.
    final siteUrl = 'https://$username.github.io/$repoName/';
    bool siteUp = false;
    try {
      final siteRes = await http
          .get(Uri.parse(siteUrl))
          .timeout(const Duration(seconds: 8));
      siteUp = siteRes.statusCode == 200;
    } catch (_) {}

    if (siteUp) return SiteBuildStatus.live;

    if (sawRun) {
      if (runStatus == 'in_progress' ||
          runStatus == 'queued' ||
          runStatus == 'pending') {
        return SiteBuildStatus.building;
      }
      if (runStatus == 'completed') {
        if (conclusion == 'success') {
          // Deploy succeeded but cert may still be provisioning.
          return SiteBuildStatus.building;
        }
        return SiteBuildStatus.error;
      }
    }

    return SiteBuildStatus.unknown;
  }
}
