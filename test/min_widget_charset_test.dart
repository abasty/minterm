import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:minterm/min/min_widget.dart';

// Positions où le G0 Videotex diffère du jeu Américain (STUM2 §3.10) et que
// tools/patch_g0_charsets.py doit donc corriger. 0x7C ('|') fait partie des
// positions repeintes par le script mais était déjà correct dans g0g2.png —
// absent d'ici à dessein, cf. le test de forme exactes ci-dessous qui le
// couvre quand même.
const _patchedCodes = {0x5E, 0x60, 0x7B, 0x7D, 0x7E};

const _atlasWidth = 64;

// Le glyphe vit entièrement dans le canal alpha (RGB toujours (0,0,0)) :
// drawChar utilise l'image comme masque via BlendMode.srcIn. Comparer le
// canal 0 (rouge) donnerait un test qui passe toujours à vide.
bool _isInk(Uint8List pixels, int offset) => pixels[offset + 3] != 0;

bool _cellsMatch(Uint8List a, Uint8List b, int code) {
  final gx = (code ~/ 16) * 8;
  final gy = (code % 16) * 10;
  for (int row = 0; row < 10; row++) {
    for (int col = 0; col < 8; col++) {
      final offset = ((gy + row) * _atlasWidth + (gx + col)) * 4;
      if (_isInk(a, offset) != _isInk(b, offset)) return false;
    }
  }
  return true;
}

void main() {
  testWidgets(
      'g0_american.png only differs from g0g2.png on the STUM2 §3.10 '
      'patched positions', (WidgetTester tester) async {
    await tester.runAsync(() async {
      final settings = MinSettings();
      while (!settings.isLoaded) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final base =
          (await settings.fontG0G2.toByteData(format: ui.ImageByteFormat.rawRgba))!
              .buffer
              .asUint8List();
      final american = (await settings.fontG0American
              .toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();

      for (int code = 0x20; code <= 0x7F; code++) {
        final shouldDiffer = _patchedCodes.contains(code);
        final matches = _cellsMatch(base, american, code);
        expect(
          matches,
          !shouldDiffer,
          reason: shouldDiffer
              ? '0x${code.toRadixString(16)} was expected to be patched'
              : '0x${code.toRadixString(16)} should be unchanged from '
                  'g0g2.png but differs',
        );
      }
    });
  });

  testWidgets('g0_american.png ASCII patches match STUM2 §3.10 shapes',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      final settings = MinSettings();
      while (!settings.isLoaded) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final pixels = (await settings.fontG0American
              .toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();

      // Un octet par ligne (8 colonnes, bit de poids fort = colonne de
      // gauche), doit rester synchronisé avec AMERICAN_PATCHES dans
      // tools/patch_g0_charsets.py.
      final expected = {
        0x5E: [0x10, 0x28, 0x44, 0, 0, 0, 0, 0, 0, 0], // ^
        0x60: [0x30, 0x0C, 0, 0, 0, 0, 0, 0, 0, 0], // `
        0x7B: [0, 0x1C, 0x10, 0x10, 0x20, 0x10, 0x10, 0x1C, 0, 0], // {
        0x7C: List.filled(10, 0x10), // |
        0x7D: [0, 0x70, 0x10, 0x10, 0x08, 0x10, 0x10, 0x70, 0, 0], // }
        0x7E: [0, 0, 0, 0x64, 0x98, 0, 0, 0, 0, 0], // ~
      };

      for (final entry in expected.entries) {
        final code = entry.key;
        final gx = (code ~/ 16) * 8;
        final gy = (code % 16) * 10;
        for (int row = 0; row < 10; row++) {
          final bits = entry.value[row];
          for (int col = 0; col < 8; col++) {
            final expectedOn = (bits >> (7 - col)) & 1 != 0;
            final offset = ((gy + row) * _atlasWidth + (gx + col)) * 4;
            expect(
              _isInk(pixels, offset),
              expectedOn,
              reason: 'code=0x${code.toRadixString(16)} row=$row col=$col',
            );
          }
        }
      }
    });
  });

  testWidgets(
      'g0_french.png is currently a placeholder identical to '
      'g0_american.png — update this test (and the real glyphs) once the '
      'STUM 1B French table is confirmed', (WidgetTester tester) async {
    await tester.runAsync(() async {
      final settings = MinSettings();
      while (!settings.isLoaded) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final american = (await settings.fontG0American
              .toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
      final french = (await settings.fontG0French
              .toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();

      for (int code = 0x20; code <= 0x7F; code++) {
        expect(
          _cellsMatch(american, french, code),
          isTrue,
          reason: '0x${code.toRadixString(16)} placeholder should still '
              'match the American atlas',
        );
      }
    });
  });
}
