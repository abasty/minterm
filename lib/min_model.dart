import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'min_emulator.dart';

class MinModel extends ChangeNotifier {
  static final MinModel _singleton = MinModel._internal();
  static final File _captureFile = File('capture.vdt');
  static const int _capturePauseMarker = 0xFF;
  static const Duration _capturePauseThreshold = Duration(seconds: 2);
  final minitel = TMinitel();
  var _codes = <int>[];
  int _index = -1;
  int _bps = 1200;
  bool _isShifted = false;
  bool _isCtrl = false;
  Timer? _timer;
  String? _serverAddress;
  dynamic _server;
  IOSink? _captureSink;
  DateTime? _lastCaptureAt;
  bool _captureEnabled = false;
  bool _isReplayingCapture = false;
  bool _isReplayPaused = false;
  List<int> _replayPayload = <int>[];
  int _replayOffset = 0;
  bool showBlink = true;
  int endKeyTap = 0;

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

  bool get isCaptureEnabled => _captureEnabled;

  bool get isReplayingCapture => _isReplayingCapture;

  bool get isReplayPaused => _isReplayPaused;

  bool get isEchoed => minitel.isEchoed;
  set isEchoed(bool value) {
    if (isEchoed != value) {
      minitel.isEchoed = value;
      notifyListeners();
    }
  }

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

  TMinitelScreenMode get screenMode => minitel.screenMode;

  void setScreenMode(TMinitelScreenMode mode) {
    minitel.setScreenMode(mode);
    notifyListeners();
  }

  void toggleScreenMode() {
    minitel.toggleScreenMode();
    notifyListeners();
  }

