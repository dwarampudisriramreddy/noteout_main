import 'package:uuid/uuid.dart';

class Note {
  final String id;
  String title;
  String content;
  final DateTime createdAt;
  DateTime updatedAt;
  String? githubSha;
  DateTime? githubModifiedAt;
  bool isDeleted;

  Note({
    String? id,
    this.title = '',
    this.content = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.githubSha,
    this.githubModifiedAt,
    this.isDeleted = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  List<String> get tags {
    final tagPattern =
        RegExp(r'(?:^|\s)#([a-zA-Z0-9_]+(?:/[a-zA-Z0-9_]+)*)');
    return tagPattern
        .allMatches(content)
        .map((m) => m.group(1)!)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> get outgoingLinks {
    final linkPattern = RegExp(r'\[\[([^\]]+)\]\]');
    return linkPattern
        .allMatches(content)
        .map((m) => m.group(1)!)
        .toSet()
        .toList()
      ..sort();
  }

  String get plainText {
    return content
        .replaceAll(RegExp(r'\[\[([^\]]+)\]\]'), r'$1')
        .replaceAll(RegExp(r'#{1,6}\s'), '')
        .replaceAll(RegExp(r'\*{1,2}([^*]+)\*{1,2}'), r'$1')
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
        .replaceAll(RegExp(r'\$\$[^$]+\$\$'), '[math]')
        .replaceAll(RegExp(r'\$[^$]+\$'), '[math]')
        .replaceAll(RegExp(r'#{1,6}\s'), '')
        .replaceAll(RegExp(r'[-*+]\s'), '')
        .replaceAll(RegExp(r'\n{2,}'), ' ')
        .trim();
  }

  String get excerpt {
    final text = plainText;
    if (text.length <= 120) return text;
    return '${text.substring(0, 120)}...';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'github_sha': githubSha,
      'github_modified_at': githubModifiedAt?.millisecondsSinceEpoch,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      githubSha: map['github_sha'] as String?,
      githubModifiedAt: map['github_modified_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['github_modified_at'] as int)
          : null,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
    );
  }

  Note copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    String? githubSha,
    DateTime? githubModifiedAt,
    bool? isDeleted,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      githubSha: githubSha ?? this.githubSha,
      githubModifiedAt: githubModifiedAt ?? this.githubModifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
