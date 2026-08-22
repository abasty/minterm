import 'package:charcode/ascii.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

// Some Minitel special codes
const int $rep = 0x12;

const int $sep = 0x13;
const int $ss2 = 0x19;

const int $pro1 = 0x39;
const int $pro2 = 0x3A;
const int $pro3 = 0x3B;

const int kStatePro1 = 110;
const int kStatePro2 = 120;
const int kStatePro3 = 130;
const int kStateSequence = 150;
const int kStateTeleinfoEsc = 200;
const int kStateTeleinfoCsi = 201;
const int kStateTeleinfoPro1 = 202;
const int kStateTeleinfoPro2 = 203;
const int kStateTeleinfoUs = 204;
const int kStateTeleinfoUsAt = 205;

const int kAttrDisjointed = kAttrUnderline;
const int kAttrDoubleHeight = 0x20;
const int kAttrDoubleHeightWidth = kAttrDoubleHeight | kAttrDoubleWidth;
const int kAttrDoubleWidth = 0x40;
// Local attributes
// fgcolor (3), flash (1), inverse (1), taille(2), double part (1)
const int kAttrBlink = 0x08;
const int kAttrInverse = 0x10;

const int kAttrNone = 0x00;
const int kAttrSpace = 0x40;
// Global attributes
// bgcolor (3), lignage / disjoint (1), charset (2), espsep (1)
const int kAttrUnderline = 0x08;
const int kCharsetMask = 0x30;
const int kColorBlack = 0x00;
// Attribute masks
const int kColorMask = 0x07;

const int kColorWhite = 0x07;

const int kDoublePart = 0x80;
const int kG0Charset = 0x00;
const int kG1Charset = 0x10;

const int kG2Charset = 0x20;
// Char code redraw flag
const int kIsDirty = 0x80;
const int kSizeMask = 0x60;

class TMinitelKey {
  static const cxFin = '\x13Y';
  static const sommaire = '\x13F';
  static const guide = '\x13D';
  static const annulation = '\x13E';
  static const correction = '\x13G';
  static const retour = '\x13B';
  static const suite = '\x13H';
  static const repetition = '\x13C';
  static const envoi = '\x13A';
  static const grave = '\x19A';
  static const aigu = '\x19B';
  static const circonflexe = '\x19C';
  static const trema = '\x19H';
  static const cedille = '\x19K';
  static const flecheHaut = '\x19\x2d';
  static const livre = '\x19\x23';
  // ignore: constant_identifier_names
  static const OE = '\x19\x6a';
  static const oe = '\x19\x7a';
  static const beta = '\x19\x7b';
  static const paragraph = '\x19\x27';
  static const degree = '\x19\x30';
  static const arrowUp = '\x1b[A';
  static const arrowDown = '\x1b[B';
  static const arrowRight = '\x1b[C';
  static const arrowLeft = '\x1b[D';
  static const ePage = '\x1b\x5b\x32\x4a';
  static const home = "\x1b\x5b\x48";
  static const supL = '\x1b\x5b\x4d';
  static const insL = '\x1b\x5b\x4c';
  static const delC = '\x1b\x5b\x50';
}

final kEmptyChar = TMinitelChar(kG1Charset, kColorWhite, kIsDirty + $space);

// Types
typedef FHandleCode = void Function();

typedef TMinitelScreen = List<List<TMinitelChar>>;

enum TMinitelScreenMode {
  videotex40,
  teleinfo80,
}

class TMinitel {
  static const int kRows = 25;

  int stateCode = 0;
  bool _isPro3On = false;
  bool _isPro3StatusEcho = false;
  int currentCode = 0;
  int prevCode = 0;
  int lastCode = 0;
  int lastCharset = kG0Charset;
  bool scrollOn = false;
  bool cursorOn = false;
  bool keyboardLowercase = false;
  bool speedChanged = false;
  int speed = 1200;
  bool bip = false;
  bool echoChanged = false;
  bool _isEchoed = true;
  List<int> currentSequence = [];
  List<int> reply = [];
  TMinitelScreenMode _screenMode = TMinitelScreenMode.videotex40;
  int _columns = 40;
  StringBuffer _teleinfoCsiBuffer = StringBuffer();
  // Marqueur intermédiaire CSI : 0=aucun, 0x3F='?' (Téléinformatique), 0x3C='<' (Minitel 80 cols)
  int _teleinfoCsiIntermediate = 0;
  int _teleinfoPro2Prefix = -1;
  int _teleinfoSavedRow = 1;
  int _teleinfoSavedColumn = 1;
  int _teleinfoLine0ReturnRow = 1;
  int _teleinfoLine0ReturnColumn = 1;
  bool _teleinfoInsertMode = false;

  bool get isEchoed => _isEchoed;
  set isEchoed(bool value) {
    if (_isEchoed != value) {
      _isEchoed = value;
      echoChanged = true;
    }
  }

  TMinitelScreenMode get screenMode => _screenMode;

  int get columns => _columns;

  int get rows => kRows;

  int get lastColumn => _columns;

  int get lastLine => rows - 1;

  int get _dirtyColumn => _columns + 1;

  bool get isTeleinfoMode => _screenMode == TMinitelScreenMode.teleinfo80;

  void setScreenMode(TMinitelScreenMode mode) {
    if (_screenMode == mode) return;
    _screenMode = mode;
    if (mode == TMinitelScreenMode.videotex40) {
      scrollOn = false;
      // Sur Minitel réel, repasser en 40 colonnes éteint le curseur et
      // remet le clavier en majuscules seules.
      cursorOn = false;
      keyboardLowercase = false;
    }
    _columns = mode == TMinitelScreenMode.teleinfo80 ? 80 : 40;
    _initScreen();
    clearScreen();
  }

  void toggleScreenMode() {
    setScreenMode(
      _screenMode == TMinitelScreenMode.videotex40
          ? TMinitelScreenMode.teleinfo80
          : TMinitelScreenMode.videotex40,
    );
  }

  TMinitelState state = TMinitelState(l: 1, c: 1);
  TMinitelState savedState = TMinitelState();
  TMinitelScreen screen = [];

  TMinitel() {
    _initScreen();
    clearScreen();
  }

  void _initScreen() {
    screen = List.generate(
      rows,
      (_) => List.generate(
        _columns + 2,
        (_) => TMinitelChar(kG1Charset, kColorWhite, kIsDirty + $space),
      ),
    );
  }

