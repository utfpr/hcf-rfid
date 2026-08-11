import 'package:flutter/material.dart';

import 'start/load_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beontag UTFPR Agro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007A33)),
      ),
      home: const LoadScreen(), 
    );
  }
}
