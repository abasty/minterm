import 'package:flutter/foundation.dart';

import 'window_setup_web.dart' if (dart.library.io) 'window_setup_io.dart'
    as impl;

bool get isFullscreenToggleSupported => impl.isFullscreenToggleSupported;

ValueListenable<bool> get fullscreenListenable => impl.fullscreenListenable;

Future<void> initializeWindow() => impl.initializeWindow();

Future<void> toggleFullscreen() => impl.toggleFullscreen();

/// Entre ou sort du plein écran, sans dépendre de l'état courant : le cycle
/// "mode zen" a besoin d'une direction explicite, car en web l'entrée peut
/// être refusée par le navigateur et une bascule relative partirait alors
/// dans le mauvais sens à la sortie.
Future<void> setFullscreen(bool enabled) => impl.setFullscreen(enabled);

void setEscapeInFullscreenHandler(void Function() handler) =>
    impl.setEscapeInFullscreenHandler(handler);
