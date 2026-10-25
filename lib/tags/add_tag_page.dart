import 'dart:async';

import 'package:flutter/material.dart';

import '../components/page_title_header.dart';
import '../services/btl_reader_plugin.dart';
import '../services/c72_reader_plugin.dart';
import '../services/reader_service.dart';
import '../services/rfid_service.dart';
import '../services/urovo_reader_plugin.dart';
import '../theme/app_colors.dart';

class AddTagPage extends StatefulWidget {
  const AddTagPage({super.key});

  @override
  State<AddTagPage> createState() => _AddTagPageState();
}

class _AddTagPageState extends State<AddTagPage> {
  bool _isScanning = false;
  String? _bestTid;
  int _bestRssi = -999;

  // Tag existence check
  bool _isCheckingTag = false;
  RfidValidado? _existingTag; // non-null → tag already in DB
  String? _checkError;

  final Map<String, int> _tagsMap = {};
  final Map<String, String> _epcByTid = {};
  final RfidService _service = RfidService();
  final ReaderService _readerService = ReaderService();

  bool get _isBTL =>
      _readerService.isAcuraBTLReader(_readerService.connectedReader);

  bool get _isUrovo =>
      _readerService.isUrovoReader(_readerService.connectedReader);

  StreamSubscription<Map<String, dynamic>>? _tagStreamSubscription;
  StreamSubscription<bool>? _triggerSubscription;

  @override
  void initState() {
    super.initState();
    _initTrigger();
  }

  @override
  void dispose() {
    _tagStreamSubscription?.cancel();
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
    super.dispose();
  }

  void _initTrigger() {
    final stream = _isBTL
        ? BTLReaderPlugin.triggerStream
        : _isUrovo
            ? UrovoReaderPlugin.triggerStream
            : C72ReaderPlugin.triggerStream;
    _triggerSubscription = stream.listen(
      (pressed) {
        if (!mounted) return;
        if (pressed) {
          _startScan();
        } else {
          _stopScan();
        }
      },
      onError: (_) {},
    );
  }

  void _startScan() {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _bestTid = null;
      _bestRssi = -999;
      _existingTag = null;
      _checkError = null;
      _isCheckingTag = false;
      _tagsMap.clear();
      _epcByTid.clear();
    });

    _tagStreamSubscription?.cancel();
    if (_isBTL) {
      _tagStreamSubscription = BTLReaderPlugin.tagStream.listen(_onTagReceived);
      BTLReaderPlugin.startScan();
    } else if (_isUrovo) {
      _tagStreamSubscription = UrovoReaderPlugin.tagStream.listen(_onTagReceived);
      UrovoReaderPlugin.startScan();
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
    final epc = (map['epc'] as String? ?? '').trim();

    setState(() {
      _tagsMap[tid] = rssi;
      if (epc.isNotEmpty) _epcByTid[tid] = epc;
      String? best;
      int bestRssi = -999;
      for (final entry in _tagsMap.entries) {
        if (entry.value > bestRssi) {
          bestRssi = entry.value;
          best = entry.key;
        }
      }
      _bestTid = best;
      _bestRssi = bestRssi;
    });
  }

  void _stopScan() {
    if (!_isScanning) return;
    _tagStreamSubscription?.cancel();
    _tagStreamSubscription = null;
    if (_isBTL) {
      BTLReaderPlugin.stopScan();
    } else if (_isUrovo) {
      UrovoReaderPlugin.stopScan();
    } else {
      C72ReaderPlugin.stopScan();
    }
    setState(() => _isScanning = false);
    if (_bestTid != null) _checkTag(_bestTid!);
  }

  Future<void> _checkTag(String tid) async {
    setState(() => _isCheckingTag = true);
    try {
      final existing = await _service.validarTid(tid);
      if (mounted) {
        setState(() {
          _existingTag = existing;
          _isCheckingTag = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkError = 'Não foi possível consultar a tag: $e';
          _isCheckingTag = false;
        });
      }
    }
  }

  void _showDetails() {
    final rfid = _existingTag;
    if (rfid == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: _TagDetailsSheet(
          rfid: rfid,
          scannedEpc: _epcByTid[rfid.tid],
        ),
      ),
    );
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
              const PageTitleHeader(title: 'Adicionar Tag'),
              const SizedBox(height: 24),
              _buildInfoCard(),
              const SizedBox(height: 16),
              Expanded(child: _buildTagDisplay()),
              if (!_isScanning && _bestTid != null) ...[
                const SizedBox(height: 16),
                _buildActionButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    String subtitle;
    if (_isScanning) {
      subtitle = 'Best signal:';
    } else if (_bestTid != null) {
      subtitle = 'Last read:';
    } else {
      subtitle = 'Ready to scan';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _bestTid ?? '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
                _bestTid != null ? _bestRssi.toString() : '—',
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
      ),
    );
  }

  Widget _buildTagDisplay() {
    String message;
    if (_isScanning) {
      message = _bestTid == null ? 'Aguardando tags...' : 'Lendo...';
    } else if (_isCheckingTag) {
      message = 'Consultando tag...';
    } else if (_bestTid == null) {
      message = 'Pressione o gatilho para iniciar a leitura';
    } else if (_checkError != null) {
      message = _checkError!;
    } else if (_existingTag != null) {
      message = 'Tag já cadastrada no banco de dados';
    } else {
      message = 'Tag não cadastrada. O cadastro de tags não está disponível na nova API.';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: _isCheckingTag
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_existingTag != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.warningBorder),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: AppColors.warningText),
                        SizedBox(width: 6),
                        Text(
                          'Tag existente',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warningText,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }

  Widget _buildActionButton() {
    if (_isCheckingTag || _checkError != null) return const SizedBox.shrink();

    final isExisting = _existingTag != null;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        // Sem rota de cadastro na nova API: apenas a consulta fica habilitada.
        onPressed: isExisting ? _showDetails : null,
        icon: Icon(isExisting ? Icons.visibility : Icons.add),
        label: Text(isExisting ? 'Ver Tag' : 'Adicionar Tag'),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isExisting ? AppColors.textSecondary : AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Bottom-sheet de detalhes (somente leitura)
// ──────────────────────────────────────────────

class _TagDetailsSheet extends StatelessWidget {
  final RfidValidado rfid;

  /// EPC read from the tag during the scan.
  final String? scannedEpc;

  const _TagDetailsSheet({required this.rfid, this.scannedEpc});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  'Tag cadastrada',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHeading,
                  ),
                ),
                if (rfid.statusRfid != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warningBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warningBorder),
                    ),
                    child: Text(
                      rfid.statusRfid!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warningText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // TID read-only display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primarySofter,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TID (lido)',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rfid.tid,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textHeading,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildField('Tombo HCF', rfid.tomboHcf),
            _buildField('Nome científico', rfid.nomeCientifico),
            _buildField('Coletor principal', rfid.coletorPrincipal),
            _buildField('EPC', rfid.epc ?? '-'),
            _buildField('EPC (hex)', rfid.epcHex ?? '-'),
            if (scannedEpc != null && scannedEpc!.isNotEmpty)
              _buildField('EPC (lido)', scannedEpc!),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Fechar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.inputFill,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: SelectableText(
          value,
          style: const TextStyle(fontSize: 14, color: AppColors.textHeading),
        ),
      ),
    );
  }
}