  bool get isDirty {
    return (screen[0][_dirtyColumn].code & kIsDirty) != 0;
  }

  set isDirty(bool value) {
    if (value) {
      screen[0][_dirtyColumn].code |= kIsDirty;
    } else {
      screen[0][_dirtyColumn].code &= ~kIsDirty;
    }
  }

  void clearScreen() {
    if (!isTeleinfoMode) {
      state.resetAttr();
    }
    if (isTeleinfoMode) {
      scrollOn = true;
      cursorOn = true;
      _teleinfoInsertMode = false;
      _teleinfoLine0ReturnRow = 1;
      _teleinfoLine0ReturnColumn = 1;
      state.fgColor = 2; // couleur par défaut Téléinformatique
    }
    state.l = 1;
    state.c = 1;
    for (int line = 1; line <= lastLine; ++line) {
      for (int column = 0; column <= _dirtyColumn; ++column) {
        screen[line][column].copyFrom(kEmptyChar);
      }
    }
    for (int column = 0; column <= _dirtyColumn; ++column) {
      screen[0][column].copyFrom(kEmptyChar);
    }
    stateCode = 0;
  }

  void clearScreenPreserveLine0() {
    state.resetAttr();
    state.l = 1;
    state.c = 1;
    for (int line = 1; line <= lastLine; ++line) {
      for (int column = 0; column <= _dirtyColumn; ++column) {
        screen[line][column].copyFrom(kEmptyChar);
      }
    }
    stateCode = 0;
  }

  void setPartAttr(int l, int c, TMinitelChar char, int partFlags) {
    final partChar = screen[l][c];
    partChar.code = char.code;
    partChar.lAttr = (char.lAttr & ~kSizeMask) | kDoublePart | partFlags;
    if ((char.gAttr & kAttrSpace) == kAttrSpace) {
      partChar.gAttr = (char.gAttr & kColorMask) | kAttrSpace;
    } else {
      inheritGlobalAttr(l, c);
    }
  }

  void emulate(List<int> codes) {
    if (isTeleinfoMode) {
      emulateTeleinfo(codes);
      return;
    }

    final fadr = <FHandleCode>[
      handleNull,
      handleNull,
      handleNull,
      handleNull,
      handleNull,
      handleNull,
      handleNull,
      handleBell,
      handleBackSpace,
      handleTabulation,
      handleLineFeed,
      handleVerticalTab,
      clearScreenPreserveLine0,
      handleCarriageReturn,
      setG1Charset,
      setG0Charset,
      handleNull,
      setCursorOn,
      handleRepeat,
      handleSeparator,
      setCursorOff,
      handleNull,
      setG2Charset,
      handleNull,
      handleCancel,
      setG2Charset,
      handleNull,
      handleEscape,
      handleNull,
      handleNull,
      setCursorHome,
      handleCursorPosition,
    ];

    int line, column;
    bool cursor;
    int codeIndex;

    cursor = cursorOn;
    column = state.c;
    line = state.l;
    codeIndex = 0;
    while (codeIndex < codes.length) {
      if (isTeleinfoMode) {
        emulateTeleinfo(codes.sublist(codeIndex));
        break;
      }
      currentCode = codes[codeIndex];
      if (currentCode < $space) {
        fadr[currentCode]();
      } else if (stateCode == 0) {
        handleChar();
      } else {
        switch (stateCode) {
          case $rep:
            handleRepeatChar(currentCode);
            break;
          case $sep:
            stateCode = 0;
            break;
          case $us:
            prevCode = currentCode;
            stateCode = $us + 1;
            break;
          case const ($us + 1):
            setCursorPosition(prevCode, currentCode);
            stateCode = 0;
            break;
          // Add the rest of the cases here
          case $ss2:
            handleSS2();
            break;
          case const ($ss2 + 1):
            handleSS2AccentedChar();
            break;
          case $esc:
            handleEscapeNext();
            break;
          case const ($esc + 1):
            stateCode = 0;
            break;
          case const ($esc + 2):
            if (!(currentCode >= 0x20 && currentCode <= 0x2F)) stateCode = 0;
            break;
          case kStatePro1:
            handleProtocol1(currentCode);
            break;
          case kStatePro2:
            stateCode++;
            prevCode = currentCode;
            break;
          case const (kStatePro2 + 1):
            handleProtocol2(prevCode, currentCode);
            break;
          case kStatePro3:
            // PRO3 / ON/OFF
            _isPro3StatusEcho = currentCode == 0x61 || currentCode == 0x60;
            _isPro3On = currentCode == 0x61;
            stateCode++;
            break;
          case const (kStatePro3 + 1):
            // PRO3 / ON/OFF / MODEM
            _isPro3StatusEcho = _isPro3StatusEcho && currentCode == 0x5a;
            stateCode++;
            break;
          case const (kStatePro3 + 2):
            // PRO3 / ON/OFF / MODEM / CLAVIER
            // ECHO OFF: "\x1b\x3b\x60\x5a\x51"
            // ECHO ON:  "\x1b\x3b\x61\x5a\x51"
            _isPro3StatusEcho = _isPro3StatusEcho && currentCode == 0x51;
            if (_isPro3StatusEcho) {
              isEchoed = _isPro3On;
            }
            stateCode = 0;
            break;
          case kStateSequence:
            stateCode = handleSequence(currentCode);
            break;
        }
      }
      ++codeIndex;
      if (cursor != cursorOn) {
        markCharAsDirty(line, column);
      } else if (cursorOn && (column != state.c || line != state.l)) {
        markCharAsDirty(line, column);
        markCharAsDirty(state.l, state.c);
      }
    }
  }

  void emulateTeleinfo(List<int> codes) {
    int line = state.l;
    int column = state.c;
    bool cursor = cursorOn;

    for (int i = 0; i < codes.length; i++) {
      if (!isTeleinfoMode) {
        emulate(codes.sublist(i));
        break;
      }

      final code = codes[i];
      currentCode = code;
      if (stateCode == kStateTeleinfoPro1) {
        handleProtocol1(code);
      } else if (stateCode == kStateTeleinfoPro2) {
        _handleTeleinfoPro2(code);
      } else if (stateCode == kStateTeleinfoUs) {
        _handleTeleinfoUs(code);
      } else if (stateCode == kStateTeleinfoUsAt) {
        _handleTeleinfoUsAt(code);
      } else if (stateCode == kStateTeleinfoEsc) {
        _handleTeleinfoEscape(code);
      } else if (stateCode == kStateTeleinfoCsi) {
        _handleTeleinfoCsi(code);
      } else if (code == $esc) {
        stateCode = kStateTeleinfoEsc;
      } else if (code < $space) {
        _handleTeleinfoControl(code);
      } else if (code != 0x7F) {
        if (_teleinfoInsertMode) {
          _teleinfoInsertChars(1);
        }
        _putCharTeleinfo(code);
        _setCursorForwardTeleinfo();
      }

      if (cursor != cursorOn) {
        markCharAsDirty(line, column);
      } else if (cursorOn && (column != state.c || line != state.l)) {
        markCharAsDirty(line, column);
        markCharAsDirty(state.l, state.c);
      }

      line = state.l;
      column = state.c;
      cursor = cursorOn;
    }
  }

