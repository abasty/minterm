import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'min_emulator.dart';
import 'min_model.dart';
import 'min_serial.dart';
import 'min_widget.dart';
import 'server_endpoints/server_menu_section.dart';
import 'serial_support.dart';
import 'window_setup.dart' as window_setup;

class MinTerm extends StatelessWidget {
  const MinTerm({super.key});

  bool get _isMobileDevice {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinSettings(),
      builder: (context, _) {
        final appBackground = MinSettings().appBackgroundColor;
        final isDarkMode = appBackground.computeLuminance() < 0.5;
        return Scaffold(
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
                const SetSoundMode(),
                Divider(),
                Clear(),
                const RecentConnectionsSection(),
                if (isSerialSupported) const ConnectionSerial(),
              ],
            ),
          ),
          appBar: AppBar(
            leading: Builder(
              builder: (context) => _PointerOnlyFocus(
                child: IconButton(
                  tooltip: 'Ouvrir le menu',
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
            foregroundColor: isDarkMode ? Colors.white : Colors.black,
            title: const Text('Minterm'),
            actions: [
              if (window_setup.isWindowControlsSupported)
                const _PointerOnlyFocus(child: FullscreenToggleButton()),
              if (_isMobileDevice)
                const _PointerOnlyFocus(child: MobileKeyboardButton()),
              if (!_isMobileDevice)
                const _PointerOnlyFocus(child: DesktopKeyboardLayoutButton()),
              const _PointerOnlyFocus(child: BackgroundButton()),
              _PointerOnlyFocus(child: CaptureButton()),
              const _PointerOnlyFocus(child: ReplayCaptureIndicator()),
              const _PointerOnlyFocus(child: ColorsButton()),
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
        );
      },
    );
  }
}

class _PointerOnlyFocus extends StatelessWidget {
  final Widget child;

  const _PointerOnlyFocus({required this.child});

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      descendantsAreFocusable: false,
      skipTraversal: true,
      child: child,
    );
  }
}

class MobileKeyboardButton extends StatefulWidget {
  const MobileKeyboardButton({super.key});

  @override
  State<MobileKeyboardButton> createState() => _MobileKeyboardButtonState();
}

