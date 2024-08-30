import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

Future<ui.Image> loadUiImage(String imageAssetPath) async {
  final ByteData data = await rootBundle.load(imageAssetPath);
  final Completer<ui.Image> completer = Completer();
  ui.decodeImageFromList(Uint8List.view(data.buffer), (ui.Image img) {
    return completer.complete(img);
  });
  return completer.future;
}

class FontAtlas {
  static final FontAtlas _singleton = FontAtlas._internal();
  static late final ui.Image _fontImage;

  ui.Image get fontImage => _fontImage;

  factory FontAtlas() {
    return _singleton;
  }

  FontAtlas._internal() {
    // Load the font image
    loadUiImage('assets/fonts.png').then((image) {
      _fontImage = image;
    });
  }
}

class MinWidget extends StatelessWidget {
  const MinWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 4.0,
      child: SizedBox(
        width: 8 * 40,
        height: 10 * 25,
        child: CustomPaint(
          painter: _MinPainter(),
        ),
      ),
    );
  }
}

class _MinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Clear the canvas with a black color
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

    // Draw the background color of the character
    canvas.drawRect(
      const Rect.fromLTWH(8, 10, 8, 10),
      Paint()..color = Colors.grey.shade900,
    );

    // Get the character image from the FontAtlas singleton
    final fontImage = FontAtlas().fontImage;

    // Get the character image from the font image
    const char = Rect.fromLTWH(0, 0, 8, 10);

    // Draw the character in the foreground color
    canvas.drawAtlas(
      fontImage,
      [
        RSTransform.fromComponents(
          rotation: 0.0,
          scale: 1.0,
          anchorX: 0.0,
          anchorY: 0.0,
          translateX: 8.0,
          translateY: 10.0,
        ),
      ],
      [
        char,
      ],
      [
        Colors.grey.shade500,
      ],
      BlendMode.dstIn,
      null,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(_MinPainter oldDelegate) {
    return false;
  }
}
