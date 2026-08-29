void main() {
  var bold = RegExp(r'\*\*(.*?)\*\*');
  print(bold.hasMatch('this is **bold** text'));
}
