import 'clipboard_paste_listener_stub.dart'
    if (dart.library.html) 'clipboard_paste_listener_web.dart' as impl;

/// Écoute l'évènement natif `paste` du navigateur (no-op hors web). À
/// appeler une fois au démarrage. Voir clipboard_paste_listener_web.dart
/// pour le détail (contournement d'une limitation Safari/WebKit).
void registerPasteListener(
  bool Function() shouldHandle,
  void Function(String text) onPaste,
) {
  impl.registerPasteListener(shouldHandle, onPaste);
}
