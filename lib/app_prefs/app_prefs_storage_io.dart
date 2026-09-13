import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

const _fileName = 'app_prefs.json';

Future<File> _resolveStorageFile() async {
  final baseDir = await getApplicationSupportDirectory();
  if (!await baseDir.exists()) {
    await baseDir.create(recursive: true);
  }

  return File('${baseDir.path}/$_fileName');
}

Future<String?> loadAppPrefsJson() async {
  final file = await _resolveStorageFile();
  if (!await file.exists()) {
    return null;
  }
  return file.readAsString();
}

Future<void> saveAppPrefsJson(String jsonText) async {
  final file = await _resolveStorageFile();
  await file.writeAsString(jsonText, flush: true);
}
