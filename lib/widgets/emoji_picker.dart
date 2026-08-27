import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmojiPicker extends StatefulWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final VoidCallback? onRemoved;

  const EmojiPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.onRemoved,
  });

  @override
  State<EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<EmojiPicker> {
  final _searchController = TextEditingController();
  String _query = '';
  int _selectedCategory = 0;

  static const _categories = [
    _Category('faces', '😀', _faces),
    _Category('people', '👋', _people),
    _Category('nature', '🌿', _nature),
    _Category('food', '🍕', _food),
    _Category('activities', '⚽', _activities),
    _Category('objects', '💡', _objects),
    _Category('symbols', '❤️', _symbols),
    _Category('flags', '🏁', _flags),
  ];

  static const _faces = [
    '😀','😃','😄','😁','😆','😅','🤣','😂','🙂','😊',
    '😇','🥰','😍','🤩','😘','😗','😚','😙','🥲','😋',
    '😛','😜','🤪','😝','🤑','🤗','🤭','🫢','🫣','🤫',
    '🤔','🫡','🤐','🤨','😐','😑','😶','🫥','😏','😒',
    '🙄','😬','🤥','😌','😔','😪','🤤','😴','😷','🤒',
    '🤕','🤢','🤮','🥵','🥶','🥴','😵','🤯','🤠','🥳',
    '🥸','😎','🤓','🧐','😕','🫤','😟','🙁','😮','😯',
    '😲','😳','🥺','🥹','😦','😧','😨','😰','😥','😢',
    '😭','😱','😖','😣','😞','😓','😩','😫','🥱','😤',
    '😡','😠','🤬','😈','👿','💀','☠️','💩','🤡','👹',
    '👺','👻','👽','👾','🤖',
  ];

  static const _people = [
    '👋','🤚','🖐️','✋','🖖','🫱','🫲','🫳','🫴','👌',
    '🤌','🤏','✌️','🤞','🫰','🤟','🤘','🤙','👈','👉',
    '👆','🖕','👇','☝️','🫵','👍','👎','✊','👊','🤛',
    '🤜','👏','🙌','🫶','👐','🤲','🤝','🙏','💪','🦾',
    '🦿','🦵','🦶','👂','🦻','👃','🧠','🫀','🫁','🦷',
    '🦴','👀','👁️','👅','👄','🫦',
  ];

  static const _nature = [
    '🌿','🍀','🌱','🌲','🌳','🌴','🌵','🌾','🌺','🌻',
    '🌹','🌷','🌸','💐','🍄','🐶','🐱','🐭','🐹','🐰',
    '🦊','🐻','🐼','🐻‍❄️','🐨','🐯','🦁','🐮','🐷','🐽',
    '🐸','🐵','🙈','🙉','🙊','🐒','🐔','🐧','🐦','🐤',
    '🐣','🐥','🦆','🦅','🦉','🦇','🐺','🐗','🐴','🦄',
    '🐝','🪱','🐛','🦋','🐌','🐞','🐜','🪰','🪲','🪳',
    '🦟','🦗','🕷️','🦂','🐢','🐍','🦎','🦖','🦕','🐙',
    '🦑','🦐','🦞','🦀','🐡','🐠','🐟','🐬','🐳','🐋',
    '🦈','🐊','🐅','🐆','🦓','🦍','🦧','🐘','🦛','🦏',
    '🐪','🐫','🦒','🦘','🦬','🐃','🐂','🐄','🐎','🐖',
    '🐏','🐑','🦙','🐐','🦌','🐕','🐩','🦮','🐈',
    '☀️','🌙','⭐','🌟','✨','⚡','🔥','💧','🌊','❄️',
    '🌈','☁️','🌧️','⛈️','🌩️','🌪️',
  ];

  static const _food = [
    '🍕','🍔','🍟','🌭','🍿','🧂','🥓','🥚','🍳','🧇',
    '🥞','🧈','🍞','🥐','🥖','🥨','🧀','🥗','🥙','🧆',
    '🌮','🌯','🫔','🥪','🍝','🍜','🍲','🍛','🍣','🍱',
    '🥟','🦪','🍤','🍙','🍚','🍘','🍥','🥠','🥮','🍢',
    '🍡','🍧','🍨','🍦','🥧','🧁','🍰','🎂','🍮','🍬',
    '🍭','🍫','🍩','🍪','🌰','🥜','🍯','🥛','🍼','🫖',
    '☕','🍵','🧃','🥤','🍶','🍺','🍻','🥂','🍷','🥃',
    '🍸','🍹','🧉','🍾','🧊','🥄','🍴','🍽️','🥣','🥡',
    '🥢','🧄','🧅','🫚','🫛','🥦','🥬','🥒','🌶️','🫑',
    '🌽','🥕','🫒','🧄','🧅','🥔','🍠','🫘','🥐','🍞',
  ];

  static const _activities = [
    '⚽','🏀','🏈','⚾','🥎','🎾','🏐','🏉','🥏','🎱',
    '🪀','🏓','🏸','🏒','🥅','⛳','🪁','🏹','🎣','🤿',
    '🥊','🥋','🎽','🛹','🛼','🛷','⛸️','🥌','🎿','🪂',
    '🎮','🕹️','🎲','♟️','🧩','🎭','🎨','🧵','🧶','🎼',
    '🎵','🎶','🎹','🥁','🪘','🎷','🎺','🪗','🎸','🪕',
    '🎻','🎬','🎤','🎧','📻','🎙️','🎚️','🎛️','🧭','⏱️',
    '⏲️','⏰','🕰️','⌛','⏳','📡','🔋','🪫','🔌','💡',
    '🔦','🕯️','🪔','🧯','🛢️','💰','🪙','💴','💵','💶',
    '💷','💸','💳','🪪','💎','⚖️','🪜','🧰','🪛','🔧',
    '🔩','⚙️','🗜️','⛏️','⚒️','🛠️','🗡️','⚔️','🔫','🪃',
    '🏹','🛡️','🪚','🪤','🧱','⛓️','🪜','🧲','🔫',
  ];

  static const _objects = [
    '💡','🔦','🕯️','📱','💻','⌨️','🖥️','🖨️','🖱️','🖲️',
    '💾','💿','📀','📷','📸','📹','🎥','📽️','🎞️','📞',
    '☎️','📟','📠','📺','📻','🎙️','🎚️','🎛️','🧭','⏱️',
    '⏲️','⏰','🕰️','⌛','⏳','📡','🔋','🪫','🔌','💰',
    '🪙','💴','💵','💶','💷','💸','💳','🪪','💎','⚖️',
    '🧰','🪛','🔧','🔩','⚙️','🗜️','⛏️','⚒️','🛠️','🗡️',
    '⚔️','🔫','🪃','🏹','🛡️','🪚','🪤','🧱','⛓️','🧲',
    '🧪','🧫','🧬','🔬','🔭','📡','💉','🩸','💊','🩹',
    '🩺','🚽','🪠','🚿','🛁','🛀','🧼','🪥','🪒','🧽',
    '🪣','🧴','🔑','🗝️','🚪','🪑','🛋️','🛏️','🛌','🧸',
    '🪆','🖼️','🪞','🪟','🧱','🪜','🧹','🧺','🧻','🚰',
    '🚿','🛁','🛀','🧼','🪥','🪒','🧽','🪣','🧴','🛎️',
  ];

  static const _symbols = [
    '❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔',
    '❤️‍🔥','❤️‍🩹','❣️','💕','💞','💓','💗','💖','💘','💝',
    '💟','☮️','✝️','☪️','🕉️','☸️','✡️','🔯','🕎','☯️',
    '☦️','🛐','⛎','♈','♉','♊','♋','♌','♍','♎',
    '♏','♐','♑','♒','♓','🆔','⚛️','🉑','☢️','☣️',
    '📴','📳','🈶','🈚','🈸','🈺','🈷️','✴️','🆚','💮',
    '🉐','㊙️','㊗️','🈴','🈵','🈹','🈲','🅰️','🅱️','🆎',
    '🆑','🅾️','🆘','❌','⭕','🛑','⛔','📛','🚫','💯',
    '💢','♨️','🚷','🚯','🚳','🚱','🔞','📵','🚭','❗',
    '❕','❓','❔','‼️','⁉️','🔅','🔆','〽️','⚠️','🚸',
    '🔱','⚜️','🔰','♻️','✅','🈯','💹','❇️','✳️','❎',
    '🌐','💠','Ⓜ️','🌀','💤','🏧','🚾','♿','🅿️','🛗',
    '🈳','🈂️','🛂','🛃','🛄','🛅','🚹','🚺','🚼','⚧',
    '🚻','🚮','🎦','📶','🈁','🔣','ℹ️','🔤','🔡','🔠',
    '🆖','🆗','🆙','🆒','🆕','🆓','0️⃣','1️⃣','2️⃣','3️⃣',
    '4️⃣','5️⃣','6️⃣','7️⃣','8️⃣','9️⃣','🔟','🔢','#️⃣','*️⃣',
    '⏏️','▶️','⏸️','⏯️','⏹️','⏺️','⏭️','⏮️','⏩','⏪',
    '⏫','⏬','◀️','🔼','🔽','➡️','⬅️','⬆️','⬇️','↗️',
    '↘️','↙️','↖️','↕️','↔️','↪️','↩️','⤴️','⤵️','🔀',
    '🔁','🔂','🔄','🔃','🎵','🎶','➕','➖','➗','✖️',
    '🟰','♾️','💲','💱','™️','©️','®️','〰️','➰','➿',
    '🔚','🔙','🔛','🔝','🔜','✔️','☑️','🔘','🔴','🟠',
    '🟡','🟢','🔵','🟣','⚫','⚪','🟤','🔺','🔻','🔸',
    '🔹','🔶','🔷','🔳','🔲','▪️','▫️','◾','◽','◼️',
    '◻️','🟥','🟧','🟨','🟩','🟦','🟪','⬛','⬜','🟫',
    '🔈','🔇','🔉','🔊','🔔','🔕','📣','📢','💬','💭',
    '🗯️','♠️','♣️','♥️','♦️','🃏','🎴','🀄','🕐','🕑',
    '🕒','🕓','🕔','🕕','🕖','🕗','🕘','🕙','🕚','🕛',
  ];

  static const _flags = [
    '🏁','🚩','🎌','🏴','🏳️','🏳️‍🌈','🏳️‍⚧️','🏴‍☠️',
    '🇺🇸','🇬🇧','🇨🇦','🇦🇺','🇮🇳','🇩🇪','🇫🇷','🇯🇵',
    '🇰🇷','🇧🇷','🇲🇽','🇮🇹','🇪🇸','🇷🇺','🇨🇳','🇿🇦',
    '🇳🇬','🇰🇪','🇪🇬','🇹🇷','🇸🇦','🇦🇪','🇮🇱','🇵🇰',
    '🇧🇩','🇻🇳','🇹🇭','🇮🇩','🇲🇾','🇵🇭','🇸🇬','🇳🇿',
    '🇸🇪','🇳🇴','🇫🇮','🇩🇰','🇳🇱','🇧🇪','🇨🇭','🇦🇹',
    '🇵🇱','🇺🇦','🇨🇿','🇷🇴','🇭🇺','🇬🇷','🇵🇹','🇮🇪',
    '🇮🇸','🇱🇺','🇭🇷','🇧🇬','🇷🇸','🇵🇭','🇨🇴','🇦🇷',
    '🇨🇱','🇵🇪','🇪🇨','🇻🇪','🇺🇾','🇵🇾','🇧🇴','🇭🇳',
    '🇬🇹','🇨🇷','🇵🇦','🇨🇺','🇯🇲','🇹🇹','🇭🇹','🇩🇴',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _filteredEmojis() {
    if (_query.isNotEmpty) {
      final all = _categories.expand((c) => c.emojis).toList();
      return all;
    }
    return _categories[_selectedCategory].emojis;
  }

  @override
  Widget build(BuildContext context) {
    final emojis = _filteredEmojis();

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.nLine,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v.trim()),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: 'search emoji',
              hintStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: context.nFaint,
              ),
              prefixIcon: Icon(Icons.search, size: 18, color: context.nFaint),
              filled: true,
              fillColor: context.nPanel2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          if (_query.isEmpty)
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final selected = i == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = i),
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : context.nPanel2,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cat.icon,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          if (_query.isEmpty && widget.selected.isNotEmpty) ...[
            GestureDetector(
              onTap: () {
                widget.onRemoved?.call();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'remove emoji',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: emojis.length,
              itemBuilder: (context, i) {
                final emoji = emojis[i];
                final isSelected = emoji == widget.selected;
                return GestureDetector(
                  onTap: () {
                    widget.onSelected(emoji);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : context.nPanel2,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emoji,
                      style: TextStyle(
                        fontSize: 22,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Category {
  final String name;
  final String icon;
  final List<String> emojis;
  const _Category(this.name, this.icon, this.emojis);
}
