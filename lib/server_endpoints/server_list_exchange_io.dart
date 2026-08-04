import 'package:file_picker/file_picker.dart';
import 'package:universal_io/io.dart';

Future<String?> importServerListJson() async {
  final picked = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    type: FileType.custom,
    allowedExtensions: const ['json'],
    withData: true,
  );

  if (picked == null || picked.files.isEmpty) {
    return null;
  }

  final file = picked.files.first;
  if (file.bytes != null) {
    return String.fromCharCodes(file.bytes!);
  }

  if (file.path != null && file.path!.isNotEmpty) {
    return File(file.path!).readAsString();
  }

  return null;
}

Future<bool> exportServerListJson(String jsonText, String filename) async {
  final savePath = await FilePicker.platform.saveFile(
    dialogTitle: 'Exporter la liste des serveurs',
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );

  if (savePath == null || savePath.isEmpty) {
    return false;
  }

  await File(savePath).writeAsString(jsonText, flush: true);
  return true;
}
