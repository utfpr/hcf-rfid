import 'package:flutter/material.dart';

import '../components/page_title_header.dart';
import '../services/reader_service.dart';
import '../theme/app_colors.dart';

class AddReaderPage extends StatefulWidget {
  const AddReaderPage({super.key});

  @override
  State<AddReaderPage> createState() => _AddReaderPageState();
}

class _AddReaderPageState extends State<AddReaderPage> {
  final TextEditingController _nicknameController = TextEditingController();
  final ReaderService _readerService = ReaderService();

  String? _selectedManufacturer;
  String? _selectedModel;
  List<String> _availableModels = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Set default manufacturer
    final manufacturers = ReaderCatalog.manufacturers;
    if (manufacturers.isNotEmpty) {
      _selectedManufacturer = manufacturers.first;
      _availableModels =
          ReaderCatalog.getModelsForManufacturer(_selectedManufacturer!);
      if (_availableModels.isNotEmpty) {
        _selectedModel = _availableModels.first;
      }
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _onManufacturerChanged(String? value) {
    setState(() {
      _selectedManufacturer = value;
      _availableModels =
          value != null ? ReaderCatalog.getModelsForManufacturer(value) : [];
      _selectedModel =
          _availableModels.isNotEmpty ? _availableModels.first : null;
    });
  }

  void _onSave() async {
    if (_selectedManufacturer != null && _selectedModel != null) {
      setState(() => _isSaving = true);
      final newReader = ReaderDevice(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        manufacturer: _selectedManufacturer!,
        model: _selectedModel!,
        nickname: _nicknameController.text.trim().isNotEmpty
            ? _nicknameController.text.trim()
            : null,
      );
      await _readerService.addReader(newReader);
      try {
        await _readerService.connectToReader(newReader.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved but connection failed: $e')),
          );
        }
      }
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageTitleHeader(title: 'Setting reader'),
              const SizedBox(height: 32),

              // Choose the manufacture
              const Text(
                'Choose the manufacture',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _selectedManufacturer,
                items: ReaderCatalog.manufacturers,
                onChanged: _onManufacturerChanged,
              ),

              const SizedBox(height: 24),

              // Choose the reader
              const Text(
                'Choose the reader',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _selectedModel,
                items: _availableModels,
                onChanged: (value) {
                  setState(() {
                    _selectedModel = value;
                  });
                },
              ),

              const SizedBox(height: 24),

              // Nickname (optional)
              const Text(
                'Nickname (optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nicknameController,
                decoration: InputDecoration(
                  hintText: 'Store reader',
                  hintStyle: const TextStyle(
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.border,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.border,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),

              const Spacer(),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.textSecondary,
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
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
