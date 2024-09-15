import 'package:charcode/ascii.dart';

const int kAttrNone = 0x00;

const int kColorBlack = 0x00;
const int kColorWhite = 0x07;

// Global attributes
// bgcolor (3), lignage / disjoint (1), charset (2), espsep (1)
const int kAttrUnderline = 0x08;
const int kAttrDisjointed = kAttrUnderline;
const int kG0Charset = 0x00;
const int kG1Charset = 0x10;
const int kG2Charset = 0x20;
const int kAttrSpace = 0x40;

// Local attributes
// fgcolor (3), flash (1), inverse (1), taille(2), double part (1)
const int kAttrFlash = 0x08;
const int kAttrInverse = 0x10;
const int kAttrDoubleHeight = 0x20;
const int kAttrDoubleWidth = 0x40;
const int kAttrDoubleHeightWidth = kAttrDoubleHeight | kAttrDoubleWidth;
const int kDoublePart = 0x80;

// Char code redraw flag
const int kIsDirty = 0x80;

// Attribute masks
const int kColorMask = 0x07;
const int kCharsetMask = 0x30;
const int kSizeMask = 0x60;

// Some Minitel special codes
const int $rep = 0x12;
const int $sep = 0x13;
const int $ss2 = 0x19;

// Types
typedef FHandleCode = void Function();

class TPoint {
  int x, y;
  TPoint(this.x, this.y);
}

class TRect {
  TPoint a, b;
  TRect(this.a, this.b);
}

class TMinitelChar {
  int gAttr;
  int lAttr;
  int code;
  TMinitelChar(this.gAttr, this.lAttr, this.code);
}

typedef TMinitelScreen = List<List<TMinitelChar>>;

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

class TMinitel {
  int stateCode = 0;
  int currentCode = 0;
  int prevCode = 0;
  int lastCode = 0;
  int lastCharset = kG0Charset;
  bool scrollOn = false;
  bool cursorOn = false;
  TMinitelState state = TMinitelState(l: 1, c: 1);
  TMinitelState savedState = TMinitelState();
  TMinitelScreen screen = List.generate(
    25,
    (_) => List.generate(
      42,
      (_) => TMinitelChar(kG1Charset, kColorWhite, kIsDirty + $space),
    ),
  );

  bool get isDirty {
    return (screen[0][41].code & kIsDirty) != 0;
  }

  void markCharAsDirty(int l, int c) {
    screen[l][c].code |= kIsDirty;
    screen[l][0].code |= kIsDirty;
    screen[0][41].code |= kIsDirty;
  }

  void setBackgroundColor(int code) {
    if (code >= 80 && code <= 80 + 7) {
      state.bgColor = code - 80;
      state.needAttrSpace = true;
    }
  }

  void setForegroundColor(int code) {
    if (code >= 64 && code <= 64 + 7) {
      state.fgColor = code - 64;
    }
  }

  void setFlashAttr(int code) {
    state.blink = code == $H ? kAttrFlash : kAttrNone;
  }

