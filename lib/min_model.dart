import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'capture_web_storage_stub.dart'
    if (dart.library.html) 'capture_web_storage_web.dart' as web_capture;
import 'min_emulator.dart';

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

    _stopThrottleTimer();
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
