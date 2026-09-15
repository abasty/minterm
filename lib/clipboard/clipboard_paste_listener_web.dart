// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

/// Écoute l'évènement natif `paste` du navigateur.
///
/// Sur Safari/WebKit (macOS/iOS), l'API asynchrone `Clipboard.getData()` de
/// Flutter (`navigator.clipboard.readText()`) échoue silencieusement quand
/// elle est appelée depuis un raccourci clavier (Cmd+V) : WebKit exige que
/// la lecture du presse-papier se fasse strictement pendant le traitement
/// synchrone d'un geste utilisateur, ce que la chaîne d'appels
/// Dart → JS interop → Promise ne respecte plus. L'évènement `paste` natif,
/// lui, transporte directement les données dans `clipboardData` sans passer
/// par cette API à permission : il fonctionne de façon fiable partout,
/// Safari compris.
///
/// Pour que cet évènement natif puisse se déclencher, main.dart ne doit pas
/// intercepter/`preventDefault` Cmd+V / Ctrl+V au niveau clavier Flutter en
/// mode web.
///
/// [shouldHandle] est consulté à chaque `paste` : s'il renvoie `false` (par
/// exemple parce qu'un champ de texte Flutter a le focus, tel le champ
/// d'adresse serveur), le collage natif du navigateur suit son cours sans
/// interférence ; [onPaste] n'est alors pas appelé.
void registerPasteListener(
  bool Function() shouldHandle,
  void Function(String text) onPaste,
) {
  html.document.onPaste.listen((event) {
    if (!shouldHandle()) return;
    final text = event.clipboardData?.getData('text/plain');
    event.preventDefault();
    if (text != null && text.isNotEmpty) {
      onPaste(text);
    }
  });
}
