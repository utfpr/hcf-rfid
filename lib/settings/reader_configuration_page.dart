import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/page_title_header.dart';
import '../services/reader_service.dart';

class ReaderConfigurationPage extends StatefulWidget {
  const ReaderConfigurationPage({super.key});

  @override
  State<ReaderConfigurationPage> createState() =>
      _ReaderConfigurationPageState();
}

class _ReaderConfigurationPageState extends State<ReaderConfigurationPage> {
  static const Color _screenBackground = Color(0xFFF0F2F5);
  static const Color _sectionTitleColor = Color(0xFF1A1A1A);

  final ReaderService _readerService = ReaderService();
  late TextEditingController _readPowerController;
  late TextEditingController _writePowerController;

  double _readPower = 0;
  double _writePower = 0;
  bool _isC72 = false;
  bool _isBTL = false;

  @override
  void initState() {
    super.initState();
    _isC72 = _readerService.isC72Reader(_readerService.connectedReader);
    _isBTL = _readerService.isAcuraBTLReader(_readerService.connectedReader);
    _readPower = _readerService.configuration.readPower;
    _writePower = _readerService.configuration.writePower;
    _readPowerController =
        TextEditingController(text: _readPower.round().toString());
    _writePowerController =
        TextEditingController(text: _writePower.round().toString());
    if (_isC72 || _isBTL) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDevicePower());
    }
  }

  Future<void> _loadDevicePower() async {
    await _readerService.refreshPowerFromDevice();
    if (mounted) {
      setState(() {
        _readPower = _readerService.configuration.readPower;
        _writePower = _readerService.configuration.writePower;
        _readPowerController.text = _readPower.round().toString();
        _writePowerController.text = _writePower.round().toString();
      });
    }
  }

  @override
  void dispose() {
    _readPowerController.dispose();
    _writePowerController.dispose();
    super.dispose();
  }

  double get _minPower {
    if (_isC72) return ReaderConfiguration.minPowerC72;
    if (_isBTL) return ReaderConfiguration.minPowerBTL;
    return ReaderConfiguration.minPower;
  }

  double get _maxPower {
    if (_isC72) return ReaderConfiguration.maxPowerC72;
    if (_isBTL) return ReaderConfiguration.maxPowerBTL;
    return ReaderConfiguration.maxPower;
  }

  void _onReadPowerSliderChanged(double value) {
    setState(() {
      _readPower = value;
      _readPowerController.text = value.round().toString();
    });
    _readerService.updateReadPower(value);
  }

  // void _onWritePowerSliderChanged(double value) {
  //   setState(() {
  //     _writePower = value;
  //     _writePowerController.text = value.round().toString();
  //   });
  //   _readerService.updateWritePower(value);
  // }

  void _onReadPowerTextChanged(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null) {
      final clamped = parsed.clamp(_minPower, _maxPower);
      setState(() {
        _readPower = clamped;
      });
      _readerService.updateReadPower(clamped);
    }
  }

  // void _onWritePowerTextChanged(String value) {
  //   final parsed = double.tryParse(value);
  //   if (parsed != null) {
  //     final clamped = parsed.clamp(
  //       ReaderConfiguration.minPower,
  //       ReaderConfiguration.maxPower,
  //     );
  //     setState(() {
  //       _writePower = clamped;
  //     });
  //     _readerService.updateWritePower(clamped);
  //   }
  // }

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
              const PageTitleHeader(title: 'Reader configuration'),
              const SizedBox(height: 32),

              // Section title
              const Text(
                'Config the reader',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _sectionTitleColor,
                ),
              ),
              const SizedBox(height: 24),

              // Read power
              _PowerControl(
                label: 'Read power',
                value: _readPower,
                min: _minPower,
                max: _maxPower,
                controller: _readPowerController,
                onSliderChanged: _onReadPowerSliderChanged,
                onTextChanged: _onReadPowerTextChanged,
              ),

              // const SizedBox(height: 24),
              // Write power
              // _PowerControl(
              //   label: 'Write power',
              //   value: _writePower,
              //   controller: _writePowerController,
              //   onSliderChanged: _onWritePowerSliderChanged,
              //   onTextChanged: _onWritePowerTextChanged,
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PowerControl extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final TextEditingController controller;
  final ValueChanged<double> onSliderChanged;
  final ValueChanged<String> onTextChanged;

  const _PowerControl({
    required this.label,
    required this.value,
    this.min = -100,
    this.max = 100,
    required this.controller,
    required this.onSliderChanged,
    required this.onTextChanged,
  });

  static const Color _primaryColor = Color(0xFF007A33);
  static const Color _inactiveColor = Color(0xFFBDBDBD);
  static const Color _labelColor = Color(0xFF424242);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _labelColor,
          ),
        ),
        const SizedBox(height: 12),

        // Custom slider
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _primaryColor,
            inactiveTrackColor: _inactiveColor,
            thumbColor: _primaryColor,
            overlayColor: _primaryColor.withOpacity(0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 8,
              elevation: 2,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onSliderChanged,
          ),
        ),
        const SizedBox(height: 8),

        // Value input with unit
        Row(
          children: [
            SizedBox(
              width: 72,
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: false,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1A1A1A),
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: _primaryColor,
                      width: 1.5,
                    ),
                  ),
                ),
                onSubmitted: onTextChanged,
                onChanged: (value) {
                  // Only trigger update on valid input
                  if (value.isNotEmpty &&
                      value != '-' &&
                      double.tryParse(value) != null) {
                    onTextChanged(value);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'dBm',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF757575),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
