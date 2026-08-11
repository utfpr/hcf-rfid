import 'package:flutter/material.dart';

import '../services/scan_session_service.dart';
import '../theme/app_colors.dart';
import 'session_details_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final ScanSessionService _sessionService = ScanSessionService();
  List<HistoryItem> _historyItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    // Listen to changes in the session service
    _sessionService.addListener(_loadSessions);
  }

  @override
  void dispose() {
    _sessionService.removeListener(_loadSessions);
    super.dispose();
  }

  Future<void> _loadSessions() async {
    // Wait for service to load if needed
    while (!_sessionService.isLoaded) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    setState(() {
      _historyItems = _sessionService.sortedSessions.map((session) {
        return HistoryItem(
          sessionId: session.sessionId,
          dateTime: session.startTime,
          tagCount: session.tagCount,
          isSynced: session.isSynced,
        );
      }).toList();
      _isLoading = false;
    });
  }

  final Set<int> _expandedIndices = {0};

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
              // Header - matching PageTitleHeader style
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Icon(
                    Icons.chevron_left,
                    color: AppColors.textHeading,
                    size: 28,
                  ),
                ),
              ),
              Row(
                children: [
                  const Text(
                    'History',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHeading,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _historyItems.length.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: 48,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.textHeading,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // History list - Accordion style
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _historyItems.isEmpty
                        ? const Center(
                            child: Text(
                              'No scan sessions yet',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: List.generate(_historyItems.length, (index) {
                                final item = _historyItems[index];
                                final isExpanded = _expandedIndices.contains(index);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _HistoryAccordionItem(
                                    item: item,
                                    isExpanded: isExpanded,
                                    onToggle: () {
                                      setState(() {
                                        if (isExpanded) {
                                          _expandedIndices.remove(index);
                                        } else {
                                          _expandedIndices.add(index);
                                        }
                                      });
                                    },
                                    onViewDetails: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => SessionDetailsPage(
                                            sessionId: item.sessionId,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryAccordionItem extends StatelessWidget {
  final HistoryItem item;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onViewDetails;

  const _HistoryAccordionItem({
    required this.item,
    required this.isExpanded,
    required this.onToggle,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.secondary, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: onToggle,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(6),
                  topRight: const Radius.circular(6),
                  bottomLeft: isExpanded ? Radius.zero : const Radius.circular(6),
                  bottomRight: isExpanded ? Radius.zero : const Radius.circular(6),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.dateTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: onViewDetails,
                    child: const Icon(
                      Icons.visibility_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expanded content with animation
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      children: [
                        const TextSpan(
                          text: 'Time stamp: ',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: item.dateTime),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      children: [
                        const TextSpan(
                          text: 'Tags scanned: ',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: item.tagCount.toString()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      children: [
                        const TextSpan(
                          text: 'Status: ',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: item.isSynced ? 'Synced' : 'Pending sync',
                          style: TextStyle(
                            color: item.isSynced ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class HistoryItem {
  final String sessionId;
  final String dateTime;
  final int tagCount;
  final bool isSynced;

  HistoryItem({
    required this.sessionId,
    required this.dateTime,
    required this.tagCount,
    required this.isSynced,
  });
}
