import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

import 'serial_support_api.dart';

bool get isSerialSupported => Platform.isLinux;

List<SerialPortInfo> listSerialPorts() {
  if (!isSerialSupported) return const <SerialPortInfo>[];

  return SerialPort.availablePorts.map((address) {
    final port = SerialPort(address);
    try {
      return SerialPortInfo(
        address: address,
        transport: _transportLabel(port.transport),
        description: port.description,
        busNumber: port.busNumber,
        deviceNumber: port.deviceNumber,
        vendorId: port.vendorId,
        productId: port.productId,
        manufacturer: port.manufacturer,
        productName: port.productName,
        serialNumber: port.serialNumber,
        macAddress: port.macAddress,
      );
    } finally {
      port.dispose();
    }
  }).toList(growable: false);
}

SerialConnection? openSerialConnection(String portName) {
  if (!isSerialSupported) return null;

  final port = SerialPort(portName);
  if (!port.openReadWrite()) {
    port.dispose();
    return null;
  }

  return _FlutterSerialConnection(port);
}

class _FlutterSerialConnection implements SerialConnection {
  _FlutterSerialConnection(this._port) : _reader = SerialPortReader(_port);

  final SerialPort _port;
  final SerialPortReader _reader;
  bool _closed = false;

  @override
  Stream<Uint8List> get stream => _reader.stream;

  @override
  bool get isOpen => !_closed && _port.isOpen;

  @override
  void configure(int speed) {
    if (!isOpen) return;

    _port.config = SerialPortConfig()
      ..baudRate = speed
      ..bits = 7
      ..parity = SerialPortParity.even
      ..stopBits = 1
      ..setFlowControl(SerialPortFlowControl.none);
  }

  @override
  void write(Uint8List bytes) {
    if (!isOpen) return;
    _port.write(bytes);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _reader.close();
    if (_port.isOpen) {
      _port.close();
    }
    _port.dispose();
  }
}

String _transportLabel(int transport) {
  switch (transport) {
    case SerialPortTransport.usb:
      return 'USB';
    case SerialPortTransport.bluetooth:
      return 'Bluetooth';
    case SerialPortTransport.native:
      return 'Native';
    default:
      return 'Unknown';
  }
}
