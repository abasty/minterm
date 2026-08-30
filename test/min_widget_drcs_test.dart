import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:minterm/min_emulator.dart';
import 'package:minterm/min_model.dart';
import 'package:minterm/min_widget.dart';

// Twelve distinct 8x10 bit patterns, each easy to eyeball, used as DRCS
// glyphs for char codes 0x21..0x2C ('!' through ',').
const Map<int, List<String>> _glyphPatterns = {
  0x21: [
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
  ], // all off
  0x22: [
    '########',
    '########',
    '########',
    '########',
    '########',
    '########',
    '########',
    '########',
    '########',
    '########',
  ], // all on
  0x23: [
    '#.#.#.#.',
    '.#.#.#.#',
    '#.#.#.#.',
    '.#.#.#.#',
    '#.#.#.#.',
    '.#.#.#.#',
    '#.#.#.#.',
    '.#.#.#.#',
    '#.#.#.#.',
    '.#.#.#.#',
  ], // checkerboard
  0x24: [
    '#.......',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
  ], // top-left pixel
  0x25: [
    '.......#',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
  ], // top-right pixel
  0x26: [
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '#.......',
  ], // bottom-left pixel
  0x27: [
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '.......#',
  ], // bottom-right pixel
  0x28: [
    '########',
    '........',
    '########',
    '........',
    '########',
    '........',
    '########',
    '........',
    '########',
    '........',
  ], // horizontal stripes
  0x29: [
    '#.#.#.#.',
    '#.#.#.#.',
    '#.#.#.#.',
    '#.#.#.#.',
    '#.#.#.#.',
    '#.#.#.#.',
    '#.#.#.#.',
    '#.#.#.#.',
    '#.#.#.#.',
    '#.#.#.#.',
  ], // vertical stripes
  0x2A: [
    '#.......',
    '.#......',
    '..#.....',
    '...#....',
    '....#...',
    '.....#..',
    '......#.',
    '.......#',
    '#.......',
    '.#......',
  ], // diagonal
  0x2B: [
    '########',
    '#......#',
    '#......#',
    '#......#',
    '#......#',
    '#......#',
    '#......#',
    '#......#',
    '#......#',
    '########',
  ], // border outline
  0x2C: [
    '...##...',
    '...##...',
    '...##...',
    '...##...',
    '########',
    '########',
    '...##...',
    '...##...',
    '...##...',
    '...##...',
  ], // cross
};

// Converts a 10x8 '#'/'.' bitmap into the 80-value pixel list matching
// the DRCS download order (row-major, 8 cols x 10 rows).
List<int> _rowsToPixels(List<String> rows) {
  final pixels = <int>[];
  for (final row in rows) {
    for (final char in row.split('')) {
      pixels.add(char == '#' ? 1 : 0);
    }
  }
  return pixels;
}

// Encodes 80 pixels into STUM2 §2.3.5 byte stream: 14 bytes in [0x40,0x7F],
// each carrying 6 pixels b5-first. Exact inverse of TMinitel._handleDrcsData.
List<int> _encodeGlyphBytes(List<int> pixels80) {
  final bytes = <int>[];
  for (int i = 0; i < 80; i += 6) {
    int bits = 0;
    for (int p = 0; p < 6; p++) {
      final idx = i + p;
      if (idx < 80 && pixels80[idx] != 0) {
        bits |= 1 << (5 - p);
      }
    }
    bytes.add(0x40 | bits);
  }
  return bytes;
}

// US 0x23 header announcing a G'0 (or G'1) DRCS download.
List<int> _buildDrcsHeader({bool g1 = false}) {
  return [
    0x1F, 0x23, // US 0x23 -> DRCS header
    0x20, 0x20, 0x20, // three intermediate bytes
    g1 ? 0x43 : 0x42, // 0x42 = G'0, 0x43 = G'1
    0x49, // validation byte
  ];
}

