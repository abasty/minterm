import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
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
            Scale(),
            SetColors(),
            SetBps(),
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
      body: Column(
        children: [
          MinScreen(),
          Container(height: 0, color: Colors.amber),
        ],
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
  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        final bps = MinModel().bps * 2;
        setState(() => MinModel().bps = bps <= 9600 ? bps : 300);
      },
      title: Text('${MinModel().bps} bps'),
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
      onTap: () {
        var scale = MinSettings().scale + 0.5;
        if (scale > 4) scale = 0.5;
        setState(() => MinSettings.setScale(scale));
      },
      title: Text('Scale x${MinSettings().scale}'),
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
        MinModel().setServer('wss://3611.re/ws');
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
