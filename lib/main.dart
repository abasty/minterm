import 'package:flutter/material.dart';

import 'min_widget.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      ),
      home: Scaffold(
        body: Container(
          color: const Color.fromARGB(255, 44, 27, 3),
          child: Center(
            child: MinWidget(),
          ),
        ),
      ),
    );
  }
}
