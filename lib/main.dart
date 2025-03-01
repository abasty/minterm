import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:audioplayers/audioplayers.dart';

import 'min_emulator.dart';
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
      if (event.logicalKey.keyLabel == '[') {
        var shift = HardwareKeyboard.instance.isShiftPressed;
        MinModel().handleKeys(
          shift ? TMinitelKey.trema : TMinitelKey.circonflexe,
        );
        return true;
      }
      switch (event.logicalKey) {
        case LogicalKeyboardKey.pageDown:
          // Suite
          MinModel().handleKeys(TMinitelKey.suite);
          break;
        case LogicalKeyboardKey.pageUp:
          // Retour
          MinModel().handleKeys(TMinitelKey.retour);
          break;
        case LogicalKeyboardKey.f1:
          // Guide
          MinModel().handleKeys(TMinitelKey.guide);
          break;
        case LogicalKeyboardKey.backspace:
          // Correction
          MinModel().handleKeys(TMinitelKey.correction);
          break;
        case LogicalKeyboardKey.enter:
          // Envoi
          MinModel().handleKeys(TMinitelKey.envoi);
          break;
        case LogicalKeyboardKey.home:
          // Sommaire
          MinModel().handleKeys(TMinitelKey.sommaire);
          break;
        case LogicalKeyboardKey.escape:
          // Annulation
          MinModel().handleKeys(TMinitelKey.annulation);
          break;
        default:
          // Other keys
          if (event.character != null) {
            switch (event.character) {
              case 'à':
                MinModel().handleKeys('${TMinitelKey.grave}a');
                break;
              case 'é':
                MinModel().handleKeys('${TMinitelKey.aigu}e');
                break;
              case 'è':
                MinModel().handleKeys('${TMinitelKey.grave}e');
                break;
              case 'ù':
                MinModel().handleKeys('${TMinitelKey.grave}u');
                break;
              case 'ç':
                MinModel().handleKeys('${TMinitelKey.cedille}c');
                break;
              case 'Ç':
                MinModel().handleKeys('${TMinitelKey.cedille}C');
                break;
              case '£':
                MinModel().handleKeys(TMinitelKey.livre);
                break;
              case '§':
                MinModel().handleKeys(TMinitelKey.paragraph);
                break;
              case '°':
                MinModel().handleKeys(TMinitelKey.degree);
                break;
              default:
                MinModel().handleKeys(event.character!);
                break;
            }
          }
          break;
      }
      return true;
    }
    return false;
  });

  // debugPaintSizeEnabled = true;

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
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
                MinSettings.toggleKeyboard();
                Navigator.pop(context);
              },
            ),
            Divider(),
            Clear(),
            SendHOH(),
            SendFile(),
            Connection('3615', 'wss://3615co.de/ws'),
            Connection('3611', 'wss://3611.re/ws'),
            Connection('Zboub', 'tcp://217.154.8.76:1967'),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Minterm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard),
            onPressed: () => MinSettings.toggleKeyboard(),
          ),
          CapsLock(),
          IconButton(
            icon: const Icon(Icons.color_lens),
            onPressed: () => MinSettings().toggleColors(),
          ),
        ],
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

class CapsLock extends StatefulWidget {
  const CapsLock({
    super.key,
  });

  @override
  State<CapsLock> createState() => _CapsLockState();
}

class _CapsLockState extends State<CapsLock> {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: MinSettings().capslock ? const Text('A') : const Text('a'),
      onPressed: () => setState(() => MinSettings.toggleCapslock()),
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
        MinModel().end();
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
        MinModel().end();
        MinModel().emulate([0x0C]);
        final player = AudioPlayer();
        player.play(AssetSource('min_bip.wav'), mode: PlayerMode.lowLatency);
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
        MinModel().end();
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
        Navigator.pop(context);
      },
    );
  }
}

class Connection extends StatelessWidget {
  final String uri;
  final String text;
  const Connection(this.text, this.uri, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        MinModel().serverAddress = uri;
        MinModel().connect();
        Navigator.pop(context);
      },
      title: Text(text),
    );
  }
}
