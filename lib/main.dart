import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart';

import 'min_model.dart';
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
      home: ChangeNotifierProvider<MinModel>(
        create: (context) => MinModel(),
        child: const Scaffold(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Clear(),
                Scale(),
                SetColors(),
                SendABC(),
                SendFile(),
              ]),
              MinWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

class SetColors extends StatelessWidget {
  const SetColors({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => MinSettings().toggleColors(),
      child: const Text('Colors'),
    );
  }
}

class SendABC extends StatelessWidget {
  const SendABC({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MinModel>(
      builder: (context, minmodel, child) => ElevatedButton(
        onPressed: () {
          minmodel
              .emulate([0x48, 0x1B, 0x5D, 0x4F, 0x1B, 0x5C, 0x48, 0x20, 10]);
        },
        child: const Text('Send HOH'),
      ),
    );
  }
}

class Clear extends StatelessWidget {
  const Clear({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MinModel>(
      builder: (context, minmodel, child) => ElevatedButton(
        onPressed: () {
          minmodel.emulate([0x0C]);
        },
        child: const Text('Clear'),
      ),
    );
  }
}

class Scale extends StatelessWidget {
  const Scale({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        var scale = MinSettings().scale + 0.5;
        if (scale > 4) scale = 0.5;
        MinSettings.setScale(scale);
      },
      child: const Text('Scale'),
    );
  }
}

class SendFile extends StatelessWidget {
  const SendFile({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MinModel>(
      builder: (context, minmodel, child) => ElevatedButton(
        onPressed: () async {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            initialDirectory: '/home/alain/Projects/minitel/new-zboub/pages/',
            type: FileType.custom,
            allowedExtensions: ['tel'],
          );
          if (result != null) {
            Uint8List? codes;
            if (kIsWeb) {
              codes = result.files.single.bytes;
            } else {
              final file = File(result.files.single.path!);
              codes = file.readAsBytesSync();
            }
            if (codes != null) {
              minmodel.emulate(codes);
            }
          }
        },
        child: const Text('Load file...'),
      ),
    );
  }
}
