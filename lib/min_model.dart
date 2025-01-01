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
  Timer? _timer;
  String? _serverAddress;
  WebSocketChannel? _server;

  factory MinModel() {
    return _singleton;
  }

  MinModel._internal();

  int get bps => _bps;
  set bps(int value) {
    if (value > 0) {
      _bps = value;
      notifyListeners();
    }
  }

  void emulate(List<int> codes) {
    // Manage the timer to send the codes at the right speed
    if (_timer != null) _timer!.cancel();
    final us = (8.0e+6 / _bps.toDouble()).toInt();
    // Add the new codes to the list
    _codes += codes;
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

  void closeServer() {
    if (_server != null) {
      _server!.sink.close();
      _server = null;
    }
    _serverAddress = null;
  }

  void setServer(String serverAddress) {
    if (_serverAddress != null) _server!.sink.close();
    _serverAddress = serverAddress;
    _server = WebSocketChannel.connect(Uri.parse(serverAddress));
    _server!.stream.listen((message) {
      emulate(message.codeUnits);
    }, onError: (error) {
      debugPrint('WebSocket error: $error');
      closeServer();
    }, onDone: () {
      debugPrint('WebSocket connection closed');
      closeServer();
    });
  }

  void sendKeysToServer(String keys) {
    if (_server != null) {
      _server!.sink.add(keys);
    } else {
      debugPrint('No server connection established.');
    }
  }
}