class _MobileKeyboardButtonState extends State<MobileKeyboardButton> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();
  bool _clearing = false;
  String _lastInputValue = '';

  @override
  void initState() {
    super.initState();
    MinSettings.setMobileKeyboardLayout(MobileKeyboardLayoutMode.bitmap);
    _focusNode.addListener(() {
      final mode = MinSettings().mobileKeyboardLayout;
      if (!_focusNode.hasFocus &&
          mode == MobileKeyboardLayoutMode.virtualCompact) {
        MinSettings.setMobileKeyboardLayout(
            MobileKeyboardLayoutMode.compactOnly);
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    MinSettings.setMobileKeyboardLayout(MobileKeyboardLayoutMode.bitmap);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleTextInput(String value) {
    if (_clearing) return;

    if (value == _lastInputValue) return;

    // Compute common prefix to determine user edits and committed delta.
    int common = 0;
    final max = math.min(_lastInputValue.length, value.length);
    while (common < max &&
        _lastInputValue.codeUnitAt(common) == value.codeUnitAt(common)) {
      common++;
    }

    // If text shrank or was replaced, emit correction key(s) for removed chars.
    final removedCount = _lastInputValue.length - common;
    for (int i = 0; i < removedCount; i++) {
      MinModel().handleKeys(TMinitelKey.correction);
    }

    // Emit added tail as typed characters.
    final added = value.substring(common);
    for (final rune in added.runes) {
      MinModel().handleKeys(String.fromCharCode(rune));
    }

    _lastInputValue = value;
  }

  void _handleValidationKey() {
    MinModel().handleKeys(TMinitelKey.envoi);
    _clearing = true;
    _controller.clear();
    _lastInputValue = '';
    _clearing = false;
    // Re-open the keyboard: TextInputAction.done causes the IME to dismiss it.
    if (MinSettings().mobileKeyboardLayout ==
        MobileKeyboardLayoutMode.virtualCompact) {
      _openKeyboard();
    }
  }

  Future<void> _openKeyboard() async {
    FocusScope.of(context).requestFocus(_focusNode);
    await Future<void>.delayed(const Duration(milliseconds: 16));
    await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  Future<void> _closeKeyboard() async {
    _focusNode.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    _clearing = true;
    _controller.clear();
    _lastInputValue = '';
    _clearing = false;
  }

  Future<void> _applyMobileKeyboardMode(MobileKeyboardLayoutMode mode) async {
    MinSettings.setMobileKeyboardLayout(mode);
    if (mode == MobileKeyboardLayoutMode.virtualCompact) {
      await _openKeyboard();
    } else {
      await _closeKeyboard();
    }
    if (mounted) setState(() {});
  }

  MobileKeyboardLayoutMode _nextMobileKeyboardMode(
      MobileKeyboardLayoutMode mode) {
    switch (mode) {
      case MobileKeyboardLayoutMode.bitmap:
        return MobileKeyboardLayoutMode.virtualCompact;
      case MobileKeyboardLayoutMode.virtualCompact:
        return MobileKeyboardLayoutMode.compactOnly;
      case MobileKeyboardLayoutMode.compactOnly:
        return MobileKeyboardLayoutMode.bitmap;
    }
  }

  (IconData, String) _modeVisuals(MobileKeyboardLayoutMode mode) {
    switch (mode) {
      case MobileKeyboardLayoutMode.bitmap:
        return (
          Icons.keyboard_alt_outlined,
          'Mode clavier: bitmap (tap pour virtuel + compact)'
        );
      case MobileKeyboardLayoutMode.virtualCompact:
        return (Icons.keyboard, 'Mode clavier: virtuel + compact');
      case MobileKeyboardLayoutMode.compactOnly:
        return (Icons.view_stream, 'Mode clavier: compact uniquement');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = MinSettings().mobileKeyboardLayout;
    final visuals = _modeVisuals(mode);
    return Stack(
      children: [
        IconButton(
          tooltip: visuals.$2,
          icon: Icon(visuals.$1),
          onPressed: () async {
            await _applyMobileKeyboardMode(_nextMobileKeyboardMode(mode));
          },
        ),
        IgnorePointer(
          child: Opacity(
            opacity: 0,
            child: SizedBox(
              width: 1,
              height: 1,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: false,
                autocorrect: true,
                enableSuggestions: true,
                showCursor: false,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.text,
                onChanged: _handleTextInput,
                onSubmitted: (_) => _handleValidationKey(),
                decoration: const InputDecoration.collapsed(hintText: ''),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DesktopKeyboardLayoutButton extends StatelessWidget {
  const DesktopKeyboardLayoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinSettings(),
      builder: (context, _) {
        final imageMode = MinSettings().desktopImageKeyboardEnabled;
        return IconButton(
          tooltip: imageMode
              ? 'Utiliser le clavier compact'
              : 'Utiliser le clavier image',
          icon: Icon(imageMode ? Icons.keyboard_hide : Icons.keyboard),
          onPressed: () => MinSettings.toggleDesktopImageKeyboard(),
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
          tooltip: isDark ? 'Fond blanc' : 'Fond noir',
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
          tooltip: isFullscreen ? 'Quitter le plein écran' : 'Plein écran',
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
      title: const Text('Fermer le menu'),
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
            const Text('Vitesse'),
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
      title: const Text('Couleurs'),
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
              const Text('Fond'),
              Expanded(child: Container()),
              Text(isBlack ? 'NOIR' : 'BLANC'),
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
              Text(enabled ? 'ACTIVÉE' : 'DÉSACTIVÉE'),
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
          tooltip: enabled ? 'Capture activée' : 'Capture désactivée',
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
              const Text('Rejouer la capture'),
              Expanded(child: Container()),
              Text(replaying
                  ? 'EN COURS'
                  : (captureEnabled ? 'VERROUILLÉ' : 'PRÊT')),
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
              const Text('Importer une capture'),
              Expanded(child: Container()),
              Text(actionAllowed ? 'PRÊT' : 'VERROUILLÉ'),
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
              const Text('Exporter la capture'),
              Expanded(child: Container()),
              Text(hasCapture ? 'PRÊT' : 'VIDE'),
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

class SetScreenMode extends StatelessWidget {
  const SetScreenMode({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinModel(),
      builder: (context, _) {
        final isTeleinfo =
            MinModel().screenMode == TMinitelScreenMode.teleinfo80;
        return SwitchListTile(
          title: const Text('80 cols'),
          value: isTeleinfo,
          onChanged: (_) => MinModel().toggleScreenMode(),
        );
      },
    );
  }
}

class SetSoundMode extends StatelessWidget {
  const SetSoundMode({super.key});

  static const _icons = {
    SoundMode.none: Icons.volume_off,
    SoundMode.bipAndKeyboard: Icons.volume_up,
    SoundMode.keyboard: Icons.keyboard,
    SoundMode.bip: Icons.notifications_active,
  };

  static const _labels = {
    SoundMode.none: 'Aucun',
    SoundMode.bipAndKeyboard: 'Bip + Clavier',
    SoundMode.keyboard: 'Clavier',
    SoundMode.bip: 'Bip',
  };

  static SoundMode _next(SoundMode mode) {
    switch (mode) {
      case SoundMode.none:
        return SoundMode.bipAndKeyboard;
      case SoundMode.bipAndKeyboard:
        return SoundMode.keyboard;
      case SoundMode.keyboard:
        return SoundMode.bip;
      case SoundMode.bip:
        return SoundMode.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinSettings(),
      builder: (context, _) {
        final mode = MinSettings().soundMode;
        return ListTile(
          onTap: () => MinSettings.setSoundMode(_next(mode)),
          title: const Text('Son'),
          trailing: Tooltip(
            message: _labels[mode],
            child: Icon(_icons[mode]),
          ),
        );
      },
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
        if (MinSettings().bipEnabled) {
          final player = AudioPlayer();
          player.play(AssetSource('min_bip.wav'), mode: PlayerMode.lowLatency);
        }
        Navigator.pop(context);
      },
      title: const Text('Clear'),
    );
  }
}
