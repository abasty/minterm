// import 'dart:typed_data';

// Constants
import 'package:charcode/ascii.dart';

const int kAttrNormal = 0x00;

const int kColorBlack = 0x00;
const int kColorWhite = 0x07;

const int kAttrUnderline = 0x08;

const int kG0Charset = 0x00;
const int kG1Charset = 0x20;
const int kG2Charset = 0x10;
const int kEspSep = 0x30;

const int kLocationTL = 0x40;
const int kLocationBR = 0x80;
const int kLocationTR = kLocationTL | kLocationBR;

const int kAttrFlash = 0x08;
const int kAttrInverse = 0x10;
const int kAttrDoubleH = 0x20;
const int kAttrDoubleW = 0x40;
const int kAttrDoubleHW = kAttrDoubleH | kAttrDoubleW;

const int kCharsetMask = 0x30;
const int kLocationMask = 0xC0;
const int kSizeMask = 0x60;
const int kRedrawFlag = 0x80;

const int $rep = 0x12;
const int $sep = 0x13;
const int $ss2 = 0x19;

typedef FHandleCode = void Function();

// Types
class TPoint {
  int x, y;
  TPoint(this.x, this.y);
}

class TRect {
  TPoint a, b;
  TRect(this.a, this.b);
}

class TMinitelChar {
  int globalAttr;
  int localAttr;
  int charCode;
  TMinitelChar(this.globalAttr, this.localAttr, this.charCode);
}

typedef TMinitelScreen = List<List<TMinitelChar>>;

class TMinitelState {
  bool separatorFlag = false;
  int backgroundColor = kColorBlack;
  int underlinedFlag = kAttrNormal;
  int disjointed = kAttrNormal;
  int foregroundColor = kColorWhite;
  int flashFlag = kAttrNormal;
  int charSize = kAttrNormal;
  int inverseFlag = kAttrNormal;
  int charset = kG0Charset;
  int line = 0;
  int column = 0;

  TMinitelState({this.line = 0, this.column = 0});

