import 'api_client.dart';

/// Bloco `taxonomia` de `GET /tombos/:hcf`.
class TomboTaxonomia {
  final int hcf;
  final String nomeCientifico;
  final String nomePopular;
  final String familia;
  final String genero;
  final String especie;
  final String especieAutor;

  const TomboTaxonomia({
    required this.hcf,
    required this.nomeCientifico,
    required this.nomePopular,
    required this.familia,
    required this.genero,
    required this.especie,
    required this.especieAutor,
  });

  factory TomboTaxonomia.fromJson(int hcf, Map<String, dynamic> json) {
    final taxonomia = json['taxonomia'] as Map<String, dynamic>? ?? const {};
    final especie = taxonomia['especie'] as Map<String, dynamic>? ?? const {};
    String texto(Object? valor) => valor?.toString().trim() ?? '';

    return TomboTaxonomia(
      hcf: lerIntOpcional(json['hcf']) ?? hcf,
      nomeCientifico: texto(taxonomia['nome_cientifico']),
      nomePopular: texto(taxonomia['nome_popular']),
      familia: texto(taxonomia['familia']),
      genero: texto(taxonomia['genero']),
      especie: texto(especie['nome']),
      especieAutor: texto(especie['autor']),
    );
  }
}

class TomboService {
  static final TomboService _instance = TomboService._internal();
  factory TomboService() => _instance;
  TomboService._internal();

  final ApiClient _api = ApiClient();
  final Map<int, Future<TomboTaxonomia>> _cache = {};

  // GET /tombos/:hcf é pesado (também carrega listas de cadastro), por isso o cache por sessão do app.
  Future<TomboTaxonomia> buscar(int hcf) {
    return _cache.putIfAbsent(hcf, () async {
      try {
        final resposta =
            await _api.get('/tombos/$hcf', timeout: const Duration(seconds: 30))
                as Map<String, dynamic>;
        return TomboTaxonomia.fromJson(hcf, resposta);
      } catch (_) {
        _cache.remove(hcf);
        rethrow;
      }
    });
  }
}
