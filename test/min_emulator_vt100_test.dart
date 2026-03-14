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

void main() {
  group('TMinitel mode switching sequences', () {
    test('ESC : 2 } switches to VT100 80 columns', () {
      final minitel = TMinitel();
      expect(minitel.screenMode, TMinitelScreenMode.videotex40);
      expect(minitel.columns, 40);

      minitel.emulate([0x1B, 0x3A, 0x32, 0x7D]);

      expect(minitel.screenMode, TMinitelScreenMode.vt10080);
      expect(minitel.columns, 80);
    });

    test('ESC : 2 ~ switches back to Videotex 40 columns', () {
      final minitel = TMinitel();
      minitel.setScreenMode(TMinitelScreenMode.vt10080);
      expect(minitel.columns, 80);

      minitel.emulate([0x1B, 0x3A, 0x32, 0x7E]);

      expect(minitel.screenMode, TMinitelScreenMode.videotex40);
      expect(minitel.columns, 40);
    });
  });

  group('TMinitel Videotex', () {
    test('RS resets attributes and homes cursor', () {
      final minitel = TMinitel();

      minitel.emulate([0x0E]);
      expect(minitel.state.charset, kG1Charset);

      minitel.emulate([0x1B, 0x50]);
      expect(minitel.state.bgColor, 0);
      expect(minitel.state.needAttrSpace, isTrue);

      minitel.emulate([0x1E]);

      expect(minitel.state.l, 1);
      expect(minitel.state.c, 1);
      expect(minitel.state.charset, kG0Charset);
      expect(minitel.state.bgColor, kColorBlack);
      expect(minitel.state.needAttrSpace, isFalse);
    });
  });

  group('TMinitel VT100', () {
    late TMinitel minitel;

    setUp(() {
      minitel = TMinitel();
      minitel.setScreenMode(TMinitelScreenMode.vt10080);
    });

    test('switches to 80-column mode and clears screen', () {
      expect(minitel.columns, 80);
      expect(minitel.rows, 25);
      expect(minitel.cursorOn, isTrue);
      expect(minitel.scrollOn, isTrue);
      expect(readLine(minitel, 1, 5), '     ');
    });

    test('writes text and moves cursor with CSI H', () {
      minitel.emulate('ABC'.codeUnits);
      minitel.emulate('\x1b[2;10H'.codeUnits);
      minitel.emulate('Z'.codeUnits);

      expect(readLine(minitel, 1, 3), 'ABC');
      expect(readChar(minitel, 9, 2), 'Z');
      expect(minitel.state.l, 2);
      expect(minitel.state.c, 11);
    });

    test('applies SGR colors and erase line', () {
      minitel.emulate('\x1b[31;44mA'.codeUnits);
      final char = minitel.screen[1][1];

      expect(char.lAttr & kColorMask, 1);
      expect(char.gAttr & kColorMask, 4);

      minitel.emulate('BCDE'.codeUnits);
      minitel.emulate('\x1b[3G\x1b[K'.codeUnits);

      expect(readLine(minitel, 1, 5), 'AB   ');
    });

    test('saves and restores cursor with CSI s/u', () {
      minitel.emulate('\x1b[10;20H\x1b[s\x1b[1;1HA\x1b[uB'.codeUnits);

      expect(readChar(minitel, 0, 1), 'A');
      expect(readChar(minitel, 19, 10), 'B');
      expect(minitel.state.l, 10);
      expect(minitel.state.c, 21);
    });
  });
}