  void resetAttr() {
    separatorFlag = false;
    backgroundColor = kColorBlack;
    underlinedFlag = kAttrNormal;
    disjointed = kAttrNormal;
    foregroundColor = kColorWhite;
    flashFlag = kAttrNormal;
    charSize = kAttrNormal;
    inverseFlag = kAttrNormal;
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
  TMinitelState currentState = TMinitelState(line: 1, column: 1);
  TMinitelState savedState = TMinitelState();
  TMinitelScreen screen = List.generate(
    25,
    (_) => List.generate(
      42,
      (_) => TMinitelChar(kG1Charset, kColorWhite, kRedrawFlag + $space),
    ),
  );

  void markAllAsDirty() {
    for (int line = 0; line <= 24; ++line) {
      for (int column = 0; column <= 41; ++column) {
        screen[line][column].charCode |= kRedrawFlag;
      }
    }
  }

  void markCharAsDirty(int l, int c) {
    screen[l][c].charCode |= kRedrawFlag;
    screen[l][0].charCode |= kRedrawFlag;
    screen[0][41].charCode |= kRedrawFlag;
  }

  void markRectAsDirty(TRect r) {
    for (int line = r.a.y; line <= r.b.y; ++line) {
      for (int column = r.a.x; column <= r.b.x; ++column) {
        markCharAsDirty(line, column);
      }
    }
  }

  // TODO: This should go away and be implemented in the widget
  void draw() {
    // Test if the screen has at least one dirty character
    if ((screen[0][41].charCode & kRedrawFlag) != 0) return;

    // Clear the screen dirty flag
    screen[0][41].charCode &= ~kRedrawFlag;

    for (int line = 0; line <= 24; ++line) {
      // Test if the line has at least one dirty character
      if ((screen[line][0].charCode & kRedrawFlag) != 0) continue;

      // Clear the line dirty flag
      screen[line][0].charCode &= ~kRedrawFlag;

      for (int column = 1; column <= 40; ++column) {
        if ((screen[line][column].charCode & kRedrawFlag) == 0) continue;

        screen[line][column].charCode &= ~kRedrawFlag;
        // AfficheCar(ADRC, line, column);
      }
    }
  }

  void setBackgroundColor(int code) {
    if (code >= 80 && code <= 80 + 7) {
      currentState.backgroundColor = code - 80;
      currentState.separatorFlag = true;
    }
  }

  void setForegroundColor(int code) {
    if (code >= 64 && code <= 64 + 7) {
      currentState.foregroundColor = code - 64;
      currentState.separatorFlag = true;
    }
  }

  void setFlashAttr(int code) {
    currentState.flashFlag = code == $H ? kAttrFlash : kAttrNormal;
  }

  void setInverseAttr(int code) {
    currentState.inverseFlag = code == $backslash ? kAttrInverse : kAttrNormal;
  }

  void setSizeAttr(int code) {
    const sizeAttr = [kAttrNormal, kAttrDoubleH, kAttrDoubleW, kAttrDoubleHW];
    if (code >= $L && code <= $O) {
      currentState.charSize = sizeAttr[code - $L];
    }
  }

  void setUnderlineAttr(int code) {
    int underlineFlag = code == $Z ? kAttrUnderline : kAttrNormal;
    if (currentState.charset == kG1Charset) {
      currentState.disjointed = underlineFlag;
    } else {
      currentState.underlinedFlag = underlineFlag;
      currentState.separatorFlag = true; // FIXME: Check this
    }
  }

  void setG0Charset() {
    currentState.charSize = kAttrNormal;
    currentState.inverseFlag = kAttrNormal;
    currentState.charset = kG0Charset;
  }

  void setG1Charset() {
    currentState.underlinedFlag = kAttrNormal;
    currentState.disjointed = kAttrNormal;
    currentState.charSize = kAttrNormal;
    currentState.inverseFlag = kAttrNormal;
    currentState.charset = kG1Charset;
    currentState.separatorFlag = false;
  }

  void setG2Charset() {
    if (currentState.charset == kG0Charset) {
      stateCode = $ss2;
    } else {
      stateCode = 0;
    }
  }

  void setCursorPosition(int line, int column) {
    if ((line >= 64) && (line <= 88) && (column >= 65) && (column <= 105)) {
      if ((currentState.line != 0) && (line == 64)) {
        savedState = currentState;
      }
      currentState.line = line - 64;
      currentState.column = column - 64;
      currentState.separatorFlag = false;
    } else if ((line >= 48) &&
        (line <= 50) &&
        (column >= 48) &&
        (column <= 57)) {
      if ((currentState.line != 0) && (line == 48) && (column == 48)) {
        savedState = currentState;
      }
      currentState.line = ((line & 15) * 10) + (column & 15);
      currentState.column = 1;
      currentState.separatorFlag = false;
    }
    currentState.resetAttr();
  }

  void setCursorForward() {
    currentState.column++;
    if ((currentState.charSize & kAttrDoubleW) != 0) {
      currentState.column++;
    }
    if (currentState.column > 40) {
      if (currentState.line == 0) {
        currentState.column = 40;
      } else {
        currentState.column = currentState.column - 40;
        currentState.line++;
        if ((currentState.charSize & kAttrDoubleH) != 0) {
          currentState.line++;
        }
        if (scrollOn) {
          while (currentState.line > 24) {
            scrollUp();
            currentState.line--;
          }
        } else if (currentState.line > 24) {
          currentState.line = currentState.line - 24;
          if (currentState.line == 1 &&
              (currentState.charSize & kAttrDoubleH) != 0) {
            currentState.line = 2;
          }
        }
      }
    }
  }

  void setCursorHome() {
    currentState.line = 1;
    currentState.column = 1;
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
    currentState.resetAttr();
    currentState.line = 1;
    currentState.column = 1;
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
      if (lastCharset == kG2Charset && currentState.charset == kG0Charset) {
        currentState.charset = kG2Charset;
      }
      for (i = 1; i <= n; ++i) {
        handleChar();
      }
      if (lastCharset == kG2Charset && currentState.charset == kG2Charset) {
        currentState.charset = kG0Charset;
      }
    }
    stateCode = 0;
  }

