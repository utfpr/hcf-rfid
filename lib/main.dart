import 'package:flutter/material.dart';

import 'start/load_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HCF UTFPR',
      theme: AppTheme.light,
      home: const LoadScreen(), 
    );
  }
}
