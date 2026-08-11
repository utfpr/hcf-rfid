import 'package:flutter/material.dart';

import 'config_screen.dart';
import '../home_page.dart';
import '../services/c72_reader_plugin.dart';
import '../services/reader_service.dart';
import '../theme/app_colors.dart';

class ConnectReaderScreen extends StatefulWidget {
  const ConnectReaderScreen({super.key});

  @override
  State<ConnectReaderScreen> createState() => _ConnectReaderScreenState();
}

class _ConnectReaderScreenState extends State<ConnectReaderScreen> {
  final ReaderService _readerService = ReaderService();
  bool _isLoading = true;
  String _loadingStatus = 'Initializing…';
  ReaderDevice? _lastReader;

  @override
  void initState() {
    super.initState();
    _checkForConfiguredReader();
  }

  Future<void> _checkForConfiguredReader() async {
    // Wait for service to load
    _setStatus('Loading settings…');
    while (!_readerService.isLoaded) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Auto-detect Chainway C72 device and connect directly
    if (await _tryAutoConnectC72()) return;

    // Check if there's a previously connected reader
    final connectedReader = _readerService.connectedReader;

    if (connectedReader == null && _readerService.availableReaders.isEmpty) {
      // No reader configured, go directly to config screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const ConfigScreen(),
          ),
        );
      }
      return;
    }

    // Try to connect to the last reader in the background
    final reader = connectedReader ??
        (_readerService.availableReaders.isNotEmpty
            ? _readerService.availableReaders.first
            : null);

    if (reader != null) {
      _setStatus('Connecting to ${reader.displayName}…');
      try {
        await _readerService.connectToReader(reader.id);
        final connected = await _readerService.isDeviceConnected();
        if (connected && mounted) {
          // Already connected — show the "continue" screen
          setState(() {
            _lastReader = reader;
            _isLoading = false;
          });
          return;
        }
      } catch (_) {
        // Connection failed
      }
    }

    // Connection failed or no reader — go to config
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const ConfigScreen(),
        ),
      );
    }
  }

  /// Attempts to detect and connect to a Chainway C72 built-in RFID reader.
  /// Returns true if successful and navigation occurred.
  Future<bool> _tryAutoConnectC72() async {
    try {
      _setStatus('Detecting reader…');
      final isC72 = await C72ReaderPlugin.isC72Device();
      if (!isC72 || !mounted) return false;

      _setStatus('Initializing C72 reader…');
      // Register the C72 as available if not already
      final reader = ReaderDevice(
        id: c72ReaderId,
        manufacturer: chainwayManufacturer,
        model: c72Model,
      );
      if (!_readerService.availableReaders.any((r) => r.id == reader.id)) {
        await _readerService.addReader(reader);
      }

      // connectToReader calls C72ReaderPlugin.initReader() internally
      _setStatus('Connecting to C72…');
      await _readerService.connectToReader(reader.id);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const MyHomePage(title: 'Beontag UTFPR Agro'),
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('C72 auto-connect failed: $e');
      _setStatus('Reader not found, continuing…');
      return false;
    }
  }

  void _setStatus(String status) {
    if (mounted) {
      setState(() => _loadingStatus = status);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _loadingStatus,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final nickname = _lastReader?.displayName ?? 'Unknown';
    final readerModel = _lastReader?.model ?? 'Unknown';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // Circle with barcode icon
              Container(
                width: 160,
                height: 160,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Image.asset(
                    'assets/barcode-scan.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.qr_code_scanner,
                      size: 80,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Nickname: $nickname',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Reader: $readerModel',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const Spacer(),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => const MyHomePage(title: 'Beontag UTFPR Agro'),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Continue with the last reader'),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ConfigScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'connect a new reader',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
