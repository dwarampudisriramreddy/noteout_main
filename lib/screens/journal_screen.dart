import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/emoji_picker.dart';
import 'editor_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;
  Note? _selectedNote;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _selectedDate = DateTime.now();
    _loadDayNote();
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _journalTitle(DateTime date) =>
      'journal:${_dateKey(date)}';

  Future<void> _loadDayNote() async {
    if (_selectedDate == null) return;
    setState(() => _isLoading = true);
    final title = _journalTitle(_selectedDate!);
    final note = await StorageService.getNoteByTitle(title);
    if (mounted) {
      setState(() {
        _selectedNote = note;
        _isLoading = false;
      });
    }
  }

  Future<void> _openDayNote() async {
    if (_selectedDate == null) return;
    final title = _journalTitle(_selectedDate!);
    var note = await StorageService.getNoteByTitle(title);

    if (note == null) {
      final newNote = Note(title: title, content: '');
      await StorageService.saveNote(newNote);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EditorScreen(noteId: newNote.id)),
      );
    } else {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EditorScreen(noteId: note.id)),
      );
    }
    await _loadDayNote();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'journal',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: context.nText,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.today, size: 20),
            onPressed: () {
              setState(() {
                _currentMonth =
                    DateTime(DateTime.now().year, DateTime.now().month);
                _selectedDate = DateTime.now();
              });
              _loadDayNote();
            },
          ),
          _buildThemeToggle(),
        ],
      ),
      body: Column(
        children: [
          _buildMonthHeader(),
          _buildWeekdayLabels(),
          _buildCalendarGrid(),
          const SizedBox(height: 8),
          Expanded(child: _buildDayPanel()),
        ],
      ),
    );
  }

  Widget _buildThemeToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 20),
      tooltip: isDark ? 'light mode' : 'dark mode',
      onPressed: () {
        SettingsService.themeMode =
            isDark ? ThemeMode.light : ThemeMode.dark;
      },
    );
  }

  Widget _buildMonthHeader() {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 22),
            onPressed: () {
              setState(() {
                _currentMonth =
                    DateTime(_currentMonth.year, _currentMonth.month - 1);
              });
            },
          ),
          Text(
            '${months[_currentMonth.month - 1]} ${_currentMonth.year}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 22),
            onPressed: () {
              setState(() {
                _currentMonth =
                    DateTime(_currentMonth.year, _currentMonth.month + 1);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayLabels() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: days
            .map((d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.nFaint,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday;
    final totalDays = lastDay.day;
    final today = DateTime.now();

    final cells = <Widget>[];

    for (int i = 1; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }

    for (int day = 1; day <= totalDays; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final dateKey = _dateKey(date);
      final emoji = SettingsService.getEmoji(dateKey);
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final isSelected = _selectedDate != null &&
          date.year == _selectedDate!.year &&
          date.month == _selectedDate!.month &&
          date.day == _selectedDate!.day;

      cells.add(
        GestureDetector(
          onTap: () {
            setState(() => _selectedDate = date);
            _loadDayNote();
          },
          onLongPress: () => _showEmojiPicker(dateKey, day),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : context.nPanel2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isToday
                        ? Colors.blue
                        : isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : context.nText,
                  ),
                ),
                const SizedBox(height: 2),
                if (isToday)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                    ),
                  ),
                if (emoji.isNotEmpty)
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 14),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.0,
        children: cells,
      ),
    );
  }

  Widget _buildDayPanel() {
    if (_selectedDate == null) {
    return Center(
      child: Text(
        'select a day',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: context.nFaint,
        ),
      ),
    );
    }

    final formattedDate = DateFormat('EEEE, MMM d').format(_selectedDate!);
    final noteExists = _selectedNote != null;

    return GestureDetector(
      onTap: _openDayNote,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.nPanel2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedDate,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.nText,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: context.nText,
                  ),
                ),
              )
            else if (noteExists)
              Expanded(
                child: Text(
                  _selectedNote!.excerpt.isEmpty
                      ? 'tap to write your note…'
                      : _selectedNote!.excerpt,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.7,
                    color: context.nMuted,
                  ),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              Text(
                'tap to write ${DateFormat('MMM d').format(_selectedDate!)}\'s note',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: context.nFaint,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker(String dateKey, int day) {
    final current = SettingsService.getEmoji(dateKey);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => EmojiPicker(
        selected: current,
        onSelected: (emoji) => SettingsService.setEmoji(dateKey, emoji),
        onRemoved: () => SettingsService.setEmoji(dateKey, ''),
      ),
    ).then((_) => setState(() {}));
  }
}
