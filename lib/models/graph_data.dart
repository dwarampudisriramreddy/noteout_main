class GraphNode {
  final String id;
  final String label;
  final int type;

  GraphNode({required this.id, required this.label, this.type = 0});
}

class GraphEdge {
  final String from;
  final String to;

  GraphEdge({required this.from, required this.to});
}

class NoteLink {
  final String sourceId;
  final String targetTitle;
  final int offset;

  NoteLink({
    required this.sourceId,
    required this.targetTitle,
    required this.offset,
  });
}

class NoteTag {
  final String tag;
  final int offset;

  NoteTag({required this.tag, required this.offset});
}

class NoteParser {
  static final _linkPattern = RegExp(r'\[\[([^\]]+)\]\]');
  static final _tagPattern = RegExp(r'(?:^|\s)#([a-zA-Z0-9_]+)');

  static List<NoteLink> parseLinks(String content, String sourceId) {
    return _linkPattern
        .allMatches(content)
        .map((m) => NoteLink(
              sourceId: sourceId,
              targetTitle: m.group(1)!,
              offset: m.start,
            ))
        .toList();
  }

  static List<NoteTag> parseTags(String content) {
    return _tagPattern
        .allMatches(content)
        .map((m) => NoteTag(
              tag: m.group(1)!,
              offset: m.start,
            ))
        .toList();
  }

  static List<String> parseAllTags(String content) {
    return parseTags(content).map((t) => t.tag).toSet().toList()..sort();
  }

  static Map<String, List<String>> buildLinkGraph(
      Map<String, String> noteIdToTitle, Map<String, String> noteIdToContent) {
    final graph = <String, List<String>>{};

    for (final entry in noteIdToContent.entries) {
      final id = entry.key;
      final content = entry.value;
      final links = parseLinks(content, id);

      graph.putIfAbsent(id, () => []);
      for (final link in links) {
        final targetId = noteIdToTitle.entries
            .where((e) => e.value.toLowerCase() == link.targetTitle.toLowerCase())
            .map((e) => e.key)
            .firstOrNull;
        if (targetId != null) {
          graph[id]!.add(targetId);
          graph.putIfAbsent(targetId, () => []);
        }
      }
    }

    return graph;
  }
}
