import 'package:flutter/material.dart';

import '../services/btl_reader_plugin.dart';
import '../services/reader_service.dart';
import '../home_page.dart';
import '../theme/app_colors.dart';

class ConnectionSuccessScreen extends StatefulWidget {
  final String manufacturer;
  final String model;
  final String? nickname;
  final String selectedDeviceId;

  const ConnectionSuccessScreen({
    super.key,
    required this.manufacturer,
    required this.model,
    this.nickname,
    required this.selectedDeviceId,
  });

  @override
  State<ConnectionSuccessScreen> createState() => _ConnectionSuccessScreenState();
}

class _ConnectionSuccessScreenState extends State<ConnectionSuccessScreen> {
  final ReaderService _readerService = ReaderService();

  void _onBack() {
    Navigator.of(context).pop();
  }

  Future<void> _onNext() async {
    // Create and save the reader (use selectedDeviceId for C72 so id is stable)
    final reader = ReaderDevice(
      id: widget.selectedDeviceId,
      manufacturer: widget.manufacturer,
      model: widget.model,
      nickname: widget.nickname?.isNotEmpty == true ? widget.nickname : null,
    );

    // Avoid duplicate add when same reader already in list
    if (!_readerService.availableReaders.any((r) => r.id == reader.id)) {
      await _readerService.addReader(reader);
    }

    // For Acura BTL: check Bluetooth connection directly (the device is
    // already connected when we reach this screen). Skip the platform
    // connect call to avoid a disconnect/reconnect cycle.
    final isAcura = widget.manufacturer == acuraManufacturer;
    final alreadyConnected = isAcura && await BTLReaderPlugin.isConnected();

    if (alreadyConnected) {
      // Just persist the reader selection without touching Bluetooth
      _readerService.selectReader(reader.id);
      await _readerService.connectSelectedReader();
    } else {
      await _readerService.connectToReader(reader.id);
    }

    if (mounted) {
      // Navigate to Home Page
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const MyHomePage(title: 'Home'),
        ),
        (route) => false, // Remove all previous routes
      );
    }
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
              // Step indicator - step 3 of 3
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
                ],
              ),
              const Spacer(flex: 2),
              // Success icon
              Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check,
                      size: 60,
                      color: AppColors.textHeading,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Success text
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Your connection to the reader has been established',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 2),
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
}
