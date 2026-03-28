import 'package:flutter/material.dart';

import 'min_model.dart';
import 'serial_support.dart';

class ConnectionSerial extends StatelessWidget {
  const ConnectionSerial({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Serial ports'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MinSerial()),
        );
      },
    );
  }
}

class MinSerial extends StatefulWidget {
  const MinSerial({super.key});

  @override
  State<MinSerial> createState() => MinSerialState();
}

extension _IntFormat on int {
  String toHex() => '0x${toRadixString(16)}';
  String toPadded([int width = 3]) => toString().padLeft(width, '0');
}

class MinSerialState extends State<MinSerial> {
  var availablePorts = const <SerialPortInfo>[];

  @override
  void initState() {
    super.initState();
    initPorts();
  }

  void initPorts() {
    setState(() => availablePorts = listSerialPorts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Serial ports')),
      body: Scrollbar(
        child: ListView(
          children: [
            for (final port in availablePorts)
              Builder(
                builder: (context) {
                  return ListTile(
                    title: Text(port.address),
                    subtitle: Text(
                      'Description: ${port.description ?? "N/A"}'
                      '\nTransport: ${port.transport}'
                      '\nUSB Bus: ${port.busNumber?.toPadded() ?? "N/A"}'
                      '\nUSB Device: ${port.deviceNumber?.toPadded() ?? "N/A"}'
                      '\nVendor ID: ${port.vendorId?.toHex() ?? "N/A"}'
                      '\nProduct ID: ${port.productId?.toHex() ?? "N/A"}'
                      '\nManufacturer: ${port.manufacturer ?? "N/A"}'
                      '\nProduct Name: ${port.productName ?? "N/A"}'
                      '\nSerial Number: ${port.serialNumber ?? "N/A"}'
                      '\nMAC Address: ${port.macAddress ?? "N/A"}',
                    ),
                    onTap: () {
                      final navigator = Navigator.of(context);
                      MinModel().serverAddress = 'serial://${port.address}';
                      MinModel().connect();
                      navigator.pop();
                      if (navigator.canPop()) {
                        navigator.pop();
                      }
                    },
                  );
                },
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: initPorts,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
