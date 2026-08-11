import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'about/about_page.dart';
import 'components/page_title_header.dart';
import 'history/history_page.dart';
import 'scan/scan_page.dart';
import 'search/search_page.dart';
import 'services/auth_service.dart';
import 'services/reader_service.dart';
import 'settings/settings_page.dart';
import 'tags/add_tag_page.dart';
import 'theme/app_colors.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ReaderService _readerService = ReaderService();

  bool _isNetworkConnected = false;
  Timer? _connectivityTimer;

  @override
  void initState() {
    super.initState();
    _readerService.addListener(_onReaderServiceUpdate);
    _checkConnectivity();
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkConnectivity(),
    );
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _readerService.removeListener(_onReaderServiceUpdate);
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('beontag.cm.utfpr.edu.br');
      if (mounted) {
        setState(() => _isNetworkConnected =
            result.isNotEmpty && result[0].rawAddress.isNotEmpty);
      }
    } on SocketException catch (_) {
      if (mounted) setState(() => _isNetworkConnected = false);
    }
  }

  void _onReaderServiceUpdate() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: PageTitleHeader(
                      title: 'Home',
                      showBackButton: false,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/hcf-logo.png',
                      height: 40,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.eco,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Connection status card
              _buildConnectionCard(),
              const SizedBox(height: 32),
              // 3x2 grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _HomeMenuButton(
                      icon: Icons.document_scanner,
                      label: 'Scan',
                      onTap: () => _pushPage(context, const ScanPage()),
                    ),
                    _HomeMenuButton(
                      icon: Icons.history,
                      label: 'History',
                      onTap: () => _pushPage(context, const HistoryPage()),
                    ),
                    _HomeMenuButton(
                      icon: Icons.settings,
                      label: 'Settings',
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute<void>(
                            builder: (_) => const SettingsPage(),
                          ))
                          .then((_) => setState(() {})),
                    ),
                    _HomeMenuButton(
                      icon: Icons.document_scanner_outlined,
                      label: 'Search',
                      onTap: () => _pushPage(context, const SearchPage()),
                    ),
                    _HomeMenuButton(
                      icon: Icons.nfc,
                      label: 'Add Tag',
                      onTap: () => _pushPage(context, const AddTagPage()),
                    ),
                    _HomeMenuButton(
                      icon: Icons.info_outline,
                      label: 'About',
                      onTap: () => _pushPage(context, const AboutPage()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pushPage(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  Widget _buildConnectionCard() {
    final connectedReader = _readerService.isPhysicallyConnected
        ? _readerService.connectedReader
        : null;
    final user = AuthService().currentUser;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isNetworkConnected ? Icons.wifi : Icons.wifi_off,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                _isNetworkConnected ? 'Connected' : 'Not connected',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _cardInfoRow(
            icon: Icons.person_outline,
            label: 'User',
            value: user?.email ?? 'Visitante',
          ),
          const SizedBox(height: 4),
          _cardInfoRow(
            icon: Icons.nfc,
            label: 'Reader',
            value: connectedReader?.model ?? 'Não conectado',
          ),
        ],
      ),
    );
  }

  Widget _cardInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _HomeMenuButton extends StatelessWidget {
  const _HomeMenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: AppColors.textHeading),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHeading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
