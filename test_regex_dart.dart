void main() {
  final text = '# Heading\nContent';
  final lines = text.split('\n');
  print(lines);
  
  final match1 = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(lines[0]);
  print('Line 0 match: \${match1?.group(2)}');
  
  final match2 = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(lines[1]);
  print('Line 1 match: \${match2?.group(2)}');
}
