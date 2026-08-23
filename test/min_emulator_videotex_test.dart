import 'package:flutter_test/flutter_test.dart';
import 'package:minterm/min_emulator.dart';

String readLine(TMinitel minitel, int y, int width) {
  return String.fromCharCodes(
    List.generate(width, (index) => readChar(minitel, index, y).codeUnitAt(0)),
  );
}

String readChar(TMinitel minitel, int x, int y) {
  final code = minitel.screen[y][x + 1].code & ~kIsDirty;
  return String.fromCharCode(code);
}

// US 0x1F suivi de (0x40+ligne, 0x40+colonne) : positionnement curseur Minitel.
List<int> cursorTo(int line, int column) => [0x1F, 0x40 + line, 0x40 + column];

void main() {
  group('TMinitel Videotex 40 cols character insert mode', () {
    late TMinitel minitel;

    setUp(() {
      minitel = TMinitel();
      expect(minitel.screenMode, TMinitelScreenMode.videotex40);
    });

    test('ESC[4h shifts following characters right on write', () {
      minitel.emulate('ABCDE'.codeUnits);
      minitel.emulate('\x1b[4h'.codeUnits);
      minitel.emulate(cursorTo(1, 3));
      minitel.emulate('XYZ'.codeUnits);
      expect(readLine(minitel, 1, 8), 'ABXYZCDE');
    });

    test('ESC[4l restores overwrite behaviour', () {
      minitel.emulate('ABCDE'.codeUnits);
      minitel.emulate('\x1b[4h'.codeUnits);
      minitel.emulate('\x1b[4l'.codeUnits);
      minitel.emulate(cursorTo(1, 3));
      minitel.emulate('Q'.codeUnits);
      expect(readLine(minitel, 1, 6), 'ABQDE ');
    });

    test('insert mode is reset by a full screen clear', () {
      minitel.emulate('\x1b[4h'.codeUnits);
      minitel.emulate(TMinitelKey.ePage.codeUnits); // Envoi/PageAcceuil: clearScreen
      minitel.emulate('ABCDE'.codeUnits);
      minitel.emulate(cursorTo(1, 3));
      minitel.emulate('Q'.codeUnits);
      expect(readLine(minitel, 1, 6), 'ABQDE ');
    });

    test('insert mode does not leak across a round trip through Téléinformatique 80 cols',
        () {
      minitel.setScreenMode(TMinitelScreenMode.teleinfo80);
      minitel.emulate('\x1b[4h'.codeUnits);
      minitel.setScreenMode(TMinitelScreenMode.videotex40);
      minitel.emulate('ABCDE'.codeUnits);
      minitel.emulate(cursorTo(1, 3));
      minitel.emulate('Q'.codeUnits);
      expect(readLine(minitel, 1, 6), 'ABQDE ');
    });
  });
}
