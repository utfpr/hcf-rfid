import 'dart:async';

import 'package:flutter/material.dart';

import '../components/page_title_header.dart';
import '../services/btl_reader_plugin.dart';
import '../services/c72_reader_plugin.dart';
import '../services/catalogo_rfid_service.dart';
import '../services/reader_service.dart';
import '../services/rfid_service.dart';
import '../services/urovo_reader_plugin.dart';
import '../theme/app_colors.dart';

class SearchPage extends StatefulWidget {
  final String? initialTid;

  const SearchPage({super.key, this.initialTid});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final CatalogoRfidService _catalogo = CatalogoRfidService();
  final ReaderService _readerService = ReaderService();

  /// Whether the active reader is an Acura Bluetooth reader (otherwise Urovo or C72).
  bool get _isBTL =>
      _readerService.isAcuraBTLReader(_readerService.connectedReader);

  /// Whether the active reader is the integrated reader of a Urovo device.
  bool get _isUrovo =>
      _readerService.isUrovoReader(_readerService.connectedReader);

  final TextEditingController _buscaController = TextEditingController();
  final FocusNode _buscaFocusNode = FocusNode();
  // Texto exibido no campo para a seleção atual; se o usuário editá-lo, a seleção é desfeita.
  String? _textoSelecionado;

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
    final initialTid = widget.initialTid;
    if (initialTid != null) {
      _selectedTid = initialTid;
      _textoSelecionado = initialTid;
      _buscaController.text = initialTid;
    }
    _buscaController.addListener(_onBuscaChanged);
    _catalogo.carregar();
    _catalogo.addListener(_onCatalogoChanged);
    _exibirEpcDaSelecao();
    _initTrigger();
  }

  static String _textoDoRfid(Rfid rfid) => rfid.epc ?? rfid.tid!;

  void _onCatalogoChanged() {
    if (!mounted) return;
    if (_catalogo.carregando) _buscaFocusNode.unfocus();
    setState(() {});
    _exibirEpcDaSelecao();
  }

  /// Troca o TID recebido em [SearchPage.initialTid] pelo EPC, quando ele está na lista.
  void _exibirEpcDaSelecao() {
    final selectedTid = _selectedTid;
    if (selectedTid == null || _buscaController.text != _textoSelecionado) return;
    final epc = _catalogo.buscarPorTid(selectedTid)?.epc;
    if (epc == null || epc == _textoSelecionado) return;
    _textoSelecionado = epc;
    _buscaController.text = epc;
  }

  void _onBuscaChanged() {
    if (_selectedTid != null && _buscaController.text != _textoSelecionado) {
      setState(() {
        _selectedTid = null;
        _textoSelecionado = null;
      });
    }
  }

  Iterable<Rfid> _sugestoes(TextEditingValue value) {
    final termo = value.text.trim().toUpperCase();
    if (termo.length < 3) return const [];
    return _catalogo.rfids
        .where((r) =>
            (r.epc?.toUpperCase().contains(termo) ?? false) ||
            (r.epcHex?.toUpperCase().contains(termo) ?? false) ||
            r.tid!.toUpperCase().contains(termo))
        .take(20);
  }

  void _selecionarRfid(Rfid rfid) {
    setState(() {
      _textoSelecionado = _textoDoRfid(rfid);
      _selectedTid = rfid.tid;
    });
    _buscaFocusNode.unfocus();
  }

  void _limparBusca() {
    _buscaController.clear();
    setState(() {
      _selectedTid = null;
      _textoSelecionado = null;
    });
  }

  @override
  void dispose() {
    _catalogo.removeListener(_onCatalogoChanged);
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
    _scrollController.dispose();
    _buscaController.dispose();
    _buscaFocusNode.dispose();
    super.dispose();
  }

  void _initTrigger() {
    debugPrint('[SearchPage] _isBTL: $_isBTL, _isUrovo: $_isUrovo, connectedReader: ${_readerService.connectedReader?.manufacturer}/${_readerService.connectedReader?.model}');
    final stream = _isBTL
        ? BTLReaderPlugin.triggerStream
        : _isUrovo
            ? UrovoReaderPlugin.triggerStream
            : C72ReaderPlugin.triggerStream;
    _triggerSubscription = stream.listen(
      (pressed) {
        debugPrint('[SearchPage] Trigger event: pressed=$pressed');
        if (!mounted) return;
        if (pressed) {
          if (_catalogo.carregando) {
            _avisarCarregando();
            return;
          }
          _startScan();
        } else {
          _stopScan();
        }
      },
      onError: (e) => debugPrint('[SearchPage] Trigger stream error: $e'),
    );
  }

  void _avisarCarregando() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Aguarde o carregamento da lista de RFIDs.')),
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
    final chave = CatalogoRfidService.normalizarTid(tid);

    if (_selectedTid != null) {
      // Filtered mode: only track the selected TID
      if (chave == CatalogoRfidService.normalizarTid(_selectedTid!)) {
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
      // All-tags mode: only tags present in the preloaded RFID list
      final rfid = _catalogo.buscarPorTid(tid);
      if (rfid == null) return;
      setState(() {
        _tagsMap[chave] = _C72Tag(tid: tid, rssi: rssi, rfid: rfid);
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
    } else if (_isUrovo) {
      UrovoReaderPlugin.stopScan();
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
      backgroundColor: AppColors.background,
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
        color: AppColors.primary,
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
              'Buscar por EPC (opcional)',
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
                onPressed: _catalogo.carregando
                    ? null
                    : () => _catalogo.carregar(forcar: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Digite ao menos 3 caracteres do EPC ou TID, ou deixe vazio para encontrar a tag com o sinal mais forte',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: RawAutocomplete<Rfid>(
            textEditingController: _buscaController,
            focusNode: _buscaFocusNode,
            displayStringForOption: _textoDoRfid,
            optionsBuilder: _sugestoes,
            onSelected: _selecionarRfid,
            fieldViewBuilder: _buildCampoBusca,
            optionsViewBuilder: _buildSugestoes,
          ),
        ),
        if (_catalogo.carregando) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(
            minHeight: 4,
            color: Colors.white,
            backgroundColor: Colors.white24,
          ),
          const SizedBox(height: 6),
          const Text(
            'Carregando lista de RFIDs...',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ] else if (_catalogo.erro != null) ...[
          const SizedBox(height: 6),
          Text(
            'Falha ao carregar RFIDs: ${_catalogo.erro}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ] else if (_catalogo.carregado) ...[
          const SizedBox(height: 6),
          Text(
            '${_catalogo.rfids.length} RFIDs carregados',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildCampoBusca(
    BuildContext context,
    TextEditingController controller,
    FocusNode focusNode,
    VoidCallback onFieldSubmitted,
  ) {
    final carregando = _catalogo.carregando;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: !carregando,
      textCapitalization: TextCapitalization.characters,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      onSubmitted: (_) => onFieldSubmitted(),
      decoration: InputDecoration(
        hintText: carregando ? 'Carregando RFIDs...' : 'EPC ou TID',
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: carregando
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted),
                ),
              )
            : const Icon(Icons.search, color: AppColors.textSecondary),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                  onPressed: carregando ? null : _limparBusca,
                ),
        ),
      ),
    );
  }

  Widget _buildSugestoes(
    BuildContext context,
    AutocompleteOnSelected<Rfid> onSelected,
    Iterable<Rfid> options,
  ) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final rfid = options.elementAt(index);
              return ListTile(
                dense: true,
                title: Text(
                  rfid.epc ?? '—',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  rfid.tid!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
                onTap: () => onSelected(rfid),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScanningCardContent() {
    if (_selectedTid != null) {
      final epc = _catalogo.buscarPorTid(_selectedTid!)?.epc;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  epc != null ? 'Buscando EPC:' : 'Buscando TID:',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  epc ?? _selectedTid!,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (epc != null)
                  Text(
                    _selectedTid!,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
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
              const Text('Melhor sinal:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                best?.rfid.epc ?? best?.tid ?? '—',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              if (best != null && best.rfid.epc != null)
                Text(
                  best.tid,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
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
    if (_catalogo.carregando) {
      emptyMessage = 'Carregando lista de RFIDs...';
    } else if (_selectedTid == null && !_catalogo.carregado && _catalogo.erro != null) {
      emptyMessage =
          'Lista de RFIDs indisponível: ${_catalogo.erro}\nToque em atualizar para tentar de novo.';
    } else if (_isScanning) {
      emptyMessage = _selectedTid != null ? 'Aguardando tags...' : 'Aguardando tags cadastradas...';
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 16),
                ),
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
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontFamily: 'monospace'),
              ),
              const SizedBox(width: 12),
              Text(
                'RSSI: ${entry.rssi}',
                style: const TextStyle(fontSize: 13, color: AppColors.textMutedAlt, fontFamily: 'monospace'),
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
                  child: Icon(Icons.signal_cellular_alt, size: 14, color: AppColors.primary),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag.rfid.epc ?? tag.tid,
                      style: TextStyle(
                        fontSize: 13,
                        color: isFirst ? AppColors.primary : AppColors.textHeading,
                        fontWeight: isFirst ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      tag.tid,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'RSSI: ${tag.rssi}',
                style: TextStyle(
                  fontSize: 13,
                  color: isFirst ? AppColors.primary : AppColors.textMutedAlt,
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
  final Rfid rfid;
  const _C72Tag({required this.tid, required this.rssi, required this.rfid});
}