  void _handleTeleinfoControl(int code) {
    switch (code) {
      case 0x07:
        handleBell();
        break;
      case 0x08:
        if (state.c > 1) {
          state.c--;
        }
        break;
      case $tab:
        final nextTab = (((state.c - 1) ~/ 8) + 1) * 8 + 1;
        state.c = nextTab > lastColumn ? lastColumn : nextTab;
        break;
      case 0x0A:
      case 0x0B:
      case 0x0C:
        _teleinfoLineFeed();
        break;
      case 0x0D:
        state.c = 1;
        break;
      case 0x0E:
        // SO : bascule GL vers G1 (charset seulement, pas les attrs SGR)
        state.charset = kG1Charset;
        break;
      case 0x0F:
        // SI : bascule GL vers G0 (charset seulement, pas les attrs SGR)
        state.charset = kG0Charset;
        break;
      case $can:
      case $sub:
        _putCharTeleinfo(0x7F);
        _setCursorForwardTeleinfo();
        break;
      case $rs:
        _setCursorClamped(1, 1);
        break;
      case $us:
        stateCode = kStateTeleinfoUs;
        return;
      default:
        break;
    }
    stateCode = 0;
  }

  void _handleTeleinfoUs(int code) {
    if (code == 0x40) {
      stateCode = kStateTeleinfoUsAt;
      return;
    }
    // US ignoré (hors séquence ligne 0) : re-traite le byte courant normalement
    stateCode = 0;
    if (code == $esc) {
      stateCode = kStateTeleinfoEsc;
    } else if (code < $space) {
      _handleTeleinfoControl(code);
    } else if (code != 0x7F) {
      if (_teleinfoInsertMode) {
        _teleinfoInsertChars(1);
      }
      _putCharTeleinfo(code);
      _setCursorForwardTeleinfo();
    }
  }

  void _handleTeleinfoUsAt(int code) {
    if (code >= 0x40) {
      code -= 0x40;
    }
    if (code > 0 && code < 64) {
      if (state.l != 0) {
        _teleinfoLine0ReturnRow = state.l;
        _teleinfoLine0ReturnColumn = state.c;
      }
      state.l = 0;
      state.c = code;
    }
    stateCode = 0;
  }

  void _handleTeleinfoEscape(int code) {
    if (code == $pro1) {
      stateCode = kStateTeleinfoPro1;
      return;
    }

    if (code == $pro2) {
      _teleinfoPro2Prefix = -1;
      stateCode = kStateTeleinfoPro2;
      return;
    }

    if (code == 0x5B) {
      _teleinfoCsiBuffer = StringBuffer();
      _teleinfoCsiIntermediate = 0;
      stateCode = kStateTeleinfoCsi;
      return;
    }

    switch (code) {
      case 0x37: // DECSC
        _teleinfoSavedRow = state.l;
        _teleinfoSavedColumn = state.c;
        break;
      case 0x38: // DECRC
        _setCursorClamped(_teleinfoSavedRow, _teleinfoSavedColumn);
        break;
      case 0x44: // IND
        _teleinfoLineFeed();
        break;
      case 0x45: // NEL
        state.c = 1;
        _teleinfoLineFeed();
        break;
      case 0x4D: // RI
        if (state.l > 1) {
          state.l--;
        } else {
          _teleinfoScrollDown();
        }
        break;
      case 0x63: // RIS
        clearScreen();
        break;
      default:
        break;
    }
    stateCode = 0;
  }

  void _handleTeleinfoPro2(int code) {
    if (_teleinfoPro2Prefix < 0) {
      _teleinfoPro2Prefix = code;
      stateCode = kStateTeleinfoPro2;
      return;
    }

    if (_teleinfoPro2Prefix == 0x32) {
      if (code == 0x7D) {
        setScreenMode(TMinitelScreenMode.teleinfo80);
      } else if (code == 0x7E) {
        setScreenMode(TMinitelScreenMode.videotex40);
      }
    } else {
      // Délégation aux séquences protocole 2 communes (ex. rouleau/page)
      handleProtocol2(_teleinfoPro2Prefix, code);
    }

    _teleinfoPro2Prefix = -1;
    stateCode = 0;
  }

  void _handleTeleinfoCsi(int code) {
    if ((code >= 0x30 && code <= 0x39) || code == 0x3B) {
      _teleinfoCsiBuffer.writeCharCode(code);
      return;
    }
    // Marqueurs intermédiaires : '?' (Téléinformatique) et '<' (Minitel 80 cols)
    if ((code == 0x3F || code == 0x3C) &&
        _teleinfoCsiBuffer.isEmpty &&
        _teleinfoCsiIntermediate == 0) {
      _teleinfoCsiIntermediate = code;
      return;
    }
    if (code >= 0x40 && code <= 0x7E) {
      _executeTeleinfoCsi(
          code, _teleinfoParseParams(_teleinfoCsiBuffer.toString()));
      _teleinfoCsiBuffer = StringBuffer();
      _teleinfoCsiIntermediate = 0;
      stateCode = 0;
      return;
    }

    // Unsupported CSI fragment: reset state to avoid getting stuck.
    _teleinfoCsiBuffer = StringBuffer();
    _teleinfoCsiIntermediate = 0;
    stateCode = 0;
  }

  List<int> _teleinfoParseParams(String raw) {
    if (raw.isEmpty) return [];
    return raw.split(';').map((s) {
      if (s.isEmpty) return 0;
      return int.tryParse(s) ?? 0;
    }).toList();
  }

  int _teleinfoParam(List<int> params, int index, int fallback) {
    if (index >= params.length || params[index] == 0) return fallback;
    return params[index];
  }

