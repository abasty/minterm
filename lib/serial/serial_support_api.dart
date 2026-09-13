import 'dart:typed_data';

class SerialPortInfo {
  const SerialPortInfo({
    required this.address,
    required this.transport,
    this.description,
    this.busNumber,
    this.deviceNumber,
    this.vendorId,
    this.productId,
    this.manufacturer,
    this.productName,
    this.serialNumber,
    this.macAddress,
  });

  final String address;
  final String transport;
  final String? description;
  final int? busNumber;
  final int? deviceNumber;
  final int? vendorId;
  final int? productId;
  final String? manufacturer;
  final String? productName;
  final String? serialNumber;
  final String? macAddress;
}

abstract class SerialConnection {
  Stream<Uint8List> get stream;
  bool get isOpen;
  void configure(int speed);
  void write(Uint8List bytes);
  void close();
}
