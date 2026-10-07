import 'api_client.dart';

class Rfid {
  final int id;
  final String? tid;
  final int? tomboFotoId;
  final String? epc;
  final String? epcHex;
  final String? status;

  const Rfid({
    required this.id,
    this.tid,
    this.tomboFotoId,
    this.epc,
    this.epcHex,
    this.status,
  });

  factory Rfid.fromJson(Map<String, dynamic> json) => Rfid(
        id: (json['id'] as num).toInt(),
        tid: json['tid'] as String?,
        tomboFotoId: (json['tombo_foto_id'] as num?)?.toInt(),
        epc: json['epc'] as String?,
        epcHex: json['epc_hex'] as String?,
        status: json['status'] as String?,
      );

  /// Mesmo critério da API: TID vazio ou "N/A" não pode ser conferido.
  bool get tidValido {
    final valor = tid?.trim() ?? '';
    return valor.isNotEmpty && valor.toUpperCase() != 'N/A';
  }
}

/// Resposta de `GET /api/rfids/validar-tid/:tid` (campo `dados`).
class RfidValidado {
  final int idRfid;
  final String tid;
  final String? epc;
  final String? epcHex;
  final String? statusRfid;
  final String tomboHcf;
  final String nomeCientifico;
  final String coletorPrincipal;

  const RfidValidado({
    required this.idRfid,
    required this.tid,
    this.epc,
    this.epcHex,
    this.statusRfid,
    required this.tomboHcf,
    required this.nomeCientifico,
    required this.coletorPrincipal,
  });

  factory RfidValidado.fromJson(Map<String, dynamic> json) => RfidValidado(
        idRfid: (json['id_rfid'] as num).toInt(),
        tid: json['tid'] as String,
        epc: json['epc'] as String?,
        epcHex: json['epc_hex'] as String?,
        statusRfid: json['status_rfid'] as String?,
        // A API devolve número ou 'N/A'.
        tomboHcf: json['tombo_hcf']?.toString() ?? 'N/A',
        nomeCientifico: json['nome_cientifico']?.toString() ?? 'N/A',
        coletorPrincipal: json['coletor_principal']?.toString() ?? 'N/A',
      );
}

class RfidService {
  final ApiClient _api = ApiClient();

  /// Somente CURADOR.
  Future<List<Rfid>> listar({String? status}) async {
    final dados = await _api.buscarTodasPaginas(
      '/api/rfids',
      query: {'status': ?status},
    );
    return dados.map(Rfid.fromJson).toList();
  }

  /// Somente CURADOR. Retorna `null` quando o TID não está cadastrado.
  Future<RfidValidado?> validarTid(String tid) async {
    try {
      final resposta = await _api.get(
        '/api/rfids/validar-tid/${Uri.encodeComponent(tid)}',
      ) as Map<String, dynamic>;
      return RfidValidado.fromJson(resposta['dados'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }
}