  void _executeTeleinfoCsi(int finalCode, List<int> params) {
    switch (finalCode) {
      case 0x41: // CUU
        _setCursorClamped(state.l - _teleinfoParam(params, 0, 1), state.c);
        break;
      case 0x42: // CUD
        _setCursorClamped(state.l + _teleinfoParam(params, 0, 1), state.c);
        break;
      case 0x43: // CUF
        _setCursorClamped(state.l, state.c + _teleinfoParam(params, 0, 1));
        break;
      case 0x44: // CUB
        _setCursorClamped(state.l, state.c - _teleinfoParam(params, 0, 1));
        break;
      case 0x47: // CHA
        _setCursorClamped(state.l, _teleinfoParam(params, 0, 1));
        break;
      case 0x48: // CUP
      case 0x66: // HVP
        _setCursorClamped(
            _teleinfoParam(params, 0, 1), _teleinfoParam(params, 1, 1));
        break;
      case 0x64: // VPA
        _setCursorClamped(_teleinfoParam(params, 0, 1), state.c);
        break;
      case 0x4A: // ED
        _teleinfoEraseDisplay(_teleinfoParam(params, 0, 0));
        break;
      case 0x4B: // EL
        _teleinfoEraseLine(_teleinfoParam(params, 0, 0));
        break;
      case 0x40: // ICH
        _teleinfoInsertChars(_teleinfoParam(params, 0, 1));
        break;
      case 0x4C: // IL
        _teleinfoInsertLines(_teleinfoParam(params, 0, 1));
        break;
      case 0x4D: // DL
        _teleinfoDeleteLines(_teleinfoParam(params, 0, 1));
        break;
      case 0x50: // DCH
        _teleinfoDeleteChars(_teleinfoParam(params, 0, 1));
        break;
      case 0x6D: // SGR
        _teleinfoSetSgr(params);
        break;
      case 0x6E: // DSR
        if (params.isNotEmpty && params.first == 6) {
          reply.addAll([0x1B, 0x5B]);
          reply.addAll(state.l.toString().codeUnits);
          reply.add(0x3B);
          reply.addAll(state.c.toString().codeUnits);
          reply.add(0x52);
        }
        break;
      case 0x73: // SCP
        _teleinfoSavedRow = state.l;
        _teleinfoSavedColumn = state.c;
        break;
      case 0x75: // RCP
        _setCursorClamped(_teleinfoSavedRow, _teleinfoSavedColumn);
        break;
      case 0x68: // SM
      case 0x6C: // RM
        final enable = finalCode == 0x68;
        if (_teleinfoCsiIntermediate == 0x3F && params.isNotEmpty) {
          // Séquences Téléinformatique privées : CSI ? Pn h/l
          switch (params.first) {
            case 1:
              cursorOn = enable;
              break;
            case 3:
              setScreenMode(
                enable
                    ? TMinitelScreenMode.videotex40
                    : TMinitelScreenMode.teleinfo80,
              );
              break;
            case 4:
              scrollOn = !enable;
              break;
            default:
              break;
          }
        } else if (_teleinfoCsiIntermediate == 0x3C && params.isNotEmpty) {
          // Séquences Minitel 80 cols : CSI < Pn h/l
          // Convention inversée : l (0x6C) = ON, h (0x68) = OFF
          final minitelEnable = finalCode == 0x6C;
          switch (params.first) {
            case 1: // Allumage/arrêt du curseur
              cursorOn = minitelEnable;
              break;
            case 4: // Mode page (CSI < 4 h) / mode rouleau (CSI < 4 l)
              scrollOn = minitelEnable;
              break;
            default:
              break;
          }
        } else if (params.isNotEmpty && params.first == 4) {
          _teleinfoInsertMode = enable;
        }
        break;
      default:
        break;
    }
  }

  void _teleinfoInsertChars(int count) {
    final n = count < 1 ? 1 : count;
    final l = state.l;
    if (l < 1 || l > lastLine) return;
    final c = state.c;
    for (int column = lastColumn; column >= c; --column) {
      final src = column - n;
      screen[l][column] = src >= c
          ? TMinitelChar.from(screen[l][src])
          : TMinitelChar.from(kEmptyChar);
      markCharAsDirty(l, column);
    }
  }

  void _teleinfoDeleteChars(int count) {
    final n = count < 1 ? 1 : count;
    final l = state.l;
    if (l < 1 || l > lastLine) return;
    final c = state.c;
    for (int column = c; column <= lastColumn; ++column) {
      final src = column + n;
      screen[l][column] = src <= lastColumn
          ? TMinitelChar.from(screen[l][src])
          : TMinitelChar.from(kEmptyChar);
      markCharAsDirty(l, column);
    }
  }

  void _teleinfoInsertLines(int count) {
    final n = count < 1 ? 1 : count;
    final start = state.l;
    if (start < 1 || start > lastLine) return;
    for (int line = lastLine; line >= start; --line) {
      final src = line - n;
      for (int column = 1; column <= lastColumn; ++column) {
        screen[line][column] = src >= start
            ? TMinitelChar.from(screen[src][column])
            : TMinitelChar.from(kEmptyChar);
      }
      screen[line][0].code |= kIsDirty;
    }
    screen[0][_dirtyColumn].code |= kIsDirty;
  }

  void _teleinfoDeleteLines(int count) {
    final n = count < 1 ? 1 : count;
    final start = state.l;
    if (start < 1 || start > lastLine) return;
    for (int line = start; line <= lastLine; ++line) {
      final src = line + n;
      for (int column = 1; column <= lastColumn; ++column) {
        screen[line][column] = src <= lastLine
            ? TMinitelChar.from(screen[src][column])
            : TMinitelChar.from(kEmptyChar);
      }
      screen[line][0].code |= kIsDirty;
    }
    screen[0][_dirtyColumn].code |= kIsDirty;
  }

