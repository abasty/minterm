// ignore_for_file: deprecated_member_use

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

const _storageKey = 'minterm.server_endpoints.v1';

Future<String?> loadServerListJson() async {
  return html.window.localStorage[_storageKey];
}

Future<void> saveServerListJson(String jsonText) async {
  html.window.localStorage[_storageKey] = jsonText;
}
