import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart';
import 'package:window_manager/window_manager.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          surface: Colors.black,
        ),
      ),
      home: ChangeNotifierProvider<MinModel>(
        create: (context) => MinModel(),
        child: Scaffold(
          appBar: AppBar(
            title: Row(children: [
              Clear(),
              Scale(),
              SetColors(),
              SetBps(),
              SendABC(),
              SendFile(),
              Connection(),
              SendKey(),
            ]),
          ),
          body: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MinWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

class SetBps extends StatefulWidget {
  const SetBps({super.key});

  @override
  State<SetBps> createState() => _SetBpsState();
}

class _SetBpsState extends State<SetBps> {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        final bps = MinModel().bps * 2;
        setState(() => MinModel().bps = bps <= 9600 ? bps : 300);
      },
      child: Text('${MinModel().bps} bps'),
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
    return ElevatedButton(
      onPressed: () {
        MinModel()
            .emulate([0x48, 0x1B, 0x5D, 0x4F, 0x1B, 0x5C, 0x48, 0x20, 10]);
      },
      child: const Text('Send HOH'),
    );
  }
}

class Clear extends StatelessWidget {
  const Clear({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => MinModel().emulate([0x0C]),
      child: const Text('Clear'),
    );
  }
}

class Scale extends StatefulWidget {
  const Scale({super.key});

  @override
  State<Scale> createState() => _ScaleState();
}

class _ScaleState extends State<Scale> {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        var scale = MinSettings().scale + 0.5;
        if (scale > 4) scale = 0.5;
        setState(() => MinSettings.setScale(scale));
      },
      child: Text('Scale x${MinSettings().scale}'),
    );
  }
}

class SendFile extends StatefulWidget {
  const SendFile({super.key});

  @override
  State<SendFile> createState() => _SendFileState();
}

class _SendFileState extends State<SendFile> {
  late final List<String> pages;
  bool isLoaded = false;

  @override
  initState() {
    super.initState();
    AssetManifest.loadFromAssetBundle(rootBundle).then((manifest) {
      pages = manifest
          .listAssets()
          .where((string) => string.endsWith("tel"))
          .toList();
      isLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      child: const Text('Load page...'),
      onPressed: () async {
        if (!isLoaded) return;

        int? pageIndex = await showMenu(
            context: context,
            position: RelativeRect.fill,
            items: [
              for (int idx = 0; idx < pages.length; idx++)
                PopupMenuItem<int>(
                  value: idx,
                  child: Text(basenameWithoutExtension(pages[idx])),
                )
            ]);
        if (pageIndex != null) {
          final ByteData bytes = await rootBundle.load(pages[pageIndex]);
          Uint8List codes = bytes.buffer.asUint8List();
          MinModel().emulate(codes);
        }
      },
    );
  }
}

class Connection extends StatelessWidget {
  const Connection({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        MinModel().setServer('wss://echo.websocket.events');
      },
      child: const Text('Connect'),
    );
  }
}

class SendKey extends StatelessWidget {
  const SendKey({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        MinModel().sendKeysToServer('*SOS');
      },
      child: Text('Key'),
    );
  }
}