  void putChar(int charCode) {
    // Implement putChar logic here (set chars in screen)
  }

  void handleChar() {
    lastCharset = currentState.charset;
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
    if (currentState.line != 0) {
      if (currentState.line > 1) {
        currentState.line--;
      } else if (scrollOn) {
        currentState.line = 1;
        scrollDown();
      } else {
        currentState.line = 24;
      }
    }
    stateCode = 0;
  }

  void handleLineFeed() {
    if (currentState.line == 0) {
      currentState = savedState;
    } else if (currentState.line < 24) {
      currentState.line++;
    } else if (scrollOn) {
      currentState.line = 24;
      scrollUp();
    } else {
      currentState.line = 1;
    }
    stateCode = 0;
  }

  void handleBackSpace() {
    if (currentState.column > 1) {
      currentState.column--;
      stateCode = 0;
    } else {
      currentState.column = 40;
      handleVerticalTab();
    }
  }

  void handleTabulation() {
    if (currentState.column < 40) {
      currentState.column++;
      stateCode = 0;
    } else {
      currentState.column = 1;
      handleLineFeed();
    }
  }

  void handleCarriageReturn() {
    currentState.column = 1;
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

    n = 41 - currentState.column;
    currentCode = $space;
    size = currentState.charSize;
    column = currentState.column;
    line = currentState.line;
    scroll = scrollOn;
    scrollOn = false;
    if ((size & kAttrDoubleH) != 0) {
      currentState.charSize = kAttrDoubleH;
    } else {
      currentState.charSize = kAttrNormal;
    }
    for (int i = 1; i <= n; ++i) {
      handleChar();
    }
    currentState.charSize = size;
    currentState.column = column;
    currentState.line = line;
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
    column = currentState.column;
    line = currentState.line;
    codeIndex = 0;
    while (codes[codeIndex] != 0) {
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
              currentState.charset = kG2Charset;
              handleChar();
              currentState.charset = kG0Charset;
            } else if (currentCode == $A ||
                currentCode == $B ||
                currentCode == $C ||
                currentCode == $H ||
                currentCode == $K) {
              prevCode = currentCode;
              stateCode = $ss2 + 1;
            } else {
              currentState.charset = kG0Charset;
              stateCode = 0;
            }
            break;
          case const ($ss2 + 1):
            currentState.charset = kG2Charset;
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
                    currentState.charset = kG0Charset;
                    break;
                }
                break;
              case $B: // Aigu
                switch (currentCode) {
                  case $e:
                    currentCode = 0x53;
                    break;
                  default:
                    currentState.charset = kG0Charset;
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
                    currentState.charset = kG0Charset;
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
                    currentState.charset = kG0Charset;
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
                    currentState.charset = kG0Charset;
                    break;
                }
                break;
            }
            handleChar();
            currentState.charset = kG0Charset;
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
                  if (currentState.charset != kG1Charset) {
                    setInverseAttr(currentCode);
                  }
                  break;
                case >= $L && <= $O:
                  if (currentState.charset != kG1Charset) {
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
        ++codeIndex;
      }
      if (cursor != cursorOn) {
        markCharAsDirty(line, column);
      } else if (cursorOn &&
          (column != currentState.column || line != currentState.line)) {
        markCharAsDirty(line, column);
        markCharAsDirty(currentState.line, currentState.column);
      }
    }
  }
}

final TMinitelChar emptyChar =
    TMinitelChar(kG1Charset, kColorWhite, kRedrawFlag + $space);
