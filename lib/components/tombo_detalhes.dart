import 'package:flutter/material.dart';

import '../services/tombo_service.dart';
import '../theme/app_colors.dart';

/// Taxonomia do tombo, buscada ao montar (montar só com o item expandido).
class TomboDetalhes extends StatefulWidget {
  final int? tomboHcf;

  const TomboDetalhes({super.key, required this.tomboHcf});

  @override
  State<TomboDetalhes> createState() => _TomboDetalhesState();
}

class _TomboDetalhesState extends State<TomboDetalhes> {
  Future<TomboTaxonomia>? _taxonomia;

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  @override
  void didUpdateWidget(TomboDetalhes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tomboHcf != widget.tomboHcf) _buscar();
  }

  void _buscar() {
    final hcf = widget.tomboHcf;
    _taxonomia = hcf == null ? null : TomboService().buscar(hcf);
  }

  @override
  Widget build(BuildContext context) {
    final taxonomia = _taxonomia;
    if (taxonomia == null) {
      return const Text(
        'Tombo não encontrado no catálogo',
        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
      );
    }

    return FutureBuilder<TomboTaxonomia>(
      future: taxonomia,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final dados = snapshot.data;
        if (snapshot.hasError || dados == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _linha('Tombo HCF:', '${widget.tomboHcf}'),
              const SizedBox(height: 6),
              const Text(
                'Dados do tombo indisponíveis',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          );
        }

        final especie = [
          dados.especie,
          dados.especieAutor,
        ].where((parte) => parte.isNotEmpty).join(' ');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _linha('Tombo HCF:', '${dados.hcf}'),
            const SizedBox(height: 6),
            _linha('Nome científico:', dados.nomeCientifico),
            const SizedBox(height: 6),
            _linha('Família:', dados.familia),
            const SizedBox(height: 6),
            _linha('Gênero:', dados.genero),
            const SizedBox(height: 6),
            _linha('Espécie:', especie),
            const SizedBox(height: 6),
            _linha('Nome popular:', dados.nomePopular),
          ],
        );
      },
    );
  }

  Widget _linha(String rotulo, String valor) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: Colors.black87),
        children: [
          TextSpan(
            text: '$rotulo ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: valor.isEmpty ? '-' : valor),
        ],
      ),
    );
  }
}
