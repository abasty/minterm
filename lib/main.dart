import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:minterm/min_emulator.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart';
// import 'package:window_manager/window_manager.dart';

import 'min_model.dart';
import 'min_widget.dart';

void main() async {
  if (kIsWeb) {
    // Code to execute only on web targets
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // await windowManager.ensureInitialized();

    // WindowOptions windowOptions = const WindowOptions(
    //   // size: Size(4 * 8 * 40 + 64, 4 * 10 * 25 + 64),
    //   size: Size(700, 1100),
    //   center: true,
    //   title: 'Terminal Minitel',
    //   // backgroundColor: Colors.transparent,
    //   // skipTaskbar: false,
    //   // titleBarStyle: TitleBarStyle.hidden,
    //   // windowButtonVisibility: false,
    // );
    // windowManager.waitUntilReadyToShow(windowOptions, () async {
    //   await windowManager.show();
    //   await windowManager.focus();
  }

  WidgetsFlutterBinding.ensureInitialized();

  HardwareKeyboard.instance.addHandler((event) {
    if (event is KeyDownEvent) {
      // If local (not connected)
      // MinModel().emulate([event.logicalKey.keyId]);
      // If connected
      switch (event.logicalKey) {
        case LogicalKeyboardKey.pageDown:
          // Suite
          MinModel().sendKeysToServer(TMinitelKey.suite);
          break;
        case LogicalKeyboardKey.pageUp:
          // Retour
          MinModel().sendKeysToServer(TMinitelKey.retour);
          break;
        case LogicalKeyboardKey.f1:
          // Guide
          MinModel().sendKeysToServer(TMinitelKey.guide);
          break;
        case LogicalKeyboardKey.backspace:
          // Correction
          MinModel().sendKeysToServer(TMinitelKey.correction);
          break;
        case LogicalKeyboardKey.enter:
          // Envoi
          MinModel().sendKeysToServer(TMinitelKey.envoi);
          break;
        case LogicalKeyboardKey.home:
          // Sommaire
          MinModel().sendKeysToServer(TMinitelKey.sommaire);
          break;
        case LogicalKeyboardKey.escape:
          // Annulation
          MinModel().sendKeysToServer(TMinitelKey.annulation);
          break;

        default:
          // Other keys
          if (event.character != null) {
            MinModel().sendKeysToServer(event.character!);
          }
          break;
      }
      // int code = event.character != null ? event.character!.codeUnitAt(0) : 0;
      // debugPrint(
      // 'char: #$code, label: ${event.logicalKey.keyLabel}, id: ${event.logicalKey.keyId}',
      // );
      return true;
    }
    return false;
  });

  // debugPaintSizeEnabled = true;

  runApp(MaterialApp(
    debugShowCheckedModeBanner: true,
    theme: ThemeData(
      primarySwatch: Colors.blue,
    ),
    home: MinTerm(),
  ));
}

class MinTerm extends StatelessWidget {
  const MinTerm({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          children: [
            CloseMenu(),
            Divider(),
            SetBps(),
            Scale(),
            SetColors(),
            ListTile(
              title: const Text('Keyboard'),
              onTap: () {
                MinSettings().toggleKeyboard();
                Navigator.pop(context);
              },
            ),
            Divider(),
            Clear(),
            SendHOH(),
            SendFile(),
            Connection(),
            SendKey(),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Minterm'),
      ),
      body: Center(
        child: Column(
          children: [
            MinScreen(),
            MinKeyboard(),
          ],
        ),
      ),
    );
  }
}

class MinKeyboard extends StatelessWidget {
  const MinKeyboard({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MinSettings(),
      child: Consumer<MinSettings>(
        builder: (context, settings, child) => ChangeNotifierProvider(
          create: (context) => MinSettings(),
          child: Visibility(
            visible: MinSettings().keyboard,
            replacement: const Text('HW keyboard'),
            child: Container(
              color: Colors.grey[200],
              child: SizedBox(
                width: 8 * 40 * MinSettings().scale,
                height: 10 * 25 * MinSettings().scale,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Container(
                      color: Colors.grey[200],
                      child: Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage("assets/clavier.png"),
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CloseMenu extends StatelessWidget {
  const CloseMenu({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Close menu'),
      onTap: () {
        Navigator.pop(context);
      },
    );
  }
}

class SetBps extends StatefulWidget {
  const SetBps({super.key});

  @override
  State<SetBps> createState() => _SetBpsState();
}

class _SetBpsState extends State<SetBps> {
  static const speeds = [300, 1200, 4800, 9600, 0];
  int speedIndex = 1;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        speedIndex = (speedIndex + 1) % speeds.length;
        setState(() => MinModel().bps = speeds[speedIndex]);
      },
      title: Row(
        children: [
          const Text('Speed'),
          Expanded(child: Container()),
          MinModel().bps == 0
              ? const Text('max')
              : Text('${MinModel().bps} bps'),
        ],
      ),
    );
  }
}

class SetColors extends StatelessWidget {
  const SetColors({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        MinSettings().toggleColors();
        Navigator.pop(context);
      },
      title: const Text('Colors'),
    );
  }
}

class SendHOH extends StatelessWidget {
  const SendHOH({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        MinModel()
            .emulate([0x48, 0x1B, 0x5D, 0x4F, 0x1B, 0x5C, 0x48, 0x20, 10]);
        Navigator.pop(context);
      },
      title: const Text('Send HOH'),
    );
  }
}

class Clear extends StatelessWidget {
  const Clear({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        MinModel().emulate([0x0C]);
        Navigator.pop(context);
      },
      title: const Text('Clear'),
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
    return ListTile(
      title: Row(
        children: [
          const Text('Scale'),
          Expanded(child: Container()),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () {
              var scale = MinSettings().scale - 0.5;
              if (scale < 1) scale = 4.0;
              setState(() => MinSettings.setScale(scale));
            },
          ),
          Text('${MinSettings().scale}'),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              var scale = MinSettings().scale + 0.5;
              if (scale > 4) scale = 0.5;
              setState(() => MinSettings.setScale(scale));
            },
          ),
        ],
      ),
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
    return ListTile(
      title: const Text('Load page...'),
      onTap: () async {
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
        // FIXME: problem on context (async gap)
        Navigator.pop(context);
      },
    );
  }
}

class Connection extends StatelessWidget {
  const Connection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        // MinModel().setServer('wss://3611.re/ws');
        MinModel().setServer('wss://3615co.de/ws');
        Navigator.pop(context);
      },
      title: const Text('Connection'),
    );
  }
}

class SendKey extends StatelessWidget {
  const SendKey({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        MinModel().sendKeysToServer('*SOS');
        Navigator.pop(context);
      },
      title: Text('Send *SOS'),
    );
  }
}
