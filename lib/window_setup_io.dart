import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

bool get isWindowControlsSupported =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

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

  final nextState = !await windowManager.isFullScreen();
  await windowManager.setFullScreen(nextState);
  fullscreenListenable.value = nextState;
}

void setEscapeInFullscreenHandler(void Function() handler) {
  // Sans objet hors web : Échap ne quitte pas le plein écran nativement,
  // le clavier Flutter reçoit toujours l'évènement normalement.
}
