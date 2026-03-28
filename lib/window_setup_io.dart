import 'dart:io';

import 'package:window_manager/window_manager.dart';

Future<void> initializeWindow() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return;
  }

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    fullScreen: true,
    title: 'Terminal Minitel',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
