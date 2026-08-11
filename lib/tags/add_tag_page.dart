import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/page_title_header.dart';
import '../services/btl_reader_plugin.dart';
import '../services/c72_reader_plugin.dart';
import '../services/reader_service.dart';
import '../services/rfid_tag_service.dart';
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
  Map<String, dynamic>? _existingTag; // non-null → tag already in DB

  final Map<String, int> _tagsMap = {};
  final Map<String, String> _epcByTid = {};
  final RfidTagService _service = RfidTagService();
  final ReaderService _readerService = ReaderService();

  bool get _isBTL =>
      _readerService.isAcuraBTLReader(_readerService.connectedReader);

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
      } else {
        C72ReaderPlugin.stopScan();
      }
    }
    super.dispose();
  }

  void _initTrigger() {
    final stream =
        _isBTL ? BTLReaderPlugin.triggerStream : C72ReaderPlugin.triggerStream;
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
      _isCheckingTag = false;
      _tagsMap.clear();
      _epcByTid.clear();
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
    } else {
      C72ReaderPlugin.stopScan();
    }
    setState(() => _isScanning = false);
    if (_bestTid != null) _checkTag(_bestTid!);
  }

  Future<void> _checkTag(String tid) async {
    setState(() => _isCheckingTag = true);
    try {
      final existing = await _service.getByTagId(tid);
      if (mounted) {
        setState(() {
          _existingTag = existing;
          _isCheckingTag = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingTag = false);
    }
  }

  String get _deviceName {
    final reader = _readerService.connectedReader;
    if (reader == null) return '';
    return reader.nickname?.isNotEmpty == true ? reader.nickname! : reader.model;
  }

  void _showForm({required bool readOnly}) {
    if (_bestTid == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: _AddTagForm(
        tid: _bestTid!,
        scannedEpc: _epcByTid[_bestTid!],
        existingTag: readOnly ? _existingTag : null,
        deviceName: _deviceName,
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
              const PageTitleHeader(title: 'Add Tag'),
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
      message = _bestTid == null ? 'Waiting for tags...' : 'Reading...';
    } else if (_isCheckingTag) {
      message = 'Checking tag...';
    } else if (_bestTid == null) {
      message = 'Press trigger to start scanning';
    } else if (_existingTag != null) {
      message = 'Tag already registered in database';
    } else {
      message = 'New tag — press "Add Tag" to register';
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
    if (_isCheckingTag) return const SizedBox.shrink();

    final isExisting = _existingTag != null;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showForm(readOnly: isExisting),
        icon: Icon(isExisting ? Icons.visibility : Icons.add),
        label: Text(isExisting ? 'Ver Tag' : 'Add Tag'),
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
// Bottom-sheet form
// ──────────────────────────────────────────────

class _AddTagForm extends StatefulWidget {
  final String tid;

  /// EPC read from the tag during the scan, used to pre-fill the EPC field.
  final String? scannedEpc;

  /// When non-null the form is in read-only / "Ver Tag" mode.
  final Map<String, dynamic>? existingTag;

  /// Display name of the connected reader device, used to auto-fill fields.
  final String deviceName;

  const _AddTagForm({
    required this.tid,
    required this.deviceName,
    this.scannedEpc,
    this.existingTag,
  });

  @override
  State<_AddTagForm> createState() => _AddTagFormState();
}

class _AddTagFormState extends State<_AddTagForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _typeController;
  late final TextEditingController _mainLabelController;
  late final TextEditingController _epcController;
  late final TextEditingController _readerController;
  late final TextEditingController _protocolController;
  late final TextEditingController _antennaController;
  late final TextEditingController _userController;

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _readOnly => widget.existingTag != null;

  final RfidTagService _service = RfidTagService();

  @override
  void initState() {
    super.initState();
    final tag = widget.existingTag;
    _typeController =
        TextEditingController(text: tag?['type']?.toString() ?? '');
    _mainLabelController =
        TextEditingController(text: tag?['description']?.toString() ?? '');
    _epcController = TextEditingController(
      text: tag?['epc']?.toString() ?? widget.scannedEpc ?? '',
    );
    _readerController = TextEditingController(
      text: widget.deviceName,
    );
    _protocolController = TextEditingController(
      text: 'EPC Gen2',
    );
    _antennaController = TextEditingController(
      text: '1',
    );
    _userController = TextEditingController(
      text: widget.deviceName,
    );
  }

  @override
  void dispose() {
    _typeController.dispose();
    _mainLabelController.dispose();
    _epcController.dispose();
    _readerController.dispose();
    _protocolController.dispose();
    _antennaController.dispose();
    _userController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final dto = <String, dynamic>{
        'tid': widget.tid,
        'description': _mainLabelController.text.trim(),
        'type': _typeController.text.trim(),
      };

      final epc = _epcController.text.trim();
      if (epc.isNotEmpty) dto['epc'] = epc;

      await _service.createTag(dto);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tag added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Não foi possível adicionar a tag.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
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
                  Text(
                    _readOnly ? 'Tag Registrada' : 'Add Tag to Database',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHeading,
                    ),
                  ),
                  if (_readOnly) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warningBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warningBorder),
                      ),
                      child: const Text(
                        'Tag existente',
                        style: TextStyle(
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

              // EPC read-only display
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      'TID (scanned)',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.tid,
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

              _buildField(_typeController, 'Type',
                  required: true, hint: 'e.g. Animal, Equipment'),
              _buildField(_mainLabelController, 'Description', required: true, hint: 'Tag description'),
              _buildField(_epcController, 'EPC', hint: 'e.g. E200...', inputFormatters: [LengthLimitingTextInputFormatter(16)]),
              _buildField(_readerController, 'Reader',
                  required: true, hint: 'Reader identifier'),
              _buildField(_protocolController, 'Protocol', required: true),
              _buildField(
                _antennaController,
                'Antenna',
                required: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (int.tryParse(v.trim()) == null) return 'Must be a number';
                  return null;
                },
              ),
              _buildField(_userController, 'User',
                  required: true, hint: 'Username / operator'),

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],

              const SizedBox(height: 20),

              if (!_readOnly)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Save Tag'),
                  ),
                )
              else
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
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    bool required = false,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        enabled: !_readOnly,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          filled: _readOnly,
          fillColor: AppColors.inputFill,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        validator: _readOnly
            ? null
            : (validator ??
                (required
                    ? (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null
                    : null)),
      ),
    );
  }
}
