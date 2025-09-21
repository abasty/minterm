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
  var scale = 1.0;
  var duration = durationMax;
  var _colors = MinGrey;
  int _loaded = 0;
  bool _keyboard = false;
  bool _capslock = true;

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

  static void setScale(double scale) {
    _singleton.duration = 0;
    _singleton.scale = math.max(1.0, math.min(4.0, scale));
    _singleton.notifyListeners();
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
}

class MinScreen extends StatelessWidget {
  const MinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MinSettings(),
      child: Consumer<MinSettings>(
        builder: (context, settings, child) => ChangeNotifierProvider(
          create: (context) => MinModel(),
          child: SizedBox(
            width: 8 * 40 * MinSettings().scale,
            height: 10 * 25 * MinSettings().scale,
            child: Consumer<MinModel>(
              builder: (context, minmodel, child) => Transform.scale(
                scale: MinSettings().scale,
                alignment: Alignment.topLeft,
                child: Stack(
                  children: [
                    GestureDetector(
                      onTapDown: (TapDownDetails details) {
                        final tapPosition = details.localPosition;
                        final x = (tapPosition.dx / 8.0).toInt();
                        final y = (tapPosition.dy / 10.0).toInt();
                        minmodel.handleTap(x, y);
                      },
                    ),
                    CustomPaint(
                      painter: _MinPainter(minmodel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MinPainter extends CustomPainter {
  final MinModel minmodel;

  _MinPainter(this.minmodel);

  void draw(Canvas canvas) {
    var screen = minmodel.minitel.screen;
    if (minmodel.minitel.bip) {
      final player = AudioPlayer();
      player.play(AssetSource('min_bip.wav'), mode: PlayerMode.lowLatency);
      minmodel.minitel.bip = false;
    }
    screen[0][41].code &= ~kIsDirty;
    for (int line = 0; line <= 24; ++line) {
      screen[line][0].code &= ~kIsDirty;
      for (int column = 40; column >= 1; --column) {
        screen[line][column].code &= ~kIsDirty;
        drawChar(
          canvas,
          (column - 1) * 8.0,
          line * 10.0,
          screen[line][column],
        );
      }
    }

    final statusCode = minmodel.isConnected ? 0x43 : 0x46;
    final statusChar = TMinitelChar(0, kAttrInverse + kColorWhite, statusCode);
    drawChar(canvas, 36 * 8, 0, statusChar);
  }

  // Method to draw a character
  void drawChar(Canvas canvas, double x, double y, TMinitelChar char) {
    var fgColor = MinSettings().colors[char.lAttr & kColorMask];
    var bgColor = MinSettings().colors[char.gAttr & kColorMask];

    // Manage the cursor
    if (minmodel.minitel.cursorOn &&
        minmodel.showBlink &&
        minmodel.minitel.state.c * 8 - 8 == x &&
        minmodel.minitel.state.l * 10 == y) {
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
    canvas.drawRect(Rect.fromLTWH(x, y, 8, 10), Paint()..color = bgColor);

    // If the character is a part of a double character stop rendering here
    if ((char.lAttr & kDoublePart) != 0) return;

    // Compute scale factors and adjust y position given the size attributes
    double scaleWidth = (char.lAttr & kAttrDoubleWidth) != 0 ? 2.0 : 1.0;
    double scaleHeight = 1.0;
    if ((char.lAttr & kAttrDoubleHeight) != 0 && y >= 10) {
      y -= 10.0;
      scaleHeight = 2.0;
    }

    // Get the character image from the font image
    final code = char.code;
    final charRect = Rect.fromLTWH(
        8 * (code ~/ 16).toDouble(), 10 * (code % 16).toDouble(), 8, 10);

    // Draw the character in the foreground color
    final ui.Image font = (char.gAttr & kCharsetMask) != kG1Charset
        ? MinSettings().fontG0G2
        : MinSettings().fontG1;
    canvas.drawImageRect(
      font,
      charRect,
      Rect.fromLTWH(x, y, 8.0 * scaleWidth, 10.0 * scaleHeight),
      Paint()..colorFilter = ColorFilter.mode(fgColor, BlendMode.srcIn),
    );

    // Draw underline if applicable (only for G0/G2 charset, not espsep)
    if ((char.gAttr & kAttrUnderline) != 0 &&
        (char.gAttr & kCharsetMask) != kG1Charset &&
        (char.gAttr & kAttrSpace) == 0) {
      canvas.drawRect(
        Rect.fromLTWH(x, y + 9.0 * scaleHeight, 8.0 * scaleWidth, scaleHeight),
        Paint()..color = fgColor,
      );
    }

    // Draw disjointed if applicable (only for G1 charset)
    if ((char.gAttr & kAttrDisjointed) != 0 &&
        (char.gAttr & kCharsetMask) == kG1Charset) {
      // Get the disjoint mask
      const maskRect = Rect.fromLTWH(0, 0, 8, 10);
      // Apply disjoint mask on character
      canvas.drawImageRect(
        font,
        maskRect,
        Rect.fromLTWH(x, y, 8.0 * scaleWidth, 10.0 * scaleHeight),
        Paint()..colorFilter = ColorFilter.mode(bgColor, BlendMode.srcIn),
      );
    }
  }

  // Method to draw a string
  void drawString(
      Canvas canvas, double x, double y, TMinitelChar attr, String str) {
    double stepX = (attr.lAttr & kAttrDoubleWidth) != 0 ? 16.0 : 8.0;
    for (var i = 0; i < str.length; i++) {
      drawChar(
        canvas,
        x + i * stepX,
        y,
        TMinitelChar(attr.gAttr, attr.lAttr, str.codeUnitAt(i)),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!MinSettings().isLoaded) return;

    // Draw the screen
    draw(canvas);

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
    return ChangeNotifierProvider(
      create: (context) => MinSettings(),
      child: Consumer<MinSettings>(
        builder: (context, settings, child) => ChangeNotifierProvider(
          create: (context) => MinSettings(),
          child: SizedBox(
            width: 8 * 40 * MinSettings().scale,
            height: 10 * 25 * MinSettings().scale,
            child: Stack(
              children: [
                MinKeyboardImage(),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      width: 0.5,
                      color: Colors.black,
                    ),
                  ),
                ),
                // Function keys
                MinKey(left: 5, top: 10, width: 35, k: TMinitelKey.cxFin),
                for (int i = 0; i < 4; i++)
                  MinKey(
                    left: 66 + i * 40,
                    top: 36,
                    width: 35,
                    k: [
                      TMinitelKey.sommaire,
                      TMinitelKey.annulation,
                      TMinitelKey.retour,
                      TMinitelKey.repetition,
                    ][i],
                    ks: [
                      TMinitelKey.circonflexe,
                      "\\",
                      TMinitelKey.aigu,
                      "{",
                    ][i],
                    kc: [
                      "\x00",
                      TMinitelKey.livre,
                      TMinitelKey.OE,
                      TMinitelKey.oe,
                    ][i],
                  ),
                for (int i = 0; i < 4; i++)
                  MinKey(
                    left: 66 + i * 40,
                    top: 63,
                    width: 35,
                    k: [
                      TMinitelKey.guide,
                      TMinitelKey.correction,
                      TMinitelKey.suite,
                      TMinitelKey.envoi,
                    ][i],
                    ks: [
                      TMinitelKey.trema,
                      TMinitelKey.paragraph,
                      TMinitelKey.grave,
                      "}",
                    ][i],
                    kc: [
                      "\x00",
                      "${TMinitelKey.cedille}c",
                      TMinitelKey.beta,
                      "\x00",
                    ][i],
                  ),
                for (int i = 0; i < 3; i++)
                  MinKey(
                    left: 237 + i * 29,
                    top: 8,
                    k: "123"[i],
                    ks: "!\"#"[i],
                  ),
                for (int i = 0; i < 3; i++)
                  MinKey(
                    left: 237 + i * 29,
                    top: 34,
                    k: "456"[i],
                    ks: "\$%&"[i],
                  ),
                for (int i = 0; i < 3; i++)
                  MinKey(
                    left: 237 + i * 29,
                    top: 60,
                    k: "789"[i],
                    ks: "'()"[i],
                  ),
                for (int i = 0; i < 3; i++)
                  MinKey(
                    left: 237 + i * 29,
                    top: 86,
                    k: "*0#"[i],
                    ks: [
                      "[",
                      TMinitelKey.flecheHaut,
                      "]",
                    ][i],
                  ),
                MinKey(left: 37, top: 120, k: '\x1b'), // Escape key
                // Special chars
                for (int i = 0; i < 7; i++)
                  MinKey(
                    left: 67 + i * 30,
                    top: 120,
                    k: ",.';-:?"[i],
                    ks: "<>@+=*/"[i],
                  ),
                // AZERTY first line
                for (int i = 0; i < 10; i++)
                  MinKey(
                    left: 26 + i * 28.8,
                    top: 147,
                    k: "AZERTYUIOP"[i],
                  ),
                // AZERTY second line
                MinKey(
                  left: 6,
                  top: 173,
                  width: 25,
                  k: "ctrl",
                ),
                for (int i = 0; i < 10; i++)
                  MinKey(
                    left: 34 + i * 28.8,
                    top: 173,
                    k: "QSDFGHJKLM"[i],
                  ),
                MinKey(
                  left: 20,
                  top: 199,
                  width: 25,
                  k: "shift",
                ),
                // AZERTY third line
                for (int i = 0; i < 6; i++)
                  MinKey(
                    left: 49 + i * 28.8,
                    top: 199,
                    k: "WXCVBN"[i],
                  ),
                MinKey(
                  left: 221,
                  top: 199,
                  width: 25,
                  k: "shift",
                ),
                MinKey(
                  left: 6,
                  top: 225,
                  width: 25,
                  k: TMinitelKey.arrowUp,
                ),
                MinKey(
                  left: 35,
                  top: 225,
                  width: 25,
                  k: TMinitelKey.arrowDown,
                ),
                MinKey(
                  left: 64,
                  top: 225,
                  width: 142,
                  k: " ",
                ),
                MinKey(
                  left: 210,
                  top: 225,
                  width: 25,
                  k: TMinitelKey.arrowLeft,
                  kc: "\x7f",
                ),
                MinKey(
                  left: 239,
                  top: 225,
                  width: 25,
                  k: TMinitelKey.arrowRight,
                ),
                MinKey(
                  left: 282,
                  top: 226,
                  width: 35,
                  k: "\x0d",
                  ks: "\x1e",
                  kc: "\x0c",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MinKeyboardImage extends StatelessWidget {
  const MinKeyboardImage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/clavier.png"),
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}

class MinKey extends StatelessWidget {
  final double left;
  final double top;
  final double width;
  final double height;
  final String k;
  final String ks;
  final String kc;

  const MinKey({
    super.key,
    this.left = 0,
    this.top = 0,
    this.width = 25,
    this.height = 20,
    this.k = "",
    this.ks = "",
    this.kc = "",
  });

  @override
  Widget build(BuildContext context) {
    final scale = MinSettings().scale;
    return Positioned(
      left: left * scale,
      top: top * scale,
      width: width * scale,
      height: height * scale,
      child: InkWell(
        hoverColor: Colors.grey,
        splashColor: const ui.Color.fromARGB(255, 107, 66, 0),
        child: kDebugMode
            ? Container(
                decoration: BoxDecoration(
                  border: Border.all(width: 1, color: Colors.red),
                ),
              )
            : null,
        onTap: () {
          final player = AudioPlayer();
          player.play(AssetSource('key_min.wav'), mode: PlayerMode.lowLatency);

          final letters = RegExp('^[A-Z]\$');
          final shifted = MinModel().isShifted;
          final ctrl = MinModel().isCtrl;
          final upMode = MinSettings().capslock;
          var key = '';
          if (letters.hasMatch(k)) {
            if (k.toUpperCase() == 'G' && ctrl) {
              key = '\x07';
            } else {
              key = (shifted && upMode) || (!shifted && !upMode)
                  ? k.toLowerCase()
                  : k;
            }
          } else {
            if (ctrl && kc.isNotEmpty) {
              key = kc;
            } else {
              key = shifted && ks.isNotEmpty ? ks : k;
            }
          }
          MinModel().handleKeys(key);
        },
      ),
    );
  }
}
