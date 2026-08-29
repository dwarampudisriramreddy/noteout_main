import 'package:flutter/material.dart';

void main() {
  final text = '# Heading\nNext line';
  final lines = text.split('\n');
  print('Lines: $lines');
  
  final headingMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(lines[0]);
  print('Matches heading? ${headingMatch != null}');
  if (headingMatch != null) {
    print('Rest: ${headingMatch.group(2)}');
  }

  final nextMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(lines[1]);
  print('Next matches heading? ${nextMatch != null}');
}
