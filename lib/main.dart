import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'min_emulator.dart';
import 'min_model.dart';
import 'min_term.dart';
import 'min_widget.dart';
import 'window_setup.dart' as window_setup;

bool _hasEditableTextFocus() {
  final focusedContext = FocusManager.instance.primaryFocus?.context;
  if (focusedContext == null) return false;

  if (focusedContext.widget is EditableText) return true;
  if (focusedContext.findAncestorWidgetOfExactType<EditableText>() != null) {
    return true;
  }
  if (focusedContext.findAncestorStateOfType<EditableTextState>() != null) {
    return true;
  }
  return false;
}

final _letterKeyLabel = RegExp(r'^[A-Z]$');

/// Resolves the character to send for a letter key given the physical Shift
/// state and the Minitel keyboard case mode: when [keyboardLowercase] is
/// false (majuscule seule, l'état par défaut du Minitel), une touche seule
/// envoie une majuscule et Shift+touche envoie une minuscule (inverse du
/// clavier PC standard). Non-letter keys just pass through `event.character`.
String _resolveKeyboardCaseChar(KeyEvent event, bool shift) {
  final label = event.logicalKey.keyLabel;
  if (!_letterKeyLabel.hasMatch(label)) {
    return event.character ?? '';
  }
  final upMode = !MinModel().minitel.keyboardLowercase;
  return (shift && upMode) || (!shift && !upMode) ? label.toLowerCase() : label;
}

/// Normalizes a URN by inserting `://` after the scheme if absent.
/// For example: `tcp:localhost:1967` becomes `tcp://localhost:1967`.
String _normalizeUrn(String urn) {
  if (urn.contains('://')) return urn;
  final colonIndex = urn.indexOf(':');
  if (colonIndex == -1) return urn;
  return '${urn.substring(0, colonIndex)}://${urn.substring(colonIndex + 1)}';
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  await window_setup.initializeWindow();
  window_setup.setEscapeInFullscreenHandler(() {
    MinModel().handleKeys('\x1b');
  });

  HardwareKeyboard.instance.addHandler((event) {
    if (_hasEditableTextFocus()) {
      return false;
    }

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.f11) {
        // Ne pas consommer F11 : laisser le navigateur basculer en plein
        // écran nativement en mode web (sinon preventDefault bloque Chrome).
        return false;
      }
      playKeyClickSound();
      if (event.logicalKey.keyLabel == '[') {
        var shift = HardwareKeyboard.instance.isShiftPressed;
        MinModel().handleKeys(
          shift ? TMinitelKey.trema : TMinitelKey.circonflexe,
        );
        return true;
      }
      var ctrl = HardwareKeyboard.instance.isControlPressed;
      var shift = HardwareKeyboard.instance.isShiftPressed;
      final isTeleinfo = MinModel().screenMode == TMinitelScreenMode.teleinfo80;
      switch (event.logicalKey) {
        case LogicalKeyboardKey.escape:
          // En Flutter web, event.character est souvent nul pour Echap :
          // on la gère explicitement plutôt que via le fallback event.character.
          MinModel().handleKeys('\x1b');
          break;
        case LogicalKeyboardKey.pageDown:
          // Suite, que ce soit en 40 ou 80 colonnes.
          MinModel().handleKeys(TMinitelKey.suite);
          break;
        case LogicalKeyboardKey.pageUp:
          // Retour, que ce soit en 40 ou 80 colonnes.
          MinModel().handleKeys(TMinitelKey.retour);
          break;
        case LogicalKeyboardKey.f1:
          // Guide
          MinModel().handleKeys(TMinitelKey.guide);
          break;
        case LogicalKeyboardKey.backspace:
          // Correction, que ce soit en 40 ou 80 colonnes.
          MinModel().handleKeys(TMinitelKey.correction);
          break;
        case LogicalKeyboardKey.enter:
        case LogicalKeyboardKey.numpadEnter:
          // Shift/Ctrl+Entrée envoient les mêmes codes en 40 et 80 colonnes.
          // Entrée seule : Envoi en Minitel, \r en téléinformatique.
          if (shift) {
            MinModel().handleKeys('\x1E'); // 30
          } else if (ctrl) {
            MinModel().handleKeys('\x0C'); // 12
          } else if (isTeleinfo) {
            MinModel().handleKeys('\r');
          } else {
            MinModel().handleKeys(TMinitelKey.envoi);
          }
          break;
        case LogicalKeyboardKey.home:
          // Sommaire, que ce soit en 40 ou 80 colonnes.
          MinModel().handleKeys(TMinitelKey.sommaire);
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
          if (shift) {
            // Bascule mode insertion caractère.
            MinModel().handleKeys(
              MinModel().minitel.insertMode
                  ? TMinitelKey.insCOff
                  : TMinitelKey.insCOn,
            );
          } else {
            MinModel().handleKeys(TMinitelKey.arrowRight);
          }
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
            MinModel().handleKeys(_resolveKeyboardCaseChar(event, shift));
          }
          break;
        case LogicalKeyboardKey.keyC:
          // Ctrl+C in Téléinformatique mode, CX/Fin in Minitel mode
          if (ctrl) {
            MinModel().handleKeys(isTeleinfo ? '\x03' : TMinitelKey.cxFin);
          } else {
            MinModel().handleKeys(_resolveKeyboardCaseChar(event, shift));
          }
          break;
        case LogicalKeyboardKey.keyG:
          // Ctrl+G (Graphic mode)
          if (ctrl) {
            MinModel().handleKeys('\x07');
          } else {
            MinModel().handleKeys(_resolveKeyboardCaseChar(event, shift));
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
                MinModel().handleKeys(_resolveKeyboardCaseChar(event, shift));
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

  if (args.isNotEmpty) {
    MinModel().serverAddress = _normalizeUrn(args[0]);
    MinModel().connect();
  }
}