  void _teleinfoSetSgr(List<int> params) {
    final effective = params.isEmpty ? [0] : params;
    for (final param in effective) {
      switch (param) {
        case 0:
          state.resetAttr();
          state.fgColor =
              2; // couleur par défaut Téléinformatique (pas kColorWhite)
          break;
        case 1:
          state.fgColor = kColorWhite; // surintensité → couleur 7
          break;
        case 4:
          state.underlined = kAttrUnderline;
          break;
        case 5:
          state.blink = kAttrBlink;
          break;
        case 7:
          state.inverse = kAttrInverse;
          break;
        case 22:
          state.fgColor = 2; // fin surintensité → couleur par défaut 2
          break;
        case 24:
          state.underlined = kAttrNone;
          break;
        case 25:
          state.blink = kAttrNone;
          break;
        case 27:
          state.inverse = kAttrNone;
          break;
        case >= 30 && <= 37:
          state.fgColor = param - 30;
          break;
        case 39:
          state.fgColor = 2; // couleur fg par défaut Téléinformatique
          break;
        case >= 40 && <= 47:
          state.bgColor = param - 40;
          break;
        case 49:
          state.bgColor = kColorBlack;
          break;
      }
    }
    state.charset = kG0Charset;
    state.size = kAttrNone;
    state.needAttrSpace = false;
  }

  void _teleinfoEraseDisplay(int mode) {
    switch (mode) {
      case 1:
        for (int line = 1; line < state.l; ++line) {
          _teleinfoClearLine(line, 1, lastColumn);
        }
        _teleinfoClearLine(state.l, 1, state.c);
        break;
      case 2:
        for (int line = 1; line <= lastLine; ++line) {
          _teleinfoClearLine(line, 1, lastColumn);
        }
        break;
      case 0:
      default:
        _teleinfoClearLine(state.l, state.c, lastColumn);
        for (int line = state.l + 1; line <= lastLine; ++line) {
          _teleinfoClearLine(line, 1, lastColumn);
        }
        break;
    }
  }

  void _teleinfoEraseLine(int mode) {
    switch (mode) {
      case 1:
        _teleinfoClearLine(state.l, 1, state.c);
        break;
      case 2:
        _teleinfoClearLine(state.l, 1, lastColumn);
        break;
      case 0:
      default:
        _teleinfoClearLine(state.l, state.c, lastColumn);
        break;
    }
  }

  void _teleinfoClearLine(int line, int fromColumn, int toColumn) {
    final start = fromColumn < 1 ? 1 : fromColumn;
    final end = toColumn > lastColumn ? lastColumn : toColumn;
    for (int column = start; column <= end; ++column) {
      screen[line][column] = TMinitelChar.from(kEmptyChar);
      markCharAsDirty(line, column);
    }
  }

  void _putCharTeleinfo(int code) {
    final l = state.l;
    final c = state.c;
    final char = screen[l][c];
    char.code = code;
    char.gAttr = state.bgColor | state.underlined;
    char.lAttr = state.fgColor | state.blink | state.inverse;
    markCharAsDirty(l, c);
  }

  void _setCursorForwardTeleinfo() {
    if (state.c < lastColumn) {
      state.c++;
    }
  }

  void _teleinfoLineFeed() {
    if (state.l == 0) {
      _setCursorClamped(_teleinfoLine0ReturnRow, _teleinfoLine0ReturnColumn);
      return;
    }
    if (state.l < lastLine) {
      state.l++;
    } else if (scrollOn) {
      _teleinfoScrollUp();
    } else {
      // Mode page : retour en ligne 1 (même comportement qu'en 40 cols)
      state.l = 1;
    }
  }

  void _teleinfoScrollUp({int fromLine = 1}) {
    scrollUp(fromLine: fromLine);
  }

  void _teleinfoScrollDown({int fromLine = 1}) {
    scrollDown(fromLine: fromLine);
  }

  void _setCursorClamped(int line, int column) {
    state.l = line < 1 ? 1 : (line > lastLine ? lastLine : line);
    state.c = column < 1 ? 1 : (column > lastColumn ? lastColumn : column);
  }

  void handleBackSpace() {
    if (state.c > 1) {
      state.c--;
      stateCode = 0;
    } else {
      state.c = lastColumn;
      handleVerticalTab();
    }
  }

  void handleBell() {
    bip = true;
    stateCode = 0;
  }

  void handleCancel() {
    int n;
    int size;
    int column, line;
    bool scroll;

    n = lastColumn + 1 - state.c;
    currentCode = $space;
    size = state.size;
    column = state.c;
    line = state.l;
    scroll = scrollOn;
    scrollOn = false;
    if ((size & kAttrDoubleHeight) != 0) {
      state.size = kAttrDoubleHeight;
    } else {
      state.size = kAttrNone;
    }
    for (int i = 1; i <= n; ++i) {
      handleChar();
    }
    state.size = size;
    state.c = column;
    state.l = line;
    scrollOn = scroll;
    stateCode = 0;
  }

  void handleCarriageReturn() {
    state.c = 1;
    stateCode = 0;
  }

  void handleChar() {
    lastCharset = state.charset;
    putChar(currentCode);
    lastCode = currentCode;
    setCursorForward();
    stateCode = 0;
  }

  void handleCursorPosition() {
    stateCode = $us;
  }

  void handleEscape() {
    stateCode = $esc;
  }

  void handleEscapeNext() {
    if (currentCode >= 0x40) {
      switch (currentCode) {
        case >= $at && <= $G:
          setForegroundColor(currentCode);
          break;
        case >= $P && <= $W:
          setBackgroundColor(currentCode);
          break;
        case >= $H && <= $I:
          setFlashAttr(currentCode);
          break;
        case >= $Y && <= $Z:
          setUnderlineAttr(currentCode);
          break;
        case == 0x5C || == 0x5D:
          if (state.charset != kG1Charset) {
            setInverseAttr(currentCode);
          }
          break;
        case >= $L && <= $O:
          if (state.charset != kG1Charset) {
            setSizeAttr(currentCode);
          }
          break;
      }
      if (currentCode == 0x5b) {
        currentSequence = [0x1b, 0x5b];
        stateCode = kStateSequence;
      } else {
        stateCode = 0;
      }
    } else if (currentCode >= $pro1 && currentCode <= $pro3) {
      switch (currentCode) {
        case $pro1:
          stateCode = kStatePro1;
          break;
        case $pro2:
          stateCode = kStatePro2;
          break;
        case $pro3:
          stateCode = kStatePro3;
          break;
        default:
          stateCode = 0;
          break;
      }
    } else if (currentCode >= 0x35 && currentCode <= 0x37) {
      stateCode = $esc + 1;
    } else if (currentCode >= 0x20 && currentCode <= 0x2F) {
      stateCode = $esc + 2;
    }
  }

  void handleLineFeed() {
    if (state.l == 0) {
      state = TMinitelState.from(savedState);
    } else if (state.l < lastLine) {
      state.l++;
    } else if (scrollOn) {
      state.l = lastLine;
      scrollUp();
    } else {
      state.l = 1;
    }
    stateCode = 0;
  }

