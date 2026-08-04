import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

const _fileName = 'server_endpoints.json';

Future<File> _resolveStorageFile() async {
  final baseDir = await getApplicationSupportDirectory();
  if (!await baseDir.exists()) {
    await baseDir.create(recursive: true);
  }

  return File('${baseDir.path}/$_fileName');
}

Future<String?> loadServerListJson() async {
  final file = await _resolveStorageFile();
  if (!await file.exists()) {
    return null;
  }
  return file.readAsString();
}

Future<void> saveServerListJson(String jsonText) async {
  final file = await _resolveStorageFile();
  await file.writeAsString(jsonText, flush: true);
}
