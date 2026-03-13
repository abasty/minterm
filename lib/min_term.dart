import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import 'min_emulator.dart';
import 'min_model.dart';
import 'min_serial.dart';
import 'min_widget.dart';

class MinTerm extends StatelessWidget {
  const MinTerm({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      excluding: true,
      child: Scaffold(
        drawer: Drawer(
          child: ListView(
            children: [
              CloseMenu(),
              Divider(),
              SetBps(),
              Scale(),
              SetScreenMode(),
              SetColors(),
              // ListTile(
              //   title: const Text('Keyboard'),
              //   onTap: () {
              //     MinSettings.toggleKeyboard();
              //     Navigator.pop(context);
              //   },
              // ),
              Divider(),
              Clear(),
              Connection('3615', 'ws://3615co.de/ws'),
              Connection('3611', 'ws://3611.re/ws'),
              Connection('Minipavi', 'tcp://go.minipavi.fr:516'),
              Connection('Zboub', 'tcp://abasty-retro.fr:1967'),
              Connection('Hacker', 'ws://mntl.joher.com:2018/?echo'),
              Connection(
                'BASTOS (localhost:1967)',
                'tcp://127.0.0.1:1967',
              ),
              Connection(
                'WS/WSS Gateway (localhost:1963)',
                'tcp://127.0.0.1:1963',
              ),
              ConnectionSerial(),
            ],
          ),
        ),
        appBar: AppBar(
          title: const Text('Minterm'),
          actions: [
            // IconButton(
            //   icon: const Icon(Icons.keyboard),
            //   onPressed: () => MinSettings.toggleKeyboard(),
            // ),
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

class SetScreenMode extends StatefulWidget {
  const SetScreenMode({super.key});

  @override
  State<SetScreenMode> createState() => _SetScreenModeState();
}

class _SetScreenModeState extends State<SetScreenMode> {
  @override
  Widget build(BuildContext context) {
    final mode = MinModel().screenMode;
    final label = mode == TMinitelScreenMode.vt10080
        ? 'VT100 80 colonnes'
        : 'Minitel 40 colonnes';
    return ListTile(
      onTap: () {
        setState(() => MinModel().toggleScreenMode());
        Navigator.pop(context);
      },
      title: Row(
        children: [
          const Text('Mode écran'),
          Expanded(child: Container()),
          Text(label),
        ],
      ),
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

class ConnectionSerial extends StatelessWidget {
  const ConnectionSerial({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MinSerial()),
        );
      },
      title: const Text('ESP8266 / USB série'),
    );
  }
}
