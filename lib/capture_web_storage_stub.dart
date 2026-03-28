import 'dart:typed_data';

Future<void> saveCaptureToBrowserStorage(String key, Uint8List data) async {}

Future<Uint8List?> loadCaptureFromBrowserStorage(String key) async {
  return null;
}

Future<void> exportCaptureAsDownload(Uint8List data, String filename) async {}

Future<Uint8List?> importCaptureFromFilePicker({String accept = '.vdt'}) async {
  return null;
}
