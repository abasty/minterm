import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
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
  dynamic _server;
  SerialPortReader? _serialReader;
  bool showBlink = true;

  factory MinModel() {
    return _singleton;
  }

  MinModel._internal() {
    Timer.periodic(Duration(milliseconds: 1000), (Timer timer) {
      _singleton.showBlink = !_singleton.showBlink;
      _singleton.minitel.isDirty = true;
      _singleton.notifyListeners();
    });
  }

  bool get isConnected => _server != null;

  bool get isShifted => _isShifted;

  bool get isCtrl => _isCtrl;

  int get bps => _bps;
  set bps(int value) {
    _bps = value;
    notifyListeners();
  }

  set serverAddress(String? value) {
    _serverAddress = value;
  }

  void emulate(List<int> codes) {
    // Manage the timer to send the codes at the right speed
    if (_timer != null) _timer!.cancel();

    // Add the new codes to the list
    _codes += codes;

    // If the speed is 0, send all the codes at once
    if (_bps == 0 || _serialReader != null) {
      // Send all the codes at once
      minitel.emulate(_codes);
      _codes.clear();
      if (minitel.speedChanged) {
        setSerialSpeed(minitel.speed);
        minitel.speedChanged = false;
      }
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
        if (minitel.speedChanged) {
          _bps = minitel.speed;
          minitel.speedChanged = false;
        }
      }
    });
  }

  void setSerialSpeed(int speed) {
    if (_server is SerialPort) {
      final port = _server as SerialPort;
      if (port.isOpen) {
        port.config = SerialPortConfig()
          ..baudRate = speed
          ..bits = 7
          ..parity = SerialPortParity.even
          ..stopBits = 1
          ..setFlowControl(SerialPortFlowControl.none);
      }
    }
  }

  void end() {
    debugPrint('End connection');

    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }

    _index = -1;
    _codes.clear();

    if (isConnected) {
      if (_server is WebSocketChannel) {
        _server!.sink.close();
      } else if (_server is Socket) {
        _server.destroy();
      } else if (_server is SerialPort) {
        final port = _server as SerialPort;
        debugPrint('Closing serial port reader');
        if (_serialReader != null) {
          _serialReader!.close();
          _serialReader = null;
        }
        debugPrint('Closing serial port: ${port.name}');
        if (port.isOpen) {
          port.close();
          debugPrint('Serial port closed: ${port.name}');
        }
        port.dispose();
      }
    }
    _server = null;
  }

  void connect() {
    if (isConnected) end();
    if (_serverAddress == null) return;

    var uri = Uri.parse(_serverAddress!);
    debugPrint('Connect to: $uri');

    if (uri.scheme == 'serial') {
      connectSerial(uri.path);
      return;
    }

    if (uri.scheme == 'ws' || uri.scheme == 'wss') {
      connectWebSocket(uri);
      return;
    }

    if (uri.scheme == 'tcp' || uri.scheme == 'udp') {
      connectSocket(uri);
      return;
    }
  }

  void connectSerial(String portName) {
    if (isConnected) end();

    final port = SerialPort(portName);
    debugPrint('Opening serial port: $portName');
    if (!port.openReadWrite()) {
      // Open the port for reading and writing
      debugPrint('Failed to open serial port: ${port.name}');
      return;
    }

    _server = port;
    setSerialSpeed(1200);

    _serialReader = SerialPortReader(port);
    _serialReader!.stream.listen(
      (data) {
        emulate(data);
      },
      onError: (error) {
        debugPrint('Serial port error: $error');
        end();
      },
      onDone: () {
        debugPrint('Serial port connection closed');
        end();
      },
    );
    debugPrint('Serial port opened: ${port.name}');

    port.write(Uint8List.fromList('BASTOS\r'.codeUnits));
  }

  void connectSocket(Uri uri) {
    Socket.connect(uri.host, uri.port).then(
      (Socket socket) {
        _server = socket;
        (_server as Socket).listen(
          (data) {
            emulate(data);
          },
          onDone: () {
            debugPrint('Socket connection closed');
            end();
          },
          onError: (error) {
            debugPrint('Socket error: $error');
            end();
          },
        );
      },
    ).onError(
      (error, stackTrace) {
        debugPrint('Socket error: $error');
        end();
      },
    );
  }

  void connectWebSocket(Uri uri) {
    _server = WebSocketChannel.connect(uri);
    _server!.stream.listen(
      (data) {
        emulate(data.codeUnits);
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
      if (_server is WebSocketChannel) {
        _server!.sink.add(keys);
      } else if (_server is Socket) {
        _server.write(keys);
      } else if (_server is SerialPort) {
        final port = _server as SerialPort;
        if (port.isOpen) {
          final keysU8 = Uint8List.fromList(keys.codeUnits);
          port.write(keysU8);
        } else {
          debugPrint('Serial port is not open: ${port.name}');
        }
      }
    } else {
      emulate(keys.codeUnits);
    }
  }

  void handleTap(int x, int y) {
    final c = minitel.getStringAlphaNum(x, y).toUpperCase();
    switch (c) {
      case '':
        // Ignore empty string
        break;
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