// US 0x23 Y [B1 <14 bytes>]+ B1(flush) glyph data, starting at startCharCode.
List<int> _buildDrcsGlyphData(int startCharCode, List<List<int>> glyphs) {
  return [
    0x1F, 0x23, startCharCode,
    for (final g in glyphs) ...[0x30, ...g],
    0x30,
  ];
}

void main() {
  testWidgets(
      'DRCS: a dozen G\'0 glyphs are displayed exactly as downloaded',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      // Constructing MinSettings wires TMinitel.onDrcsGlyph to
      // MinSettings.updateDrcsGlyph and starts loading the font atlases.
      final settings = MinSettings();
      while (!settings.isLoaded) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final minitel = MinModel().minitel;
      minitel.setScreenMode(TMinitelScreenMode.videotex40);
      minitel.clearScreen();

      const atlasWidth = 64;
      bool glyphLanded(Uint8List pixels, int code) {
        final rows = _glyphPatterns[code]!;
        final gx = (code ~/ 16) * 8;
        final gy = (code % 16) * 10;
        for (int row = 0; row < 10; row++) {
          for (int col = 0; col < 8; col++) {
            final expectedOn = rows[row][col] == '#';
            final offset = ((gy + row) * atlasWidth + (gx + col)) * 4;
            if ((pixels[offset] != 0) != expectedOn) return false;
          }
        }
        return true;
      }

      // Download the twelve glyphs as G'0, char codes 0x21..0x2C. Sent one
      // at a time (as bytes trickling in over a real serial line would
      // arrive) so each glyph's async decodeImageFromPixels round trip has
      // landed in the font atlas before the next glyph overwrites the
      // shared pixel buffer.
      final codes = _glyphPatterns.keys.toList()..sort();
      minitel.emulate(_buildDrcsHeader(g1: false));
      for (final code in codes) {
        minitel.emulate(_buildDrcsGlyphData(
          code,
          [_encodeGlyphBytes(_rowsToPixels(_glyphPatterns[code]!))],
        ));
        for (var attempt = 0; attempt < 100; attempt++) {
          final ByteData? byteData = await settings.fontG0p
              .toByteData(format: ui.ImageByteFormat.rawRgba);
          if (glyphLanded(byteData!.buffer.asUint8List(), code)) break;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }

      // Designate G'0 as DRCS (ESC 2/8 SP 4/2), then "display" the twelve
      // characters by writing them to the screen, row 1 columns 1..12.
      minitel.emulate([0x1b, 0x28, 0x20, 0x42]);
      minitel.emulate(codes);

      // The emulator's screen buffer is what is actually "displayed":
      // check each cell got the right code and the DRCS attribute.
      for (int i = 0; i < codes.length; i++) {
        final cell = minitel.screen[1][i + 1];
        // .code carries a redraw "dirty" flag (kIsDirty) in its top bit.
        expect(cell.code & ~kIsDirty, codes[i], reason: 'cell $i char code');
        expect(cell.lAttr & kDRCSCharset, isNot(0),
            reason: 'cell $i should be flagged as DRCS');
        expect(cell.gAttr & kCharsetMask, isNot(kG1Charset),
            reason: 'cell $i should stay on the G0 charset side');
      }

      // Copy what is actually displayed: decode the exact font atlas image
      // that _MinPainter samples glyphs from (every glyph was already
      // confirmed landed above), and compare it bit-for-bit against the
      // pattern that was downloaded for each character.
      final ByteData? byteData =
          await settings.fontG0p.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(byteData, isNotNull);
      final pixels = byteData!.buffer.asUint8List();

      for (final code in codes) {
        final rows = _glyphPatterns[code]!;
        final gx = (code ~/ 16) * 8;
        final gy = (code % 16) * 10;
        for (int row = 0; row < 10; row++) {
          for (int col = 0; col < 8; col++) {
            final expectedOn = rows[row][col] == '#';
            final offset = ((gy + row) * atlasWidth + (gx + col)) * 4;
            final actualOn = pixels[offset] != 0;
            expect(
              actualOn,
              expectedOn,
              reason: 'code=0x${code.toRadixString(16)} row=$row col=$col',
            );
          }
        }
      }
    });
  });
}
