import 'package:flutter/foundation.dart';

import 'window_setup_web.dart' if (dart.library.io) 'window_setup_io.dart'
    as impl;

bool get isWindowControlsSupported => impl.isWindowControlsSupported;

ValueListenable<bool> get fullscreenListenable => impl.fullscreenListenable;

Future<void> initializeWindow() => impl.initializeWindow();

Future<void> toggleFullscreen() => impl.toggleFullscreen();

void setEscapeInFullscreenHandler(void Function() handler) =>
    impl.setEscapeInFullscreenHandler(handler);
