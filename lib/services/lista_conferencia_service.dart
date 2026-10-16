import 'api_client.dart';
import 'rfid_service.dart';

class ListaConferencia {
  final int id;
  final String nome;
  final String? descricao;
  final int? totalRfids;

  const ListaConferencia({
    required this.id,
    required this.nome,
    this.descricao,
    this.totalRfids,
  });

  factory ListaConferencia.fromJson(
    Map<String, dynamic> json, {
    int? totalRfids,
  }) =>
      ListaConferencia(
        id: lerInt(json['id']),
        nome: json['nome'] as String,
        descricao: json['descricao'] as String?,
        totalRfids: totalRfids,
      );

  String get displayName =>
      totalRfids == null ? '#$id - $nome' : '#$id - $nome ($totalRfids itens)';
}

class Inventario {
  final int id;
  final int listaConferenciaId;
  final int? usuarioId;
  final int totalEsperado;
  final int totalEncontrados;
  final int totalNaoEncontrados;
  final List<String> encontrados;
  final List<String> naoEncontrados;
  final List<String> tidsInvalidos;

  const Inventario({
    required this.id,
    required this.listaConferenciaId,
    this.usuarioId,
    required this.totalEsperado,
    required this.totalEncontrados,
    required this.totalNaoEncontrados,
    required this.encontrados,
    required this.naoEncontrados,
    required this.tidsInvalidos,
  });

  factory Inventario.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as Map<String, dynamic>? ?? const {};
    List<String> lista(String chave) =>
        (status[chave] as List<dynamic>? ?? const []).cast<String>();

    return Inventario(
      id: lerInt(json['id']),
      listaConferenciaId: lerInt(json['lista_conferencia_id']),
      usuarioId: lerIntOpcional(json['usuario_id']),
      totalEsperado: lerInt(json['total_esperado']),
      totalEncontrados: lerInt(json['total_encontrados']),
      totalNaoEncontrados: lerInt(json['total_nao_encontrados']),
      encontrados: lista('encontrados'),
      naoEncontrados: lista('nao_encontrados'),
      tidsInvalidos: lista('tids_invalidos'),
    );
  }
}

class ListaConferenciaService {
  static const String _path = '/rfids/listas_conferencias';

  final ApiClient _api = ApiClient();

  /// A listagem da API não traz a quantidade de RFIDs, então ela é buscada por lista.
  Future<List<ListaConferencia>> listar() async {
    final dados = await _api.buscarTodasPaginas(_path);
    return Future.wait(dados.map((json) async => ListaConferencia.fromJson(
          json,
          totalRfids: await _contarRfids(lerInt(json['id'])),
        )));
  }

  Future<List<Rfid>> listarRfids(int id) async {
    final dados = await _api.buscarTodasPaginas('$_path/$id/rfids');
    return dados.map(Rfid.fromJson).toList();
  }

  /// [tids] são os TIDs lidos; a API compara com os TIDs esperados da lista.
  Future<Inventario> registrarInventario(
    int id, {
    required List<String> tids,
  }) async {
    final resposta = await _api.post('$_path/$id/inventario', body: {
      'tids': tids,
    });
    return Inventario.fromJson(resposta as Map<String, dynamic>);
  }

  Future<int?> _contarRfids(int id) async {
    try {
      final resposta = await _api.get(
        '$_path/$id/rfids',
        query: {'limite': '1'},
      ) as Map<String, dynamic>;
      return lerInt((resposta['meta'] as Map<String, dynamic>)['total']);
    } on SessaoExpiradaException {
      rethrow;
    } catch (_) {
      return null;
    }
  }
}
