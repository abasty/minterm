import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

bool get isWindowControlsSupported =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// Pas de plein écran fenêtré sur mobile : l'app y est déjà plein écran.
bool get isFullscreenToggleSupported => isWindowControlsSupported;

final ValueNotifier<bool> fullscreenListenable = ValueNotifier<bool>(false);

Future<void> initializeWindow() async {
  if (!isWindowControlsSupported) {
    return;
  }

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    fullScreen: false,
    title: 'Terminal Minitel',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    fullscreenListenable.value = await windowManager.isFullScreen();
  });
}

Future<void> toggleFullscreen() async {
  if (!isWindowControlsSupported) {
    return;
  }

  await setFullscreen(!await windowManager.isFullScreen());
}

Future<void> setFullscreen(bool enabled) async {
  if (!isWindowControlsSupported) {
    return;
  }

  await windowManager.setFullScreen(enabled);
  fullscreenListenable.value = enabled;
}

void setEscapeInFullscreenHandler(void Function() handler) {
  // Sans objet hors web : Échap ne quitte pas le plein écran nativement,
  // le clavier Flutter reçoit toujours l'évènement normalement.
}
