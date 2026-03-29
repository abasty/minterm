import 'dart:async';
import 'dart:math' as math; // Add this line to import the 'math' library
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:minterm/min_model.dart';
import 'package:provider/provider.dart';

import 'min_emulator.dart';

// ignore: non_constant_identifier_names
final MinColors = <Color>[
  Colors.black,
  Colors.red, // 800
  Colors.green, // 600
  Colors.yellow, // 400
  Colors.blue, // 850
  const Color(0xFFFF00FF), // 700
  Colors.cyan, // 500
  Colors.white,
];

// ignore: non_constant_identifier_names
final MinGrey = <Color>[
  Colors.black,
  Colors.grey[700]!,
  Colors.grey[500]!,
  Colors.grey[350]!,
  Colors.grey[800]!,
  Colors.grey[600]!,
  Colors.grey[400]!,
  Colors.white,
];

Future<ui.Image> loadUiImage(String imageAssetPath) async {
  final ByteData data = await rootBundle.load(imageAssetPath);
  final Completer<ui.Image> completer = Completer();
  ui.decodeImageFromList(
    Uint8List.view(data.buffer),
    (ui.Image img) {
      return completer.complete(img);
    },
  );
  return completer.future;
}

class MinSettings extends ChangeNotifier {
  static final MinSettings _singleton = MinSettings._internal();

  static late final ui.Image _fontG0G2;
  static late final ui.Image _fontG1;
  static const durationMax = 400;
  var scale = 1.5;
  var duration = durationMax;
  var _colors = MinGrey;
  int _loaded = 0;
  bool _keyboard = false;
  bool _capslock = true;
  bool _startupScaleInitialized = false;
  Color _appBackgroundColor = Colors.black;

  factory MinSettings() {
    return _singleton;
  }
  MinSettings._internal() {
    loadUiImage('assets/g0g2.png').then((image) {
      _fontG0G2 = image;
      _loaded++;
      notifyListeners();
    });

    loadUiImage('assets/g1.png').then((image) {
      _fontG1 = image;
      _loaded++;
      notifyListeners();
    });
  }
  List<Color> get colors => _colors;

  set colors(List<Color> colors) {
    _colors = colors;
    notifyListeners();
  }

  ui.Image get fontG0G2 => _fontG0G2;

  ui.Image get fontG1 => _fontG1;

  bool get isLoaded => _loaded == 2;

  bool get keyboard => _keyboard;

  bool get capslock => _capslock;

  Color get appBackgroundColor => _appBackgroundColor;

  static void setScale(double scale) {
    _singleton.duration = 0;
    _singleton.scale = math.max(1.0, math.min(4.0, scale));
    _singleton._startupScaleInitialized = true;
    _singleton.notifyListeners();
  }

  void initializeScaleForViewport(
    double maxWidth,
    double maxHeight, {
    required double baseWidth,
    required double baseHeight,
  }) {
    if (_startupScaleInitialized) return;
    if (maxWidth <= 0 || maxHeight <= 0) return;
    if (baseWidth <= 0 || baseHeight <= 0) return;

    final fittedScale = math.min(maxWidth / baseWidth, maxHeight / baseHeight);
    scale = math.max(1.0, math.min(4.0, fittedScale));
    _startupScaleInitialized = true;
    notifyListeners();
  }

  // Toggles between two color schemes
  void toggleColors() {
    colors = colors == MinColors ? MinGrey : MinColors;
    _singleton.notifyListeners();
  }

  static void toggleKeyboard() {
    _singleton.duration = durationMax;
    _singleton._keyboard = !_singleton._keyboard;
    _singleton.notifyListeners();
  }

  static void toggleCapslock() {
    _singleton._capslock = !_singleton._capslock;
    _singleton.notifyListeners();
  }

  void setAppBackgroundColor(Color color) {
    if (_appBackgroundColor == color) return;
    _appBackgroundColor = color;
    notifyListeners();
  }

  void toggleAppBackgroundColor() {
    setAppBackgroundColor(
      _appBackgroundColor == Colors.black ? Colors.white : Colors.black,
    );
  }
}

