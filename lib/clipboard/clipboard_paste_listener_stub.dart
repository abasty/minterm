// Hors web (desktop/mobile) : rien à faire, le collage passe par
// Clipboard.getData() dans main.dart.
void registerPasteListener(
  bool Function() shouldHandle,
  void Function(String text) onPaste,
) {}
