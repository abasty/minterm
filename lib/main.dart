import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'min_widget.dart';

void main() async {
  if (kIsWeb) {
    // Code to execute only on web targets
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(4 * 8 * 40 + 64, 4 * 10 * 25 + 64),
      center: true,
      title: 'Terminal Minitel',
      // backgroundColor: Colors.transparent,
      // skipTaskbar: false,
      // titleBarStyle: TitleBarStyle.hidden,
      // windowButtonVisibility: false,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      ),
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                var scale = MinSettings().scale + 0.5;
                if (scale > 4) scale = 0.5;
                MinSettings.setScale(scale);
              },
              child: Text('Scale'),
            ),
            // Add a button widget
            MinWidget(),
          ],
        ),
      ),
    );
  }
}
