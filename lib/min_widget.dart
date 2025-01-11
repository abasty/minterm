import 'dart:async';
import 'dart:math' as math; // Add this line to import the 'math' library
import 'dart:ui' as ui;

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
  Colors.grey[800]!,
  Colors.grey[600]!,
  Colors.grey[400]!,
  Colors.grey[850]!,
  Colors.grey[700]!,
  Colors.grey[500]!,
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
  var scale = 1.0;
  var duration = 200;
  var _colors = MinGrey;
  int _loaded = 0;
  bool _keyboard = true;

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

  get keyboard => _keyboard;

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
    _singleton.duration = 200;
    _singleton._keyboard = !_singleton._keyboard;
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
                child: CustomPaint(
                  painter: _MinPainter(minmodel),
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
  }

  // Method to draw a character
  void drawChar(Canvas canvas, double x, double y, TMinitelChar char) {
    var fgColor = MinSettings().colors[char.lAttr & kColorMask];
    var bgColor = MinSettings().colors[char.gAttr & kColorMask];

    // Swap the foreground and background colors if the inverse attribute is set
    if ((char.lAttr & kAttrInverse) != 0) {
      final tmp = fgColor;
      fgColor = bgColor;
      bgColor = tmp;
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

    // TODO: Draw the cursor
  }

  @override
  bool shouldRepaint(_MinPainter oldDelegate) {
    return minmodel.minitel.isDirty;
  }
}
