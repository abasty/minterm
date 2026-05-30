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
  });
}
