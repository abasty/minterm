import 'dart:async';
import 'package:flutter/foundation.dart';

import 'min_emulator.dart';

class MinModel extends ChangeNotifier {
  static final MinModel _singleton = MinModel._internal();
  final minitel = TMinitel();
  var _codes = <int>[];
  int _index = 0;
  int _bps = 4800;
  Timer? _timer;

  factory MinModel() {
    return _singleton;
  }

  MinModel._internal();

  void emulate(List<int> codes, {int bps = 4800}) {
    if (_timer != null) _timer!.cancel();
    _bps = bps;
    _codes = codes;
    _index = 0;
    final us = (8.0e+6 / _bps.toDouble()).toInt();
    _timer = Timer.periodic(Duration(microseconds: us), (Timer timer) {
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
