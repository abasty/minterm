import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import 'min_emulator.dart';
import 'min_model.dart';
import 'min_serial.dart';
import 'serial_support.dart';
import 'min_widget.dart';
import 'window_setup.dart' as window_setup;

class MinTerm extends StatelessWidget {
  const MinTerm({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinSettings(),
      builder: (context, _) {
        final appBackground = MinSettings().appBackgroundColor;
        final isDarkMode = appBackground.computeLuminance() < 0.5;
        return ExcludeFocus(
          excluding: true,
          child: Scaffold(
            backgroundColor: appBackground,
            drawer: Drawer(
              child: ListView(
                children: [
                  CloseMenu(),
                  Divider(),
                  SetBps(),
                  SetScreenMode(),
                  CaptureToggle(),
                  ReplayCaptureAction(),
                  ImportCaptureAction(),
                  ExportCaptureAction(),
                  SetColors(),
                  SetBackground(),
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
                  Connection('Minipavi', 'ws://go.minipavi.fr:8182'),
                  Connection('Hacker', 'ws://mntl.joher.com:2018/?echo'),
                  Connection('Galaxy', 'ws://galaxy.microtel.fr:50124'),
                  Connection('BASTOS (localhost:1967)', 'tcp://127.0.0.1:1967'),
                  Connection(
                    'WS/WSS Gateway (localhost:1963)',
                    'tcp://127.0.0.1:1963',
                  ),
                  if (isSerialSupported) const ConnectionSerial(),
                ],
              ),
            ),
            appBar: AppBar(
              backgroundColor: isDarkMode ? Colors.black : Colors.white,
              foregroundColor: isDarkMode ? Colors.white : Colors.black,
              title: const Text('Minterm'),
              actions: [
                // IconButton(
                //   icon: const Icon(Icons.keyboard),
                //   onPressed: () => MinSettings.toggleKeyboard(),
                // ),
                if (window_setup.isWindowControlsSupported)
                  const FullscreenToggleButton(),
                const BackgroundButton(),
                CaptureButton(),
                ReplayCaptureIndicator(),
                ColorsButton(),
              ],
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(
                  child: MinScreenAndKeyboard(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BackgroundButton extends StatelessWidget {
  const BackgroundButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinSettings(),
      builder: (context, _) {
        final background = MinSettings().appBackgroundColor;
        final isDark = background.computeLuminance() < 0.5;
        return IconButton(
          tooltip: isDark ? 'Set white background' : 'Set black background',
          icon: Icon(
            isDark ? Icons.brightness_2 : Icons.wb_sunny,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () {
            MinSettings().toggleAppBackgroundColor();
          },
        );
      },
    );
  }
}

class FullscreenToggleButton extends StatelessWidget {
  const FullscreenToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: window_setup.fullscreenListenable,
      builder: (context, isFullscreen, _) {
        return IconButton(
          tooltip: isFullscreen ? 'Exit fullscreen' : 'Enter fullscreen',
          icon: Icon(
            isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
          ),
          onPressed: () {
            window_setup.toggleFullscreen();
          },
        );
      },
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

class SetBps extends StatelessWidget {
  const SetBps({super.key});

  static const speeds = [300, 1200, 4800, 9600, 0];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinModel(),
      builder: (context, _) => ListTile(
        onTap: () {
          final currentIndex = speeds.indexOf(MinModel().bps);
          final nextIndex = (currentIndex + 1) % speeds.length;
          MinModel().bps = speeds[nextIndex];
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

class SetBackground extends StatelessWidget {
  const SetBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinSettings(),
      builder: (context, _) {
        final isBlack = MinSettings().appBackgroundColor == Colors.black;
        return ListTile(
          onTap: () {
            MinSettings().toggleAppBackgroundColor();
            Navigator.pop(context);
          },
          title: Row(
            children: [
              const Text('Background'),
              Expanded(child: Container()),
              Text(isBlack ? 'BLACK' : 'WHITE'),
            ],
          ),
        );
      },
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
            final navigator = Navigator.of(context);
            await MinModel().toggleCapture();
            if (!mounted) return;
            navigator.pop();
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
                  final navigator = Navigator.of(context);
                  await MinModel().replayCapture();
                  navigator.pop();
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

class ImportCaptureAction extends StatelessWidget {
  const ImportCaptureAction({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinModel(),
      builder: (context, _) {
        final replaying = MinModel().isReplayingCapture;
        final captureEnabled = MinModel().isCaptureEnabled;
        final actionAllowed = !replaying && !captureEnabled;
        return ListTile(
          onTap: !actionAllowed
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  await MinModel().importCapture();
                  navigator.pop();
                },
          title: Row(
            children: [
              const Text('Import capture'),
              Expanded(child: Container()),
              Text(actionAllowed ? 'READY' : 'LOCK'),
            ],
          ),
        );
      },
    );
  }
}

class ExportCaptureAction extends StatelessWidget {
  const ExportCaptureAction({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinModel(),
      builder: (context, _) {
        final hasCapture = MinModel().hasCaptureData;
        return ListTile(
          onTap: !hasCapture
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  await MinModel().exportCapture();
                  navigator.pop();
                },
          title: Row(
            children: [
              const Text('Export capture'),
              Expanded(child: Container()),
              Text(hasCapture ? 'READY' : 'EMPTY'),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final keyboardWidth = constraints.maxWidth;
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
                            width: keyboardWidth > 24
                                ? keyboardWidth - 24
                                : keyboardWidth,
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
        MinModel()
            .emulate([0x0C, 0x1F, 0x40, 0x41, 0x18, 0x1B, 0x3A, 0x6A, 0x43]);
        final player = AudioPlayer();
        player.play(AssetSource('min_bip.wav'), mode: PlayerMode.lowLatency);
        Navigator.pop(context);
      },
      title: const Text('Clear'),
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