  void emulate(List<int> codes) {
    _captureCodes(codes);

    // Manage the timer to send the codes at the right speed
    if (_timer != null) _timer!.cancel();

    // Add the new codes to the list
    _codes += codes;

    // If the speed is 0, send all the codes at once
    if (_bps == 0) {
      // Send all the codes at once
      minitel.emulate(_codes);
      _codes.clear();
      if (minitel.speedChanged) {
        bps = minitel.speed;
        setSerialSpeed(bps);
        minitel.speedChanged = false;
      }
      sendReplyToServer();
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
        sendReplyToServer();
      }
    });
  }

  Future<void> toggleCapture() async {
    if (_captureEnabled) {
      await _closeCapture();
    } else {
      await _openCapture();
    }
    notifyListeners();
  }

  Future<void> _openCapture() async {
    await _closeCapture();
    try {
      _captureSink = _captureFile.openWrite();
      _lastCaptureAt = null;
      _captureEnabled = true;
      debugPrint('Capture enabled: ${_captureFile.path}');
    } catch (error) {
      _captureSink = null;
      _captureEnabled = false;
      debugPrint('Failed to open capture file: $error');
    }
  }

  Future<void> _closeCapture() async {
    final sink = _captureSink;
    _captureSink = null;
    _lastCaptureAt = null;
    _captureEnabled = false;
    if (sink != null) {
      try {
        await sink.flush();
        await sink.close();
      } catch (error) {
        debugPrint('Failed to close capture file: $error');
      }
      debugPrint('Capture disabled: ${_captureFile.path}');
    }
  }

  void _captureCodes(List<int> codes) {
    if (!_captureEnabled || _captureSink == null || codes.isEmpty) return;

    final now = DateTime.now();
    if (_lastCaptureAt != null &&
        now.difference(_lastCaptureAt!) > _capturePauseThreshold) {
      _captureSink!.add([_capturePauseMarker]);
    }

    _captureSink!.add(codes);
    _lastCaptureAt = now;
  }

  Future<void> replayCapture() async {
    if (_isReplayingCapture) return;
    if (_captureEnabled) {
      debugPrint('Replay blocked while capture is enabled');
      return;
    }

    try {
      if (!await _captureFile.exists()) {
        debugPrint('Capture file not found: ${_captureFile.path}');
        return;
      }

      final payload = await _captureFile.readAsBytes();
      if (payload.isEmpty) {
        debugPrint('Capture file is empty: ${_captureFile.path}');
        return;
      }

      _replayPayload = List<int>.from(payload);
      _replayOffset = 0;
      _isReplayPaused = false;
      _isReplayingCapture = true;
      notifyListeners();

      _continueReplay();
    } catch (error) {
      debugPrint('Failed to replay capture: $error');
      _finishReplay();
    }
  }

  void resumeReplayAfterPause() {
    if (!_isReplayPaused || !_isReplayingCapture) return;
    _isReplayPaused = false;
    notifyListeners();
    _continueReplay();
  }

  void _continueReplay() {
    while (_isReplayingCapture && _replayOffset < _replayPayload.length) {
      if (_replayPayload[_replayOffset] == _capturePauseMarker) {
        _replayOffset++;
        _isReplayPaused = true;
        notifyListeners();
        return;
      }

      final start = _replayOffset;
      while (_replayOffset < _replayPayload.length &&
          _replayPayload[_replayOffset] != _capturePauseMarker) {
        _replayOffset++;
      }

      if (_replayOffset > start) {
        _emulateReplayChunk(_replayPayload.sublist(start, _replayOffset));
      }
    }

    _finishReplay();
  }

  void _emulateReplayChunk(List<int> chunk) {
    // Replay bytes as-is, bypassing throttling and capture recording.
    minitel.emulate(chunk);
    if (minitel.speedChanged) {
      bps = minitel.speed;
      setSerialSpeed(bps);
      minitel.speedChanged = false;
    }
    sendReplyToServer();
    if (minitel.isDirty) notifyListeners();
  }

  void _finishReplay() {
    if (!_isReplayingCapture && !_isReplayPaused && _replayPayload.isEmpty) {
      return;
    }
    _isReplayPaused = false;
    _isReplayingCapture = false;
    _replayPayload = <int>[];
    _replayOffset = 0;
    notifyListeners();
    debugPrint('Capture replay finished');
  }

  void stopReplay() {
    if (!_isReplayingCapture) return;
    _finishReplay();
    debugPrint('Capture replay cancelled');
  }

  void setSerialSpeed(int speed) {}

  void sendReplyToServer() {
    if (minitel.reply.isNotEmpty) {
      if (isConnected) {
        final replyU8 = Uint8List.fromList(minitel.reply);
        if (_server is WebSocketChannel) {
          _server!.sink.add(replyU8);
        } else if (_server is Socket) {
          _server.add(replyU8);
        }
      }
      minitel.reply.clear();
    }
  }

  void end() {
    isEchoed = true;
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
      }
    }
    _server = null;
  }

  void connect() {
    if (isConnected) end();
    if (_serverAddress == null) return;

    var uri = Uri.parse(_serverAddress!);
    debugPrint('Connect to: $uri');

    if (uri.scheme == 'ws' || uri.scheme == 'wss') {
      connectWebSocket(uri);
    }

    if (uri.scheme == 'tcp' || uri.scheme == 'udp') {
      connectSocket(uri);
    }

    isEchoed = false;
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
    if (_isReplayingCapture && keys == '\x1b') {
      stopReplay();
      return;
    }

    if (_isReplayPaused) {
      resumeReplayAfterPause();
      return;
    }

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

    // Manage CX/Fin key
    if (keys == TMinitelKey.cxFin) {
      endKeyTap++;
      if (!isConnected || endKeyTap >= 2) {
        endKeyTap = 0;
        connectOrEnd();
        return;
      }
    } else {
      endKeyTap = 0;
    }

    // Manage other keys
    if (isConnected) {
      // Send key to server
      if (_server is WebSocketChannel) {
        _server!.sink.add(keys);
      } else if (_server is Socket) {
        _server.write(keys);
      }
    }
    if (isEchoed) {
      // Send key to screen
      emulate(keys.codeUnits);
    }
  }

  void handleTap(int x, int y) {
    if (_isReplayPaused) {
      resumeReplayAfterPause();
      return;
    }

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
