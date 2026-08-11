import 'package:flutter/material.dart';

import '../components/page_title_header.dart';
import '../services/conference_service.dart';
import '../theme/app_colors.dart';
import 'conference_scan_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final ConferenceService _conferenceService = ConferenceService();

  int? _selectedConferenceId;
  List<Conference> _conferences = [];
  bool _loadingConferences = false;
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _loadConferences();
  }

  Future<void> _loadConferences() async {
    setState(() => _loadingConferences = true);
    try {
      final conferences = await _conferenceService.getAll();
      if (mounted) {
        setState(() {
          _conferences = conferences;
          _loadingConferences = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingConferences = false);
    }
  }

  Future<void> _onStart() async {
    if (_selectedConferenceId == null) return;
    setState(() => _loadingDetail = true);
    try {
      final detail =
          await _conferenceService.getById(_selectedConferenceId!);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ConferenceScanPage(
              conferenceId: detail.id,
              conferenceName: detail.name,
              conferenceEpcs: detail.epcs,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load conference: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
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
              const PageTitleHeader(title: 'Scan'),
              const SizedBox(height: 24),
              _buildConferenceCard(),
              const Spacer(),
              _buildStartButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConferenceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Select conference',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.refresh,
                      color: Colors.white70, size: 20),
                  onPressed: _loadingConferences ? null : _loadConferences,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose a conference list to start scanning',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppColors.border, width: 1),
            ),
            child: _loadingConferences
                ? const Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('Loading conferences…',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedConferenceId,
                      isExpanded: true,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: AppColors.textSecondary),
                      dropdownColor: Colors.white,
                      hint: const Text(
                        'Select a conference',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textMuted),
                      ),
                      items: _conferences
                          .map((c) => DropdownMenuItem<int>(
                                value: c.id,
                                child: Text(
                                  c.displayName,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textPrimary),
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(
                            () => _selectedConferenceId = value);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    final enabled =
        _selectedConferenceId != null && !_loadingDetail;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: enabled ? _onStart : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[400],
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28)),
          elevation: 0,
        ),
        child: _loadingDetail
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow, size: 24),
                  SizedBox(width: 8),
                  Text('Start',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}
