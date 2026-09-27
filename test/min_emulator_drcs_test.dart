import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:minterm/min/min_emulator.dart';

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

    test(
        'US ending the download flushes the form in progress instead of '
        'dropping it (STUM2 §2.3.3.3 "Sortie du téléchargement")', () {
      final minitel = TMinitel();
      final codes = <int>[];

      minitel.onDrcsGlyph = (bool isG1, int code, Uint8List pixels80) {
        codes.add(code);
      };

      // One complete 14-byte glyph, immediately followed by US (no closing
      // B1) — the exact shape of a real-world capture (test/drcs/pacman.drc)
      // where the service ends the download on US to reposition the
      // cursor, relying on the last downloaded form still being applied.
      minitel.emulate([
        ..._buildDrcsHeader(g1: false),
        0x1F, 0x23, 0x21,
        0x30, ..._exampleGlyphBytes,
        0x1F, 0x41, 0x41, // US row col : ends the download
      ]);

      expect(codes, [0x21],
          reason: 'the complete form must be emitted on US, not dropped');
    });

    test(
        'a C0 code other than US/NUL fills background pixels mid-download '
        'instead of resynchronizing/exiting (STUM2 §2.3.3.2)', () {
      final minitel = TMinitel();
      Uint8List? pixels;
      final codes = <int>[];

      minitel.onDrcsGlyph = (bool isG1, int code, Uint8List pixels80) {
        codes.add(code);
        pixels = pixels80;
      };

      minitel.emulate([
        ..._buildDrcsHeader(g1: false),
        0x1F, 0x23, 0x21,
        0x30, // open form 0x21
        0x7F, // 6 pixels ON (bits 0..5)
        0x1B, // ESC: not US/NUL -> fills 6 background pixels, no resync
        ...List.filled(11, 0x7F), // 66 more pixels ON (idx 12..77)
        0x7F, // final byte: only idx 78..79 consumed (2 more pixels ON)
        0x30, // flush
      ]);

      expect(codes, [0x21],
          reason: 'ESC must not have exited the download early');
      expect(pixels, isNotNull);
      // idx 0..5 ON, 6..11 OFF (ESC fill), 12..79 ON.
      for (int i = 0; i < 80; i++) {
        final expected = (i >= 6 && i < 12) ? 0 : 1;
        expect(pixels![i], expected, reason: 'pixel index $i');
      }
    });

    test('NUL mid-download has no effect at all (STUM2 §2.3.3.2)', () {
      final minitel = TMinitel();
      late Uint8List withNul;
      late Uint8List withoutNul;

      final minitelA = TMinitel();
      minitelA.onDrcsGlyph = (bool isG1, int code, Uint8List pixels80) {
        withNul = Uint8List.fromList(pixels80);
      };
      minitelA.emulate([
        ..._buildDrcsHeader(g1: false),
        0x1F, 0x23, 0x21,
        0x30,
        ..._exampleGlyphBytes.sublist(0, 3),
        0x00, // NUL: absorbed, zero effect
        ..._exampleGlyphBytes.sublist(3),
        0x30,
      ]);

      minitel.onDrcsGlyph = (bool isG1, int code, Uint8List pixels80) {
        withoutNul = Uint8List.fromList(pixels80);
      };
      minitel.emulate([
        ..._buildDrcsHeader(g1: false),
        ..._buildDrcsGlyphData(0x21, [_exampleGlyphBytes]),
      ]);

      expect(withNul, equals(withoutNul),
          reason: 'a NUL byte mid-download must not shift/alter pixels');
    });

    test(
        'a byte arriving before the very first B1 is filtered, not '
        'accumulated into the first form (STUM2 §2.3.3.2 "B1... précède '
        'toute forme téléchargée y compris la première")', () {
      final minitel = TMinitel();
      Uint8List? pixels;
      final codes = <int>[];

      minitel.onDrcsGlyph = (bool isG1, int code, Uint8List pixels80) {
        codes.add(code);
        pixels = Uint8List.fromList(pixels80);
      };

      // US 0x23 Y, then a pixel byte AND a C0 code BEFORE the first B1 —
      // neither belongs to any form yet and both must be filtered, leaving
      // the glyph identical to the plain STUM2 §2.3.5 example.
      minitel.emulate([
        ..._buildDrcsHeader(g1: false),
        0x1F, 0x23, 0x21,
        0x7F, // pixel byte before the first B1: must be filtered
        0x1B, // C0 code before the first B1: must be filtered too
        0x30, // the actual first B1
        ..._exampleGlyphBytes,
        0x30,
      ]);

      expect(codes, [0x21]);
      expect(pixels, isNotNull);
      for (int row = 0; row < 10; row++) {
        for (int col = 0; col < 8; col++) {
          final expected = _expectedRows[row][col] == '#' ? 1 : 0;
          expect(pixels![row * 8 + col], expected, reason: 'row=$row col=$col');
        }
      }
    });

    test(
        'replays test/drcs/pacman.drc: real-world capture whose last glyph '
        'is only closed by US, not by B1', () {
      // Regression test for the pacman-eater ghost sprite (STUM2 §2.3.3.3):
      // this real capture downloads 25 G\'1 glyphs (0x41-0x59) but never
      // sends a closing B1 for the last one (0x59) — the download is
      // terminated by "US 0x41 0x41" (a cursor-position command) instead.
      // Before the fix, US was dispatched straight to the C0 handler table
      // (it doubles as ESC-position-cursor), abandoning the pending form
      // without emitting it, so the real Minitel ghost glyph never reached
      // the DRCS atlas and the cell fell back to the plain G1 shape for
      // that code instead.
      final bytes = File('test/drcs/pacman.drc').readAsBytesSync();
      final minitel = TMinitel();
      final events = <(int code, Uint8List pixels)>[];

      minitel.onDrcsGlyph = (bool isG1, int code, Uint8List pixels80) {
        events.add((code, pixels80));
      };

      minitel.emulate(bytes.toList());

      expect(events.length, 25);
      expect(events.map((e) => e.$1), List.generate(25, (i) => 0x41 + i));

      // Last glyph (0x59), decoded from the real capture bytes
      // `4f 47 7b 5b 7f 7f 7f 7f 7f 7f 7e 65 49 40`: the ghost sprite that
      // must land in the DRCS atlas instead of being silently dropped.
      const expectedRows = [
        '..####..',
        '.######.',
        '##.##.##',
        '########',
        '########',
        '########',
        '########',
        '########',
        '#.#..#.#',
        '..#..#..',
      ];
      final lastPixels = events.last.$2;
      for (int row = 0; row < 10; row++) {
        for (int col = 0; col < 8; col++) {
          final expected = expectedRows[row][col] == '#' ? 1 : 0;
          expect(
            lastPixels[row * 8 + col],
            expected,
            reason: 'row=$row col=$col',
          );
        }
      }
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

      // The capture's last B1 opens a 33rd form immediately closed by the
      // US that ends the download, with no pixel bytes in between: per
      // STUM2 §2.3.3.3 that is a legitimate blank form and must be emitted
      // (previously silently dropped before the US-flush fix above).
      expect(events.length, 33);
      expect(events.first.$1, 0x21);
      expect(events.last.$1, 0x41);

      const blankCodes = {0x21, 0x22, 0x23, 0x24, 0x2a, 0x2b, 0x41};
      for (final (code, blank) in events) {
        expect(
          blank,
          blankCodes.contains(code),
          reason: 'code=0x${code.toRadixString(16)}',
        );
      }
    });
  });

  group('accès en rangée 00 (STUM2 §2.2.2)', () {
    test(
        'repositioning the cursor to line 0 re-associates G0/G1 to the base '
        'charsets, cancelling an active DRCS association', () {
      final minitel = TMinitel();

      // Télécharge un glyphe en position 0x21 du jeu G'0 et l'associe à G0.
      // US termine le téléchargement (STUM2 §2.3.3.3) avant la désignation
      // ESC : un C0 seul (ex. ESC) ne resynchronise pas pendant un
      // téléchargement (§2.3.3.2), il serait sinon avalé comme du fond
      // d'écran — constaté aussi dans test/drcs/msx-sonytel.vdt, qui envoie
      // "US 5/3 5/0" avant sa désignation ESC.
      minitel.emulate([
        ..._buildDrcsHeader(g1: false),
        ..._buildDrcsGlyphData(0x21, [_exampleGlyphBytes]),
        0x1F, 0x41, 0x41, // US 4/1 4/1 : termine le téléchargement
        0x1b, 0x28, 0x20, 0x42, // ESC 2/8 2/0 4/2 : G'0 -> G0
      ]);
      minitel.emulate([0x21]); // Écrit le code téléchargé.

      expect(minitel.screen[1][1].lAttr & kDRCSCharset, isNot(0),
          reason: 'le caractère doit être marqué DRCS avant l\'accès rangée 00');

      // US 4/0 4/1 : positionne le curseur en rangée 00 (ligne 0, colonne 1).
      minitel.emulate([0x1F, 0x40, 0x41]);
      // Retour en rangée normale puis réécriture du même code.
      minitel.emulate([0x1F, 0x41, 0x41]); // US 4/1 4/1 : ligne 1, colonne 1
      minitel.emulate([0x21]);

      expect(minitel.screen[1][1].lAttr & kDRCSCharset, 0,
          reason: 'après un accès rangée 00, G0 doit être revenu au jeu '
              'standard (non-DRCS), sans que les glyphes téléchargés soient '
              'perdus pour autant');

      // Les glyphes téléchargés doivent en revanche rester disponibles : une
      // nouvelle association DRCS doit à nouveau afficher la forme.
      minitel.emulate([0x1b, 0x28, 0x20, 0x42]);
      minitel.emulate([0x21]);
      expect(minitel.screen[1][2].lAttr & kDRCSCharset, isNot(0),
          reason: 'les glyphes téléchargés ne doivent pas être effacés par '
              'un simple accès rangée 00 (contrairement à resetDrcs())');
    });

    test(
        'replays test/drcs/msx-sonytel.vdt: real-world capture that draws a '
        'DRCS logo then must fall back to plain text for digits/uppercase',
        () {
      // Regression test: this capture draws a "MSX" logo using DRCS tiles
      // downloaded onto G'0 codes 0x21-0x4a, written across lines 3-6. The
      // periodic "US 4/0 4/1" status-line refresh right after the logo (and
      // repeated throughout the rest of the document) must re-associate G0
      // to the base alphanumeric set (STUM2 §2.2.2) so that later digits and
      // uppercase text ("15 ans", "40000 appels", dates, "SonyTEL"...)
      // render normally instead of being read from the DRCS-overwritten
      // font atlas. Before the fix, every character after the logo stayed
      // flagged DRCS (437 cells instead of 46), scrambling most of the page.
      final bytes = File('test/drcs/msx-sonytel.vdt').readAsBytesSync();
      final minitel = TMinitel();

      minitel.emulate(bytes.toList());

      final drcsCells = <(int line, int col)>[];
      for (int line = 0; line <= minitel.lastLine; line++) {
        for (int col = 1; col <= minitel.columns; col++) {
          if ((minitel.screen[line][col].lAttr & kDRCSCharset) != 0) {
            drcsCells.add((line, col));
          }
        }
      }

      expect(drcsCells.length, 46,
          reason: 'only the MSX logo tiles should be DRCS-flagged');
      for (final (line, col) in drcsCells) {
        expect(line, inInclusiveRange(3, 6),
            reason: 'DRCS cell at line=$line col=$col falls outside the '
                'logo area — a digit/letter cell was likely left DRCS-flagged');
      }
    });
  });

  group('resetDrcs (déconnexion / changement de service)', () {
    test(
        'clears the DRCS charset selection so a previously-DRCS code renders '
        'as standard G0 again, and fires onDrcsReset', () {
      final minitel = TMinitel();

      // Télécharge un glyphe en position 0x21 du jeu G'0. US termine le
      // téléchargement (STUM2 §2.3.3.3) avant la désignation ESC (voir
      // §2.3.3.2 : un C0 seul ne resynchronise pas pendant un
      // téléchargement, il serait sinon avalé comme du fond d'écran).
      minitel.emulate([
        ..._buildDrcsHeader(g1: false),
        ..._buildDrcsGlyphData(0x21, [_exampleGlyphBytes]),
        0x1F, 0x41, 0x41, // US 4/1 4/1 : termine le téléchargement
      ]);

      // ESC 2/8 2/0 4/2 : désigne G'0 (DRCS) comme jeu G0 courant.
      minitel.emulate([0x1b, 0x28, 0x20, 0x42]);
      minitel.emulate([0x21]); // Écrit le code téléchargé.

      expect(minitel.screen[1][1].lAttr & kDRCSCharset, isNot(0),
          reason: 'le caractère doit être marqué DRCS avant reset');

      var resetFired = false;
      minitel.onDrcsReset = () => resetFired = true;
      minitel.resetDrcs();
      expect(resetFired, isTrue);

      minitel.emulate([0x21]); // Même code, réécrit après le reset.

      expect(minitel.screen[1][2].lAttr & kDRCSCharset, 0,
          reason:
              'après reset, G0 doit être revenu au jeu standard (non-DRCS)');
    });
  });
}
