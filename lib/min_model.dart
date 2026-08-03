import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_io/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'capture_web_storage_stub.dart'
    if (dart.library.html) 'capture_web_storage_web.dart' as web_capture;
import 'min_emulator.dart';
import 'serial_support.dart';

class MinModel extends ChangeNotifier {
  static final MinModel _singleton = MinModel._internal();
  static const String _captureFilePath = 'capture.vdt';
  static const String _webCaptureStorageKey = 'minterm.capture.vdt.b64';
  static const int _capturePauseMarker = 0xFF;
  static const Duration _capturePauseThreshold = Duration(seconds: 2);
  final minitel = TMinitel();
  final _codes = <int>[];
  int _bps = 1200;
  bool _isShifted = false;
  bool _isCtrl = false;
  Timer? _timer;
  DateTime? _lastDrainAt;
  double _pendingBytesBudget = 0.0;
  static const Duration _throttleTick = Duration(milliseconds: 8);
  String? _serverAddress;
  dynamic _server;
  StreamSubscription<List<int>>? _serialSubscription;
  IOSink? _captureSink;
  File? _nativeCaptureFile;
  DateTime? _lastCaptureAt;
  final List<int> _webCaptureBytes = <int>[];
  bool _captureEnabled = false;
  bool _isReplayingCapture = false;
  bool _isReplayPaused = false;
  List<int> _replayPayload = <int>[];
  int _replayOffset = 0;
  bool showBlink = true;
  int endKeyTap = 0;
  int _activeConnectionId = 0;
  bool _checkWebSocketAccept = true;

  factory MinModel() {
    return _singleton;
  }

  MinModel._internal() {
    _restoreWebCapture();
    _initializeCaptureFile();
    Timer.periodic(Duration(milliseconds: 1000), (Timer timer) {
      _singleton.showBlink = !_singleton.showBlink;
      _singleton.minitel.isDirty = true;
      _singleton.notifyListeners();
    });
  }

  bool get isConnected => _server != null;

  bool get _isLinuxDesktop => !kIsWeb && Platform.isLinux;

  bool get isCaptureEnabled => _captureEnabled;

  bool get isReplayingCapture => _isReplayingCapture;

  bool get isReplayPaused => _isReplayPaused;

  bool get hasCaptureData {
    if (kIsWeb) {
      return _webCaptureBytes.isNotEmpty;
    }
    if (_nativeCaptureFile == null) {
      unawaited(_initializeCaptureFile());
      return false;
    }
    final captureFile = _captureFile;
    if (captureFile == null || !captureFile.existsSync()) {
      return false;
    }
    return captureFile.lengthSync() > 0;
  }

  File? get _captureFile => kIsWeb ? null : _nativeCaptureFile;

  Future<void> _initializeCaptureFile() async {
    if (kIsWeb || _nativeCaptureFile != null) return;

    if (Platform.isAndroid || Platform.isIOS) {
      final appDirectory = await getApplicationDocumentsDirectory();
      _nativeCaptureFile = File('${appDirectory.path}/$_captureFilePath');
    } else {
      _nativeCaptureFile = File(_captureFilePath);
    }

    notifyListeners();
  }

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

