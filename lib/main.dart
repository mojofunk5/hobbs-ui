import 'package:flutter/material.dart';

import 'screens/startup_screen.dart';

void main() {
  runApp(const HobbsApp());
}

class HobbsApp extends StatelessWidget {
  const HobbsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hobbs',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const StartupScreen(),
    );
  }
}
