import 'serial_support_api.dart';
import 'serial_support_stub.dart' if (dart.library.io) 'serial_support_io.dart'
    as impl;

export 'serial_support_api.dart';

bool get isSerialSupported => impl.isSerialSupported;

List<SerialPortInfo> listSerialPorts() => impl.listSerialPorts();

SerialConnection? openSerialConnection(String portName) {
  return impl.openSerialConnection(portName);
}
