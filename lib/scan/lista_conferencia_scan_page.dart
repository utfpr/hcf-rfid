import 'dart:async';

import 'package:flutter/material.dart';

import '../components/tombo_detalhes.dart';
import '../history/session_details_page.dart';
import '../services/btl_reader_plugin.dart';
import '../services/c72_reader_plugin.dart';
import '../services/catalogo_rfid_service.dart';
import '../services/reader_service.dart';
import '../services/scan_session_service.dart';
import '../services/urovo_reader_plugin.dart';
import '../theme/app_colors.dart';

class ListaConferenciaScanPage extends StatefulWidget {
  final int listaConferenciaId;
  final String listaConferenciaNome;
  final List<String> tidsEsperados;

  const ListaConferenciaScanPage({
    super.key,
    required this.listaConferenciaId,
    required this.listaConferenciaNome,
    required this.tidsEsperados,
  });

  @override
  State<ListaConferenciaScanPage> createState() =>
      _ListaConferenciaScanPageState();
}

class _ListaConferenciaScanPageState extends State<ListaConferenciaScanPage> {
  final ScanSessionService _sessionService = ScanSessionService();
  final ReaderService _readerService = ReaderService();
  final CatalogoRfidService _catalogo = CatalogoRfidService();

  final Set<String> _readTids = {};
  final ValueNotifier<int> _readCount = ValueNotifier<int>(0);
  final Set<String> _expandedTids = {};

  StreamSubscription<Map<String, dynamic>>? _tagSubscription;
  StreamSubscription<bool>? _triggerSubscription;

  bool _isScanning = false;
  bool _isFinishing = false;

  DateTime? _startTime;
  DateTime? _endTime;