  void handleNull() {
    stateCode = 0;
  }

  void handleProtocol1(int x) {
    if (x == 0x74) {
      // 4 = 100 = 1200
      // 6 = 110 = 4800 (M1B)
      // 7 = 111 = 9600 (M2)
      int speedReply = 0;
      if (speed == 9600) {
        speedReply = 0x7f;
      } else if (speed == 4800) {
        speedReply = 0x76;
      } else {
        speedReply = 0x64;
      }
      if (speed != 0) {
        if (kDebugMode) {
          print('Protocol 1: speed reply $speedReply');
        }
        reply.addAll([0x1b, 0x3a, 0x75, speedReply]);
      }
    } else if (x == 0x7f) {
      setScreenMode(TMinitelScreenMode.videotex40);
    }
    stateCode = 0;
  }

  void handleProtocol2(int x, int y) {
    if (y == 0x43) {
      switch (x) {
        case 0x69:
          scrollOn = true;
          break;
        case 0x6A:
          scrollOn = false;
          break;
      }
    } else if (y == 0x45) {
      // Minuscules : PRO2 START/STOP + MINUSCULES (0x45) bascule le clavier
      // entre émission minuscule/majuscule et majuscule seule (par défaut).
      switch (x) {
        case 0x69:
          keyboardLowercase = true;
          break;
        case 0x6A:
          keyboardLowercase = false;
          break;
      }
    } else if (x == 0x73) {
      scrollOn = (y & 0x02) == 0x02;
    } else if (x == 0x6b) {
      if (y == 0x7f) {
        speedChanged = true;
        speed = 9600;
      } else if (y == 0x76) {
        speedChanged = true;
        speed = 4800;
      } else if (y == 0x64) {
        speedChanged = true;
        speed = 1200;
      }
    } else if (x == 0x32) {
      if (y == 0x7D) {
        setScreenMode(TMinitelScreenMode.teleinfo80);
      } else if (y == 0x7E) {
        setScreenMode(TMinitelScreenMode.videotex40);
      }
    }
    stateCode = 0;
  }

  int handleSequence(int code) {
    // TODO: Add more sequences as needed (ins, del, etc.)
    var knownSequences = {
      TMinitelKey.ePage.codeUnits: clearScreen,
      TMinitelKey.arrowUp.codeUnits: handleVerticalTab,
      TMinitelKey.arrowDown.codeUnits: handleLineFeed,
      TMinitelKey.arrowRight.codeUnits: handleTabulation,
      TMinitelKey.arrowLeft.codeUnits: handleBackSpace,
      TMinitelKey.home.codeUnits: setCursorHome,
      TMinitelKey.supL.codeUnits: handleSupL,
      TMinitelKey.insL.codeUnits: handleInsL,
      TMinitelKey.delC.codeUnits: handleDelC,
      [0x1b, 0x5b, 0x3f, 0x33, 0x68]: () {
        setScreenMode(TMinitelScreenMode.videotex40);
      },
      [0x1b, 0x5b, 0x3f, 0x33, 0x6c]: () {
        setScreenMode(TMinitelScreenMode.teleinfo80);
      },
    };

    // Add the new code to the current sequence
    currentSequence.add(code);

    // Search for currentSequence in knownSequences
    for (var seq in knownSequences.entries) {
      var sequence = seq.key;
      var handler = seq.value;
      if (currentSequence.length <= sequence.length) {
        // Count matching characters
        int matchCount = 0;
        for (int i = 0; i < currentSequence.length; i++) {
          if (currentSequence[i] == sequence[i]) {
            matchCount++;
          }
        }
        if (matchCount == sequence.length) {
          // Full match
          handler();
          return 0;
        } else if (matchCount == currentSequence.length) {
          // Partial match
          return kStateSequence;
        }
      }
    }

    currentSequence.clear();
    // If not found: return 0
    return 0;
  }

  void handleRepeat() {
    stateCode = $rep;
  }

  void handleRepeatChar(int charCode) {
    int i;
    int n;
    if (charCode >= 65) {
      n = charCode - 64;
      currentCode = lastCode;
      if (lastCharset == kG2Charset && state.charset == kG0Charset) {
        state.charset = kG2Charset;
      }
      for (i = 1; i <= n; ++i) {
        handleChar();
      }
      if (lastCharset == kG2Charset && state.charset == kG2Charset) {
        state.charset = kG0Charset;
      }
    }
    stateCode = 0;
  }

  void handleSeparator() {
    stateCode = $sep;
  }

  void handleSS2() {
    if (currentCode == $A ||
        currentCode == $B ||
        currentCode == $C ||
        currentCode == $H ||
        currentCode == $K) {
      // Accented characters
      prevCode = currentCode;
      stateCode = $ss2 + 1;
    } else {
      // Special characters
      handleSS2SpecialChar();
    }
  }

  void handleSS2AccentedChar() {
    state.charset = kG2Charset;
    switch (prevCode) {
      case $A: // Grave
        switch (currentCode) {
          case $a:
            currentCode = 0x10;
            break;
          case $e:
            currentCode = 0x11;
            break;
          case $u:
            currentCode = 0x12;
            break;
          default:
            state.charset = kG0Charset;
            break;
        }
        break;
      case $B: // Aigu
        switch (currentCode) {
          case $e:
            currentCode = 0x13;
            break;
          default:
            state.charset = kG0Charset;
            break;
        }
        break;
      case $C: // Circonflexe
        switch (currentCode) {
          case $a:
            currentCode = 0x14;
            break;
          case $e:
            currentCode = 0x15;
            break;
          case $i:
            currentCode = 0x16;
            break;
          case $o:
            currentCode = 0x17;
            break;
          case $u:
            currentCode = 0x18;
            break;
          default:
            state.charset = kG0Charset;
            break;
        }
        break;
      case $H: // Tréma
        switch (currentCode) {
          case $a:
            currentCode = 0x19;
            break;
          case $e:
            currentCode = 0x1A;
            break;
          case $i:
            currentCode = 0x1B;
            break;
          case $o:
            currentCode = 0x1C;
            break;
          case $u:
            currentCode = 0x1D;
            break;
          default:
            state.charset = kG0Charset;
            break;
        }
        break;
      case $K: // Cedille
        switch (currentCode) {
          case $c:
            currentCode = 0x1E;
            break;
          case $C:
            currentCode = 0x1F;
            break;
          default:
            state.charset = kG0Charset;
            break;
        }
        break;
    }
    handleChar();
    state.charset = kG0Charset;
  }

