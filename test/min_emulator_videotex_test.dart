import 'package:flutter_test/flutter_test.dart';
import 'package:minterm/min/min_emulator.dart';

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

  group('Séquences magiques non standard (PRO2 0x10 / 0x11)', () {
    late TMinitel minitel;

    setUp(() {
      minitel = TMinitel();
    });

    test('PRO2 0x10 0x41/0x42/0x43/0x44 set the simulated speed', () {
      minitel.emulate([0x1b, 0x3a, 0x10, 0x41]);
      expect(minitel.speed, 1200);
      expect(minitel.speedChanged, isTrue);

      minitel.speedChanged = false;
      minitel.emulate([0x1b, 0x3a, 0x10, 0x42]);
      expect(minitel.speed, 4800);
      expect(minitel.speedChanged, isTrue);

      minitel.speedChanged = false;
      minitel.emulate([0x1b, 0x3a, 0x10, 0x43]);
      expect(minitel.speed, 9600);
      expect(minitel.speedChanged, isTrue);

      minitel.speedChanged = false;
      minitel.emulate([0x1b, 0x3a, 0x10, 0x44]);
      expect(minitel.speed, 0);
      expect(minitel.speedChanged, isTrue);
    });

    test('PRO2 0x11 0x41/0x42 toggle onColorModeChange callback', () {
      final calls = <bool>[];
      minitel.onColorModeChange = calls.add;

      minitel.emulate([0x1b, 0x3a, 0x11, 0x41]);
      minitel.emulate([0x1b, 0x3a, 0x11, 0x42]);

      expect(calls, [false, true]);
    });
  });

  group('Passage en Téléinformatique 80 colonnes', () {
    test('PRO2 31 7D (ESC : 1 }) switches to teleinfo80', () {
      final minitel = TMinitel();
      expect(minitel.screenMode, TMinitelScreenMode.videotex40);

      minitel.emulate([0x1b, 0x3a, 0x31, 0x7d]);

      expect(minitel.screenMode, TMinitelScreenMode.teleinfo80);
    });

    test('CSI ?3 l enters teleinfo80, CSI <3 h returns to videotex40 '
        '(confirmé sur M2 réel)', () {
      final minitel = TMinitel();
      expect(minitel.screenMode, TMinitelScreenMode.videotex40);

      minitel.emulate([0x1b, 0x5b, 0x3f, 0x33, 0x6c]);
      expect(minitel.screenMode, TMinitelScreenMode.teleinfo80);

      minitel.emulate([0x1b, 0x5b, 0x3c, 0x33, 0x68]);
      expect(minitel.screenMode, TMinitelScreenMode.videotex40);
    });

    test('CSI <3 l and CSI ?3 h have no effect (confirmé sur M2 réel)', () {
      final minitel = TMinitel();

      // Depuis Videotex, `<3 l` ne fait pas passer en 80 colonnes.
      minitel.emulate([0x1b, 0x5b, 0x3c, 0x33, 0x6c]);
      expect(minitel.screenMode, TMinitelScreenMode.videotex40);

      minitel.emulate([0x1b, 0x5b, 0x3f, 0x33, 0x6c]); // -> teleinfo80
      expect(minitel.screenMode, TMinitelScreenMode.teleinfo80);

      // Depuis Téléinformatique, `?3 h` ne fait pas revenir en 40 colonnes.
      minitel.emulate([0x1b, 0x5b, 0x3f, 0x33, 0x68]);
      expect(minitel.screenMode, TMinitelScreenMode.teleinfo80);
    });
  });
}
