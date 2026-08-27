import 'dart:convert';
import 'package:hive_ce/hive.dart';
import '../models/note.dart';

class StorageService {
  static late Box<String> _notesBox;

  static Future<void> init() async {
    _notesBox = await Hive.openBox<String>('notes');
  }

  static List<Note> _notesFromBox() {
    return _notesBox.toMap().entries.map((entry) {
      final map = jsonDecode(entry.value) as Map<String, dynamic>;
      return Note.fromMap(map);
    }).toList();
  }

  static Future<List<Note>> getAllNotes() async {
    final notes = _notesFromBox()
        .where((n) => !n.isDeleted)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  static Future<Note?> getNote(String id) async {
    final json = _notesBox.get(id);
    if (json == null || json.isEmpty) return null;
    final note = Note.fromMap(jsonDecode(json) as Map<String, dynamic>);
    if (note.isDeleted) return null;
    return note;
  }

  static Future<Note?> getNoteByTitle(String title) async {
    final notes = await getAllNotes();
    for (final note in notes) {
      if (note.title.toLowerCase() == title.toLowerCase()) return note;
    }
    return null;
  }

  static Future<void> saveNote(Note note) async {
    final json = jsonEncode(note.toMap());
    await _notesBox.put(note.id, json);
  }

  static Future<void> deleteNote(String id) async {
    final json = _notesBox.get(id);
    if (json == null || json.isEmpty) return;
    final note = Note.fromMap(jsonDecode(json) as Map<String, dynamic>);
    final updated = note.copyWith(
      isDeleted: true,
      updatedAt: DateTime.now().toUtc(),
    );
    await _notesBox.put(id, jsonEncode(updated.toMap()));
  }

  static Future<void> permanentDeleteNote(String id) async {
    await _notesBox.delete(id);
  }

  static Future<List<Note>> getDeletedNotes() async {
    return _notesFromBox()
        .where((n) => n.isDeleted)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static Future<void> restoreNote(String id) async {
    final json = _notesBox.get(id);
    if (json == null || json.isEmpty) return;
    final note = Note.fromMap(jsonDecode(json) as Map<String, dynamic>);
    final updated = note.copyWith(
      isDeleted: false,
      updatedAt: DateTime.now().toUtc(),
    );
    await _notesBox.put(id, jsonEncode(updated.toMap()));
  }

  static Future<List<Note>> searchNotes(String query) async {
    final notes = await getAllNotes();
    final q = query.toLowerCase();
    return notes.where((n) {
      return n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q);
    }).toList();
  }

  static Future<List<String>> getAllTags() async {
    final notes = await getAllNotes();
    final tags = <String>{};
    for (final note in notes) {
      tags.addAll(note.tags);
    }
    return tags.toList()..sort();
  }

  static Future<void> importFromJson(String id, String json) async {
    await _notesBox.put(id, json);
  }

  static String? getRawJson(String id) {
    return _notesBox.get(id);
  }

  static Map<String, String> get allEntries =>
      Map<String, String>.from(_notesBox.toMap());
}