  void handleSS2SpecialChar() {
    // Special characters
    state.charset = kG2Charset;
    switch (currentCode) {
      case 0x23:
        currentCode = 0x00; // £
        break;
      case 0x24:
        currentCode = $dollar; // $
        break;
      case 0x26:
        currentCode = 0x23; // #
        break;
      case 0x27:
        currentCode = 0x0E; // paragraph
        break;
      case 0x2C:
        currentCode = 0x01; // left arrow
        break;
      case 0x2D:
        currentCode = 0x02; // up arrow
        break;
      case 0x2E:
        currentCode = 0x03; // right arrow
        break;
      case 0x2F:
        currentCode = 0x04; // down arrow
        break;
      case 0x30:
        currentCode = 0x05; // degree
        break;
      case 0x31:
        currentCode = 0x06; // plus/minus
        break;
      case 0x38:
        currentCode = 0x07; // division
        break;
      case 0x3A:
        currentCode = 0x08; // fraction 1/4
        break;
      case 0x3B:
        currentCode = 0x09; // fraction 1/2
        break;
      case 0x3C:
        currentCode = 0x0A; // fraction 3/4
        break;
      case 0x6A:
        currentCode = 0x0B; // OE
        break;
      case 0x7A:
        currentCode = 0x0C; // oe
        break;
      case 0x7B:
        currentCode = 0x0D; // beta
        break;
      default:
        state.charset = kG0Charset;
        break;
    }
    if (state.charset == kG2Charset) {
      handleChar();
      state.charset = kG0Charset;
    }
    stateCode = 0;
  }

  void handleTabulation() {
    if (state.c < lastColumn) {
      state.c++;
      stateCode = 0;
    } else {
      state.c = 1;
      handleLineFeed();
    }
  }

  void handleVerticalTab() {
    if (state.l != 0) {
      if (state.l > 1) {
        state.l--;
      } else if (scrollOn) {
        state.l = 1;
        scrollDown();
      } else {
        state.l = lastLine;
      }
    }
    stateCode = 0;
  }

  void inheritGlobalAttr(int l, int c) {
    var char = screen[l][c];
    // Set background and underline attributes from previous char
    final left = screen[l][c - 1];
    char.gAttr = left.gAttr & (kColorMask | kAttrUnderline);
    // If previous char is G1 charset, remove underline attribute
    if ((left.gAttr & kCharsetMask) == kG1Charset) {
      char.gAttr &= ~kAttrUnderline;
    }
  }

  void markCharAsDirty(int l, int c) {
    screen[l][c].code |= kIsDirty;
    screen[l][0].code |= kIsDirty;
    screen[0][_dirtyColumn].code |= kIsDirty;
  }

  // Propagates global attributes and dirty flag to the right
  void propagateAndMakeDirty(int l, int c) {
    var first = screen[l][c];
    markCharAsDirty(l, c);
    for (int col = c + 1; col < lastColumn; ++col) {
      var char = screen[l][col];
      if ((char.gAttr & (kG1Charset | kAttrSpace)) != 0) {
        break;
      }
      char.gAttr = first.gAttr & (kColorMask | kAttrUnderline);
      markCharAsDirty(l, col);
    }
  }

  void putChar(int code) {
    final l = state.l;
    final c = state.c;
    var char = screen[l][c];

    // Reset global attributes
    char.gAttr = 0;

    // Set common local attributes
    char.lAttr = state.fgColor;
    char.lAttr |= state.blink;

    // Set char code
    char.code = code;

    // Set special attributes
    if (state.charset == kG1Charset) {
      // Set G1 global attributes
      char.gAttr |= kG1Charset;
      char.gAttr |= state.bgColor;
      char.gAttr |= state.disjointed;
    } else {
      // Set size and inverse attribute
      char.lAttr |= state.size;
      char.lAttr |= state.inverse;
      if (code == $space && state.needAttrSpace) {
        // Set background color and underline for separator
        char.gAttr |= state.bgColor;
        char.gAttr |= state.underlined;
        char.gAttr |= kAttrSpace;
        state.needAttrSpace = false;
      } else {
        inheritGlobalAttr(l, c);
      }
    }
    // Handle top left if applicable
    if ((char.lAttr & kAttrDoubleHeight) != 0 && l > 0) {
      setPartAttr(l - 1, c, char, kAttrDoubleHeight);
    }
    // Handle bottom right if applicable
    if ((char.lAttr & kAttrDoubleWidth) != 0 && c < lastColumn) {
      setPartAttr(l, c + 1, char, kAttrDoubleWidth);
    }
    // Handle top right if applicable
    if ((char.lAttr & kSizeMask) == kAttrDoubleHeightWidth &&
        l > 0 &&
        c < lastColumn) {
      setPartAttr(l - 1, c + 1, char, kAttrDoubleHeightWidth);
    }
    // Propagate global attributes to the right and update dirty flag
    propagateAndMakeDirty(l, c);
    if ((char.lAttr & kAttrDoubleHeight) != 0 && l > 0) {
      propagateAndMakeDirty(l - 1, c);
    }
  }

  void scrollDown({int fromLine = 1}) {
    for (int line = lastLine - 1; line >= fromLine; --line) {
      for (int column = 1; column <= lastColumn; ++column) {
        screen[line + 1][column] = screen[line][column];
      }
    }
    for (int column = 1; column <= lastColumn; ++column) {
      screen[fromLine][column] = TMinitelChar.from(kEmptyChar);
    }
    screen[0][_dirtyColumn] = TMinitelChar.from(kEmptyChar);
  }

  void scrollUp({int fromLine = 1}) {
    for (int line = fromLine; line <= lastLine - 1; ++line) {
      for (int column = 1; column <= lastColumn; ++column) {
        screen[line][column] = screen[line + 1][column];
      }
    }
    for (int column = 1; column <= lastColumn; ++column) {
      screen[lastLine][column] = TMinitelChar.from(kEmptyChar);
    }
    screen[0][_dirtyColumn] = TMinitelChar.from(kEmptyChar);
  }

  void handleSupL() {
    scrollUp(fromLine: state.l);
  }

  void handleInsL() {
    scrollDown(fromLine: state.l);
  }

