import 'package:flutter/foundation.dart';
import 'package:minterm/min_emulator.dart';

class MinModel extends ChangeNotifier {
  static final MinModel _singleton = MinModel._internal();
  final minitel = TMinitel();

  factory MinModel() {
    return _singleton;
  }

  MinModel._internal();

  void emulate(List<int> codes) {
    minitel.emulate(codes);
    if (minitel.isDirty) notifyListeners();
  }
}
