import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'start/load_screen.dart';
import 'start/login_screen.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() {
  AuthService().aoExpirarSessao = _irParaLogin;
  runApp(const MyApp());
}

void _irParaLogin() {
  _navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    (_) => false,
  );
  _scaffoldMessengerKey.currentState?.showSnackBar(
    const SnackBar(content: Text('Sessão expirada. Faça login novamente.')),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HCF UTFPR',
      theme: AppTheme.light,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      home: const LoadScreen(), 
    );
  }
}
