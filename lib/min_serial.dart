import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

import 'min_model.dart';

class MinSerial extends StatefulWidget {
  const MinSerial({super.key});

  @override
  MinSerialState createState() => MinSerialState();
}

extension IntToString on int {
  String toHex() => '0x${toRadixString(16)}';
  String toPadded([int width = 3]) => toString().padLeft(width, '0');
  String toTransport() {
    switch (this) {
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
}

class MinSerialState extends State<MinSerial> {
  var availablePorts = [];

  @override
  void initState() {
    super.initState();
    initPorts();
  }

  void initPorts() {
    setState(() => availablePorts = SerialPort.availablePorts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des ports série'),
      ),
      body: Scrollbar(
        child: ListView(
          children: [
            for (final address in availablePorts)
              Builder(builder: (context) {
                final port = SerialPort(address);
                Widget portStatus = ListTile(
                  title: Text(address),
                  subtitle: Text('Description: ${port.description ?? "N/A"}'
                      '\nTransport: ${port.transport.toTransport()}'
                      '\nUSB Bus: ${port.busNumber?.toPadded()}'
                      '\nUSB Device: ${port.deviceNumber?.toPadded()}'
                      '\nVendor ID: ${port.vendorId?.toHex()}'
                      '\nProduct ID: ${port.productId?.toHex()}'
                      '\nManufacturer: ${port.manufacturer ?? "N/A"}'
                      '\nProduct Name: ${port.productName ?? "N/A"}'
                      '\nSerial Number: ${port.serialNumber ?? "N/A"}'
                      '\nMAC Address: ${port.macAddress ?? "N/A"}'),
                  onTap: () {
                    MinModel().connectSerial(address);
                    Navigator.pop(context);
                  },
                );
                port.dispose();
                return portStatus;
              }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: initPorts,
        child: Icon(Icons.refresh),
      ),
    );
  }
}

class CardListTile extends StatelessWidget {
  final String name;
  final String? value;

  const CardListTile(this.name, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(value ?? 'N/A'),
        subtitle: Text(name),
      ),
    );
  }
}
