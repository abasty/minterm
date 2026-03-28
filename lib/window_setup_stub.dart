import 'package:flutter/foundation.dart';

const bool isWindowControlsSupported = false;

final ValueNotifier<bool> fullscreenListenable = ValueNotifier<bool>(false);

Future<void> initializeWindow() async {}

Future<void> toggleFullscreen() async {}
