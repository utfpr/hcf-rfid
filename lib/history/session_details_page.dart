import 'package:flutter/material.dart';

import '../search/search_page.dart';
import '../services/conference_service.dart';
import '../services/rfid_tag_service.dart';
import '../services/scan_session_service.dart';

class SessionDetailsPage extends StatefulWidget {
  final String sessionId;

  const SessionDetailsPage({
    super.key,
    required this.sessionId,
  });

  @override
  State<SessionDetailsPage> createState() => _SessionDetailsPageState();
}

class _SessionDetailsPageState extends State<SessionDetailsPage> {
  static const Color _screenBackground = Color(0xFFF0F2F5);
  static const Color _titleColor = Color(0xFF424242);
  static const Color _primaryBlue = Color(0xFF0066CC);
  static const Color _activeGreen = Color(0xFF4CAF50);

  final ScanSessionService _sessionService = ScanSessionService();

  // Filter state
  String _selectedFilterType = 'TID';
  final TextEditingController _filterNameController = TextEditingController();
  List<TagItem> _allTagItems = [];
  List<TagItem> _filteredTagItems = [];
  ScanSession? _session;
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    // Wait for service to load if needed
    while (!_sessionService.isLoaded) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    final session = _sessionService.getSession(widget.sessionId);
    if (session != null) {
      final readTids = session.tags.map((t) => t.tid).toSet();

      // Build list from ALL conference EPCs, marking which were read
      final List<TagItem> items = [];
      if (session.conferenceEpcs.isNotEmpty) {
        for (int i = 0; i < session.conferenceEpcs.length; i++) {
          final tid = session.conferenceEpcs[i];
          final scannedTag = session.tags.cast<ScannedTag?>().firstWhere(
            (t) => t?.tid == tid,
            orElse: () => null,
          );
          items.add(TagItem(
            id: (i + 1).toString().padLeft(2, '0'),
            tid: tid,
            epc: scannedTag?.epc ?? '',
            timeStamp: scannedTag?.timeStamp ?? '-',
            chipModel: scannedTag?.chipModel ?? '-',
            readCount: scannedTag?.readCount ?? 0,
            rssi: scannedTag?.rssi ?? 0,
            isRead: readTids.contains(tid),
          ));
        }
      } else {
        // Fallback: no conference EPCs stored, show only scanned tags
        for (final tag in session.tags) {
          items.add(TagItem(
            id: tag.id,
            tid: tag.tid,
            epc: tag.epc,
            timeStamp: tag.timeStamp,
            chipModel: tag.chipModel,
            readCount: tag.readCount,
            rssi: tag.rssi,
            isRead: true,
          ));
        }
      }

      // Enrich EPC from backend (canonical value stored in DB)
      final rfidService = RfidTagService();
      final uniqueTids = items.map((i) => i.tid).where((t) => t.isNotEmpty).toSet();
      final Map<String, String> tidToEpc = {};
      await Future.wait(uniqueTids.map((tid) async {
        try {
          final tag = await rfidService.getByTagId(tid);
          final epc = tag?['epc'];
          if (epc != null && (epc as String).isNotEmpty) tidToEpc[tid] = epc;
        } catch (_) {}
      }));

      final enrichedItems = items.map((item) {
        final backendEpc = tidToEpc[item.tid];
        if (backendEpc == null) return item;
        return TagItem(
          id: item.id,
          tid: item.tid,
          epc: backendEpc,
          timeStamp: item.timeStamp,
          chipModel: item.chipModel,
          readCount: item.readCount,
          rssi: item.rssi,
          isRead: item.isRead,
        );
      }).toList();

      setState(() {
        _session = session;
        _allTagItems = enrichedItems;
        _filteredTagItems = List.from(enrichedItems);
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _filterNameController.dispose();
    super.dispose();
  }

  final Set<int> _expandedIndices = {0};

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _screenBackground,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_session == null) {
      return Scaffold(
        backgroundColor: _screenBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Icon(
                      Icons.chevron_left,
                      color: _titleColor,
                      size: 28,
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    'Session not found',
                    style: TextStyle(fontSize: 18, color: _titleColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _screenBackground,
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
                    color: _titleColor,
                    size: 28,
                  ),
                ),
              ),
              Row(
                children: [
                  const Text(
                    'Session',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _titleColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _session!.isSynced ? _activeGreen : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _filteredTagItems.length.toString().padLeft(2, '0'),
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
                  color: _titleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // Tags list container with filter inside
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // Divider
                      Container(
                        height: 1,
                        color: Colors.grey[300],
                      ),
                      // Filter row inside container
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: _showFilterModal,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.tune,
                                    size: 22,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Filter',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.swap_vert,
                              size: 30,
                              color: Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                      // Tags list - Accordion style
                      Expanded(
                        child: _filteredTagItems.isEmpty
                            ? const Center(
                                child: Text(
                                  'No tags in this session',
                                  style: TextStyle(
                                    color: Color(0xFF9E9E9E),
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                child: Column(
                                  children: List.generate(_filteredTagItems.length, (index) {
                                    final item = _filteredTagItems[index];
                                    final isExpanded = _expandedIndices.contains(index);

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _TagAccordionItem(
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
                                        onSearch: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => SearchPage(initialTid: item.tid),
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
              const SizedBox(height: 16),
              // Sync button - only enabled when session is pending sync
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (_session!.isSynced || _isSyncing)
                      ? null
                      : _onSyncPressed,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _session!.isSynced ? Icons.check : Icons.sync,
                          color: Colors.white,
                          size: 20,
                        ),
                  label: Text(
                    _isSyncing
                        ? 'Syncing...'
                        : (_session!.isSynced ? 'Synced' : 'Sync'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    disabledBackgroundColor: Colors.grey[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSyncPressed() async {
    if (_session == null || _session!.isSynced || _isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      if (_session!.conferenceId != null) {
        final scannedTids = _session!.tags.map((t) => t.tid).toSet();
        await ConferenceService().submitInventory(
          conferenceId: _session!.conferenceId!,
          scannedEpcs: scannedTids,
          conferenceEpcs: _session!.conferenceEpcs,
        );
      }
      await _sessionService.markAsSynced(widget.sessionId);
      await _loadSession();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        selectedFilterType: _selectedFilterType,
        filterNameController: _filterNameController,
        onApplyFilter: (filterType, filterValue) {
          Navigator.pop(context);
          _applyFilter(filterType, filterValue);
        },
        onFilterTypeChanged: (filterType) {
          _resetFilter(filterType);
        },
      ),
    );
  }

  void _resetFilter(String filterType) {
    setState(() {
      _selectedFilterType = filterType;
      _filteredTagItems = List.from(_allTagItems);
      _expandedIndices.clear();
      if (_filteredTagItems.isNotEmpty) {
        _expandedIndices.add(0);
      }
    });
  }

  void _applyFilter(String filterType, String filterValue) {
    setState(() {
      _selectedFilterType = filterType;
      _expandedIndices.clear();

      if (filterValue.isEmpty) {
        _filteredTagItems = List.from(_allTagItems);
      } else {
        _filteredTagItems = _allTagItems.where((item) {
          final searchValue = filterValue.toLowerCase();
          switch (filterType) {
            case 'TID':
              return item.tid.toLowerCase().contains(searchValue);
            case 'RSSI':
              return item.rssi.toString() == filterValue;
            case 'Timestamp':
              return item.timeStamp.toLowerCase().contains(searchValue);
            default:
              return true;
          }
        }).toList();
      }

      if (_filteredTagItems.isNotEmpty) {
        _expandedIndices.add(0);
      }
    });
  }
}

class _FilterBottomSheet extends StatefulWidget {
  final String selectedFilterType;
  final TextEditingController filterNameController;
  final Function(String filterType, String filterValue) onApplyFilter;
  final Function(String filterType) onFilterTypeChanged;

  const _FilterBottomSheet({
    required this.selectedFilterType,
    required this.filterNameController,
    required this.onApplyFilter,
    required this.onFilterTypeChanged,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  static const Color _primaryBlue = Color(0xFF0066CC);
  late String _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.selectedFilterType;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Title
          const Text(
            'Filter',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          // Reader type section
          const Text(
            'Reader type',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          // Filter type chips - centered
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFilterChip('TID', _selectedType == 'TID'),
              const SizedBox(width: 10),
              _buildFilterChip('RSSI', _selectedType == 'RSSI'),
              const SizedBox(width: 10),
              _buildFilterChip('Timestamp', _selectedType == 'Timestamp'),
            ],
          ),
          const SizedBox(height: 24),
          // Dynamic label based on selected filter type
          Text(
            'Write the $_selectedType',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          // Text input
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: widget.filterNameController,
              decoration: InputDecoration(
                hintText: _getHintText(),
                hintStyle: const TextStyle(color: Colors.grey),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Filter button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                widget.onApplyFilter(_selectedType, widget.filterNameController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Filter',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getHintText() {
    switch (_selectedType) {
      case 'TID':
        return 'E200...';
      case 'RSSI':
        return '-200';
      case 'Timestamp':
        return '05/04/2012';
      default:
        return '';
    }
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (_selectedType != label) {
          setState(() {
            _selectedType = label;
          });
          widget.filterNameController.clear();
          widget.onFilterTypeChanged(label);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _primaryBlue : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _TagAccordionItem extends StatelessWidget {
  final TagItem item;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onSearch;

  const _TagAccordionItem({
    required this.item,
    required this.isExpanded,
    required this.onToggle,
    required this.onSearch,
  });

  static const Color _readGreen = Color(0xFF4CAF50);
  static const Color _unreadBlue = Color(0xFF1A1A2E);

  @override
  Widget build(BuildContext context) {
    final headerColor = item.isRead ? _readGreen : _unreadBlue;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: headerColor, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: onToggle,
            child: Container(
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(6),
                  topRight: const Radius.circular(6),
                  bottomLeft: isExpanded ? Radius.zero : const Radius.circular(6),
                  bottomRight: isExpanded ? Radius.zero : const Radius.circular(6),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    item.isRead ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.tid,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white70,
                    size: 20,
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
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('TID:', item.tid),
                  const SizedBox(height: 6),
                  _buildInfoRow('EPC:', item.epc.isNotEmpty ? item.epc : 'Not read'),
                  const SizedBox(height: 6),
                  _buildInfoRow('Status:', item.isRead ? 'Found' : 'Not found'),
                  const SizedBox(height: 6),
                  _buildInfoRow('Time stamp:', item.timeStamp),
                  const SizedBox(height: 6),
                  _buildInfoRow('Chip model:', item.chipModel),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoRow('Read count:', item.readCount.toString()),
                      SizedBox(
                        height: 32,
                        width: 32,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.search, size: 20, color: Color(0xFF0066CC)),
                          tooltip: 'Search this tag',
                          onPressed: onSearch,
                        ),
                      ),
                    ],
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

  Widget _buildInfoRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: Colors.black87),
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class TagItem {
  final String id;
  final String tid;
  final String epc;
  final String timeStamp;
  final String chipModel;
  final int readCount;
  final int rssi;
  final bool isRead;

  TagItem({
    required this.id,
    required this.tid,
    required this.epc,
    required this.timeStamp,
    required this.chipModel,
    required this.readCount,
    required this.rssi,
    this.isRead = false,
  });
}
