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
  group('TMinitelKey.teleinformatiqueOverrides (STUM 1B §3-3-2-2)', () {
    test('maps each Videotex/Mixte SEP function key to its ESC O code', () {
      expect(TMinitelKey.teleinformatiqueOverrides, {
        TMinitelKey.envoi: '\x1b\x4f\x4d',
        TMinitelKey.sommaire: '\x1b\x4f\x50',
        TMinitelKey.annulation: '\x1b\x4f\x51',
        TMinitelKey.retour: '\x1b\x4f\x52',
        TMinitelKey.repetition: '\x1b\x4f\x53',
        TMinitelKey.correction: '\x1b\x4f\x6c',
        TMinitelKey.guide: '\x1b\x4f\x6d',
        TMinitelKey.suite: '\x1b\x4f\x6e',
        TMinitelKey.cxFin: '\x1b\x29\x34\x0d',
      });
    });
  });

  group('TMinitel mode switching sequences', () {
    test('ESC : 2 } switches to Mixte (80 columns)', () {
      final minitel = TMinitel();
      expect(minitel.screenMode, TMinitelScreenMode.videotex40);
      expect(minitel.columns, 40);

      minitel.emulate([0x1B, 0x3A, 0x32, 0x7D]);

      expect(minitel.screenMode, TMinitelScreenMode.teleinfo80);
      expect(minitel.isMixteMode, isTrue);
      expect(minitel.columns, 80);
    });

    test('ESC : 2 ~ switches back to Videotex 40 columns (depuis Mixte)', () {
      final minitel = TMinitel();
      minitel.enterMixte();
      expect(minitel.columns, 80);

      minitel.emulate([0x1B, 0x3A, 0x32, 0x7E]);

      expect(minitel.screenMode, TMinitelScreenMode.videotex40);
      expect(minitel.columns, 40);
    });

    test('ESC 9 7F switches back to Videotex 40 columns (depuis Mixte)', () {
      final minitel = TMinitel();
      minitel.enterMixte();
      expect(minitel.columns, 80);

      minitel.emulate([0x1B, 0x39, 0x7F]);

      expect(minitel.screenMode, TMinitelScreenMode.videotex40);
      expect(minitel.columns, 40);
    });

    test(
        'ESC 9 7F has no effect in standard Téléinformatique (Protocole '
        'gelé, STUM 1B)', () {
      final minitel = TMinitel();
      minitel.enterTeleinformatique();
      expect(minitel.isTeleinformatiqueStandard, isTrue);
      expect(minitel.columns, 80);

      minitel.emulate([0x1B, 0x39, 0x7F]);

      expect(minitel.screenMode, TMinitelScreenMode.teleinfo80);
      expect(minitel.isTeleinformatiqueStandard, isTrue);
    });

    test('entering standard Téléinformatique does not touch local echo '
        '(géré au niveau connexion par MinModel.connect()/end(), pas ici)',
        () {
      final minitel = TMinitel();
      expect(minitel.isEchoed, isTrue);

      minitel.enterTeleinformatique();

      // TMinitel n'a pas la notion de connecté/local : c'est MinModel qui
      // coupe l'écho à la connexion et le rétablit à la déconnexion, quel
      // que soit le mode — voir min_model.dart connect()/end().
      expect(minitel.isEchoed, isTrue);
    });

    test('CSI 12 h/l (SM12/RM12) toggles local echo, no private marker', () {
      final minitel = TMinitel();
      minitel.enterTeleinformatique();
      expect(minitel.isEchoed, isTrue);

      minitel.emulate('\x1b[12h'.codeUnits);
      expect(minitel.isEchoed, isFalse);

      minitel.emulate('\x1b[12l'.codeUnits);
      expect(minitel.isEchoed, isTrue);
    });

    test('CSI ? { switches back to Videotex from Téléinformatique', () {
      final minitel = TMinitel();
      minitel.enterTeleinformatique();

      minitel.emulate('\x1b[?{'.codeUnits);

      expect(minitel.screenMode, TMinitelScreenMode.videotex40);
      expect(minitel.reply, [0x13, 0x5E]); // Acquittement SEP 0x5E
    });

    test('switching from 80 to 40 columns turns the cursor off', () {
      // Comportement du vrai Minitel : repasser en mode 40 colonnes
      // (Videotex) éteint le curseur, même s'il était allumé en 80 colonnes.
      final minitel = TMinitel();
      minitel.enterMixte();
      expect(minitel.cursorOn, isTrue);

      minitel.emulate([0x1B, 0x3A, 0x32, 0x7E]);

      expect(minitel.screenMode, TMinitelScreenMode.videotex40);
      expect(minitel.cursorOn, isFalse);
    });

    test('switching from 40 to 80 columns turns the cursor on', () {
      final minitel = TMinitel();
      expect(minitel.cursorOn, isFalse);

      minitel.emulate([0x1B, 0x3A, 0x32, 0x7D]);

      expect(minitel.screenMode, TMinitelScreenMode.teleinfo80);
      expect(minitel.cursorOn, isTrue);
    });

    test('switching from 40 to 80 columns sets keyboard to minuscules', () {
      final minitel = TMinitel();
      expect(minitel.keyboardLowercase, isFalse);

      minitel.emulate([0x1B, 0x3A, 0x32, 0x7D]);

      expect(minitel.screenMode, TMinitelScreenMode.teleinfo80);
      expect(minitel.keyboardLowercase, isTrue);
    });

    test('switching from 80 to 40 columns resets keyboard to majuscules', () {
      final minitel = TMinitel();
      minitel.enterMixte();
      minitel.emulate([0x1B, 0x3A, 0x69, 0x45]); // PRO2 START MINUSCULES
      expect(minitel.keyboardLowercase, isTrue);

      minitel.emulate([0x1B, 0x3A, 0x32, 0x7E]); // ESC : 2 ~ → 40 colonnes

      expect(minitel.screenMode, TMinitelScreenMode.videotex40);
      expect(minitel.keyboardLowercase, isFalse);
    });

    test(
        'SEP p/q (0x13 0x70 / 0x13 0x71) switch Videotex<->Mixte directly '
        '(bug réel constaté sur capture SonyTel RTC : le serveur envoie '
        'SEP p sans PRO2 32 7D, et le terminal restait bloqué en 40 '
        'colonnes)', () {
      final minitel = TMinitel();
      expect(minitel.screenMode, TMinitelScreenMode.videotex40);

      minitel.emulate([0x13, 0x70]);
      expect(minitel.screenMode, TMinitelScreenMode.teleinfo80);
      expect(minitel.isMixteMode, isTrue);

      minitel.emulate([0x13, 0x71]);
      expect(minitel.screenMode, TMinitelScreenMode.videotex40);
    });

    test(
        'SO (0x0E) received once in Mixte via SEP p does not leave the '
        'following text mosaic-shifted (capture SonyTel RTC : la liste '
        'du serveur suit un SO et doit rester en ASCII lisible)', () {
      final minitel = TMinitel();
      // Reproduit l'ordre exact de la capture réelle : SEP p (bascule
      // Mixte) puis SO puis du texte ASCII simple.
      minitel.emulate([0x13, 0x70]);
      expect(minitel.screenMode, TMinitelScreenMode.teleinfo80);

      final line = minitel.state.l;
      final startColumn = minitel.state.c;
      minitel.emulate([0x0E, ...'Bruno Mozart'.codeUnits]);

      expect(
        String.fromCharCodes(
          List.generate(
            12,
            (i) =>
                minitel.screen[line][startColumn + i].code & ~kIsDirty,
          ),
        ),
        'Bruno Mozart',
      );
    });
  });

  group('TMinitel Videotex', () {
    test(
        'PRO3 aiguillage clavier<->modem OFF/ON drives local echo '
        '(bug réel constaté sur capture SonyTel : doublement de caractères)',
        () {
      final minitel = TMinitel();
      expect(minitel.isEchoed, isTrue); // valeur par défaut

      // PRO3 60 (') Z Q : aiguillage coupé -> écho local activé (ON).
      minitel.emulate([0x1B, 0x3B, 0x60, 0x5A, 0x51]);
      expect(minitel.isEchoed, isTrue);

      // PRO3 61 (a) Z Q : aiguillage rétabli -> écho local coupé (OFF).
      // C'est cette séquence, envoyée par SonyTel juste avant le contenu
      // interactif, qui laissait l'écho local activé par erreur (logique
      // inversée) et provoquait le doublement des caractères tapés.
      minitel.emulate([0x1B, 0x3B, 0x61, 0x5A, 0x51]);
      expect(minitel.isEchoed, isFalse);
    });

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

    test('PRO2 START/STOP MINUSCULES toggles keyboard lowercase mode', () {
      final minitel = TMinitel();
      expect(minitel.keyboardLowercase, isFalse);

      minitel.emulate([0x1B, 0x3A, 0x69, 0x45]); // ESC : i E → minuscules
      expect(minitel.keyboardLowercase, isTrue);

      minitel.emulate([0x1B, 0x3A, 0x6A, 0x45]); // ESC : j E → majuscules
      expect(minitel.keyboardLowercase, isFalse);
    });

    test('FF clears screen without clearing line 0', () {
      final minitel = TMinitel();

      minitel.screen[0][1].code = 'H'.codeUnitAt(0);
      minitel.screen[1][1].code = 'A'.codeUnitAt(0);

      minitel.emulate([0x0C]);

      expect(readChar(minitel, 0, 0), 'H');
      expect(readChar(minitel, 0, 1), ' ');
      expect(minitel.state.l, 1);
      expect(minitel.state.c, 1);
    });
  });

  group('TMinitel Téléinformatique', () {
    late TMinitel minitel;

    setUp(() {
      minitel = TMinitel();
      minitel.setScreenMode(TMinitelScreenMode.teleinfo80);
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

    test('keeps writing on the last column without wrapping', () {
      minitel.emulate(('A' * 80).codeUnits);
      minitel.emulate('B'.codeUnits);

      expect(readChar(minitel, 79, 1), 'B');
      expect(readChar(minitel, 0, 2), ' ');
      expect(minitel.state.l, 1);
      expect(minitel.state.c, 80);
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

    test('default fg color is 2 in Téléinformatique mode', () {
      // En mode 80 cols la couleur par défaut est 2 (pas kColorWhite=7)
      expect(minitel.state.fgColor, 2);

      // Un caractère écrit sans SGR doit avoir la couleur 2
      minitel.emulate('A'.codeUnits);
      expect(minitel.screen[1][1].lAttr & kColorMask, 2);
    });

    test('SGR 1 activates bold (fg color 7)', () {
      minitel.emulate('\x1b[1mA'.codeUnits);
      expect(minitel.state.fgColor, kColorWhite);
      expect(minitel.screen[1][1].lAttr & kColorMask, kColorWhite);
    });

    test('SGR 22 deactivates bold (back to default fg color 2)', () {
      minitel.emulate('\x1b[1m'.codeUnits); // surintensité ON
      expect(minitel.state.fgColor, kColorWhite);

      minitel.emulate('\x1b[22m'.codeUnits); // surintensité OFF
      expect(minitel.state.fgColor, 2);

      minitel.emulate('A'.codeUnits);
      expect(minitel.screen[1][1].lAttr & kColorMask, 2);
    });

    test('SGR 0 resets fg color to 2 (Téléinformatique default)', () {
      minitel.emulate('\x1b[1m'.codeUnits); // bold ON
      minitel.emulate('\x1b[0m'.codeUnits); // reset

      expect(minitel.state.fgColor, 2);
      minitel.emulate('A'.codeUnits);
      expect(minitel.screen[1][1].lAttr & kColorMask, 2);
    });

    test('SGR 39 restores default fg color 2', () {
      minitel.emulate('\x1b[31m'.codeUnits); // rouge
      expect(minitel.state.fgColor, 1);

      minitel.emulate('\x1b[39m'.codeUnits); // fg par défaut
      expect(minitel.state.fgColor, 2);
    });

    test('saves and restores cursor with CSI s/u', () {
      minitel.emulate('\x1b[10;20H\x1b[s\x1b[1;1HA\x1b[uB'.codeUnits);

      expect(readChar(minitel, 0, 1), 'A');
      expect(readChar(minitel, 19, 10), 'B');
      expect(minitel.state.l, 10);
      expect(minitel.state.c, 21);
    });

    test('supports ICH and DCH', () {
      minitel.emulate('ABCDE'.codeUnits);
      minitel.emulate('\x1b[1;3H\x1b[2@'.codeUnits);
      minitel.emulate('XY'.codeUnits);

      expect(readLine(minitel, 1, 7), 'ABXYCDE');

      minitel.emulate('\x1b[1;3H\x1b[2P'.codeUnits);
      expect(readLine(minitel, 1, 5), 'ABCDE');
    });

    test('supports IL and DL', () {
      minitel.emulate('AAAA'.codeUnits);
      minitel.emulate('\x1b[2;1HBBBB'.codeUnits);
      minitel.emulate('\x1b[3;1HCCCC'.codeUnits);

      minitel.emulate('\x1b[2;1H\x1b[L'.codeUnits);
      expect(readLine(minitel, 1, 4), 'AAAA');
      expect(readLine(minitel, 2, 4), '    ');
      expect(readLine(minitel, 3, 4), 'BBBB');

      minitel.emulate('\x1b[2;1H\x1b[M'.codeUnits);
      expect(readLine(minitel, 1, 4), 'AAAA');
      expect(readLine(minitel, 2, 4), 'BBBB');
      expect(readLine(minitel, 3, 4), 'CCCC');
    });

    test('supports insert/replace mode via SM4/RM4', () {
      minitel.emulate('ABCDE'.codeUnits);
      minitel.emulate('\x1b[1;3H\x1b[4hZ'.codeUnits);
      expect(readLine(minitel, 1, 6), 'ABZCDE');

      minitel.emulate('\x1b[4l\x1b[1;3HQ'.codeUnits);
      expect(readLine(minitel, 1, 6), 'ABQCDE');
    });

    test('supports private mode cursor visibility (CSI ?1 h/l)', () {
      expect(minitel.cursorOn, isTrue);
      minitel.emulate('\x1b[?1l'.codeUnits);
      expect(minitel.cursorOn, isFalse);
      minitel.emulate('\x1b[?1h'.codeUnits);
      expect(minitel.cursorOn, isTrue);
    });

    test('CSI ?3 h has no effect on columns (confirmé sur M2 réel)', () {
      expect(minitel.columns, 80);
      minitel.emulate('\x1b[?3h'.codeUnits);
      expect(minitel.columns, 80);
    });

    test('supports Minitel CSI < 1 l/h for cursor on/off', () {
      // CSI < 1 l → allumage du curseur (l = ON dans la convention Minitel)
      minitel.emulate('\x1b[<1l'.codeUnits);
      expect(minitel.cursorOn, isTrue);

      // CSI < 1 h → arrêt du curseur (h = OFF dans la convention Minitel)
      minitel.emulate('\x1b[<1h'.codeUnits);
      expect(minitel.cursorOn, isFalse);

      // Ré-allumage
      minitel.emulate('\x1b[<1l'.codeUnits);
      expect(minitel.cursorOn, isTrue);
    });

    test('supports DSR 6n report', () {
      minitel.emulate('\x1b[12;34H\x1b[6n'.codeUnits);
      expect(String.fromCharCodes(minitel.reply), '\x1b[12;34R');
    });

    test('scroll mode: LF on last line scrolls up', () {
      // Mode rouleau par défaut (scrollOn = true)
      expect(minitel.scrollOn, isTrue);
      minitel.emulate('\x1b[24;1H'.codeUnits);
      minitel.emulate('A'.codeUnits);
      minitel.emulate('\n'.codeUnits);

      // Le curseur reste en ligne 24 (dernière), le contenu a scrollé
      expect(minitel.state.l, 24);
      expect(readChar(minitel, 0, 23), 'A'); // 'A' maintenant en ligne 23
    });

    test('page mode: LF on last line wraps to line 1', () {
      // CSI < 4 h → mode page (séquence Minitel 80 cols)
      minitel.emulate('\x1b[<4h'.codeUnits);
      expect(minitel.scrollOn, isFalse);

      minitel.emulate('\x1b[24;1H'.codeUnits);
      minitel.emulate('A'.codeUnits);
      minitel.emulate('\n'.codeUnits);

      // Curseur revient en ligne 1, pas de scroll, 'A' reste en ligne 24
      expect(minitel.state.l, 1);
      expect(readChar(minitel, 0, 24), 'A');
    });

    test('CSI ? 4 l restores scroll mode (séquence Minitel 80 cols)', () {
      minitel.emulate('\x1b[<4h'.codeUnits);
      expect(minitel.scrollOn, isFalse);
      minitel.emulate('\x1b[?4l'.codeUnits);
      expect(minitel.scrollOn, isTrue);
    });

    // Les 3 tests suivants utilisent PRO2 (ESC :), qui n'est interprété que
    // si le Protocole est actif — donc en Mixte, pas en standard
    // Téléinformatique où il est gelé (STUM 1B). Ils utilisent donc leur
    // propre instance en mode Mixte plutôt que le `minitel` du groupe.
    test('ESC : i C sets scroll mode (Mixte, même séquence qu\'en 40 cols)',
        () {
      final minitel = TMinitel()..enterMixte();
      minitel.emulate([0x1B, 0x3A, 0x6A, 0x43]); // ESC : j C → page
      expect(minitel.scrollOn, isFalse);
      minitel.emulate([0x1B, 0x3A, 0x69, 0x43]); // ESC : i C → rouleau
      expect(minitel.scrollOn, isTrue);
    });

    test(
        'ESC : s y sets scroll mode via bitmask (Mixte, même séquence '
        'qu\'en 40 cols)', () {
      final minitel = TMinitel()..enterMixte();
      minitel.emulate([0x1B, 0x3A, 0x73, 0x00]); // bit 0x02 = 0 → page
      expect(minitel.scrollOn, isFalse);
      minitel.emulate([0x1B, 0x3A, 0x73, 0x02]); // bit 0x02 = 1 → rouleau
      expect(minitel.scrollOn, isTrue);
    });

    test(
        'ESC : i E / ESC : j E toggles keyboard lowercase mode '
        '(Mixte, même séquence qu\'en 40 cols)', () {
      final minitel = TMinitel()..enterMixte();
      // Passer en Mixte configure déjà le clavier en minuscules.
      expect(minitel.keyboardLowercase, isTrue);
      minitel.emulate([0x1B, 0x3A, 0x6A, 0x45]); // PRO2 STOP MINUSCULES
      expect(minitel.keyboardLowercase, isFalse);
      minitel.emulate([0x1B, 0x3A, 0x69, 0x45]); // PRO2 START MINUSCULES
      expect(minitel.keyboardLowercase, isTrue);
    });

    test(
        'ESC : i C (scroll mode) has no effect in standard Téléinformatique '
        '(Protocole gelé)', () {
      // Contrairement au test Mixte ci-dessus : ici `minitel` (du groupe)
      // est en vrai standard Téléinformatique, où PRO2 est ignoré.
      // clearScreen() met déjà scrollOn=true par défaut en 80 colonnes ;
      // PRO2 étant gelé, ces séquences ne doivent rien changer à cet état.
      expect(minitel.scrollOn, isTrue);
      minitel.emulate([0x1B, 0x3A, 0x6A, 0x43]); // ESC : j C → page (Mixte)
      expect(minitel.scrollOn, isTrue);
      minitel.emulate([0x1B, 0x3A, 0x69, 0x43]); // ESC : i C → rouleau (Mixte)
      expect(minitel.scrollOn, isTrue);
    });

    test('scroll-up new line is plain empty (no SGR attrs)', () {
      minitel.emulate('\x1b[7m'.codeUnits); // SGR inverse actif
      minitel.emulate('\x1b[24;1H'.codeUnits);
      minitel.emulate('\n'.codeUnits); // scroll up

      // Nouvelle ligne vierge : espace sans attributs (kEmptyChar)
      final char = minitel.screen[24][1];
      expect(char.lAttr & kAttrInverse, 0);
      expect(char.gAttr & kColorMask, kColorBlack);
    });

    test('scroll-up new line is plain empty (no bgColor)', () {
      minitel.emulate('\x1b[44m'.codeUnits); // SGR bg bleu actif
      minitel.emulate('\x1b[24;1H'.codeUnits);
      minitel.emulate('\n'.codeUnits); // scroll up

      // Nouvelle ligne vierge : fond noir (kEmptyChar, pas le SGR courant)
      final char = minitel.screen[24][1];
      expect(char.gAttr & kColorMask, kColorBlack);
    });

    test('RI scroll-down new line is plain empty (no SGR attrs)', () {
      minitel.emulate('\x1b[42m'.codeUnits); // SGR bg vert actif
      minitel.emulate('\x1b[1;1H'.codeUnits);
      minitel.emulate('\x1bM'.codeUnits); // RI

      // Nouvelle ligne vierge en haut : fond noir (kEmptyChar)
      final char = minitel.screen[1][1];
      expect(char.gAttr & kColorMask, kColorBlack);
    });

    test('ICH blank chars are plain empty (no SGR attrs)', () {
      minitel.emulate('\x1b[41mABCDE'.codeUnits); // SGR bg rouge + texte
      minitel.emulate('\x1b[1;3H\x1b[2@'.codeUnits); // ICH 2 en col 3

      // Les 2 nouvelles cellules vierges : fond noir (kEmptyChar)
      expect(minitel.screen[1][3].gAttr & kColorMask, kColorBlack);
      expect(minitel.screen[1][4].gAttr & kColorMask, kColorBlack);
    });

    test('IL blank line is plain empty (no SGR attrs)', () {
      minitel.emulate('\x1b[43m'.codeUnits); // SGR bg jaune actif
      minitel.emulate('\x1b[2;1H\x1b[L'.codeUnits); // IL en ligne 2

      // Ligne insérée vierge : fond noir (kEmptyChar)
      expect(minitel.screen[2][1].gAttr & kColorMask, kColorBlack);
    });

    test('cls does not reset SGR terminal attributes', () {
      minitel.emulate('\x1b[7m\x1b[44m'.codeUnits); // inverse + bg bleu
      minitel.emulate('\x1b[2J'.codeUnits); // ED 2 = cls

      // Les attributs SGR sont conservés dans le state
      expect(minitel.state.inverse, kAttrInverse);
      expect(minitel.state.bgColor, 4);

      // Les nouvelles cellules écrites utilisent ces attributs
      minitel.emulate('A'.codeUnits);
      expect(minitel.screen[1][1].lAttr & kAttrInverse, kAttrInverse);
      expect(minitel.screen[1][1].gAttr & kColorMask, 4);
    });

    test('cls fills screen with plain empty chars (no SGR attrs)', () {
      minitel.emulate('\x1b[44m'.codeUnits); // bg bleu actif
      minitel.emulate('A'.codeUnits); // écrit un caractère
      minitel.emulate('\x1b[2J'.codeUnits); // cls

      // Les cellules effacées sont sans attribut (fond noir = kEmptyChar)
      expect(minitel.screen[1][1].gAttr & kColorMask, kColorBlack);
    });

    test('supports US @ Pc to access line 0', () {
      minitel.emulate([0x1F, 0x40, 0x0A]);
      minitel.emulate('S'.codeUnits);

      expect(minitel.state.l, 0);
      expect(minitel.state.c, 11);
      expect(readChar(minitel, 9, 0), 'S');
    });

    test('US outside line-0 sequence is ignored without consuming next chars',
        () {
      // "US A A" doit produire "AA" (US ignoré, les deux 'A' traités normalement)
      minitel.emulate([0x1F, 0x41, 0x41]);

      expect(readLine(minitel, 1, 2), 'AA');
      expect(minitel.state.l, 1);
      expect(minitel.state.c, 3);
    });

    test('US followed by control code is ignored without consuming it', () {
      // US suivi de CR : le CR doit être exécuté (retour en colonne 1)
      minitel.emulate('ABCD'.codeUnits);
      minitel.emulate([0x1F, 0x0D]); // US CR

      expect(minitel.state.c, 1);
    });

    test(
        'LF exits line 0 and restores previous Téléinformatique cursor position',
        () {
      minitel.emulate('\x1b[5;12H'.codeUnits);
      minitel.emulate([0x1F, 0x40, 0x4A]);

      expect(minitel.state.l, 0);
      expect(minitel.state.c, 10);

      minitel.emulate('\n'.codeUnits);

      expect(minitel.state.l, 5);
      expect(minitel.state.c, 12);
    });

    test('SI (0x0F) does not reset inverse SGR attribute', () {
      // Un serveur Minitel envoie typiquement SI en fin de ligne pour revenir
      // au charset G0. En mode Téléinformatique, cela ne doit pas désactiver l'inverse.
      minitel.emulate('\x1b[7m'.codeUnits); // activer inverse
      minitel.emulate([0x0F]); // SI — charset G0, mais inverse intact
      expect(minitel.state.inverse, kAttrInverse);

      // Le caractère suivant doit avoir l'attribut inverse
      minitel.emulate('A'.codeUnits);
      expect(minitel.screen[1][1].lAttr & kAttrInverse, kAttrInverse);
    });

    test('SO (0x0E) does not reset inverse SGR attribute', () {
      // SO bascule vers le charset G1 sans toucher aux attrs SGR
      minitel.emulate('\x1b[7m'.codeUnits); // activer inverse
      minitel.emulate([0x0E]); // SO — charset G1, mais inverse intact
      expect(minitel.state.inverse, kAttrInverse);

      minitel.emulate('A'.codeUnits);
      expect(minitel.screen[1][1].lAttr & kAttrInverse, kAttrInverse);
    });

    test('SI after CRLF keeps inverse attribute', () {
      // Scénario réel : le serveur envoie "texte\r\n\x0f" pour fin de ligne
      minitel.emulate('\x1b[7m'.codeUnits);
      minitel.emulate('Hello'.codeUnits);
      minitel.emulate([0x0D, 0x0A, 0x0F]); // CR LF SI

      // L'inverse doit être toujours actif après CR+LF+SI
      expect(minitel.state.inverse, kAttrInverse);

      // La ligne suivante doit écrire en inverse
      minitel.emulate('B'.codeUnits);
      expect(minitel.screen[2][1].lAttr & kAttrInverse, kAttrInverse);
    });

    // Régression BASTOS : édition de ligne (backspace / écrasement) en 80
    // colonnes doit se comporter exactement comme un terminal ASCII simple,
    // sans passer par une séquence d'effacement CSI/ANSI.
    test('Correction: BS SP BS erases last char and moves cursor back', () {
      minitel.emulate('AB'.codeUnits);
      expect(minitel.state.c, 3);

      minitel.emulate([0x08, 0x20, 0x08]);

      expect(readChar(minitel, 0, 1), 'A');
      expect(readChar(minitel, 1, 1), ' ');
      expect(minitel.state.c, 2);
    });

    test('Mid-line insertion: retype tail then BS overwrites in place', () {
      minitel.emulate('AC'.codeUnits);
      minitel.emulate([0x08]); // cursor back between A and C
      expect(minitel.state.c, 2);

      minitel.emulate('BC'.codeUnits);
      minitel.emulate([0x08]);

      expect(readLine(minitel, 1, 3), 'ABC');
      expect(minitel.state.c, 3);
    });

    test('Annulation: BS BS SP SP BS BS clears line and restores cursor', () {
      minitel.emulate('AB'.codeUnits);
      expect(minitel.state.c, 3);

      minitel.emulate([0x08, 0x08, 0x20, 0x20, 0x08, 0x08]);

      expect(readLine(minitel, 1, 2), '  ');
      expect(minitel.state.c, 1);
    });
  });
}
