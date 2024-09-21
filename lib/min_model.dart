import 'dart:async';
import 'package:flutter/foundation.dart';

import 'min_emulator.dart';

class MinModel extends ChangeNotifier {
  static final MinModel _singleton = MinModel._internal();
  final minitel = TMinitel();
  var _codes = <int>[];
  int _index = 0;
  int _bps = 1200;
  Timer? _timer;

  factory MinModel() {
    return _singleton;
  }

  MinModel._internal();

  void emulate(List<int> codes, {int bps = 1200}) {
    if (_timer != null) _timer!.cancel();
    _bps = bps;
    _codes = codes;
    _index = 0;
    _timer =
        Timer.periodic(Duration(milliseconds: 1000 ~/ (_bps / 8)), (timer) {
      if (_index < _codes.length) {
        minitel.emulate([_codes[_index++]]);
        if (minitel.isDirty) notifyListeners();
      } else {
        timer.cancel();
        _timer = null;
      }
    });
  }
}
