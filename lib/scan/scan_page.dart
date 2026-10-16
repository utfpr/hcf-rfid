import 'package:flutter/material.dart';

import '../components/page_title_header.dart';
import '../services/lista_conferencia_service.dart';
import '../theme/app_colors.dart';
import 'lista_conferencia_scan_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final ListaConferenciaService _listaConferenciaService =
      ListaConferenciaService();

  int? _selectedListaConferenciaId;
  List<ListaConferencia> _listasConferencias = [];
  bool _loadingListas = false;
  bool _loadingRfids = false;

  @override
  void initState() {
    super.initState();
    _loadListasConferencias();
  }

  Future<void> _loadListasConferencias() async {
    setState(() => _loadingListas = true);
    try {
      final listas = await _listaConferenciaService.listar();
      if (mounted) {
        setState(() {
          _listasConferencias = listas;
          _loadingListas = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingListas = false);
        _showError('Falha ao carregar listas de conferência: $e');
      }
    }
  }

  Future<void> _onStart() async {
    final lista = _listasConferencias
        .where((l) => l.id == _selectedListaConferenciaId)
        .firstOrNull;
    if (lista == null) return;
    setState(() => _loadingRfids = true);
    try {
      final rfids = await _listaConferenciaService.listarRfids(lista.id);
      final tids = rfids
          .where((r) => r.tidValido)
          .map((r) => r.tid!.trim())
          .toSet()
          .toList();
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ListaConferenciaScanPage(
              listaConferenciaId: lista.id,
              listaConferenciaNome: lista.nome,
              tidsEsperados: tids,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Falha ao carregar lista de conferência: $e');
    } finally {
      if (mounted) setState(() => _loadingRfids = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
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
              const PageTitleHeader(title: 'Scan'),
              const SizedBox(height: 24),
              _buildListaConferenciaCard(),
              const Spacer(),
              _buildStartButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListaConferenciaCard() {
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
                'Selecionar lista de conferência',
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
                  onPressed: _loadingListas ? null : _loadListasConferencias,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Escolha uma lista de conferência para iniciar a leitura',
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
            child: _loadingListas
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
                        Text('Carregando listas de conferência…',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedListaConferenciaId,
                      isExpanded: true,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: AppColors.textSecondary),
                      dropdownColor: Colors.white,
                      hint: const Text(
                        'Selecione uma lista de conferência',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textMuted),
                      ),
                      items: _listasConferencias
                          .map((l) => DropdownMenuItem<int>(
                                value: l.id,
                                child: Text(
                                  l.displayName,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textPrimary),
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(
                            () => _selectedListaConferenciaId = value);
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
        _selectedListaConferenciaId != null && !_loadingRfids;
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
        child: _loadingRfids
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