  // Track tag details for session saving
  final Map<String, ScannedTag> _scannedTagsMap = {};

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _catalogo.addListener(_onCatalogoAtualizado);
    _catalogo.carregar();
    _initTrigger();
  }

  void _onCatalogoAtualizado() {
    if (mounted) setState(() {});
  }

  bool get _isBTL =>
      _readerService.isAcuraBTLReader(_readerService.connectedReader);

  bool get _isUrovo =>
      _readerService.isUrovoReader(_readerService.connectedReader);

  @override
  void dispose() {
    _catalogo.removeListener(_onCatalogoAtualizado);
    _tagSubscription?.cancel();
    _triggerSubscription?.cancel();
    if (_isScanning) {
      if (_isBTL) {
        BTLReaderPlugin.stopScan();
      } else if (_isUrovo) {
        UrovoReaderPlugin.stopScan();
      } else {
        C72ReaderPlugin.stopScan();
      }
    }
    _readCount.dispose();
    super.dispose();
  }

  void _initTrigger() {
    final stream = _isBTL
        ? BTLReaderPlugin.triggerStream
        : _isUrovo
        ? UrovoReaderPlugin.triggerStream
        : C72ReaderPlugin.triggerStream;
    _triggerSubscription = stream.listen((pressed) {
      if (!mounted) return;
      if (pressed) {
        _startScanning();
      } else {
        _stopScanning();
      }
    }, onError: (_) {});
  }

  void _startScanning() {
    if (_isScanning) return;
    _isScanning = true;
    if (mounted) setState(() {});

    _tagSubscription?.cancel();
    if (_isBTL) {
      _tagSubscription = BTLReaderPlugin.tagStream.listen(_onTagReceived);
      BTLReaderPlugin.startScan();
    } else if (_isUrovo) {
      _tagSubscription = UrovoReaderPlugin.tagStream.listen(_onTagReceived);
      UrovoReaderPlugin.startScan();
    } else {
      _tagSubscription = C72ReaderPlugin.tagStream.listen(_onTagReceived);
      C72ReaderPlugin.startScan();
    }
  }

  void _stopScanning() {
    if (!_isScanning) return;
    _tagSubscription?.cancel();
    _tagSubscription = null;
    if (_isBTL) {
      BTLReaderPlugin.stopScan();
    } else if (_isUrovo) {
      UrovoReaderPlugin.stopScan();
    } else {
      C72ReaderPlugin.stopScan();
    }
    _isScanning = false;
    if (mounted) setState(() {});
  }

  void _onTagReceived(Map<String, dynamic> map) {
    if (!mounted) return;
    final tid = (map['tid'] as String? ?? '').toString();
    if (tid.isEmpty) return;

    // Only process tags that belong to the lista de conferência
    if (!widget.tidsEsperados.contains(tid)) return;

    // Track tag details for session saving
    if (_scannedTagsMap.containsKey(tid)) {
      final existing = _scannedTagsMap[tid]!;
      _scannedTagsMap[tid] = ScannedTag(
        id: existing.id,
        tid: existing.tid,
        epc: existing.epc,
        timeStamp: existing.timeStamp,
        chipModel: existing.chipModel,
        readCount: existing.readCount + 1,
        rssi: (map['rssi'] as num?)?.toInt() ?? existing.rssi,
      );
    } else {
      _scannedTagsMap[tid] = ScannedTag.fromPlatformTag(
        map,
        index: _scannedTagsMap.length,
      );
    }

    if (_readTids.add(tid)) {
      _readCount.value = _readTids.length;
      setState(() {});
    }
  }

  Future<void> _finishScan() async {
    _stopScanning();
    _triggerSubscription?.cancel();
    setState(() => _isFinishing = true);

    _endTime = DateTime.now();

    final sessionId = ScanSessionService.generateSessionId();
    final session = ScanSession(
      sessionId: sessionId,
      startTime: ScanSessionService.formatDateTime(_startTime!),
      endTime: ScanSessionService.formatDateTime(_endTime!),
      tags: _scannedTagsMap.values.toList(),
      isSynced: false,
      listaConferenciaId: widget.listaConferenciaId,
      tidsEsperados: widget.tidsEsperados,
    );

    await _sessionService.addSession(session);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionDetailsPage(sessionId: sessionId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort: unread first, then read
    final sortedTids = List<String>.from(widget.tidsEsperados)
      ..sort((a, b) {
        final aRead = _readTids.contains(a) ? 1 : 0;
        final bRead = _readTids.contains(b) ? 1 : 0;
        return aRead.compareTo(bRead);
      });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              GestureDetector(
                onTap: () {
                  _stopScanning();
                  Navigator.of(context).pop();
                },
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Icon(
                    Icons.chevron_left,
                    color: AppColors.textHeading,
                    size: 28,
                  ),
                ),
              ),
              // Title
              Text(
                widget.listaConferenciaNome,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHeading,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 48,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.textHeading,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Status header card
              _buildStatusCard(),
              const SizedBox(height: 16),
              // TID list
              Expanded(
                child: sortedTids.isEmpty
                    ? Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'Nenhum TID nesta lista de conferência',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Column(
                          children: List.generate(sortedTids.length, (index) {
                            final tid = sortedTids[index];
                            final isRead = _readTids.contains(tid);
                            final isExpanded = _expandedTids.contains(tid);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _TidAccordionItem(
                                tid: tid,
                                tomboHcf: _catalogo.buscarPorTid(tid)?.tomboHcf,
                                isRead: isRead,
                                isExpanded: isExpanded,
                                onToggle: () {
                                  setState(() {
                                    if (_expandedTids.contains(tid)) {
                                      _expandedTids.remove(tid);
                                    } else {
                                      _expandedTids.add(tid);
                                    }
                                  });
                                },
                              ),
                            );
                          }),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              // Finish button
              _buildFinishButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final total = widget.tidsEsperados.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _isScanning
                            ? AppColors.success
                            : AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isScanning ? 'Scanning...' : 'Waiting for trigger',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<int>(
                  valueListenable: _readCount,
                  builder: (context, count, child) => Text(
                    '$count / $total encontrados',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: _readCount,
            builder: (context, count, child) => Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Não encontrados:',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  '${total - count}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isFinishing ? null : _finishScan,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[400],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        child: _isFinishing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Finish Session',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TidAccordionItem extends StatelessWidget {
  final String tid;
  final int? tomboHcf;
  final bool isRead;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _TidAccordionItem({
    required this.tid,
    required this.tomboHcf,
    required this.isRead,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final headerColor = isRead ? AppColors.success : AppColors.secondary;

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
                  bottomLeft: isExpanded
                      ? Radius.zero
                      : const Radius.circular(6),
                  bottomRight: isExpanded
                      ? Radius.zero
                      : const Radius.circular(6),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    isRead ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tomboHcf != null ? 'Tombo $tomboHcf' : tid,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white70,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: !isExpanded
                ? const SizedBox(width: double.infinity)
                : Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: TomboDetalhes(tomboHcf: tomboHcf),
                  ),
          ),
        ],
      ),
    );
  }
}
