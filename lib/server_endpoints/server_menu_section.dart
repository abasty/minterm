import 'dart:async';

import 'package:flutter/material.dart';

import '../min_model.dart';
import 'server_endpoint_catalog.dart';
import 'server_management_page.dart';

class RecentConnectionsSection extends StatefulWidget {
  const RecentConnectionsSection({super.key});

  @override
  State<RecentConnectionsSection> createState() =>
      _RecentConnectionsSectionState();
}

class _RecentConnectionsSectionState extends State<RecentConnectionsSection> {
  final catalog = ServerEndpointCatalog();

  @override
  void initState() {
    super.initState();
    unawaited(catalog.ensureLoaded());
  }

  Future<void> _connect(
      BuildContext context, String id, String url, bool check) async {
    MinModel().serverAddress = url;
    MinModel().checkWebSocketAccept = check;
    MinModel().connect();
    await catalog.markEndpointUsed(id);

    if (!context.mounted) return;
    Navigator.pop(context);
  }

  Future<void> _openManagement(BuildContext context) async {
    Navigator.pop(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ServerManagementPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: catalog,
      builder: (context, _) {
        if (!catalog.isLoaded) {
          return const ListTile(
            title: Text('Chargement des connexions...'),
          );
        }

        final recents = catalog.recentEndpoints;
        final children = <Widget>[
          for (final endpoint in recents)
            ListTile(
              title: Text(endpoint.name),
              subtitle: Text(endpoint.url),
              onTap: () => _connect(
                context,
                endpoint.id,
                endpoint.url,
                endpoint.checkWebSocketAccept,
              ),
            ),
          ListTile(
            title: const Text('Autre...'),
            subtitle: const Text('Gérer toutes les connexions'),
            onTap: () => _openManagement(context),
          ),
        ];

        if (children.isEmpty) {
          return ListTile(
            title: const Text('Autre...'),
            subtitle: const Text('Gérer toutes les connexions'),
            onTap: () => _openManagement(context),
          );
        }

        return Column(children: children);
      },
    );
  }
}
