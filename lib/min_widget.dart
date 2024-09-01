import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math; // Add this line to import the 'math' library

import 'package:flutter/services.dart';

Future<ui.Image> loadUiImage(String imageAssetPath) async {
  final ByteData data = await rootBundle.load(imageAssetPath);
  final Completer<ui.Image> completer = Completer();
  ui.decodeImageFromList(Uint8List.view(data.buffer), (ui.Image img) {
    return completer.complete(img);
  });
  return completer.future;
}

class FontAtlas extends ChangeNotifier {
  static final FontAtlas _singleton = FontAtlas._internal();
  static late final ui.Image _fontImage;
  bool _isLoaded = false;

  ui.Image get fontImage => _fontImage;

  factory FontAtlas() {
    return _singleton;
  }

  FontAtlas._internal() {
    // Load the font image
    loadUiImage('assets/g0g2.png').then((image) {
      _fontImage = image;
      _isLoaded = true;
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
  // TODO: put image atlas here

  final double repaint;

  // Add a constructor
  _MinPainter(this.repaint);

  // Method to draw a character
  void drawChar(Canvas canvas, ui.Image font, int x, int y, int char) {
    final fgColor = Colors.white;
    final bgColor = Colors.black;
    // final fgColor = Colors.grey.shade700;
    // final bgColor = Colors.grey.shade900;

    // Display the background color of the character
    canvas.drawRect(
      Rect.fromLTWH(x.toDouble(), y.toDouble(), 8, 10),
      Paint()..color = bgColor,
    );

    // Get the character image from the font image
    final charRect = Rect.fromLTWH(
      8 * (char ~/ 16).toDouble(),
      10 * (char % 16).toDouble(),
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
      Rect.fromLTWH(x.toDouble(), y.toDouble(), 8, 10),
      paint,
    );
  }

  // Method to draw a string
  void drawString(Canvas canvas, ui.Image font, int x, int y, String str) {
    for (var i = 0; i < str.length; i++) {
      drawChar(canvas, font, x + i * 8, y, str.codeUnitAt(i));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Clear the canvas with a black color
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

    if (!FontAtlas()._isLoaded) return;

    // Get the character image from the FontAtlas singleton
    final font = FontAtlas().fontImage;

    // drawChar(canvas, font, 0, 10, 65);
    drawString(canvas, font, 0, 0, "Flutter MinWidget");
    drawString(canvas, font, 0, 10, "(c) 2024 - Alain Basty - GPLv2");

    // Draw char 0x00 to 0x1F
    drawString(canvas, font, 0, 50, "Minitel font from Fr\x13d\x13ric Bisson");
    for (var i = 0; i < 32; i++) {
      drawChar(canvas, font, i * 8, 60, i);
    }
  }

  @override
  bool shouldRepaint(_MinPainter oldDelegate) {
    // TODO: Use minitel screen dirty flag
    return oldDelegate.repaint != repaint;
  }
}
