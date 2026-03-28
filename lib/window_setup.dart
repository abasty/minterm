import 'window_setup_stub.dart' if (dart.library.io) 'window_setup_io.dart'
    as impl;

Future<void> initializeWindow() => impl.initializeWindow();
