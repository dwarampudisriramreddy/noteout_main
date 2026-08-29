import 'package:emojis/emojis.dart';
import 'package:emojis/emoji.dart';

void main() {
  var emojiGroup = Emoji.byGroup(EmojiGroup.smileysEmotion);
  print('Smileys: ${emojiGroup.take(5).map((e) => e.char).join(',')}');
  var match = Emoji.byKeyword('smile');
  print('Smile: ${match.take(5).map((e) => e.char).join(',')}');
}
