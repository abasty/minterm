import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'server_endpoint.dart';
import 'server_list_storage_stub.dart'
    if (dart.library.html) 'server_list_storage_web.dart'
    if (dart.library.io) 'server_list_storage_io.dart' as server_storage;

class ServerEndpointCatalog extends ChangeNotifier {
  static final ServerEndpointCatalog _singleton =
      ServerEndpointCatalog._internal();
  static const int _storageVersion = 1;

  final Random _random = Random.secure();
  List<ServerEndpoint> _endpoints = <ServerEndpoint>[];
  Future<void>? _loadingFuture;
  bool _loaded = false;

  factory ServerEndpointCatalog() {
    return _singleton;
  }

  ServerEndpointCatalog._internal() {
    unawaited(ensureLoaded());
  }

  bool get isLoaded => _loaded;

  UnmodifiableListView<ServerEndpoint> get endpoints {
    return UnmodifiableListView<ServerEndpoint>(
        List<ServerEndpoint>.from(_endpoints));
  }

  List<ServerEndpoint> get recentEndpoints {
    final recents = _endpoints.where((e) => e.lastUsedAt != null).toList()
      ..sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
    if (recents.isNotEmpty) {
      return recents.take(3).toList(growable: false);
    }

    return _endpoints.take(3).toList(growable: false);
  }

  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    if (_loadingFuture != null) return _loadingFuture!;

