import 'package:flutter/material.dart';

import '../components/page_title_header.dart';
import '../services/auth_service.dart';
import 'profile_page.dart';
import 'reader_connection_page.dart';
import 'reader_configuration_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const Color _screenBackground = Color(0xFFF0F2F5);

  String get _profileSubtitle {
    final user = AuthService().currentUser;
    return user != null ? user.email : 'Visitante';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageTitleHeader(title: 'Settings'),
              const SizedBox(height: 24),
              _SettingsMenuItem(
                icon: Icons.person_outline,
                title: 'Profile',
                subtitle: _profileSubtitle,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfilePage(),
                    ),
                  ).then((_) => setState(() {}));
                },
              ),
              const SizedBox(height: 12),
              _SettingsMenuItem(
                icon: Icons.wifi_tethering,
                title: 'Reader connection',
                subtitle: 'Connect your reader',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReaderConnectionPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _SettingsMenuItem(
                icon: Icons.settings,
                title: 'Reader configuration',
                subtitle: 'settings the connection',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReaderConfigurationPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF007A33),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF757575),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