  void handleDelC() {
    final l = state.l;
    final c = state.c;
    for (int column = c; column < lastColumn; ++column) {
      screen[l][column] = screen[l][column + 1];
    }
    screen[l][lastColumn] = TMinitelChar.from(kEmptyChar);
    propagateAndMakeDirty(l, c);
  }

  void setBackgroundColor(int code) {
    if (code >= 80 && code <= 80 + 7) {
      state.bgColor = code - 80;
      state.needAttrSpace = true;
    }
  }

  void setCursorForward() {
    state.c++;
    if ((state.size & kAttrDoubleWidth) != 0) {
      state.c++;
    }
    if (state.c > lastColumn) {
      if (state.l == 0) {
        state.c = lastColumn;
      } else {
        state.c = state.c - lastColumn;
        state.l++;
        if ((state.size & kAttrDoubleHeight) != 0) {
          state.l++;
        }
        if (scrollOn) {
          while (state.l > lastLine) {
            scrollUp();
            state.l--;
          }
        } else if (state.l > lastLine) {
          state.l = state.l - lastLine;
          if (state.l == 1 && (state.size & kAttrDoubleHeight) != 0) {
            state.l = 2;
          }
        }
      }
    }
  }

  void setCursorHome() {
    state.resetAttr();
    state.l = 1;
    state.c = 1;
    stateCode = 0;
  }

  void setCursorOff() {
    cursorOn = false;
    stateCode = 0;
  }

  void setCursorOn() {
    cursorOn = true;
    stateCode = 0;
  }

  void setCursorPosition(int line, int column) {
    if ((line >= 64) && (line <= 88) && (column >= 65) && (column <= 105)) {
      if ((state.l != 0) && (line == 64)) {
        savedState = TMinitelState.from(state);
      }
      state.l = line - 64;
      state.c = column - 64;
      state.needAttrSpace = false;
    } else if ((line >= 48) &&
        (line <= 50) &&
        (column >= 48) &&
        (column <= 57)) {
      if ((state.l != 0) && (line == 48) && (column == 48)) {
        savedState = TMinitelState.from(state);
      }
      state.l = ((line & 15) * 10) + (column & 15);
      state.c = 1;
      state.needAttrSpace = false;
    }
    state.resetAttr();
  }

  void setFlashAttr(int code) {
    state.blink = code == $H ? kAttrBlink : kAttrNone;
  }

  void setForegroundColor(int code) {
    if (code >= 64 && code <= 64 + 7) {
      state.fgColor = code - 64;
    }
  }

  void setG0Charset() {
    state.size = kAttrNone;
    state.inverse = kAttrNone;
    state.charset = kG0Charset;
  }

  void setG1Charset() {
    state.underlined = kAttrNone;
    state.disjointed = kAttrNone;
    state.size = kAttrNone;
    state.inverse = kAttrNone;
    state.charset = kG1Charset;
    state.needAttrSpace = false;
  }

  void setG2Charset() {
    if (state.charset == kG0Charset) {
      stateCode = $ss2;
    } else {
      stateCode = 0;
    }
  }

  void setInverseAttr(int code) {
    state.inverse = code == 0x5D ? kAttrInverse : kAttrNone;
  }

  void setSizeAttr(int code) {
    const sizeAttr = [
      kAttrNone,
      kAttrDoubleHeight,
      kAttrDoubleWidth,
      kAttrDoubleHeightWidth
    ];
    if (code >= $L && code <= $O) {
      state.size = sizeAttr[code - $L];
    }
  }

  void setUnderlineAttr(int code) {
    int underlinedFlag = code == $Z ? kAttrUnderline : kAttrNone;
    if (state.charset == kG1Charset) {
      state.disjointed = underlinedFlag;
    } else {
      state.underlined = underlinedFlag;
      state.needAttrSpace = true;
    }
  }

  String getChar(int x, int y) => String.fromCharCode(screen[y][x + 1].code);

  bool isDoublePart(int x, int y) =>
      (screen[y][x + 1].lAttr & kDoublePart) != 0;

  String getStringAlphaNum(int x, int y) {
    final alphaNum = RegExp(r'^[a-zA-Z0-9*]$');
    final buffer = StringBuffer();
    // Get characters to the left
    for (int i = x; i >= 0; i--) {
      final char = getChar(i, y);
      if (alphaNum.hasMatch(char)) {
        if (!isDoublePart(i, y)) buffer.write(char);
      } else {
        break;
      }
    }
    final leftPart = buffer.toString().split('').reversed.join('');
    buffer.clear();
    // Get characters to the right
    for (int i = x + 1; i < lastColumn; i++) {
      final char = getChar(i, y);
      if (alphaNum.hasMatch(char)) {
        if (!isDoublePart(i, y)) buffer.write(char);
      } else {
        break;
      }
    }
    return leftPart + buffer.toString();
  }
}

class TMinitelChar {
  int gAttr;
  int lAttr;
  int code;
  TMinitelChar(this.gAttr, this.lAttr, this.code);
  TMinitelChar.from(TMinitelChar char)
      : gAttr = char.gAttr,
        lAttr = char.lAttr,
        code = char.code;
  void copyFrom(TMinitelChar char) {
    gAttr = char.gAttr;
    lAttr = char.lAttr;
    code = char.code;
  }
}

class TMinitelState {
  bool needAttrSpace = false;
  int bgColor = kColorBlack;
  int underlined = kAttrNone;
  int disjointed = kAttrNone;
  int fgColor = kColorWhite;
  int blink = kAttrNone;
  int size = kAttrNone;
  int inverse = kAttrNone;
  int charset = kG0Charset;
  int l = 0;
  int c = 0;

  TMinitelState({this.l = 0, this.c = 0});
  TMinitelState.from(TMinitelState state)
      : needAttrSpace = state.needAttrSpace,
        bgColor = state.bgColor,
        underlined = state.underlined,
        disjointed = state.disjointed,
        fgColor = state.fgColor,
        blink = state.blink,
        size = state.size,
        inverse = state.inverse,
        charset = state.charset,
        l = state.l,
        c = state.c;

  void resetAttr() {
    needAttrSpace = false;
    bgColor = kColorBlack;
    underlined = kAttrNone;
    disjointed = kAttrNone;
    fgColor = kColorWhite;
    blink = kAttrNone;
    size = kAttrNone;
    inverse = kAttrNone;
    charset = kG0Charset;
  }
}

class TPoint {
  int x, y;
  TPoint(this.x, this.y);
}

class TRect {
  TPoint a, b;
  TRect(this.a, this.b);
}
