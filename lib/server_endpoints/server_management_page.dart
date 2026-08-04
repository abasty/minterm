import 'dart:async';

import 'package:flutter/material.dart';

import '../min_model.dart';
import 'server_endpoint.dart';
import 'server_endpoint_catalog.dart';
import 'server_list_exchange_stub.dart'
    if (dart.library.html) 'server_list_exchange_web.dart'
    if (dart.library.io) 'server_list_exchange_io.dart' as list_exchange;

class ServerManagementPage extends StatefulWidget {
  const ServerManagementPage({super.key});

  @override
  State<ServerManagementPage> createState() => _ServerManagementPageState();
}

class _ServerManagementPageState extends State<ServerManagementPage> {
  final catalog = ServerEndpointCatalog();

  @override
  void initState() {
    super.initState();
    unawaited(catalog.ensureLoaded());
  }

  Future<void> _connect(ServerEndpoint endpoint) async {
    MinModel().serverAddress = endpoint.url;
    MinModel().checkWebSocketAccept = endpoint.checkWebSocketAccept;
    MinModel().connect();
    await catalog.markEndpointUsed(endpoint.id);

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _openEditor({ServerEndpoint? endpoint}) async {
    final result = await showDialog<_ServerEditorResult>(
      context: context,
      builder: (context) => _ServerEditorDialog(endpoint: endpoint),
    );

    if (result == null) return;

    if (endpoint == null) {
      await catalog.addEndpoint(
        name: result.name,
        url: result.url,
        checkWebSocketAccept: result.checkWebSocketAccept,
      );
    } else {
      await catalog.updateEndpoint(
        endpoint.id,
        name: result.name,
        url: result.url,
        checkWebSocketAccept: result.checkWebSocketAccept,
      );
    }
  }

  Future<void> _delete(ServerEndpoint endpoint) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce serveur ?'),
        content: Text('${endpoint.name}\n${endpoint.url}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await catalog.deleteEndpoint(endpoint.id);
    }
  }

  Future<void> _duplicate(ServerEndpoint endpoint) async {
    await catalog.duplicateEndpoint(endpoint.id);
  }

  Future<void> _exportList() async {
    final jsonText = catalog.exportJson();
    final ok = await list_exchange.exportServerListJson(
      jsonText,
      'minterm_server_endpoints.json',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Liste des serveurs exportee.' : 'Export annule.'),
      ),
    );
  }

  Future<void> _importList() async {
    final jsonText = await list_exchange.importServerListJson();
    if (jsonText == null || jsonText.trim().isEmpty) return;

    final error = await catalog.importJson(jsonText);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Liste des serveurs importee.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexions'),
        actions: [
          IconButton(
            tooltip: 'Importer',
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: _importList,
          ),
          IconButton(
            tooltip: 'Exporter',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportList,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: ListenableBuilder(
        listenable: catalog,
        builder: (context, _) {
          if (!catalog.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final endpoints = catalog.endpoints;
          return ReorderableListView.builder(
            itemCount: endpoints.length,
            onReorder: (oldIndex, newIndex) {
              unawaited(catalog.reorderEndpoint(oldIndex, newIndex));
            },
            itemBuilder: (context, index) {
              final endpoint = endpoints[index];
              final info = <String>[endpoint.url];
              if (!endpoint.checkWebSocketAccept) {
                info.add('Sec-WebSocket-Accept: OFF');
              }

              return Container(
                key: ValueKey(endpoint.id),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 0.6,
                    ),
                  ),
                ),
                child: ListTile(
                  title: Text(endpoint.name),
                  subtitle: Text(info.join('  •  ')),
                  onTap: () => _connect(endpoint),
                  leading: IconButton(
                    tooltip: 'Connecter',
                    onPressed: () => _connect(endpoint),
                    icon: const Icon(Icons.play_arrow),
                  ),
                  trailing: Wrap(
                    spacing: 2,
                    children: [
                      IconButton(
                        tooltip: 'Dupliquer',
                        onPressed: () => _duplicate(endpoint),
                        icon: const Icon(Icons.copy),
                      ),
                      IconButton(
                        tooltip: 'Modifier',
                        onPressed: () => _openEditor(endpoint: endpoint),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        onPressed: () => _delete(endpoint),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ServerEditorResult {
  const _ServerEditorResult({
    required this.name,
    required this.url,
    required this.checkWebSocketAccept,
  });

  final String name;
  final String url;
  final bool checkWebSocketAccept;
}

class _ServerEditorDialog extends StatefulWidget {
  const _ServerEditorDialog({this.endpoint});

  final ServerEndpoint? endpoint;

  @override
  State<_ServerEditorDialog> createState() => _ServerEditorDialogState();
}

class _ServerEditorDialogState extends State<_ServerEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late bool _checkWebSocketAccept;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.endpoint?.name ?? '');
    _urlController = TextEditingController(text: widget.endpoint?.url ?? '');
    _checkWebSocketAccept = widget.endpoint?.checkWebSocketAccept ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text;
    final url = _urlController.text;
    final message = ServerEndpointCatalog().validate(name: name, url: url);

    if (message != null) {
      setState(() => _error = message);
      return;
    }

    Navigator.pop(
      context,
      _ServerEditorResult(
        name: name.trim(),
        url: url.trim(),
        checkWebSocketAccept: _checkWebSocketAccept,
      ),
    );
  }

  bool get _isWsUrl {
    final uri = Uri.tryParse(_urlController.text.trim());
    final scheme = uri?.scheme.toLowerCase();
    return scheme == 'ws' || scheme == 'wss';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.endpoint == null
          ? 'Ajouter un serveur'
          : 'Modifier le serveur'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: 'URL'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vérifier Sec-WebSocket-Accept'),
              value: _checkWebSocketAccept,
              onChanged: _isWsUrl
                  ? (value) => setState(() => _checkWebSocketAccept = value)
                  : null,
            ),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