    _loadingFuture = _loadInternal();
    return _loadingFuture!;
  }

  Future<void> _loadInternal() async {
    try {
      final jsonText = await server_storage.loadServerListJson();
      if (jsonText == null || jsonText.trim().isEmpty) {
        _endpoints = _seedEndpoints();
        await _saveInternal();
      } else {
        final decoded = json.decode(jsonText);
        if (decoded is Map<String, dynamic>) {
          _endpoints = _deserialize(decoded);
        } else {
          _endpoints = _seedEndpoints();
          await _saveInternal();
        }
      }
    } catch (error) {
      debugPrint('Failed to load server endpoints: $error');
      _endpoints = _seedEndpoints();
      await _saveInternal();
    }

    _loaded = true;
    _loadingFuture = null;
    notifyListeners();
  }

  Future<void> _saveInternal() async {
    final payload = <String, dynamic>{
      'version': _storageVersion,
      'endpoints': _endpoints.map((e) => e.toJson()).toList(growable: false),
    };
    await server_storage.saveServerListJson(json.encode(payload));
  }

  List<ServerEndpoint> _deserialize(Map<String, dynamic> root) {
    final rawEndpoints = root['endpoints'];
    if (rawEndpoints is! List) {
      return _seedEndpoints();
    }

    final parsed = <ServerEndpoint>[];
    for (final item in rawEndpoints) {
      if (item is Map<String, dynamic>) {
        final endpoint = ServerEndpoint.fromJson(item);
        if (endpoint.id.isNotEmpty &&
            endpoint.name.trim().isNotEmpty &&
            endpoint.url.trim().isNotEmpty) {
          parsed.add(endpoint);
        }
      }
    }

    if (parsed.isEmpty) {
      return _seedEndpoints();
    }

    return parsed;
  }

  Future<void> addEndpoint({
    required String name,
    required String url,
    bool checkWebSocketAccept = true,
  }) async {
    await ensureLoaded();

    final now = DateTime.now().toUtc();
    final endpoint = ServerEndpoint(
      id: _newId(),
      name: name.trim(),
      url: url.trim(),
      checkWebSocketAccept: checkWebSocketAccept,
      createdAt: now,
      updatedAt: now,
    );

    _endpoints = List<ServerEndpoint>.from(_endpoints)..add(endpoint);
    await _saveInternal();
    notifyListeners();
  }

  Future<void> updateEndpoint(
    String id, {
    required String name,
    required String url,
    required bool checkWebSocketAccept,
  }) async {
    await ensureLoaded();
    final now = DateTime.now().toUtc();

    _endpoints = _endpoints
        .map(
          (e) => e.id == id
              ? e.copyWith(
                  name: name.trim(),
                  url: url.trim(),
                  checkWebSocketAccept: checkWebSocketAccept,
                  updatedAt: now,
                )
              : e,
        )
        .toList(growable: false);

    await _saveInternal();
    notifyListeners();
  }

  Future<void> deleteEndpoint(String id) async {
    await ensureLoaded();
    _endpoints = _endpoints.where((e) => e.id != id).toList(growable: false);
    if (_endpoints.isEmpty) {
      _endpoints = _seedEndpoints();
    }
    await _saveInternal();
    notifyListeners();
  }

  Future<void> duplicateEndpoint(String id) async {
    await ensureLoaded();
    ServerEndpoint? original;
    for (final endpoint in _endpoints) {
      if (endpoint.id == id) {
        original = endpoint;
        break;
      }
    }
    if (original == null) return;

    final now = DateTime.now().toUtc();
    final duplicated = ServerEndpoint(
      id: _newId(),
      name: '${original.name} (copie)',
      url: original.url,
      checkWebSocketAccept: original.checkWebSocketAccept,
      lastUsedAt: null,
      createdAt: now,
      updatedAt: now,
    );

    final current = List<ServerEndpoint>.from(_endpoints);
    final index = current.indexWhere((e) => e.id == id);
    if (index < 0) {
      current.add(duplicated);
    } else {
      current.insert(index + 1, duplicated);
    }

    _endpoints = current;
    await _saveInternal();
    notifyListeners();
  }

  Future<void> reorderEndpoint(int oldIndex, int newIndex) async {
    await ensureLoaded();
    if (oldIndex < 0 || oldIndex >= _endpoints.length) return;
    if (newIndex < 0 || newIndex > _endpoints.length) return;

    final targetIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
    if (targetIndex == oldIndex) return;

    final current = List<ServerEndpoint>.from(_endpoints);
    final item = current.removeAt(oldIndex);
    current.insert(targetIndex, item);
    _endpoints = current;
    await _saveInternal();
    notifyListeners();
  }

  String exportJson() {
    final payload = <String, dynamic>{
      'version': _storageVersion,
      'endpoints': _endpoints.map((e) => e.toJson()).toList(growable: false),
    };
    return json.encode(payload);
  }

  Future<String?> importJson(String jsonText) async {
    await ensureLoaded();

    dynamic decoded;
    try {
      decoded = json.decode(jsonText);
    } catch (_) {
      return 'Le fichier JSON est invalide.';
    }

    if (decoded is! Map<String, dynamic>) {
      return 'Le format JSON est invalide.';
    }

    final imported = _deserialize(decoded);
    if (imported.isEmpty) {
      return 'Aucun serveur valide dans le fichier.';
    }

    _endpoints = imported;
    await _saveInternal();
    notifyListeners();
    return null;
  }

  Future<void> markEndpointUsed(String id) async {
    await ensureLoaded();
    final now = DateTime.now().toUtc();
    _endpoints = _endpoints
        .map(
          (e) => e.id == id ? e.copyWith(lastUsedAt: now, updatedAt: now) : e,
        )
        .toList(growable: false);
    await _saveInternal();
    notifyListeners();
  }

  String? validate({required String name, required String url}) {
    if (name.trim().isEmpty) {
      return 'Le nom est obligatoire.';
    }

    if (url.trim().isEmpty) {
      return 'L\'URL est obligatoire.';
    }

    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme.isEmpty) {
      return 'URL invalide.';
    }

    return null;
  }

  // Defaults natifs (TCP direct disponible, notamment pour BASTOS en local).
  static const _nativeSeedDefaults = <({String name, String url, bool check})>[
    (name: '3611', url: 'ws://3611.re/ws', check: true),
    (name: '3615', url: 'ws://3615co.de/ws', check: true),
    (name: 'Minipavi', url: 'ws://go.minipavi.fr:8182', check: false),
    (name: 'Hacker', url: 'ws://mntl.joher.com:2018/?echo', check: true),
    (name: 'Galaxy', url: 'ws://galaxy.microtel.fr:50124', check: true),
    (name: 'BastOS (localhost:1967)', url: 'tcp://127.0.0.1:1967', check: true),
    (name: 'Zboub', url: 'tcp:abasty-retro.fr:1967', check: true),
  ];

  // Defaults web : uniquement des connexions WebSocket (TCP indisponible en
  // web), et BastOS local en `ws://` au lieu de `tcp://`.
  static const _webSeedDefaults = <({String name, String url, bool check})>[
    (name: 'Minipavi', url: 'wss://go.minipavi.fr:8181/', check: true),
    (name: 'Rétrocampus', url: 'wss://bbs.retrocampus.com:8051', check: true),
    (name: '3611', url: 'wss://3611.re/ws', check: true),
    (name: '3615', url: 'wss://3615co.de/ws', check: true),
    (name: 'BastOS (localhost:1967)', url: 'ws://127.0.0.1:1967', check: true),
    (name: 'SM', url: 'wss://wss.3615.live:9991/?echo', check: true),
  ];

  List<ServerEndpoint> _seedEndpoints() {
    final now = DateTime.now().toUtc();
    final defaults = kIsWeb ? _webSeedDefaults : _nativeSeedDefaults;

    return defaults
        .map(
          (d) => ServerEndpoint(
            id: _newId(),
            name: d.name,
            url: d.url,
            checkWebSocketAccept: d.check,
            createdAt: now,
            updatedAt: now,
          ),
        )
        .toList(growable: false);
  }

  String _newId() {
    final ms = DateTime.now().microsecondsSinceEpoch;
    final r = _random.nextInt(0x7fffffff);
    return '$ms-$r';
  }
}
