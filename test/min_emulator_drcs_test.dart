import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:minterm/min_emulator.dart';

// STUM2 §2.3.5 example: 14 bytes encoding an 8×10 glyph (arrow/pointer shape)
// Bytes are in 4/0–7/F range (0x40–0x7F), each carrying 6 pixels b5..b0.
const List<int> _exampleGlyphBytes = [
  0x44, 0x43, 0x60, 0x50, 0x44, 0x41, 0x40, 0x68, 0x51, 0x44, 0x50, 0x68,
  0x44, 0x40,
];

// Expected pixel matrix decoded b5-first, row-major, 8 cols × 10 rows.
// '#' = 1, '.' = 0
const List<String> _expectedRows = [
  '...#....',
  '..###...',
  '...#....',
  '...#....',
  '...#....',
  '..#.#...',
  '.#...#..',
  '.#...#..',
  '..#.#...',
  '...#....',
];

// Build G'0 header sequence (just announces charset type, no glyph data).
List<int> _buildDrcsHeader({bool g1 = false}) {
  return [
    0x1F, 0x23,                    // US 0x23 → DRCS header
    0x20, 0x20, 0x20,              // three 0x20 intermediate bytes
    g1 ? 0x43 : 0x42,             // 0x42 = G'0, 0x43 = G'1
    0x49,                          // validation byte
  ];
}

// Build glyph data sequence starting at charCode.
// STUM2 format: US 0x23 Y [B1 <14 bytes>]+ B1(flush)
List<int> _buildDrcsGlyphData(int startCharCode, List<List<int>> glyphs) {
  return [
    0x1F, 0x23, startCharCode, // US 0x23 Y → enters kStateDrcsData
    for (final g in glyphs) ...[0x30, ...g], // B1 + 14 bytes per glyph
    0x30,                      // final B1 to flush last glyph
  ];
}

void main() {
  group('DRCS bit decoding', () {
    test('b5-first pixel ordering matches STUM2 §2.3.5 example', () {
      final minitel = TMinitel();

      bool callbackFired = false;
      bool isG1Result = false;
      int codeResult = 0;
      late Uint8List pixelsResult;

      minitel.onDrcsGlyph = (bool isG1, int code, Uint8List pixels80) {
        callbackFired = true;
        isG1Result = isG1;
        codeResult = code;
        pixelsResult = Uint8List.fromList(pixels80);
      };

      minitel.emulate([
        ..._buildDrcsHeader(g1: false),
        ..._buildDrcsGlyphData(0x21, [_exampleGlyphBytes]),
      ]);

      expect(callbackFired, isTrue, reason: 'onDrcsGlyph callback must fire');
      expect(isG1Result, isFalse, reason: 'G\'0 charset');
      expect(codeResult, 0x21, reason: 'first downloadable code');
      expect(pixelsResult.length, 80);

      // Verify each row against expected pattern.
      for (int row = 0; row < 10; row++) {
        for (int col = 0; col < 8; col++) {
          final expected = _expectedRows[row][col] == '#' ? 1 : 0;
          final actual = pixelsResult[row * 8 + col];
          expect(
            actual,
            expected,
            reason: 'row=$row col=$col: '
                'expected ${_expectedRows[row][col]}, got $actual',
          );
        }
      }
    });

    test('second glyph gets code 0x22 after first B1 flush', () {
      final minitel = TMinitel();
      final codes = <int>[];

      minitel.onDrcsGlyph = (bool isG1, int code, Uint8List pixels80) {
        codes.add(code);
      };

      final seq = [
        ..._buildDrcsHeader(g1: false),
        ..._buildDrcsGlyphData(0x21, [_exampleGlyphBytes, _exampleGlyphBytes]),
      ];

      minitel.emulate(seq);

      expect(codes, [0x21, 0x22]);
    });

    test(
        'a B1 with no pixel bytes since the previous B1 emits a blank glyph '
        'and still advances the code (STUM2 §2.3.3.2/2.3.3.3)', () {
      final minitel = TMinitel();
      final events = <(int code, bool blank)>[];

      minitel.onDrcsGlyph = (bool isG1, int code, Uint8List pixels80) {
        events.add((code, pixels80.every((p) => p == 0)));
      };

      // US 0x23 Y, then B1 (opens form Y) B1 (no pixels since the previous
      // B1 -> form Y is blank) <14 bytes> B1 (flushes form Y+1).
      minitel.emulate([
        ..._buildDrcsHeader(g1: false),
        0x1F, 0x23, 0x21,
        0x30, 0x30,
        ..._exampleGlyphBytes,
        0x30,
      ]);

      expect(events, [(0x21, true), (0x22, false)]);
    });

    test('replays test/drcs/soko.drc: real-world capture with blank forms',
        () {
      // Regression test for a real download that interleaves blank forms
      // (consecutive B1 with no pixel data) between shapes, used by a
      // Sokoban game as spacers in its G'1 grid. Before the B1 fix above,
      // those blanks were silently dropped instead of consuming a code
      // slot, shifting every later glyph and scrambling the on-screen
      // sprites.
      final bytes = File('test/drcs/soko.drc').readAsBytesSync();
      final minitel = TMinitel();
      final events = <(int code, bool blank)>[];

      minitel.onDrcsGlyph = (bool isG1, int code, Uint8List pixels80) {
        events.add((code, pixels80.every((p) => p == 0)));
      };

      minitel.emulate(bytes.toList());

      expect(events.length, 32);
      expect(events.first.$1, 0x21);
      expect(events.last.$1, 0x40);

      const blankCodes = {0x21, 0x22, 0x23, 0x24, 0x2a, 0x2b};
      for (final (code, blank) in events) {
        expect(
          blank,
          blankCodes.contains(code),
          reason: 'code=0x${code.toRadixString(16)}',
        );
      }
    });
  });
}