  set checkWebSocketAccept(bool value) {
    _checkWebSocketAccept = value;
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

    // Add new codes to the buffered queue consumed by throttling.
    _codes.addAll(codes);

    // If the speed is 0, send all the codes at once
    if (_bps == 0) {
      _stopThrottleTimer();
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

    _startThrottleTimer();
  }

  void _startThrottleTimer() {
    if (_timer != null) return;
    _lastDrainAt = DateTime.now();
    _timer = Timer.periodic(_throttleTick, (_) {
      _drainBufferedCodes();
    });
  }

  void _stopThrottleTimer() {
    _timer?.cancel();
    _timer = null;
    _lastDrainAt = null;
    _pendingBytesBudget = 0.0;
  }

  void _drainBufferedCodes() {
    if (_codes.isEmpty) {
      _stopThrottleTimer();
      sendReplyToServer();
      return;
    }

    final now = DateTime.now();
    final elapsedUs = _lastDrainAt == null
        ? _throttleTick.inMicroseconds
        : now.difference(_lastDrainAt!).inMicroseconds;
    _lastDrainAt = now;

    _pendingBytesBudget += elapsedUs * (_bps / 8.0) / 1000000.0;
    int bytesToProcess = _pendingBytesBudget.floor();

    if (bytesToProcess <= 0) {
      return;
    }

    if (bytesToProcess > _codes.length) {
      bytesToProcess = _codes.length;
    }

    minitel.emulate(_codes.sublist(0, bytesToProcess));
    _codes.removeRange(0, bytesToProcess);
    _pendingBytesBudget -= bytesToProcess;

    if (minitel.speedChanged) {
      bps = minitel.speed;
      setSerialSpeed(bps);
      minitel.speedChanged = false;
    }

    sendReplyToServer();
    if (minitel.isDirty) notifyListeners();

    if (_bps == 0 && _codes.isNotEmpty) {
      minitel.emulate(_codes);
      _codes.clear();
      sendReplyToServer();
      if (minitel.isDirty) notifyListeners();
      _stopThrottleTimer();
    }
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
    if (kIsWeb) {
      _webCaptureBytes.clear();
      _lastCaptureAt = null;
      _captureEnabled = true;
      await _persistWebCapture();
      debugPrint('Capture enabled in browser memory');
      return;
    }

    try {
      await _initializeCaptureFile();
      final captureFile = _captureFile;
      if (captureFile == null) {
        _captureEnabled = false;
        return;
      }
      _captureSink = captureFile.openWrite();
      _lastCaptureAt = null;
      _captureEnabled = true;
      debugPrint('Capture enabled: ${captureFile.path}');
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
    if (kIsWeb) {
      await _persistWebCapture();
      debugPrint('Capture disabled in browser memory');
      return;
    }

    if (sink != null) {
      try {
        await sink.flush();
        await sink.close();
      } catch (error) {
        debugPrint('Failed to close capture file: $error');
      }
      final captureFile = _captureFile;
      if (captureFile != null) {
        debugPrint('Capture disabled: ${captureFile.path}');
      }
    }
  }

  void _captureCodes(List<int> codes) {
    if (!_captureEnabled || codes.isEmpty) return;

    final now = DateTime.now();
    final insertPause = _lastCaptureAt != null &&
        now.difference(_lastCaptureAt!) > _capturePauseThreshold;

    if (kIsWeb) {
      if (insertPause) {
        _webCaptureBytes.add(_capturePauseMarker);
      }
      _webCaptureBytes.addAll(codes);
      _lastCaptureAt = now;
      unawaited(_persistWebCapture());
      return;
    }

    if (_captureSink == null) return;

    if (insertPause) {
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
      List<int> payload;
      if (kIsWeb) {
        payload = List<int>.from(_webCaptureBytes);
        if (payload.isEmpty) {
          debugPrint('No in-memory capture found in this browser session');
          return;
        }
      } else {
        await _initializeCaptureFile();
        final captureFile = _captureFile;
        if (captureFile == null || !await captureFile.exists()) {
          debugPrint('Capture file not found: $_captureFilePath');
          return;
        }
        payload = await captureFile.readAsBytes();
      }

      if (payload.isEmpty) {
        debugPrint('Capture is empty');
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

  Future<void> exportCapture() async {
    if (kIsWeb) {
      if (_webCaptureBytes.isEmpty) return;
      await web_capture.exportCaptureAsDownload(
        Uint8List.fromList(_webCaptureBytes),
        _captureFilePath,
      );
      return;
    }

    await _initializeCaptureFile();
    final resolvedCaptureFile = _captureFile;
    if (resolvedCaptureFile == null || !await resolvedCaptureFile.exists()) {
      return;
    }
    final payload = await resolvedCaptureFile.readAsBytes();
    if (payload.isEmpty) return;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export capture',
        fileName: _captureFilePath,
        type: FileType.custom,
        allowedExtensions: const ['vdt'],
      );
      if (savePath != null && savePath.isNotEmpty) {
        await File(savePath).writeAsBytes(payload, flush: true);
      }
      return;
    }

    final temporaryDir = await getTemporaryDirectory();
    final exportFile = File('${temporaryDir.path}/$_captureFilePath');
    await exportFile.writeAsBytes(payload, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(exportFile.path, mimeType: 'application/octet-stream')],
        text: 'Capture Minitel',
      ),
    );
  }

  Future<void> importCapture() async {
    if (_captureEnabled || _isReplayingCapture) return;

    if (kIsWeb) {
      final imported = await web_capture.importCaptureFromFilePicker();
      if (imported == null || imported.isEmpty) return;
      _webCaptureBytes
        ..clear()
        ..addAll(imported);
      await _persistWebCapture();
      notifyListeners();
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['vdt'],
      withData: true,
    );

    if (picked == null || picked.files.isEmpty) return;

    final selectedFile = picked.files.first;
    Uint8List? importedBytes = selectedFile.bytes;
    if (importedBytes == null && selectedFile.path != null) {
      importedBytes = await File(selectedFile.path!).readAsBytes();
    }

    if (importedBytes == null || importedBytes.isEmpty) return;

    await _initializeCaptureFile();
    final captureFile = _captureFile;
    if (captureFile == null) return;
    await captureFile.writeAsBytes(importedBytes, flush: true);
    notifyListeners();
  }

  Future<void> _persistWebCapture() async {
    if (!kIsWeb) return;
    await web_capture.saveCaptureToBrowserStorage(
      _webCaptureStorageKey,
      Uint8List.fromList(_webCaptureBytes),
    );
  }

  Future<void> _restoreWebCapture() async {
    if (!kIsWeb) return;
    final restored =
        await web_capture.loadCaptureFromBrowserStorage(_webCaptureStorageKey);
    if (restored == null || restored.isEmpty) return;
    _webCaptureBytes
      ..clear()
      ..addAll(restored);
    notifyListeners();
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

  void setSerialSpeed(int speed) {
    if (_server is! SerialConnection) return;
    (_server as SerialConnection).configure(speed);
  }

  void sendReplyToServer() {
    if (minitel.reply.isNotEmpty) {
      if (isConnected) {
        final replyU8 = Uint8List.fromList(minitel.reply);
        if (_server is WebSocketChannel) {
          (_server as WebSocketChannel).sink.add(String.fromCharCodes(replyU8));
        } else if (_server is _TextWebSocketConnection) {
          (_server as _TextWebSocketConnection).sendBytes(replyU8);
        } else if (_server is Socket) {
          _server.add(replyU8);
        } else if (_server is SerialConnection) {
          (_server as SerialConnection).write(replyU8);
        }
      }
      minitel.reply.clear();
    }
  }

  void end() {
    _activeConnectionId++;
    isEchoed = true;
    debugPrint('End connection');

    _stopThrottleTimer();
    _codes.clear();

    if (isConnected) {
      _serialSubscription?.cancel();
      _serialSubscription = null;
      if (_server is WebSocketChannel) {
        _server!.sink.close();
      } else if (_server is _TextWebSocketConnection) {
        (_server as _TextWebSocketConnection).close();
      } else if (_server is Socket) {
        _server.destroy();
      } else if (_server is SerialConnection) {
        (_server as SerialConnection).close();
      }
    }
    _server = null;
  }

  void connect() {
    if (isConnected) end();
    if (_serverAddress == null) return;

    final connectionId = ++_activeConnectionId;

    final uri = _parseServerUri(_serverAddress!);
    debugPrint('Connect to: $uri');

    if (uri.scheme == 'serial') {
      if (_isLinuxDesktop) {
        connectSerial(uri.path, connectionId);
      } else {
        debugPrint('Serial is only available on Linux desktop');
      }
    }

    if (uri.scheme == 'ws' || uri.scheme == 'wss') {
      connectWebSocket(
        uri,
        connectionId,
        checkWebSocketAccept: _checkWebSocketAccept,
      );
    }

    if (uri.scheme == 'tcp' || uri.scheme == 'udp') {
      connectSocket(uri, connectionId);
    }

    isEchoed = false;
  }

  Uri _parseServerUri(String rawAddress) {
    final trimmed = rawAddress.trim();
    if (trimmed.isEmpty) {
      return Uri();
    }

    var uri = Uri.parse(trimmed);
    final scheme = uri.scheme.toLowerCase();
    final canUseAuthority =
        scheme == 'tcp' || scheme == 'udp' || scheme == 'ws' || scheme == 'wss';

    if (canUseAuthority && uri.host.isEmpty && !trimmed.contains('://')) {
      final normalized =
          '${trimmed.substring(0, scheme.length)}://${trimmed.substring(scheme.length + 1)}';
      uri = Uri.parse(normalized);
    }

    return uri;
  }

  void connectSerial(String portName, int connectionId) {
    if (!_isLinuxDesktop) return;
    if (isConnected) end();

    final connection = openSerialConnection(portName);
    if (connection == null) {
      debugPrint('Failed to open serial port: $portName');
      return;
    }

    _server = connection;
    minitel.speed = bps;
    setSerialSpeed(bps);

    final openedAt = DateTime.now();
    _serialSubscription = connection.stream.listen(
      (data) {
        if (connectionId != _activeConnectionId) return;
        // Ignore first bytes right after opening to avoid line noise.
        if (DateTime.now().difference(openedAt).inMilliseconds < 500) {
          return;
        }
        emulate(data);
      },
      onError: (error) {
        if (connectionId != _activeConnectionId) return;
        debugPrint('Serial port error: $error');
        end();
      },
      onDone: () {
        if (connectionId != _activeConnectionId) return;
        debugPrint('Serial port connection closed');
        end();
      },
    );
  }

  void connectSocket(Uri uri, int connectionId) {
    if (uri.host.isEmpty || uri.port == 0) {
      debugPrint('Socket URI invalid: $uri (expected tcp://host:port)');
      return;
    }

    Socket.connect(uri.host, uri.port).then(
      (Socket socket) {
        if (connectionId != _activeConnectionId) {
          socket.destroy();
          return;
        }
        _server = socket;
        (_server as Socket).listen(
          (data) {
            if (connectionId != _activeConnectionId) return;
            emulate(data);
          },
          onDone: () {
            if (connectionId != _activeConnectionId) return;
            debugPrint('Socket connection closed');
            end();
          },
          onError: (error) {
            if (connectionId != _activeConnectionId) return;
            debugPrint('Socket error: $error');
            end();
          },
        );
      },
    ).onError(
      (error, stackTrace) {
        if (connectionId != _activeConnectionId) return;
        debugPrint('Socket error: $error');
        end();
      },
    );
  }

  void connectWebSocket(
    Uri uri,
    int connectionId, {
    required bool checkWebSocketAccept,
  }) {
    if (kIsWeb) {
      _server = WebSocketChannel.connect(uri);
      (_server as WebSocketChannel).stream.listen(
        (data) {
          if (connectionId != _activeConnectionId) return;
          emulate(data.toString().codeUnits);
        },
        onError: (error) {
          if (connectionId != _activeConnectionId) return;
          debugPrint('WebSocket error: $error');
          end();
        },
        onDone: () {
          if (connectionId != _activeConnectionId) return;
          debugPrint('WebSocket connection closed');
          end();
        },
      );
      return;
    }

    final wsUri = uri.path.isEmpty ? uri.replace(path: '/') : uri;
    debugPrint('WebSocket connecting to: $wsUri');

    _TextWebSocketConnection.connect(
      wsUri,
      timeout: const Duration(seconds: 12),
      checkWebSocketAccept: checkWebSocketAccept,
    ).then((ws) {
      if (connectionId != _activeConnectionId) {
        ws.close();
        return;
      }
      _server = ws;
      debugPrint('WebSocket connected to: $wsUri');
      ws.stream.listen(
        (data) {
          if (connectionId != _activeConnectionId) return;
          emulate(data.codeUnits);
        },
        onError: (error) {
          if (connectionId != _activeConnectionId) return;
          debugPrint('WebSocket error: $error');
          end();
        },
        onDone: () {
          if (connectionId != _activeConnectionId) return;
          debugPrint('WebSocket connection closed');
          end();
        },
      );
    }).onError((error, stackTrace) {
      if (connectionId != _activeConnectionId) return;
      debugPrint('WebSocket connect error for $wsUri: $error');
      end();
    });
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
        (_server as WebSocketChannel).sink.add(keys);
      } else if (_server is _TextWebSocketConnection) {
        (_server as _TextWebSocketConnection).sendText(keys);
      } else if (_server is Socket) {
        _server.write(keys);
      } else if (_server is SerialConnection) {
        (_server as SerialConnection).write(Uint8List.fromList(keys.codeUnits));
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

class _TextWebSocketConnection {
  static const String _wsGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

  final Socket _socket;
  final StreamIterator<List<int>> _socketIterator;
  final StreamController<String> _textController = StreamController<String>();
  final List<int> _frameBuffer = <int>[];
  final List<int> _fragmentBuffer = <int>[];
  final Random _random = Random.secure();

  bool _closed = false;
  int? _fragmentOpcode;

  _TextWebSocketConnection._(
    this._socket,
    this._socketIterator, [
    List<int>? initialBytes,
  ]) {
    if (initialBytes != null && initialBytes.isNotEmpty) {
      _onSocketData(initialBytes);
    }

    _startReadLoop();
  }

  Stream<String> get stream => _textController.stream;

  static Future<_TextWebSocketConnection> connect(
    Uri uri, {
    Duration timeout = const Duration(seconds: 12),
    bool checkWebSocketAccept = true,
  }) async {
    final host = uri.host;
    final port = uri.hasPort ? uri.port : (uri.scheme == 'wss' ? 443 : 80);
    final Socket socket = uri.scheme == 'wss'
        ? await SecureSocket.connect(host, port, timeout: timeout)
        : await Socket.connect(host, port, timeout: timeout);
    final socketIterator = StreamIterator<List<int>>(socket);

    var target = uri.path.isEmpty ? '/' : uri.path;
    if (uri.hasQuery) target = '$target?${uri.query}';

    final random = Random.secure();
    final keyBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final wsKey = base64.encode(keyBytes);

    final request = StringBuffer()
      ..write('GET $target HTTP/1.1\r\n')
      ..write('Host: $host:$port\r\n')
      ..write('Upgrade: websocket\r\n')
      ..write('Connection: Upgrade\r\n')
      ..write('Sec-WebSocket-Version: 13\r\n')
      ..write('Sec-WebSocket-Key: $wsKey\r\n')
      ..write('\r\n');

    socket.add(ascii.encode(request.toString()));
    await socket.flush();

    final allHeaderBytes = await _readHandshakeBytes(socketIterator, timeout);
    final headerEnd = _headerEndIndex(allHeaderBytes);
    if (headerEnd < 0) {
      throw SocketException(
          'Invalid WebSocket handshake response (no header end)');
    }

    final headerText = ascii.decode(allHeaderBytes.sublist(0, headerEnd));
    final firstLine = headerText.split('\r\n').first;
    if (!firstLine.contains('101')) {
      throw SocketException('WebSocket upgrade failed: $firstLine');
    }

    final headers = _parseHandshakeHeaders(headerText);
    final upgradeHeader = headers['upgrade']?.toLowerCase().trim();
    final connectionHeader = headers['connection'];
    if (upgradeHeader != 'websocket' ||
        !_headerContainsToken(connectionHeader, 'upgrade')) {
      throw SocketException(
          'WebSocket upgrade response missing required headers');
    }

    final expectedAccept = _expectedAccept(wsKey);
    final responseAccept = headers['sec-websocket-accept']?.trim();
    if (responseAccept != expectedAccept && checkWebSocketAccept) {
      throw SocketException(
          'Invalid Sec-WebSocket-Accept in handshake response');
    }

    if (responseAccept != expectedAccept && !checkWebSocketAccept) {
      debugPrint(
        'WebSocket warning for ${uri.host}: skipped '
        'Sec-WebSocket-Accept check (expected $expectedAccept, got $responseAccept)',
      );
    }

    final remaining = allHeaderBytes.sublist(headerEnd + 4);
    return _TextWebSocketConnection._(socket, socketIterator, remaining);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _sendFrame(0x8, const <int>[]);
    await _socketIterator.cancel();
    await _socket.close();
    if (!_textController.isClosed) {
      await _textController.close();
    }
  }

  void _startReadLoop() {
    () async {
      try {
        while (!_closed) {
          final hasData = await _socketIterator.moveNext();
          if (!hasData) break;
          _onSocketData(_socketIterator.current);
        }
      } catch (error, st) {
        if (!_textController.isClosed) {
          _textController.addError(error, st);
        }
      } finally {
        _closed = true;
        if (!_textController.isClosed) {
          await _textController.close();
        }
      }
    }();
  }

  void sendText(String text) {
    if (_closed) return;
    final payload = List<int>.from(text.codeUnits.map((unit) => unit & 0xFF));
    _sendFrame(0x1, payload);
  }

  void sendBytes(Uint8List bytes) {
    if (_closed) return;
    _sendFrame(0x1, bytes);
  }

  void _onSocketData(List<int> data) {
    if (_closed) return;
    _frameBuffer.addAll(data);
    _drainFrames();
  }

  void _drainFrames() {
    while (true) {
      if (_frameBuffer.length < 2) return;

      final b0 = _frameBuffer[0];
      final fin = (b0 & 0x80) != 0;
      final opcode = b0 & 0x0F;
      final b1 = _frameBuffer[1];
      final masked = (b1 & 0x80) != 0;

      var payloadLen = b1 & 0x7F;
      var offset = 2;

      if (payloadLen == 126) {
        if (_frameBuffer.length < offset + 2) return;
        payloadLen = (_frameBuffer[offset] << 8) | _frameBuffer[offset + 1];
        offset += 2;
      } else if (payloadLen == 127) {
        if (_frameBuffer.length < offset + 8) return;
        var parsed = 0;
        for (var i = 0; i < 8; i++) {
          parsed = (parsed << 8) | _frameBuffer[offset + i];
        }
        payloadLen = parsed;
        offset += 8;
      }

      List<int>? mask;
      if (masked) {
        if (_frameBuffer.length < offset + 4) return;
        mask = _frameBuffer.sublist(offset, offset + 4);
        offset += 4;
      }

      if (_frameBuffer.length < offset + payloadLen) return;

      final payload = _frameBuffer.sublist(offset, offset + payloadLen);
      _frameBuffer.removeRange(0, offset + payloadLen);

      if (mask != null) {
        for (var i = 0; i < payload.length; i++) {
          payload[i] = payload[i] ^ mask[i % 4];
        }
      }

      switch (opcode) {
        case 0x1: // text
        case 0x2: // binary
          if (fin) {
            _emitPayload(payload);
          } else {
            _fragmentOpcode = opcode;
            _fragmentBuffer
              ..clear()
              ..addAll(payload);
          }
          break;
        case 0x0: // continuation
          if (_fragmentOpcode != null) {
            _fragmentBuffer.addAll(payload);
            if (fin) {
              _emitPayload(_fragmentBuffer);
              _fragmentBuffer.clear();
              _fragmentOpcode = null;
            }
          }
          break;
        case 0x8: // close
          close();
          return;
        case 0x9: // ping
          _sendFrame(0xA, payload);
          break;
        case 0xA: // pong
          break;
        default:
          break;
      }
    }
  }

  void _sendFrame(int opcode, List<int> payload) {
    final frame = <int>[];
    frame.add(0x80 | (opcode & 0x0F));

    final payloadLength = payload.length;
    if (payloadLength <= 125) {
      frame.add(0x80 | payloadLength);
    } else if (payloadLength <= 0xFFFF) {
      frame
        ..add(0x80 | 126)
        ..add((payloadLength >> 8) & 0xFF)
        ..add(payloadLength & 0xFF);
    } else {
      frame.add(0x80 | 127);
      final len = payloadLength;
      for (var i = 7; i >= 0; i--) {
        frame.add((len >> (i * 8)) & 0xFF);
      }
    }

    final mask = List<int>.generate(4, (_) => _random.nextInt(256));
    frame.addAll(mask);

    for (var i = 0; i < payload.length; i++) {
      frame.add(payload[i] ^ mask[i % 4]);
    }

    _socket.add(frame);
  }

  void _emitPayload(List<int> payload) {
    if (_textController.isClosed) return;
    _textController.add(String.fromCharCodes(payload));
  }

  static Future<List<int>> _readHandshakeBytes(
    StreamIterator<List<int>> socketIterator,
    Duration timeout,
  ) async {
    final bytes = <int>[];
    while (true) {
      final hasData = await socketIterator
          .moveNext()
          .timeout(timeout, onTimeout: () => false);
      if (!hasData) {
        if (_headerEndIndex(bytes) >= 0) {
          return List<int>.from(bytes);
        }
        throw TimeoutException('WebSocket handshake timeout', timeout);
      }

      bytes.addAll(socketIterator.current);
      if (_headerEndIndex(bytes) >= 0) {
        return List<int>.from(bytes);
      }
    }
  }

  static int _headerEndIndex(List<int> bytes) {
    for (var i = 0; i + 3 < bytes.length; i++) {
      if (bytes[i] == 13 &&
          bytes[i + 1] == 10 &&
          bytes[i + 2] == 13 &&
          bytes[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  static String _expectedAccept(String secWebSocketKey) {
    final input = ascii.encode('$secWebSocketKey$_wsGuid');
    final digest = _sha1(input);
    return base64.encode(digest);
  }

  static Map<String, String> _parseHandshakeHeaders(String headerText) {
    final result = <String, String>{};
    final lines = headerText.split('\r\n');
    for (final line in lines.skip(1)) {
      final sep = line.indexOf(':');
      if (sep <= 0) continue;
      final name = line.substring(0, sep).trim().toLowerCase();
      final value = line.substring(sep + 1).trim();
      result[name] = value;
    }
    return result;
  }

  static bool _headerContainsToken(String? headerValue, String token) {
    if (headerValue == null || headerValue.isEmpty) return false;
    final expected = token.toLowerCase();
    return headerValue
        .split(',')
        .any((part) => part.trim().toLowerCase() == expected);
  }

  static List<int> _sha1(List<int> bytes) {
    var h0 = 0x67452301;
    var h1 = 0xEFCDAB89;
    var h2 = 0x98BADCFE;
    var h3 = 0x10325476;
    var h4 = 0xC3D2E1F0;

    final message = List<int>.from(bytes);
    final originalBitLength = message.length * 8;

    message.add(0x80);
    while ((message.length % 64) != 56) {
      message.add(0);
    }

    for (var i = 7; i >= 0; i--) {
      message.add((originalBitLength >> (8 * i)) & 0xFF);
    }

    for (var chunkStart = 0; chunkStart < message.length; chunkStart += 64) {
      final w = List<int>.filled(80, 0);
      for (var i = 0; i < 16; i++) {
        final j = chunkStart + i * 4;
        w[i] = (message[j] << 24) |
            (message[j + 1] << 16) |
            (message[j + 2] << 8) |
            message[j + 3];
      }

      for (var i = 16; i < 80; i++) {
        w[i] = _leftRotate(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
      }

      var a = h0;
      var b = h1;
      var c = h2;
      var d = h3;
      var e = h4;

      for (var i = 0; i < 80; i++) {
        int f;
        int k;
        if (i < 20) {
          f = (b & c) | ((~b) & d);
          k = 0x5A827999;
        } else if (i < 40) {
          f = b ^ c ^ d;
          k = 0x6ED9EBA1;
        } else if (i < 60) {
          f = (b & c) | (b & d) | (c & d);
          k = 0x8F1BBCDC;
        } else {
          f = b ^ c ^ d;
          k = 0xCA62C1D6;
        }

        final temp = (_leftRotate(a, 5) + f + e + k + w[i]) & 0xFFFFFFFF;
        e = d;
        d = c;
        c = _leftRotate(b, 30);
        b = a;
        a = temp;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
    }

    return <int>[
      (h0 >> 24) & 0xFF,
      (h0 >> 16) & 0xFF,
      (h0 >> 8) & 0xFF,
      h0 & 0xFF,
      (h1 >> 24) & 0xFF,
      (h1 >> 16) & 0xFF,
      (h1 >> 8) & 0xFF,
      h1 & 0xFF,
      (h2 >> 24) & 0xFF,
      (h2 >> 16) & 0xFF,
      (h2 >> 8) & 0xFF,
      h2 & 0xFF,
      (h3 >> 24) & 0xFF,
      (h3 >> 16) & 0xFF,
      (h3 >> 8) & 0xFF,
      h3 & 0xFF,
      (h4 >> 24) & 0xFF,
      (h4 >> 16) & 0xFF,
      (h4 >> 8) & 0xFF,
      h4 & 0xFF,
    ];
  }

  static int _leftRotate(int value, int shift) {
    return ((value << shift) | (value >> (32 - shift))) & 0xFFFFFFFF;
  }
}
