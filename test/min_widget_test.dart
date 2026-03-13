import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minterm/min_emulator.dart';
import 'package:minterm/min_model.dart';
import 'package:minterm/min_widget.dart';

/*
    drawString(
      canvas,
      5 * 8,
      10,
      TMinitelChar(kColorBlack, kColorWhite, 0),
      "(c) 2024 - Alain Basty - GPLv2",
    );

    // Draw G2 chars 0x00 to 0x1F
    drawString(
      canvas,
      0,
      30,
      TMinitelChar(kColorBlack, (kColorWhite - 2) | kAttrInverse, 0),
      "G0 and G2 glyphs from Fr\x13d\x13ric Bisson   ",
    );
    for (var i = 0; i < 32; i++) {
      drawChar(
        canvas,
        i * 8,
        40,
        TMinitelChar(kColorBlack, kColorWhite, i),
      );
    }

    // Draw G1 chars 0x20 to 0x3F
    drawString(
      canvas,
      0,
      60,
      TMinitelChar(kColorBlack, (kColorWhite - 2) | kAttrInverse, 0),
      "G1 glyphs from Pierre Ficheux           ",
    );
    for (var i = 0x20; i <= 0x3F; i++) {
      drawChar(
        canvas,
        (i - 0x20) * 8,
        70,
        TMinitelChar(kColorBlack | kG1Charset, kColorWhite, i),
      );
    }
    // Draw G1 chars 0x60 to 0x7F disjointed
    for (var i = 0x60; i <= 0x7F; i++) {
      drawChar(
        canvas,
        (i - 0x60) * 8,
        80,
        TMinitelChar(
          kColorBlack | kG1Charset | kAttrDisjointed,
          kColorWhite,
          i,
        ),
      );
    }
    // Draw G1 char #0
    drawChar(
      canvas,
      0,
      90,
      TMinitelChar(
        kColorBlack | kG1Charset,
        kColorWhite,
        0,
      ),
    );
    drawString(
      canvas,
      8,
      90,
      TMinitelChar(kColorBlack, kColorWhite, 0),
      " : Disjointed graphics mask",
    );

    // Draw with double width and height, underlined
    drawString(
      canvas,
      0,
      110,
      TMinitelChar(kColorBlack, (kColorWhite - 2) | kAttrInverse, 0),
      "Flutter MinWidget by Alain Basty        ",
    );
    drawString(
      canvas,
      0,
      130,
      TMinitelChar(
        kColorBlack | kAttrUnderline,
        kColorWhite | kAttrDoubleHeightWidth,
        0,
      ),
      "Double Width Height",
    );
    // Draw with double width
    drawString(
      canvas,
      0,
      140,
      TMinitelChar(
        kColorBlack,
        kColorWhite | kAttrDoubleWidth,
        0,
      ),
      "Double Width",
    );
    // Draw with double height underlined
    drawString(
      canvas,
      0,
      160,
      TMinitelChar(
        kColorBlack | kAttrUnderline,
        kColorWhite | kAttrDoubleHeight,
        0,
      ),
      "Double Height",
    );

*/

void main() {
  setUp(() {
    MinModel().setScreenMode(TMinitelScreenMode.videotex40);
  });

  testWidgets('MinWidget creation', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MinScreen(),
        ),
      ),
    );

    expect(find.byType(MinScreen), findsOneWidget);
  });

  testWidgets('Virtual keyboard is hidden in VT100 mode', (
    WidgetTester tester,
  ) async {
    MinModel().setScreenMode(TMinitelScreenMode.vt10080);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MinKeyboard(),
        ),
      ),
    );

    expect(find.byType(MinKeyboardImage), findsNothing);
  });
}
