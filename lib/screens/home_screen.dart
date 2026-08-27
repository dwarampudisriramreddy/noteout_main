import 'package:flutter/material.dart';
import 'note_list_screen.dart';
import 'journal_screen.dart';
import 'gallery_screen.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _screens = const [
    NoteListScreen(),
    JournalScreen(),
    GalleryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: context.nSurface,
        selectedItemColor: context.nText,
        unselectedItemColor: context.nMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.notes_outlined, size: 20),
            activeIcon: Icon(Icons.notes, size: 20),
            label: 'notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined, size: 20),
            activeIcon: Icon(Icons.calendar_today, size: 20),
            label: 'journal',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library_outlined, size: 20),
            activeIcon: Icon(Icons.photo_library, size: 20),
            label: 'gallery',
          ),
        ],
      ),
    );
  }
}
