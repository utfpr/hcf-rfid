import 'dart:async';

import 'package:flutter/material.dart';

import '../components/page_title_header.dart';
import '../services/btl_reader_plugin.dart';
import '../services/c72_reader_plugin.dart';
import '../services/reader_service.dart';
import '../services/stock_service.dart';

class SearchPage extends StatefulWidget {
  final String? initialTid;

  const SearchPage({super.key, this.initialTid});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const Color _screenBackground = Color(0xFFF0F2F5);
  static const Color _cardBackground = Color(0xFF007A33);

  final StockService _stockService = StockService();
  final ReaderService _readerService = ReaderService();

  /// Whether the active reader is an Acura Bluetooth reader (otherwise C72).
  bool get _isBTL =>
      _readerService.isAcuraBTLReader(_readerService.connectedReader);

  List<String> _tids = [];
  bool _isLoadingTids = true;

  bool _isScanning = false;
  String? _selectedTid;

  // All-tags mode: current snapshot sorted by RSSI desc
  List<_C72Tag> _currentTags = [];
  final Map<String, _C72Tag> _tagsMap = {};

  // Filtered mode: time-series history for selected tag
  final List<_RssiEntry> _filteredHistory = [];
  int _currentRssi = 0;

  StreamSubscription<Map<String, dynamic>>? _tagStreamSubscription;
  StreamSubscription<bool>? _triggerSubscription;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialTid != null) {
      _selectedTid = widget.initialTid;
    }
    _loadTids();
    _initTrigger();
  }

  Future<void> _loadTids() async {
    try {
      final tids = await _stockService.getTids();
      if (mounted) setState(() { _tids = tids; _isLoadingTids = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingTids = false);
    }
  }

  @override
  void dispose() {
    _tagStreamSubscription?.cancel();
    _triggerSubscription?.cancel();
    if (_isScanning) {
      if (_isBTL) {
        BTLReaderPlugin.stopScan();
      } else {
        C72ReaderPlugin.stopScan();
      }
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _initTrigger() {
    debugPrint('[SearchPage] _isBTL: $_isBTL, connectedReader: ${_readerService.connectedReader?.manufacturer}/${_readerService.connectedReader?.model}');
    final stream =
        _isBTL ? BTLReaderPlugin.triggerStream : C72ReaderPlugin.triggerStream;
    _triggerSubscription = stream.listen(
      (pressed) {
        debugPrint('[SearchPage] Trigger event: pressed=$pressed');
        if (!mounted) return;
        if (pressed) {
          _startScan();
        } else {
          _stopScan();
        }
      },
      onError: (e) => debugPrint('[SearchPage] Trigger stream error: $e'),
    );
  }

  void _startScan() {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _currentTags = [];
      _tagsMap.clear();
      _filteredHistory.clear();
      _currentRssi = 0;
    });

    _tagStreamSubscription?.cancel();
    if (_isBTL) {
      _tagStreamSubscription = BTLReaderPlugin.tagStream.listen(_onTagReceived);
      BTLReaderPlugin.startScan();
    } else {
      _tagStreamSubscription = C72ReaderPlugin.tagStream.listen(_onTagReceived);
      C72ReaderPlugin.startScan();
    }
  }

  void _onTagReceived(Map<String, dynamic> map) {
    if (!_isScanning || !mounted) return;
    final tid = (map['tid'] as String? ?? '').toString();
    if (tid.isEmpty) return;
    final rssi = (map['rssi'] as num?)?.toInt() ?? -80;

    if (_selectedTid != null) {
      // Filtered mode: only track the selected TID
      if (tid == _selectedTid) {
        setState(() {
          _currentRssi = rssi;
          _filteredHistory.insert(
            0,
            _RssiEntry(
              timestamp: _formatTimestamp(DateTime.now()),
              rssi: rssi,
            ),
          );
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut);
          }
        });
      }
    } else {
      // All-tags mode: update tag map and sort by RSSI
      setState(() {
        _tagsMap[tid] = _C72Tag(tid: tid, rssi: rssi);
        _currentTags = _tagsMap.values.toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
      });
    }
  }

  void _stopScan() {
    if (!_isScanning) return;
    _tagStreamSubscription?.cancel();
    _tagStreamSubscription = null;
    if (_isBTL) {
      BTLReaderPlugin.stopScan();
    } else {
      C72ReaderPlugin.stopScan();
    }
    setState(() => _isScanning = false);
  }

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d/$mo/${dt.year} $h:$m:$s';
  }

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
              const PageTitleHeader(title: 'Search'),
              const SizedBox(height: 24),
              _buildInfoCard(),
              const SizedBox(height: 16),
              Expanded(child: _buildListArea()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: _isScanning ? _buildScanningCardContent() : _buildSelectionCardContent(),
    );
  }

  Widget _buildSelectionCardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Select TID (optional)',
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
                icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                onPressed: _isLoadingTids ? null : _loadTids,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Leave empty to find the tag with the strongest signal',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
          ),
          child: _isLoadingTids
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9E9E9E)),
                      ),
                      SizedBox(width: 10),
                      Text('Loading TIDs...', style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14)),
                    ],
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTid,
                    isExpanded: true,
                    hint: const Text(
                      'All tags (best signal)',
                      style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF757575)),
                    dropdownColor: Colors.white,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'All tags (best signal)',
                          style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
                        ),
                      ),
                      ..._tids.map(
                        (tid) => DropdownMenuItem<String>(
                          value: tid,
                          child: Text(
                            tid,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _selectedTid = value),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildScanningCardContent() {
    if (_selectedTid != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                const Text('Searching TID:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  _selectedTid!,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('RSSI:', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text(
                _filteredHistory.isEmpty ? '—' : _currentRssi.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      );
    }

    // All-tags mode: best signal tag
    final best = _currentTags.isNotEmpty ? _currentTags.first : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              const Text('Best signal:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                best?.tid ?? '—',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('RSSI:', style: TextStyle(color: Colors.white70, fontSize: 14)),
            Text(
              best != null ? best.rssi.toString() : '—',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildListArea() {
    final bool hasContent =
        (_selectedTid != null ? _filteredHistory.isNotEmpty : _currentTags.isNotEmpty);

    String emptyMessage;
    if (_isScanning) {
      emptyMessage = 'Waiting for tags...';
    } else {
      emptyMessage = 'Press trigger to start reading';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: hasContent
          ? Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: _selectedTid != null
                  ? _buildFilteredList()
                  : _buildAllTagsList(),
            )
          : Center(
              child: Text(
                emptyMessage,
                style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 16),
              ),
            ),
    );
  }

  // Filtered mode: time-series of RSSI readings for the selected tag
  Widget _buildFilteredList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _filteredHistory.length,
      itemBuilder: (context, index) {
        final entry = _filteredHistory[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Text(
                entry.timestamp,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E), fontFamily: 'monospace'),
              ),
              const SizedBox(width: 12),
              Text(
                'RSSI: ${entry.rssi}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF616161), fontFamily: 'monospace'),
              ),
            ],
          ),
        );
      },
    );
  }

  // All-tags mode: current snapshot sorted by RSSI desc
  Widget _buildAllTagsList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _currentTags.length,
      itemBuilder: (context, index) {
        final tag = _currentTags[index];
        final isFirst = index == 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              if (isFirst)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.signal_cellular_alt, size: 14, color: Color(0xFF007A33)),
                ),
              Expanded(
                child: Text(
                  tag.tid,
                  style: TextStyle(
                    fontSize: 12,
                    color: isFirst ? const Color(0xFF007A33) : const Color(0xFF424242),
                    fontFamily: 'monospace',
                    fontWeight: isFirst ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'RSSI: ${tag.rssi}',
                style: TextStyle(
                  fontSize: 13,
                  color: isFirst ? const Color(0xFF007A33) : const Color(0xFF616161),
                  fontFamily: 'monospace',
                  fontWeight: isFirst ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RssiEntry {
  final String timestamp;
  final int rssi;
  const _RssiEntry({required this.timestamp, required this.rssi});
}

class _C72Tag {
  final String tid;
  final int rssi;
  const _C72Tag({required this.tid, required this.rssi});
}
