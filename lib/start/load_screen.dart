import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'connect_reader_screen.dart';
import 'login_screen.dart';

class LoadScreen extends StatefulWidget {
  const LoadScreen({super.key});

  @override
  State<LoadScreen> createState() => _LoadScreenState();
}

class _LoadScreenState extends State<LoadScreen> {
  static const _loadDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    Future.delayed(_loadDuration, _navigate);
  }

  Future<void> _navigate() async {
    await AuthService().loadFromStorage();
    if (!mounted) return;
    final destination = AuthService().isLoggedIn
        ? const ConnectReaderScreen()
        : const LoginScreen();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryDark, // 0%
              AppColors.primary, // 89%
              AppColors.primaryLight, // 97%
            ],
            stops: [0.0, 0.89, 0.97],
          ),
        ),
        child: Center(
          child: Image.asset(
            'assets/hcf-logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported, color: Colors.white, size: 64),
          ),
        ),
      ),
    );
  }
}
