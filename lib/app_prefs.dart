import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_prefs_storage_stub.dart'
    if (dart.library.html) 'app_prefs_storage_web.dart'
    if (dart.library.io) 'app_prefs_storage_io.dart' as app_prefs_storage;
import 'min_model.dart';
import 'min_widget.dart';

/// Charge les préférences persistées (Vitesse, Couleur, Fond, Son) et les
/// applique à [MinModel]/[MinSettings]. À appeler une fois au démarrage,
/// avant `runApp`.
Future<void> loadAppPrefs() async {
  try {
    final jsonText = await app_prefs_storage.loadAppPrefsJson();
    if (jsonText == null || jsonText.trim().isEmpty) return;

    final decoded = json.decode(jsonText);
    if (decoded is! Map<String, dynamic>) return;

    final bps = decoded['bps'];
    if (bps is int) {
      MinModel().bps = bps;
    }

    final colorsEnabled = decoded['colorsEnabled'];
    if (colorsEnabled is bool) {
      MinSettings().colors = colorsEnabled ? MinColors : MinGrey;
    }

    final backgroundIsBlack = decoded['backgroundIsBlack'];
    if (backgroundIsBlack is bool) {
      MinSettings().setAppBackgroundColor(
        backgroundIsBlack ? Colors.black : Colors.white,
      );
    }

    final soundMode = decoded['soundMode'];
    if (soundMode is String) {
      try {
        MinSettings.setSoundMode(SoundMode.values.byName(soundMode));
      } catch (_) {
        // Valeur inconnue (ancienne version du fichier) : on garde le défaut.
      }
    }
  } catch (error) {
    debugPrint('Failed to load app preferences: $error');
  }
}

/// Sauvegarde automatiquement Vitesse, Couleur, Fond et Son dès qu'un de ces
/// réglages change. À appeler une fois au démarrage, après [loadAppPrefs].
void watchAndSaveAppPrefs() {
  int? lastBps;
  List<Color>? lastColors;
  Color? lastBackground;
  SoundMode? lastSoundMode;

  void maybeSave() {
    final bps = MinModel().bps;
    final colors = MinSettings().colors;
    final background = MinSettings().appBackgroundColor;
    final soundMode = MinSettings().soundMode;

    if (bps == lastBps &&
        colors == lastColors &&
        background == lastBackground &&
        soundMode == lastSoundMode) {
      return;
    }
    lastBps = bps;
    lastColors = colors;
    lastBackground = background;
    lastSoundMode = soundMode;

    final payload = <String, dynamic>{
      'bps': bps,
      'colorsEnabled': colors == MinColors,
      'backgroundIsBlack': background == Colors.black,
      'soundMode': soundMode.name,
    };
    unawaited(
      app_prefs_storage.saveAppPrefsJson(json.encode(payload)).catchError(
        (Object error) {
          debugPrint('Failed to save app preferences: $error');
        },
      ),
    );
  }

  MinModel().addListener(maybeSave);
  MinSettings().addListener(maybeSave);
}
