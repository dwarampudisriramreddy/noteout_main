import 'package:emojis/emojis.dart';
import 'package:emojis/emoji.dart';

void main() {
  print('byKeyword smi: ${Emoji.byKeyword('smi').length}');
  print('byKeyword smile: ${Emoji.byKeyword('smile').length}');
  
  var allEmojis = Emoji.all();
  var filtered = allEmojis.where((e) => e.name.toLowerCase().contains('smi')).toList();
  print('manual contains smi: ${filtered.length}');
}
