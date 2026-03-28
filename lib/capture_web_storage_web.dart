// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> saveCaptureToBrowserStorage(String key, Uint8List data) async {
  html.window.localStorage[key] = base64Encode(data);
}

Future<Uint8List?> loadCaptureFromBrowserStorage(String key) async {
  final encoded = html.window.localStorage[key];
  if (encoded == null || encoded.isEmpty) {
    return null;
  }
  try {
    return Uint8List.fromList(base64Decode(encoded));
  } catch (_) {
    html.window.localStorage.remove(key);
    return null;
  }
}

Future<void> exportCaptureAsDownload(Uint8List data, String filename) async {
  final blob = html.Blob(<dynamic>[data], 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<Uint8List?> importCaptureFromFilePicker({String accept = '.vdt'}) {
  final completer = Completer<Uint8List?>();
  final input = html.FileUploadInputElement()
    ..accept = accept
    ..multiple = false;

  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      return;
    }

    final file = files.first;
    final reader = html.FileReader();

    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is String) {
        final commaIndex = result.indexOf(',');
        if (commaIndex < 0 || commaIndex == result.length - 1) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          return;
        }
        try {
          final bytes = base64Decode(result.substring(commaIndex + 1));
          if (!completer.isCompleted) {
            completer.complete(Uint8List.fromList(bytes));
          }
        } catch (_) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
      } else {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }
    });

    reader.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    reader.readAsDataUrl(file);
  });

  input.click();
  return completer.future;
}
