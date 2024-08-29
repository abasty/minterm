import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MinWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 3.0,
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
    // Your drawing code here
    // Use the provided canvas object to draw on the canvas

    // debug print size
    if (kDebugMode) {
      print('size: $size');
    }

    // Clear the canvas with a black color
    // canvas.drawColor(Colors.black, BlendMode.src);

    // Draw a black rectangle at the top left corner with a size of size
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

    // Create a Paint object to define the appearance of the shape
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke;

    // Draw a blue rectangle at the top left corner with a size of size
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );

    // Draw a 8 pixels width and 10 pixels height rectangle at the top left
    // corner
    paint.color = Colors.red;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, 8, 10),
      paint,
    );
  }

  @override
  bool shouldRepaint(_MinPainter oldDelegate) {
    return false;
  }
}
