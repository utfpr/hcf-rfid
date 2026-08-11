import 'package:flutter/material.dart';

import '../services/btl_reader_plugin.dart';
import '../services/reader_service.dart';
import '../theme/app_colors.dart';
import 'connection_success_screen.dart';

/// Mock Bluetooth device for display
class MockBluetoothDevice {
  final String id;
  final String name;

  const MockBluetoothDevice({required this.id, required this.name});
}

class BluetoothConnectionScreen extends StatefulWidget {
  final String manufacturer;
  final String model;
  final String? nickname;

  const BluetoothConnectionScreen({
    super.key,
    required this.manufacturer,
    required this.model,
    this.nickname,
  });

  @override
  State<BluetoothConnectionScreen> createState() => _BluetoothConnectionScreenState();
}

class _BluetoothConnectionScreenState extends State<BluetoothConnectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isSearching = true;
  List<MockBluetoothDevice> _foundDevices = [];
  String? _selectedDeviceId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start fake search
    _startSearch();
  }

  Future<void> _startSearch() async {
    try {
      final hasDevice = await BTLReaderPlugin.hasBTLDevice();
      if (mounted) {
        setState(() {
          _isSearching = false;
          _pulseController.stop();
          if (hasDevice) {
            _foundDevices = [
              MockBluetoothDevice(id: btlReaderId, name: widget.model),
            ];
            _selectedDeviceId = _foundDevices.first.id;
          } else {
            _foundDevices = [];
            _selectedDeviceId = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _pulseController.stop();
          _foundDevices = [];
          _selectedDeviceId = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onConnect() async {
    if (_selectedDeviceId == null) return;

    final selectedDevice = _foundDevices.firstWhere((d) => d.id == _selectedDeviceId);

    try {
      await BTLReaderPlugin.connectReader();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao conectar: $e')),
        );
      }
      return;
    }

    if (!mounted) return;

    // Navigate to success screen with selected device info
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConnectionSuccessScreen(
          manufacturer: widget.manufacturer,
          model: selectedDevice.name,
          nickname: widget.nickname,
          selectedDeviceId: _selectedDeviceId!,
        ),
      ),
    );
  }

  void _onBack() {
    Navigator.of(context).pop();
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
              // Step indicator - step 2 of 3
              Row(
                children: [
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
                ],
              ),
              const SizedBox(height: 40),
              // Title
              const Center(
                child: Text(
                  'Connect bluetooth to device',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Content based on state
              Expanded(
                child: _isSearching ? _buildSearchingState() : _buildDeviceListState(),
              ),
              // Bottom buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _onBack,
                    child: Text(
                      'Back',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    height: 44,
                    child: FilledButton(
                      onPressed: _isSearching || _selectedDeviceId == null ? null : _onConnect,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: const Text(
                        'Connect',
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

  Widget _buildSearchingState() {
    return Column(
      children: [
        const Spacer(),
        // Bluetooth animation
        Center(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring
                  Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Middle ring
                  Transform.scale(
                    scale: _pulseAnimation.value * 0.95,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Inner ring
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primaryMedium,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.bluetooth,
                        size: 40,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const Spacer(),
        // Description text
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Searching for devices, connecting the device\'s bluetooth',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textHeading,
                height: 1.5,
              ),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildDeviceListState() {
    if (_foundDevices.isEmpty) {
      return Column(
        children: [
          const Spacer(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'No devices found',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textHeading,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Make sure the device is paired\nand Bluetooth is enabled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _isSearching = true);
                    _pulseController.repeat(reverse: true);
                    _startSearch();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Search again'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subtitle
        const Center(
          child: Text(
            'Select a device',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textHeading,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Device list
        Expanded(
          child: ListView.separated(
            itemCount: _foundDevices.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final device = _foundDevices[index];
              final isSelected = device.id == _selectedDeviceId;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDeviceId = device.id;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // Device icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/barcode-scan.png',
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                            color: AppColors.primary,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.qr_code_scanner,
                              size: 24,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Device name
                      Expanded(
                        child: Text(
                          device.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                      // Radio button
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
