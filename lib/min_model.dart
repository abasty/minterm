import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'min_emulator.dart';

class MinModel extends ChangeNotifier {
  static final MinModel _singleton = MinModel._internal();
  final minitel = TMinitel();
  var _codes = <int>[];
  int _index = -1;
  int _bps = 1200;
  bool _isShifted = false;
  bool _isCtrl = false;
  Timer? _timer;
  String? _serverAddress;
  WebSocketChannel? _server;

  factory MinModel() {
    return _singleton;
  }

  MinModel._internal();

  bool get isConnected => _server != null;

  bool get isShifted => _isShifted;

  bool get isCtrl => _isCtrl;

  int get bps => _bps;
  set bps(int value) {
    _bps = value;
    notifyListeners();
  }

  void emulate(List<int> codes) {
    // Manage the timer to send the codes at the right speed
    if (_timer != null) _timer!.cancel();

    // Add the new codes to the list
    _codes += codes;

    // If the speed is 0, send all the codes at once
    if (_bps == 0) {
      // Send all the codes at once
      minitel.emulate(_codes);
      _codes.clear();
      if (minitel.isDirty) notifyListeners();
      return;
    }

    final us = (8.0e+6 / _bps.toDouble()).toInt();
    // Init the index
    if (_index < 0) _index = 0;
    // Start the timer
    _timer = Timer.periodic(Duration(microseconds: us), (Timer timer) {
      if (_index < _codes.length) {
        // Send the next code to the emulator
        minitel.emulate([_codes[_index++]]);
        if (minitel.isDirty) notifyListeners();
      } else {
        // Stop the timer
        timer.cancel();
        _timer = null;
        _index = -1;
        _codes.clear();
      }
    });
  }

  void end() {
    if (isConnected) {
      _server!.sink.close();
      _server = null;
    }
  }

  void setServerAddress(String serverAddress) {
    _serverAddress = serverAddress;
  }

  void connect() {
    if (isConnected) end();
    if (_serverAddress == null) return;

    _server = WebSocketChannel.connect(Uri.parse(_serverAddress!));
    _server!.stream.listen(
      (message) {
        emulate(message.codeUnits);
      },
      onError: (error) {
        debugPrint('WebSocket error: $error');
        end();
      },
      onDone: () {
        debugPrint('WebSocket connection closed');
        end();
      },
    );
  }

  void connectOrEnd() {
    if (isConnected) {
      end();
    } else {
      connect();
    }
  }

  void handleKeys(String keys) {
    if (keys == 'shift') {
      _isShifted = !_isShifted;
      return;
    }
    if (keys == 'ctrl') {
      _isCtrl = !_isCtrl;
      return;
    }

    _isCtrl = false;
    _isShifted = false;

    if (isConnected) {
      _server!.sink.add(keys);
    } else {
      emulate(keys.codeUnits);
    }
  }

  void handleTap(int x, int y) {
    final c = minitel.getStringAlphaNum(x, y).toUpperCase();
    switch (c) {
      case 'ENVOI':
        handleKeys(TMinitelKey.envoi);
        break;
      case 'CORRECTION':
        handleKeys(TMinitelKey.correction);
        break;
      case 'ANNULATION':
        handleKeys(TMinitelKey.annulation);
        break;
      case 'GUIDE':
        handleKeys(TMinitelKey.guide);
        break;
      case 'RETOUR':
        handleKeys(TMinitelKey.retour);
        break;
      case 'SOMMAIRE':
        handleKeys(TMinitelKey.sommaire);
        break;
      case 'SUITE':
        handleKeys(TMinitelKey.suite);
        break;
      default:
        handleKeys(c);
        handleKeys(TMinitelKey.envoi);
        break;
    }
    // debugPrint('Handling tap at: x=$x, y=$y, str=$c');
  }
}