  void setInverseAttr(int code) {
    state.inverse = code == $backslash ? kAttrInverse : kAttrNone;
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

  void setCursorPosition(int line, int column) {
    if ((line >= 64) && (line <= 88) && (column >= 65) && (column <= 105)) {
      if ((state.l != 0) && (line == 64)) {
        savedState = state;
      }
      state.l = line - 64;
      state.c = column - 64;
      state.needAttrSpace = false;
    } else if ((line >= 48) &&
        (line <= 50) &&
        (column >= 48) &&
        (column <= 57)) {
      if ((state.l != 0) && (line == 48) && (column == 48)) {
        savedState = state;
      }
      state.l = ((line & 15) * 10) + (column & 15);
      state.c = 1;
      state.needAttrSpace = false;
    }
    state.resetAttr();
  }

  void setCursorForward() {
    state.c++;
    if ((state.size & kAttrDoubleWidth) != 0) {
      state.c++;
    }
    if (state.c > 40) {
      if (state.l == 0) {
        state.c = 40;
      } else {
        state.c = state.c - 40;
        state.l++;
        if ((state.size & kAttrDoubleHeight) != 0) {
          state.l++;
        }
        if (scrollOn) {
          while (state.l > 24) {
            scrollUp();
            state.l--;
          }
        } else if (state.l > 24) {
          state.l = state.l - 24;
          if (state.l == 1 && (state.size & kAttrDoubleHeight) != 0) {
            state.l = 2;
          }
        }
      }
    }
  }

  void setCursorHome() {
    state.l = 1;
    state.c = 1;
    stateCode = 0;
  }

  void setCursorOn() {
    cursorOn = true;
    stateCode = 0;
  }

  void setCursorOff() {
    cursorOn = false;
    stateCode = 0;
  }

  void clearScreen() {
    state.resetAttr();
    state.l = 1;
    state.c = 1;
    for (int line = 1; line <= 24; ++line) {
      for (int column = 0; column <= 41; ++column) {
        screen[line][column] = emptyChar;
      }
    }
    screen[0][41] = emptyChar;
    stateCode = 0;
  }

  void scrollUp() {
    for (int line = 1; line <= 23; ++line) {
      for (int column = 1; column <= 40; ++column) {
        screen[line][column] = screen[line + 1][column];
      }
    }
    for (int column = 1; column <= 40; ++column) {
      screen[24][column] = emptyChar;
    }
    screen[0][41] = emptyChar;
  }

  void scrollDown() {
    for (int line = 23; line >= 1; --line) {
      for (int column = 1; column <= 40; ++column) {
        screen[line + 1][column] = screen[line][column];
      }
    }
    for (int column = 1; column <= 40; ++column) {
      screen[1][column] = emptyChar;
    }
    screen[0][41] = emptyChar;
  }

  void repeat(int charCode) {
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

  void copyCodeAndLocalAttr(int l, int c, TMinitelChar char) {
    screen[l][c].lAttr = char.lAttr | kDoublePart;
    screen[l][c].code = char.code;
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

  // Propagates global attributes and dirty flag to the right
  void propagateAndMakeDirty(int l, int c) {
    var first = screen[l][c];
    markCharAsDirty(l, c);
    for (int col = c + 1; col < 40; ++col) {
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
      copyCodeAndLocalAttr(l - 1, c, char);
      inheritGlobalAttr(l - 1, c);
    }
    // Handle bottom right if applicable
    if ((char.lAttr & kAttrDoubleWidth) != 0 && c < 40) {
      copyCodeAndLocalAttr(l, c + 1, char);
    }
    // Handle top right if applicable
    if ((char.lAttr & kSizeMask) == kAttrDoubleHeightWidth && l > 0 && c < 40) {
      copyCodeAndLocalAttr(l - 1, c + 1, char);
    }

    // Propagate global attributes to the right and update dirty flag
    propagateAndMakeDirty(l, c);
    if ((char.lAttr & kAttrDoubleHeight) != 0 && l > 0) {
      propagateAndMakeDirty(l - 1, c);
    }
  }

  void handleChar() {
    lastCharset = state.charset;
    putChar(currentCode);
    lastCode = currentCode;
    setCursorForward();
    stateCode = 0;
  }

  void handleNull() {
    stateCode = 0;
  }

  void handleBell() {
    stateCode = 0;
  }

  void handleVerticalTab() {
    if (state.l != 0) {
      if (state.l > 1) {
        state.l--;
      } else if (scrollOn) {
        state.l = 1;
        scrollDown();
      } else {
        state.l = 24;
      }
    }
    stateCode = 0;
  }

  void handleLineFeed() {
    if (state.l == 0) {
      state = savedState;
    } else if (state.l < 24) {
      state.l++;
    } else if (scrollOn) {
      state.l = 24;
      scrollUp();
    } else {
      state.l = 1;
    }
    stateCode = 0;
  }

  void handleBackSpace() {
    if (state.c > 1) {
      state.c--;
      stateCode = 0;
    } else {
      state.c = 40;
      handleVerticalTab();
    }
  }

  void handleTabulation() {
    if (state.c < 40) {
      state.c++;
      stateCode = 0;
    } else {
      state.c = 1;
      handleLineFeed();
    }
  }

  void handleCarriageReturn() {
    state.c = 1;
    stateCode = 0;
  }

  void handleRepeat() {
    stateCode = $rep;
  }

  void handleCancel() {
    int n;
    int size;
    int column, line;
    bool scroll;

    n = 41 - state.c;
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

  void handleEscape() {
    stateCode = $esc;
  }

  void handleCursorPosition() {
    stateCode = $us;
  }

  void handleSeparator() {
    stateCode = $sep;
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
    } else if (x == 0x73) {
      scrollOn = (y & 0x02) == 0x02;
    }
    stateCode = 0;
  }

  // TODO: Use a list of uint8_t instead of List<int>
  void emulate(List<int> codes) {
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
      clearScreen,
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
      currentCode = codes[codeIndex];
      if (currentCode < $space) {
        fadr[currentCode]();
      } else if (stateCode == 0) {
        handleChar();
      } else {
        switch (stateCode) {
          case $rep:
            repeat(currentCode);
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
            if (!(currentCode >= $A && currentCode <= $H) &&
                currentCode != $J &&
                currentCode != $K &&
                !(currentCode >= $M && currentCode <= $O)) {
              state.charset = kG2Charset;
              handleChar();
              state.charset = kG0Charset;
            } else if (currentCode == $A ||
                currentCode == $B ||
                currentCode == $C ||
                currentCode == $H ||
                currentCode == $K) {
              prevCode = currentCode;
              stateCode = $ss2 + 1;
            } else {
              state.charset = kG0Charset;
              stateCode = 0;
            }
            break;
          case const ($ss2 + 1):
            state.charset = kG2Charset;
            switch (prevCode) {
              case $A: // Grave
                switch (currentCode) {
                  case $a:
                    currentCode = 0x50;
                    break;
                  case $e:
                    currentCode = 0x51;
                    break;
                  case $u:
                    currentCode = 0x52;
                    break;
                  default:
                    state.charset = kG0Charset;
                    break;
                }
                break;
              case $B: // Aigu
                switch (currentCode) {
                  case $e:
                    currentCode = 0x53;
                    break;
                  default:
                    state.charset = kG0Charset;
                    break;
                }
                break;
              case $C: // Circonflexe
                switch (currentCode) {
                  case $a:
                    currentCode = 0x54;
                    break;
                  case $e:
                    currentCode = 0x55;
                    break;
                  case $i:
                    currentCode = 0x56;
                    break;
                  case $o:
                    currentCode = 0x57;
                    break;
                  case $u:
                    currentCode = 0x58;
                    break;
                  default:
                    state.charset = kG0Charset;
                    break;
                }
                break;
              case $H: // Tréma
                switch (currentCode) {
                  case $a:
                    currentCode = 0x59;
                    break;
                  case $e:
                    currentCode = 0x5A;
                    break;
                  case $i:
                    currentCode = 0x5B;
                    break;
                  case $o:
                    currentCode = 0x5C;
                    break;
                  case $u:
                    currentCode = 0x5D;
                    break;
                  default:
                    state.charset = kG0Charset;
                    break;
                }
                break;
              case $K: // Cedille
                switch (currentCode) {
                  case $c:
                    currentCode = 0x5E;
                    break;
                  case $C:
                    currentCode = 0x5F;
                    break;
                  default:
                    state.charset = kG0Charset;
                    break;
                }
                break;
            }
            handleChar();
            state.charset = kG0Charset;
            break;

          case $esc:
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
                case >= $backslash && <= $rbracket:
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
              stateCode = 0;
            } else if (currentCode >= 0x39 && currentCode <= 0x3B) {
              switch (currentCode) {
                case 0x39:
                  stateCode = 110;
                  break;
                case 0x3A:
                  stateCode = 120;
                  break;
                case 0x3B:
                  stateCode = 130;
                  break;
                default:
                  stateCode = 0;
                  break;
              }
            } else if (currentCode >= 0x35 && currentCode <= 0x37) {
              stateCode = 28;
            } else if (currentCode >= 0x20 && currentCode <= 0x2F) {
              stateCode = 29;
            }
            break;

          case 28:
            stateCode = 0;
            break;

          case 29:
            if (!(currentCode >= 0x20 && currentCode <= 0x2F)) stateCode = 0;
            break;

          case 110:
            stateCode = 0;
            break;

          case 120:
            stateCode = 121;
            prevCode = currentCode;
            break;

          case 121:
            handleProtocol2(prevCode, currentCode);
            break;

          case 130:
            stateCode = 131;
            break;

          case 131:
            stateCode = 132;
            break;

          case 132:
            stateCode = 0;
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
}

final TMinitelChar emptyChar =
    TMinitelChar(kG1Charset, kColorWhite, kIsDirty + $space);
