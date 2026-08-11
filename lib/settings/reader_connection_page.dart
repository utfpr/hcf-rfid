import 'package:flutter/material.dart';

import '../components/page_title_header.dart';
import '../services/reader_service.dart';
import 'add_reader_page.dart';

class ReaderConnectionPage extends StatefulWidget {
  const ReaderConnectionPage({super.key});

  @override
  State<ReaderConnectionPage> createState() => _ReaderConnectionPageState();
}

class _ReaderConnectionPageState extends State<ReaderConnectionPage> {
  static const Color _screenBackground = Color(0xFFF0F2F5);

  final ReaderService _readerService = ReaderService();
  String? _selectedReaderId;

  @override
  void initState() {
    super.initState();
    _selectedReaderId = _readerService.selectedReaderId ??
        (_readerService.availableReaders.isNotEmpty
            ? _readerService.availableReaders.first.id
            : null);
  }

  void _onConnect() async {
    if (_selectedReaderId != null) {
      _readerService.selectReader(_selectedReaderId);
      await _readerService.connectSelectedReader();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _onAddNewReader() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddReaderPage()),
    );
    // Refresh the list after returning
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final readers = _readerService.availableReaders;

    return Scaffold(
      backgroundColor: _screenBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageTitleHeader(title: 'Reader connection'),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: readers.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final reader = readers[index];
                    final isSelected = _selectedReaderId == reader.id;

                    return _ReaderCard(
                      name: reader.displayName,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedReaderId = reader.id;
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _BottomActions(
                onAddNewReader: _onAddNewReader,
                onConnect: _onConnect,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderCard extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReaderCard({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  static const Color _primaryColor = Color(0xFF007A33);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? _primaryColor : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? _primaryColor : const Color(0xFFBDBDBD),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: _primaryColor,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final VoidCallback onAddNewReader;
  final VoidCallback onConnect;

  const _BottomActions({
    required this.onAddNewReader,
    required this.onConnect,
  });

  static const Color _primaryColor = Color(0xFF007A33);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: onAddNewReader,
          child: const Text(
            'Add a new reader',
            style: TextStyle(
              color: _primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: onConnect,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Connect',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
