import 'dart:js_interop';

import 'package:flutter/foundation.dart';

extension type _FullscreenElement._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> requestFullscreen();
}

extension type _KeyboardEvent._(JSObject _) implements JSObject {
  external String get key;
}

extension type _FullscreenDocument._(JSObject _) implements JSObject {
  external _FullscreenElement? get documentElement;
  external _FullscreenElement? get fullscreenElement;
  // Nullable : la propriété est absente là où l'API Fullscreen n'existe pas
  // (Safari iOS ne l'expose que pour les <video>).
  external bool? get fullscreenEnabled;
  external JSPromise<JSAny?> exitFullscreen();
  external void addEventListener(
    String type,
    JSFunction listener, [
    bool useCapture,
  ]);
}

@JS('document')
external _FullscreenDocument get _document;

/// Le clic sur l'icône produit une "user activation", seule façon fiable
/// d'obtenir requestFullscreen() en web (un raccourci clavier avec
/// modificateur n'en produit jamais, cf. MinSettings.cycleImmersiveMode).
/// document.fullscreenEnabled est faux là où l'API est indisponible (Safari
/// iOS) ou interdite (iframe sans allow="fullscreen") : inutile d'afficher
/// une icône qui ne pourrait rien faire.
bool get isFullscreenToggleSupported => _document.fullscreenEnabled ?? false;

final ValueNotifier<bool> fullscreenListenable = ValueNotifier<bool>(false);

/// Appelé quand Échap est pressée alors que le navigateur est en plein
/// écran natif : dans ce cas, le navigateur quitte le plein écran et
/// n'achemine pas toujours l'évènement clavier jusqu'à Flutter, donc on
/// l'intercepte au niveau DOM pour la transmettre quand même à l'émulateur.
void Function()? _onEscapeInFullscreen;

void setEscapeInFullscreenHandler(void Function() handler) {
  _onEscapeInFullscreen = handler;
}

void _syncFullscreenState() {
  fullscreenListenable.value = _document.fullscreenElement != null;
}

Future<void> initializeWindow() async {
  _document.addEventListener(
    'fullscreenchange',
    (() {
      _syncFullscreenState();
    }).toJS,
  );
  _document.addEventListener(
    'keydown',
    ((_KeyboardEvent event) {
      if (event.key == 'Escape' && _document.fullscreenElement != null) {
        _onEscapeInFullscreen?.call();
      }
    }).toJS,
    true,
  );
  _syncFullscreenState();
}

Future<void> toggleFullscreen() =>
    setFullscreen(_document.fullscreenElement == null);

Future<void> setFullscreen(bool enabled) async {
  if (enabled == (_document.fullscreenElement != null)) return;
  try {
    if (enabled) {
      await _document.documentElement?.requestFullscreen().toDart;
    } else {
      await _document.exitFullscreen().toDart;
    }
  } catch (_) {
    // Le navigateur peut refuser (ex: pas déclenché par un geste utilisateur,
    // ou plein écran désactivé par une politique) : on ignore silencieusement,
    // fullscreenListenable reste synchronisé via l'évènement fullscreenchange.
  }
}
