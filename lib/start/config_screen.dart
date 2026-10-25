import 'package:flutter/material.dart';

import '../home_page.dart';
import '../services/reader_service.dart';
import '../services/c72_reader_plugin.dart';
import '../services/urovo_reader_plugin.dart';
import '../theme/app_colors.dart';
import 'bluetooth_connection_screen.dart';
import 'connection_success_screen.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final TextEditingController _nicknameController = TextEditingController();

  String? _selectedManufacturer;
  String? _selectedReader;
  List<String> _availableReaders = [];

  @override
  void initState() {
    super.initState();
    // Set default manufacturer
    if (ReaderCatalog.manufacturers.isNotEmpty) {
      _selectedManufacturer = ReaderCatalog.manufacturers.first;
      _availableReaders = ReaderCatalog.getModelsForManufacturer(_selectedManufacturer!);
      if (_availableReaders.isNotEmpty) {
        _selectedReader = _availableReaders.first;
      }
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _onManufacturerChanged(String? manufacturer) {
    if (manufacturer != null) {
      setState(() {
        _selectedManufacturer = manufacturer;
        _availableReaders = ReaderCatalog.getModelsForManufacturer(manufacturer);
        _selectedReader = _availableReaders.isNotEmpty ? _availableReaders.first : null;
      });
    }
  }

  void _onReaderChanged(String? reader) {
    if (reader != null) {
      setState(() {
        _selectedReader = reader;
      });
    }
  }

  Future<void> _onNext() async {
    if (_selectedManufacturer == null || _selectedReader == null) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // C72 (Chainway): no Bluetooth; init reader and go to success screen
    if (_selectedManufacturer == chainwayManufacturer && _selectedReader == c72Model) {
      final isC72 = await C72ReaderPlugin.isC72Device();
      if (isC72 && mounted) {
        try {
          await C72ReaderPlugin.initReader();
          if (mounted) {
            navigator.push(
              MaterialPageRoute<void>(
                builder: (_) => ConnectionSuccessScreen(
                  manufacturer: chainwayManufacturer,
                  model: c72Model,
                  nickname: _nicknameController.text.isNotEmpty ? _nicknameController.text : null,
                  selectedDeviceId: c72ReaderId,
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text('Falha ao inicializar leitor C72: $e')),
            );
          }
        }
      } else if (mounted) {
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => BluetoothConnectionScreen(
              manufacturer: _selectedManufacturer!,
              model: _selectedReader!,
              nickname: _nicknameController.text.isNotEmpty ? _nicknameController.text : null,
            ),
          ),
        );
      }
      return;
    }

    // Urovo: integrated reader, no Bluetooth; init reader and go to success screen
    if (_selectedManufacturer == urovoManufacturer) {
      final isUrovo = await UrovoReaderPlugin.isUrovoDevice();
      if (!mounted) return;
      if (!isUrovo) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Leitor Urovo não detectado neste dispositivo.')),
        );
        return;
      }
      try {
        await UrovoReaderPlugin.initReader();
        if (mounted) {
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => ConnectionSuccessScreen(
                manufacturer: urovoManufacturer,
                model: _selectedReader!,
                nickname: _nicknameController.text.isNotEmpty ? _nicknameController.text : null,
                selectedDeviceId: urovoReaderId,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Falha ao inicializar leitor Urovo: $e')),
          );
        }
      }
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => BluetoothConnectionScreen(
          manufacturer: _selectedManufacturer!,
          model: _selectedReader!,
          nickname: _nicknameController.text.isNotEmpty ? _nicknameController.text : null,
        ),
      ),
    );
  }

  void _onSkip() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const MyHomePage(title: 'Home'),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Step indicator - step 1 of 3
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // Title
              const Text(
                'Connect the reader to the software',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 32),
              // Manufacturer dropdown
              const Text(
                'Choose the manufacture',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textHeading,
                ),
              ),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _selectedManufacturer,
                items: ReaderCatalog.manufacturers,
                onChanged: _onManufacturerChanged,
              ),
              const SizedBox(height: 24),
              // Reader dropdown
              const Text(
                'Choose the reader',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textHeading,
                ),
              ),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _selectedReader,
                items: _availableReaders,
                onChanged: _onReaderChanged,
              ),
              const SizedBox(height: 24),
              // Nickname field
              const Text(
                'Nickname (optional)',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textHeading,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(
                    hintText: 'Store reader',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const Spacer(),
              // Bottom buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _onSkip,
                    child: Text(
                      'skip',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    height: 44,
                    child: FilledButton(
                      onPressed: _onNext,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: const Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textHeading,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
