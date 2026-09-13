import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minterm/min/min_emulator.dart';
import 'package:minterm/min/min_model.dart';
import 'package:minterm/min/min_widget.dart';

String readChar(TMinitel minitel, int x, int y) {
  final code = minitel.screen[y][x + 1].code & ~kIsDirty;
  return String.fromCharCode(code);
}

// US 0x1F suivi de (0x40+ligne, 0x40+colonne) : positionnement curseur
// Minitel. Colonnes 1-indexées (0x41 = colonne 1) : voir setCursorPosition.
List<int> cursorTo(int line, int column) => [0x1F, 0x40 + line, 0x40 + column];

void main() {
  setUp(() {
    MinModel().disconnectAndClearScreen();
    MinModel().isEchoed = true;
    // Vitesse max : pasteText() traite tout de suite (comme emulate()), sans
    // quoi le débit throttlé retarderait l'injection via un Timer basé sur
    // l'horloge réelle.
    MinModel().bps = 0;
    MinModel().minitel.emulate(cursorTo(5, 1));
  });

  testWidgets('pasteText injects plain ASCII characters as typed keys', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MinScreen())),
    );

    MinModel().pasteText('Bonjour');
    await tester.pump();

    for (var i = 0; i < 'Bonjour'.length; i++) {
      expect(readChar(MinModel().minitel, i, 5), 'Bonjour'[i]);
    }
  });

  testWidgets(
      'pasteText converts accented/special characters via the SS2 sequence '
      'a physical Minitel keyboard would send', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MinScreen())),
    );

    MinModel().pasteText('café à 5°C, Œuf: ½');
    await tester.pump();

    final minitel = MinModel().minitel;
    expect(readChar(minitel, 0, 5), 'c');
    expect(readChar(minitel, 1, 5), 'a');
    expect(readChar(minitel, 2, 5), 'f');
    // Codes internes du jeu G2 (putChar ne conserve pas le bit de charset
    // pour G0/G2, seul G1 est distingué : le rendu utilise la même police
    // pour G0 et G2, voir _MinPainter.drawChar).
    expect(readChar(minitel, 3, 5).codeUnitAt(0), 0x13); // é
    expect(readChar(minitel, 5, 5).codeUnitAt(0), 0x10); // à
    expect(readChar(minitel, 8, 5).codeUnitAt(0), 0x05); // °
    expect(readChar(minitel, 12, 5).codeUnitAt(0), 0x0B); // Œ
    expect(readChar(minitel, 17, 5).codeUnitAt(0), 0x09); // ½
  });

  testWidgets(
      'pasteText sends the same Envoi wire sequence as pressing Enter would '
      '(no local newline: a real Minitel keyboard does not draw one either)',
      (WidgetTester tester) async {
    MinModel().setScreenMode(TMinitelScreenMode.videotex40);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MinScreen())),
    );

    MinModel().pasteText('AB\nCD');
    await tester.pump();

    // SEP (0x13) + 'A' (Envoi) est absorbé par le décodeur d'affichage sans
    // avancer le curseur ni rien afficher, exactement comme quand ces mêmes
    // octets sont produits par une vraie touche Envoi en écho local :
    // "CD" s'écrit donc à la suite de "AB" sur la même ligne.
    final minitel = MinModel().minitel;
    expect(readChar(minitel, 0, 5), 'A');
    expect(readChar(minitel, 1, 5), 'B');
    expect(readChar(minitel, 2, 5), 'C');
    expect(readChar(minitel, 3, 5), 'D');
  });

  testWidgets(
      'pasteText normalizes smart punctuation with no Minitel equivalent',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MinScreen())),
    );

    MinModel().pasteText('“It’s a test…”');
    await tester.pump();

    final minitel = MinModel().minitel;
    expect(readChar(minitel, 0, 5), '"');
    expect(readChar(minitel, 1, 5), 'I');
    expect(readChar(minitel, 2, 5), 't');
    expect(readChar(minitel, 3, 5), "'");
    expect(readChar(minitel, 4, 5), 's');
  });

  testWidgets('pasteText silently drops characters with no Minitel equivalent',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MinScreen())),
    );

    MinModel().pasteText('A😀B');
    await tester.pump();

    final minitel = MinModel().minitel;
    expect(readChar(minitel, 0, 5), 'A');
    expect(readChar(minitel, 1, 5), 'B');
  });
}