class MinScreen extends StatelessWidget {
  const MinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: MinSettings(),
      child: Consumer<MinSettings>(
        builder: (context, settings, child) => ChangeNotifierProvider.value(
          value: MinModel(),
          child: Consumer<MinModel>(
            builder: (context, minmodel, child) {
              final displayColumns = 80;
              final displayWidth = 8.0 * displayColumns;
              final displayHeight = displayWidth * 3.0 / 4.0;
              return LayoutBuilder(
                builder: (context, constraints) {
                  settings.initializeScaleForViewport(
                    constraints.maxWidth,
                    constraints.maxHeight,
                    baseWidth: displayWidth,
                    baseHeight: displayHeight,
                  );

                  final maxWidth = constraints.maxWidth;
                  final maxHeight = constraints.maxHeight;
                  if (!maxWidth.isFinite || !maxHeight.isFinite) {
                    return const SizedBox.shrink();
                  }

                  final fittedScale = math.min(
                      maxWidth / displayWidth, maxHeight / displayHeight);
                  final viewportWidth = displayWidth * fittedScale;
                  final viewportHeight = displayHeight * fittedScale;
                  final cellWidth = viewportWidth / minmodel.minitel.columns;
                  final cellHeight = viewportHeight / minmodel.minitel.rows;

                  return Center(
                    child: SizedBox(
                      width: viewportWidth,
                      height: viewportHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            onTapDown: (TapDownDetails details) {
                              final tapPosition = details.localPosition;
                              final x = math.max(
                                0,
                                math.min(
                                  minmodel.minitel.columns - 1,
                                  (tapPosition.dx / cellWidth).toInt(),
                                ),
                              );
                              final y = math.max(
                                0,
                                math.min(
                                  minmodel.minitel.rows - 1,
                                  (tapPosition.dy / cellHeight).toInt(),
                                ),
                              );
                              minmodel.handleTap(x, y);
                            },
                          ),
                          CustomPaint(
                            painter: _MinPainter(minmodel),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class MinScreenAndKeyboard extends StatelessWidget {
  const MinScreenAndKeyboard({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: MinSettings(),
      child: Consumer<MinSettings>(
        builder: (context, settings, child) => ChangeNotifierProvider.value(
          value: MinModel(),
          child: Consumer<MinModel>(
            builder: (context, minmodel, child) {
              const displayColumns = 80;
              const displayWidth = 8.0 * displayColumns;
              const displayHeight = displayWidth * 3.0 / 4.0;
              const keyboardBaseHeight = 48.0;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final maxHeight = constraints.maxHeight;
                  if (!maxWidth.isFinite || !maxHeight.isFinite) {
                    return const SizedBox.shrink();
                  }

                  final fittedScale = math.min(
                    maxWidth / displayWidth,
                    maxHeight / (displayHeight + keyboardBaseHeight),
                  );
                  final viewportWidth = displayWidth * fittedScale;
                  final viewportHeight = displayHeight * fittedScale;
                  final keyboardHeight = keyboardBaseHeight * fittedScale;
                  final cellWidth = viewportWidth / minmodel.minitel.columns;
                  final cellHeight = viewportHeight / minmodel.minitel.rows;

                  settings.initializeScaleForViewport(
                    maxWidth,
                    maxHeight,
                    baseWidth: displayWidth,
                    baseHeight: displayHeight + keyboardBaseHeight,
                  );

                  return Center(
                    child: SizedBox(
                      width: viewportWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: viewportHeight,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                GestureDetector(
                                  onTapDown: (TapDownDetails details) {
                                    final tapPosition = details.localPosition;
                                    final x = math.max(
                                      0,
                                      math.min(
                                        minmodel.minitel.columns - 1,
                                        (tapPosition.dx / cellWidth).toInt(),
                                      ),
                                    );
                                    final y = math.max(
                                      0,
                                      math.min(
                                        minmodel.minitel.rows - 1,
                                        (tapPosition.dy / cellHeight).toInt(),
                                      ),
                                    );
                                    minmodel.handleTap(x, y);
                                  },
                                ),
                                CustomPaint(
                                  painter: _MinPainter(minmodel),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: keyboardHeight,
                            child: _KeyboardWithReplayOverlay(
                              scale: fittedScale,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _KeyboardWithReplayOverlay extends StatelessWidget {
  final double scale;

  const _KeyboardWithReplayOverlay({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        ListenableBuilder(
          listenable: MinModel(),
          builder: (context, child) {
            if (MinModel().screenMode == TMinitelScreenMode.vt10080) {
              return _SharedVt100Keyboard(scale: scale);
            }
            return _SharedMinitelKeyboard(scale: scale);
          },
        ),
        ListenableBuilder(
          listenable: MinModel(),
          builder: (context, _) {
            final paused = MinModel().isReplayPaused;
            return IgnorePointer(
              ignoring: !paused,
              child: Center(
                child: GestureDetector(
                  onTap:
                      paused ? () => MinModel().resumeReplayAfterPause() : null,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    opacity: paused ? 1 : 0,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final overlayWidth = constraints.maxWidth > 24
                            ? constraints.maxWidth - 24
                            : constraints.maxWidth;
                        return Container(
                          width: overlayWidth,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFD32F2F).withValues(alpha: 0.92),
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
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SharedMinitelKeyboard extends StatelessWidget {
  final double scale;

  const _SharedMinitelKeyboard({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(MinMinitelKeyboard._row1),
        _buildRow(MinMinitelKeyboard._row2),
      ],
    );
  }

  Widget _buildRow(List<List<String>> keys) {
    return Row(
      children: keys.map((entry) {
        final label = entry[0];
        return Expanded(
          flex: _minitelKeyFlex(label),
          child: SizedBox(
            height: 24 * scale,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey),
                ),
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
              ),
              onPressed: () => MinModel().handleKeys(entry[1]),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10 * scale),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  int _minitelKeyFlex(String label) {
    if (label == 'Espace') return 3;
    if (label == 'Esc') return 1;
    return label == '↑' || label == '↓' || label == '←' || label == '→' ? 1 : 2;
  }
}

class _SharedVt100Keyboard extends StatelessWidget {
  final double scale;

  const _SharedVt100Keyboard({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(MinVt100Keyboard._row1),
        _buildRow(MinVt100Keyboard._row2),
      ],
    );
  }

  Widget _buildRow(List<List<String>> keys) {
    return Row(
      children: keys.map((entry) {
        return Expanded(
          child: SizedBox(
            height: 24 * scale,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey),
                ),
                backgroundColor: const Color(0xFF212121),
                foregroundColor: Colors.white,
              ),
              onPressed: () => MinModel().handleKeys(entry[1]),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  entry[0],
                  style: TextStyle(fontSize: 10 * scale),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MinPainter extends CustomPainter {
  final MinModel minmodel;

  // Disjoint G1 mask from tools/g18x10.bdf (glyph C000, 8x10).
  // Drawing this mask explicitly avoids sprite sampling artifacts.
  static const List<int> _g1DisjointMaskRows = <int>[
    0x88,
    0x88,
    0xFF,
    0x88,
    0x88,
    0x88,
    0xFF,
    0x88,
    0x88,
    0xFF,
  ];

  _MinPainter(this.minmodel);

  Rect _snapRect(double x, double y, double width, double height, double dpr) {
    final left = (x * dpr).floorToDouble() / dpr;
    final top = (y * dpr).floorToDouble() / dpr;
    final right = ((x + width) * dpr).ceilToDouble() / dpr;
    final bottom = ((y + height) * dpr).ceilToDouble() / dpr;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  void _drawDisjointMask(
    Canvas canvas,
    double x,
    double y,
    double scaleWidth,
    double scaleHeight,
    Color bgColor,
    double dpr,
  ) {
    final paint = Paint()
      ..color = bgColor
      ..isAntiAlias = false;

    for (int row = 0; row < _g1DisjointMaskRows.length; row++) {
      final mask = _g1DisjointMaskRows[row];
      for (int col = 0; col < 8; col++) {
        final bit = 1 << (7 - col);
        if ((mask & bit) == 0) continue;
        canvas.drawRect(
          _snapRect(
            x + col * scaleWidth,
            y + row * scaleHeight,
            scaleWidth,
            scaleHeight,
            dpr,
          ),
          paint,
        );
      }
    }
  }

  void draw(Canvas canvas, Size size) {
    var screen = minmodel.minitel.screen;
    final columns = minmodel.minitel.columns;
    final lastLine = minmodel.minitel.lastLine;
    final displayWidth = size.width;
    final displayHeight = size.height;
    final dpr =
        ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1.0;
    final cellWidth = displayWidth / columns;
    final cellHeight = displayHeight / minmodel.minitel.rows;
    if (minmodel.minitel.bip) {
      final player = AudioPlayer();
      player.play(AssetSource('min_bip.wav'), mode: PlayerMode.lowLatency);
      minmodel.minitel.bip = false;
    }
    screen[0][columns + 1].code &= ~kIsDirty;
    for (int line = 0; line <= lastLine; ++line) {
      screen[line][0].code &= ~kIsDirty;
      for (int column = columns; column >= 1; --column) {
        screen[line][column].code &= ~kIsDirty;
        drawChar(
          canvas,
          (column - 1) * cellWidth,
          line * cellHeight,
          screen[line][column],
          cellWidth: cellWidth,
          cellHeight: cellHeight,
          dpr: dpr,
        );
      }
    }

    final statusCode = minmodel.isConnected ? 0x43 : 0x46;
    final statusChar = TMinitelChar(0, kAttrInverse + kColorWhite, statusCode);
    final statusColumn = minmodel.minitel.columns >= 40
        ? minmodel.minitel.columns - 3
        : minmodel.minitel.columns;
    drawChar(
      canvas,
      (statusColumn - 1) * cellWidth,
      0,
      statusChar,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      dpr: dpr,
    );
  }

  // Method to draw a character
  void drawChar(
    Canvas canvas,
    double x,
    double y,
    TMinitelChar char, {
    double cellWidth = 8.0,
    double cellHeight = 10.0,
    double dpr = 1.0,
  }) {
    var fgColor = MinSettings().colors[char.lAttr & kColorMask];
    var bgColor = MinSettings().colors[char.gAttr & kColorMask];

    // Manage the cursor
    if (minmodel.minitel.cursorOn &&
        minmodel.showBlink &&
        (minmodel.minitel.state.c - 1) * cellWidth == x &&
        minmodel.minitel.state.l * cellHeight == y) {
      fgColor = MinSettings().colors[7 - (char.lAttr & kColorMask)];
      bgColor = MinSettings().colors[7 - (char.gAttr & kColorMask)];
    }

    // Swap the foreground and background colors if the inverse attribute is set
    if ((char.lAttr & kAttrInverse) != 0) {
      // If blinking attribute is set, set foreground color to background color
      if ((char.lAttr & kAttrBlink) != 0 && !minmodel.showBlink) {
        bgColor = fgColor;
      }
      final tmp = fgColor;
      fgColor = bgColor;
      bgColor = tmp;
    } else {
      if ((char.lAttr & kAttrBlink) != 0 && minmodel.showBlink) {
        fgColor = bgColor;
      }
    }

    // Draw the background color
    final bgRect = _snapRect(x, y, cellWidth, cellHeight, dpr);
    canvas.drawRect(
      bgRect,
      Paint()
        ..color = bgColor
        ..isAntiAlias = false,
    );

    // If the character is a part of a double character stop rendering here
    if ((char.lAttr & kDoublePart) != 0) return;

    // Compute scale factors and adjust y position given the size attributes
    double scaleWidth = (char.lAttr & kAttrDoubleWidth) != 0 ? 2.0 : 1.0;
    scaleWidth *= cellWidth / 8.0;
    double scaleHeight = 1.0;
    if ((char.lAttr & kAttrDoubleHeight) != 0 && y >= cellHeight) {
      y -= cellHeight;
      scaleHeight = 2.0;
    }
    scaleHeight *= cellHeight / 10.0;

    // Get the character image from the font image
    final code = char.code;
    final charRect = Rect.fromLTWH(
        8 * (code ~/ 16).toDouble(), 10 * (code % 16).toDouble(), 8, 10);

    final glyphRect = _snapRect(
      x,
      y,
      8.0 * scaleWidth,
      10.0 * scaleHeight,
      dpr,
    );

    // Draw the character in the foreground color
    final ui.Image font = (char.gAttr & kCharsetMask) != kG1Charset
        ? MinSettings().fontG0G2
        : MinSettings().fontG1;
    canvas.drawImageRect(
      font,
      charRect,
      glyphRect,
      Paint()
        ..isAntiAlias = false
        ..filterQuality = FilterQuality.none
        ..colorFilter = ColorFilter.mode(fgColor, BlendMode.srcIn),
    );

    // Draw underline if applicable (only for G0/G2 charset, not espsep)
    if ((char.gAttr & kAttrUnderline) != 0 &&
        (char.gAttr & kCharsetMask) != kG1Charset &&
        (char.gAttr & kAttrSpace) == 0) {
      canvas.drawRect(
        _snapRect(
          x,
          y + 9.0 * scaleHeight,
          8.0 * scaleWidth,
          scaleHeight,
          dpr,
        ),
        Paint()
          ..color = fgColor
          ..isAntiAlias = false,
      );
    }

    // Draw disjointed if applicable (only for G1 charset)
    if ((char.gAttr & kAttrDisjointed) != 0 &&
        (char.gAttr & kCharsetMask) == kG1Charset) {
      _drawDisjointMask(
        canvas,
        x,
        y,
        scaleWidth,
        scaleHeight,
        bgColor,
        dpr,
      );
    }
  }

  // Method to draw a string
  void drawString(
    Canvas canvas,
    double x,
    double y,
    TMinitelChar attr,
    String str, {
    double cellWidth = 8.0,
    double cellHeight = 10.0,
    double dpr = 1.0,
  }) {
    double stepX =
        (attr.lAttr & kAttrDoubleWidth) != 0 ? 2 * cellWidth : cellWidth;
    for (var i = 0; i < str.length; i++) {
      drawChar(
        canvas,
        x + i * stepX,
        y,
        TMinitelChar(attr.gAttr, attr.lAttr, str.codeUnitAt(i)),
        cellWidth: cellWidth,
        cellHeight: cellHeight,
        dpr: dpr,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!MinSettings().isLoaded) return;

    // Draw the screen
    draw(canvas, size);

    // drawString(
    //   canvas,
    //   10 * 8,
    //   0,
    //   TMinitelChar(kColorBlack, (kColorWhite - 4) | kAttrInverse, 0),
    //   " Flutter MinWidget ",
    // );
  }

  @override
  bool shouldRepaint(_MinPainter oldDelegate) {
    return minmodel.minitel.isDirty;
  }
}

class MinKeyboard extends StatelessWidget {
  const MinKeyboard({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinModel(),
      builder: (context, child) {
        if (MinModel().screenMode == TMinitelScreenMode.vt10080) {
          return const MinVt100Keyboard();
        }
        return const MinMinitelKeyboard();
      },
    );
  }
}

/// Compact keyboard for Minitel 40-column mode.
class MinMinitelKeyboard extends StatelessWidget {
  const MinMinitelKeyboard({super.key});

  static const _row1 = [
    ['Cx/Fin', TMinitelKey.cxFin],
    ['Répétition', TMinitelKey.repetition],
    ['Sommaire', TMinitelKey.sommaire],
    ['Guide', TMinitelKey.guide],
    ['Annulation', TMinitelKey.annulation],
    ['Correction', TMinitelKey.correction],
    ['Envoi', TMinitelKey.envoi],
  ];

  static const _row2 = [
    ['Esc', '\x1b'],
    ['Suite', TMinitelKey.suite],
    ['Retour', TMinitelKey.retour],
    ['Espace', ' '],
    ['↑', TMinitelKey.arrowUp],
    ['↓', TMinitelKey.arrowDown],
    ['←', TMinitelKey.arrowLeft],
    ['→', TMinitelKey.arrowRight],
    ['Entrée', '\r'],
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinSettings(),
      builder: (context, child) {
        final scale = MinSettings().scale;
        return LayoutBuilder(
          builder: (context, constraints) {
            final displayColumns = 80;
            final displayWidth = 8.0 * displayColumns;
            final displayHeight = displayWidth * 3.0 / 4.0;

            final maxWidth = constraints.maxWidth;
            final maxHeight = constraints.maxHeight;
            if (!maxWidth.isFinite) {
              return const SizedBox.shrink();
            }

            final fittedScale =
                math.min(maxWidth / displayWidth, maxHeight / displayHeight);
            final keyboardWidth = displayWidth * fittedScale;

            return Center(
              child: SizedBox(
                width: keyboardWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRow(_row1, scale),
                    _buildRow(_row2, scale),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRow(List<List<String>> keys, double scale) {
    return Row(
      children: keys.map((entry) {
        final label = entry[0];
        return Expanded(
          flex: _keyFlex(label),
          child: SizedBox(
            height: 24 * scale,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey),
                ),
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
              ),
              onPressed: () => MinModel().handleKeys(entry[1]),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10 * scale),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  int _keyFlex(String label) {
    if (label == 'Espace') return 3;
    if (label == 'Esc') return 1;
    return label == '↑' || label == '↓' || label == '←' || label == '→' ? 1 : 2;
  }
}

/// Compact function-key bar shown in VT100 80-column mode.
class MinVt100Keyboard extends StatelessWidget {
  const MinVt100Keyboard({super.key});

  static const _row1 = [
    ['ESC', '\x1b'],
    ['F1', '\x1bOP'],
    ['F2', '\x1bOQ'],
    ['F3', '\x1bOR'],
    ['F4', '\x1bOS'],
    ['F5', '\x1b[15~'],
    ['F6', '\x1b[17~'],
    ['F7', '\x1b[18~'],
    ['F8', '\x1b[19~'],
    ['F9', '\x1b[20~'],
    ['F10', '\x1b[21~'],
  ];

  static const _row2 = [
    ['Tab', '\t'],
    ['BackSp', '\x7f'],
    ['\u2191', '\x1b[A'],
    ['\u2193', '\x1b[B'],
    ['\u2190', '\x1b[D'],
    ['\u2192', '\x1b[C'],
    ['Home', '\x1b[H'],
    ['End', '\x1b[F'],
    ['PgUp', '\x1b[5~'],
    ['PgDn', '\x1b[6~'],
    ['Del', '\x1b[3~'],
    ['Entr\u00e9e', '\r'],
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MinSettings(),
      builder: (context, child) {
        final scale = MinSettings().scale;
        return LayoutBuilder(
          builder: (context, constraints) {
            final displayColumns = 80;
            final displayWidth = 8.0 * displayColumns;
            final displayHeight = displayWidth * 3.0 / 4.0;

            final maxWidth = constraints.maxWidth;
            final maxHeight = constraints.maxHeight;
            if (!maxWidth.isFinite) {
              return const SizedBox.shrink();
            }

            final fittedScale =
                math.min(maxWidth / displayWidth, maxHeight / displayHeight);
            final keyboardWidth = displayWidth * fittedScale;

            return Center(
              child: SizedBox(
                width: keyboardWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRow(_row1, scale),
                    _buildRow(_row2, scale),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRow(List<List<String>> keys, double scale) {
    return Row(
      children: keys.map((entry) {
        return Expanded(
          child: SizedBox(
            height: 24 * scale,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey),
                ),
                backgroundColor: const Color(0xFF212121),
                foregroundColor: Colors.white,
              ),
              onPressed: () => MinModel().handleKeys(entry[1]),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  entry[0],
                  style: TextStyle(fontSize: 10 * scale),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
