import 'package:flutter/foundation.dart';
import 'package:minterm/min_emulator.dart';

class MinModel extends ChangeNotifier {
  final minitel = TMinitel();

  void emulate(List<int> codes) {
    minitel.emulate(codes);
    if (minitel.isDirty) notifyListeners();
  }
}
