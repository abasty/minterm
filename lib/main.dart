import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'min_emulator.dart';
import 'min_model.dart';
import 'min_term.dart';

void main() async {
  if (kIsWeb) {
    // Code to execute only on web targets
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // await windowManager.ensureInitialized();

    // WindowOptions windowOptions = const WindowOptions(
    //   // size: Size(4 * 8 * 40 + 64, 4 * 10 * 25 + 64),
    //   size: Size(700, 1100),
    //   center: true,
    //   title: 'Terminal Minitel',
    //   // backgroundColor: Colors.transparent,
    //   // skipTaskbar: false,
    //   // titleBarStyle: TitleBarStyle.hidden,
    //   // windowButtonVisibility: false,
    // );
    // windowManager.waitUntilReadyToShow(windowOptions, () async {
    //   await windowManager.show();
    //   await windowManager.focus();
  }

  WidgetsFlutterBinding.ensureInitialized();

  HardwareKeyboard.instance.addHandler((event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey.keyLabel == '[') {
        var shift = HardwareKeyboard.instance.isShiftPressed;
        MinModel().handleKeys(
          shift ? TMinitelKey.trema : TMinitelKey.circonflexe,
        );
        return true;
      }
      var ctrl = HardwareKeyboard.instance.isControlPressed;
      var shift = HardwareKeyboard.instance.isShiftPressed;
      final isVt100 = MinModel().screenMode == TMinitelScreenMode.vt10080;
      switch (event.logicalKey) {
        case LogicalKeyboardKey.pageDown:
          // PgDn in VT100 mode, Suite in Minitel mode
          MinModel().handleKeys(isVt100 ? '\x1b[6~' : TMinitelKey.suite);
          break;
        case LogicalKeyboardKey.pageUp:
          // PgUp in VT100 mode, Retour in Minitel mode
          MinModel().handleKeys(isVt100 ? '\x1b[5~' : TMinitelKey.retour);
          break;
        case LogicalKeyboardKey.f1:
          // Guide
          MinModel().handleKeys(TMinitelKey.guide);
          break;
        case LogicalKeyboardKey.backspace:
          // BackSp in VT100 mode, Correction in Minitel mode
          MinModel().handleKeys(isVt100 ? '\x7f' : TMinitelKey.correction);
          break;
        case LogicalKeyboardKey.enter:
        case LogicalKeyboardKey.numpadEnter:
          // Entrée in VT100 mode, Envoi/Home/ePage in Minitel mode
          if (isVt100) {
            MinModel().handleKeys('\r');
            break;
          }
          // Envoi
          if (shift) {
            MinModel().handleKeys(TMinitelKey.home);
          } else if (ctrl) {
            MinModel().handleKeys(TMinitelKey.ePage);
          } else {
            MinModel().handleKeys(TMinitelKey.envoi);
          }
          break;
        case LogicalKeyboardKey.delete:
          // Del in VT100 mode
          if (isVt100) {
            MinModel().handleKeys('\x1b[3~');
          }
          break;
        case LogicalKeyboardKey.home:
          // Home in VT100 mode, Sommaire in Minitel mode
          MinModel().handleKeys(isVt100 ? '\x1b[H' : TMinitelKey.sommaire);
          break;
        case LogicalKeyboardKey.end:
          // End in VT100 mode
          if (isVt100) {
            MinModel().handleKeys('\x1b[F');
          }
          break;
        case LogicalKeyboardKey.arrowLeft:
          if (shift) {
            MinModel().handleKeys(TMinitelKey.delC);
          } else if (ctrl) {
            MinModel().handleKeys('\x7f');
          } else {
            MinModel().handleKeys(TMinitelKey.arrowLeft);
          }
          break;
        case LogicalKeyboardKey.arrowRight:
          MinModel().handleKeys(TMinitelKey.arrowRight);
          break;
        case LogicalKeyboardKey.arrowDown:
          if (shift) {
            MinModel().handleKeys(TMinitelKey.insL);
          } else {
            MinModel().handleKeys(TMinitelKey.arrowDown);
          }
          break;
        case LogicalKeyboardKey.arrowUp:
          if (shift) {
            MinModel().handleKeys(TMinitelKey.supL);
          } else {
            MinModel().handleKeys(TMinitelKey.arrowUp);
          }
          break;
        case LogicalKeyboardKey.keyA:
          // Annulation (Ctrl+A)
          if (ctrl) {
            MinModel().handleKeys(TMinitelKey.annulation);
          } else {
            MinModel().handleKeys(event.character!);
          }
          break;
        case LogicalKeyboardKey.keyC:
          // Ctrl+C in VT100 mode, CX/Fin in Minitel mode
          if (ctrl) {
            MinModel().handleKeys(isVt100 ? '\x03' : TMinitelKey.cxFin);
          } else {
            MinModel().handleKeys(event.character!);
          }
          break;
        case LogicalKeyboardKey.keyG:
          // Ctrl+G (Graphic mode)
          if (ctrl) {
            MinModel().handleKeys('\x07');
          } else {
            MinModel().handleKeys(event.character!);
          }
          break;
        default:
          // Other keys
          if (event.character != null) {
            switch (event.character) {
              case 'à':
                MinModel().handleKeys('${TMinitelKey.grave}a');
                break;
              case 'é':
                MinModel().handleKeys('${TMinitelKey.aigu}e');
                break;
              case 'è':
                MinModel().handleKeys('${TMinitelKey.grave}e');
                break;
              case 'ù':
                MinModel().handleKeys('${TMinitelKey.grave}u');
                break;
              case 'ç':
                MinModel().handleKeys('${TMinitelKey.cedille}c');
                break;
              case 'Ç':
                MinModel().handleKeys('${TMinitelKey.cedille}C');
                break;
              case '£':
                MinModel().handleKeys(TMinitelKey.livre);
                break;
              case '§':
                MinModel().handleKeys(TMinitelKey.paragraph);
                break;
              case '°':
                MinModel().handleKeys(TMinitelKey.degree);
                break;
              default:
                MinModel().handleKeys(event.character!);
                break;
            }
          }
          break;
      }
      return true;
    }
    return false;
  });

  // debugPaintSizeEnabled = true;

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primarySwatch: Colors.blue,
    ),
    home: MinTerm(),
  ));
}
