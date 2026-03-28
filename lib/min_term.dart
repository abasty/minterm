import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import 'min_emulator.dart';
import 'min_model.dart';
// serial support removed
import 'min_widget.dart';

class MinTerm extends StatelessWidget {
  const MinTerm({super.key});

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
              CaptureToggle(),
              ReplayCaptureAction(),
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
              Connection('3611', 'ws://3611.re/ws'),
              Connection('3615', 'ws://3615co.de/ws'),
              Connection('Minipavi', 'tcp://go.minipavi.fr:516'),
              Connection('Hacker', 'ws://mntl.joher.com:2018/?echo'),
              Connection('Galaxy', 'ws://galaxy.microtel.fr:50124'),
              Connection('BASTOS (localhost:1967)', 'tcp://127.0.0.1:1967'),
              Connection(
                'WS/WSS Gateway (localhost:1963)',
                'tcp://127.0.0.1:1963',
              ),
              // Serial connections removed
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
            CaptureButton(),
            ReplayCaptureIndicator(),
            ColorsButton(),
          ],
        ),
        body: Center(
          child: Column(
            children: [
              MinScreen(),
              ReplayKeyboardOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

class CloseMenu extends StatelessWidget {
  const CloseMenu({super.key});

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

class CaptureToggle extends StatefulWidget {
  const CaptureToggle({super.key});

  @override
  State<CaptureToggle> createState() => _CaptureToggleState();
}

class _CaptureToggleState extends State<CaptureToggle> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinModel(),
      builder: (context, _) {
        final enabled = MinModel().isCaptureEnabled;
        return ListTile(
          onTap: () async {
            await MinModel().toggleCapture();
            if (!mounted) return;
            Navigator.pop(context);
          },
          title: Row(
            children: [
              const Text('Capture'),
              Expanded(child: Container()),
              Text(enabled ? 'ON' : 'OFF'),
            ],
          ),
        );
      },
    );
  }
}

class CaptureButton extends StatelessWidget {
  const CaptureButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinModel(),
      builder: (context, _) {
        final enabled = MinModel().isCaptureEnabled;
        return IconButton(
          tooltip: enabled ? 'Capture ON' : 'Capture OFF',
          icon: Icon(enabled
              ? Icons.fiber_manual_record
              : Icons.radio_button_unchecked),
          color: enabled ? Colors.redAccent : null,
          onPressed: () => MinModel().toggleCapture(),
        );
      },
    );
  }
}

class ReplayCaptureAction extends StatelessWidget {
  const ReplayCaptureAction({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinModel(),
      builder: (context, _) {
        final replaying = MinModel().isReplayingCapture;
        final captureEnabled = MinModel().isCaptureEnabled;
        final replayAllowed = !replaying && !captureEnabled;
        return ListTile(
          onTap: !replayAllowed
              ? null
              : () async {
                  await MinModel().replayCapture();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
          title: Row(
            children: [
              const Text('Replay capture'),
              Expanded(child: Container()),
              Text(replaying ? 'RUN' : (captureEnabled ? 'LOCK' : 'READY')),
            ],
          ),
        );
      },
    );
  }
}

class ReplayCaptureIndicator extends StatelessWidget {
  const ReplayCaptureIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinModel(),
      builder: (context, _) {
        final replaying = MinModel().isReplayingCapture;
        final captureEnabled = MinModel().isCaptureEnabled;
        final replayAllowed = !replaying && !captureEnabled;
        return IconButton(
          tooltip: replaying
              ? 'Replay capture en cours'
              : (captureEnabled
                  ? 'Replay indisponible pendant la capture'
                  : 'Lancer la relecture de capture'),
          icon: Icon(replaying ? Icons.play_circle : Icons.play_circle_outline),
          color: replaying
              ? Colors.green.shade700
              : (captureEnabled ? Colors.grey : null),
          onPressed: replayAllowed ? () => MinModel().replayCapture() : null,
        );
      },
    );
  }
}

class ReplayKeyboardOverlay extends StatelessWidget {
  const ReplayKeyboardOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinSettings(),
      builder: (context, _) {
        final keyboardWidth = 8.0 * 80.0 * MinSettings().scale;
        return SizedBox(
          width: keyboardWidth,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const MinKeyboard(),
              ListenableBuilder(
                listenable: MinModel(),
                builder: (context, _) {
                  final paused = MinModel().isReplayPaused;
                  return IgnorePointer(
                    ignoring: !paused,
                    child: Center(
                      child: GestureDetector(
                        onTap: paused
                            ? () => MinModel().resumeReplayAfterPause()
                            : null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          opacity: paused ? 1 : 0,
                          child: Container(
                            width: keyboardWidth - 24,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD32F2F)
                                  .withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Text(
                              'Pause lecture: touche/clic pour continuer, ESC pour quitter',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class ColorsButton extends StatelessWidget {
  const ColorsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinSettings(),
      builder: (context, _) {
        final colorsEnabled = MinSettings().colors == MinColors;
        return IconButton(
          tooltip:
              colorsEnabled ? 'Mode couleur actif' : 'Mode couleur inactif',
          icon: const Icon(Icons.color_lens),
          color: colorsEnabled ? Colors.blue.shade700 : null,
          onPressed: () => MinSettings().toggleColors(),
        );
      },
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
    final label =
        mode == TMinitelScreenMode.vt10080 ? 'VT100 80' : 'Minitel 40';
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

// ConnectionSerial widget removed with serial support
