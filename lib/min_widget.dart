import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math; // Add this line to import the 'math' library

import 'package:flutter/services.dart';
import 'min_emulator.dart';

Future<ui.Image> loadUiImage(String imageAssetPath) async {
  final ByteData data = await rootBundle.load(imageAssetPath);
  final Completer<ui.Image> completer = Completer();
  ui.decodeImageFromList(Uint8List.view(data.buffer), (ui.Image img) {
    return completer.complete(img);
  });
  return completer.future;
}

// ignore: non_constant_identifier_names
final MinColors = [
  Colors.black,
  Colors.grey[850],
  Colors.grey[800],
  Colors.grey[700],
  Colors.grey[600],
  Colors.grey[500],
  Colors.grey[400],
  Colors.white,
];

class MinFonts extends ChangeNotifier {
  static final MinFonts _singleton = MinFonts._internal();

  static late final ui.Image _fontG0G2;
  static late final ui.Image _fontG1;
  int _loaded = 0;

  ui.Image get fontG0G2 => _fontG0G2;
  ui.Image get fontG1 => _fontG1;
  bool get isLoaded => _loaded == 2;

  factory MinFonts() {
    return _singleton;
  }

  MinFonts._internal() {
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
}

class MinWidget extends StatelessWidget {
  const MinWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 2.5,
      child: FittedBox(
        child: SizedBox(
          width: 8 * 40,
          height: 10 * 25,
          child: CustomPaint(
            painter: _MinPainter(math.Random().nextDouble()),
          ),
        ),
      ),
    );
  }
}

class _MinPainter extends CustomPainter {
  final double repaint;

  // Add a constructor
  _MinPainter(this.repaint);

  // Method to draw a character
  void drawChar(Canvas canvas, double x, double y, TMinitelChar char) {
    if ((char.localAttr & kDoublePart) != 0) return;

    final code = char.charCode;
    var fgColor = MinColors[char.localAttr & kColorMask]!;
    var bgColor = MinColors[char.globalAttr & kColorMask]!;
    double scaleWidth = (char.localAttr & kAttrDoubleWidth) != 0 ? 2.0 : 1.0;
    double scaleHeight = (char.localAttr & kAttrDoubleHeight) != 0 ? 2.0 : 1.0;
    final ui.Image font = (char.globalAttr & kCharsetMask) != kG1Charset
        ? MinFonts().fontG0G2
        : MinFonts().fontG1;

    if ((char.localAttr & kAttrInverse) != 0) {
      final tmp = fgColor;
      fgColor = bgColor;
      bgColor = tmp;
    }

    if ((char.localAttr & kAttrDoubleHeight) != 0 && y >= 10) {
      y -= 10.0;
    } else {
      scaleHeight = 1.0;
    }

    // Display the background color of the character
    canvas.drawRect(
      Rect.fromLTWH(x, y, 8.0 * scaleWidth, 10.0 * scaleHeight),
      Paint()..color = bgColor,
    );

    // Get the character image from the font image
    final charRect = Rect.fromLTWH(
      8 * (code ~/ 16).toDouble(),
      10 * (code % 16).toDouble(),
      8,
      10,
    );

    // Create a paint object with the foreground color
    final paint = Paint()
      ..colorFilter = ColorFilter.mode(
        fgColor,
        BlendMode.srcIn,
      );

    // Draw the character in the foreground color
    canvas.drawImageRect(
      font,
      charRect,
      Rect.fromLTWH(x, y, 8.0 * scaleWidth, 10.0 * scaleHeight),
      paint,
    );
  }

  // Method to draw a string
  void drawString(
      Canvas canvas, double x, double y, TMinitelChar attr, String str) {
    double stepX = (attr.localAttr & kAttrDoubleWidth) != 0 ? 16.0 : 8.0;
    for (var i = 0; i < str.length; i++) {
      drawChar(
        canvas,
        x + i * stepX,
        y,
        TMinitelChar(attr.globalAttr, attr.localAttr, str.codeUnitAt(i)),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Clear the canvas with a black color
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

    if (!MinFonts().isLoaded) return;

    drawString(
      canvas,
      0,
      0,
      TMinitelChar(kColorBlack, kColorWhite, 0),
      "Flutter MinWidget",
    );
    drawString(
      canvas,
      0,
      10,
      TMinitelChar(kColorBlack, kColorWhite, 0),
      "(c) 2024 - Alain Basty - GPLv2",
    );

    // Draw G2 chars 0x00 to 0x1F
    drawString(
      canvas,
      0,
      50,
      TMinitelChar(kColorBlack, kColorWhite, 0),
      "Minitel font from Fr\x13d\x13ric Bisson",
    );
    for (var i = 0; i < 32; i++) {
      drawChar(
        canvas,
        i * 8,
        60,
        TMinitelChar(1, 3, i),
      );
    }

    // Draw G1 chars 0x20 to 0x3F
    for (var i = 0x20; i <= 0x3F; i++) {
      drawChar(
        canvas,
        (i - 0x20) * 8,
        80,
        TMinitelChar(kG1Charset, 7, i),
      );
    }
    // Draw G1 chars 0x60 to 0x7F
    for (var i = 0x60; i <= 0x7F; i++) {
      drawChar(
        canvas,
        (i - 0x60) * 8,
        90,
        TMinitelChar(kG1Charset, 7, i),
      );
    }
    // Draw "ABC" with double width and height
    drawString(
      canvas,
      0,
      110,
      TMinitelChar(
        kColorBlack,
        kColorWhite | kAttrDoubleHeightWidth,
        0,
      ),
      "Double Width Height",
    );
    // Draw "ABC" with double width
    drawString(
      canvas,
      0,
      120,
      TMinitelChar(
        kColorBlack,
        kColorWhite | kAttrDoubleWidth,
        0,
      ),
      "Double Width",
    );
    // Draw "ABC" with double height
    drawString(
      canvas,
      0,
      140,
      TMinitelChar(
        kColorBlack,
        kColorWhite | kAttrDoubleHeight,
        0,
      ),
      "Double Height",
    );
  }

  @override
  bool shouldRepaint(_MinPainter oldDelegate) {
    // TODO: Use minitel screen dirty flag
    return oldDelegate.repaint != repaint;
  }
}
