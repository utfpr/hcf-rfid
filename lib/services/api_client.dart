import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String mensagem;

  const ApiException(this.statusCode, this.mensagem);

  @override
  String toString() => mensagem;
}

class SessaoExpiradaException implements Exception {
  @override
  String toString() => 'Sessão expirada. Faça login novamente.';
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const Duration _timeout = Duration(seconds: 10);
  static const int _limitePorPagina = 100;

  final AuthService _authService = AuthService();

  Future<dynamic> get(String path, {Map<String, String>? query}) {
    return _enviar(
      (headers) => http.get(_uri(path, query), headers: headers),
    );
  }

  Future<dynamic> post(String path, {Object? body}) {
    return _enviar(
      (headers) => http.post(
        _uri(path, null),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
  }

  /// Percorre todas as páginas de uma rota que responde `{dados, meta}`.
  Future<List<Map<String, dynamic>>> buscarTodasPaginas(
    String path, {
    Map<String, String> query = const {},
  }) async {
    final dados = <Map<String, dynamic>>[];
    for (var pagina = 1;; pagina++) {
      final resposta = await get(path, query: {
        ...query,
        'pagina': '$pagina',
        'limite': '$_limitePorPagina',
      }) as Map<String, dynamic>;

      final itens =
          (resposta['dados'] as List<dynamic>).cast<Map<String, dynamic>>();
      dados.addAll(itens);

      final total = ((resposta['meta'] as Map<String, dynamic>)['total'] as num)
          .toInt();
      if (itens.isEmpty || dados.length >= total) return dados;
    }
  }

  Uri _uri(String path, Map<String, String>? query) {
    final uri = Uri.parse('$apiBaseUrl$path');
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  Map<String, String> _headers() {
    final token = _authService.accessToken;
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  Future<dynamic> _enviar(
    Future<http.Response> Function(Map<String, String> headers) requisicao,
  ) async {
    var response = await requisicao(_headers()).timeout(_timeout);

    if (_precisaRenovarToken(response)) {
      final renovado = await _authService.refresh();
      if (!renovado) throw SessaoExpiradaException();
      response = await requisicao(_headers()).timeout(_timeout);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _mensagemDeErro(response));
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  // O middleware legado responde 401 para token expirado/inválido e 403 (código 101) para token ausente.
  bool _precisaRenovarToken(http.Response response) {
    if (response.statusCode == 401) return true;
    if (response.statusCode != 403) return false;
    final erro = _decodificar(response)?['error'];
    return erro is Map && erro['code'] == 101;
  }

  // A API usa `mensagem`, `message`, `erro` ou `error.message` dependendo da rota.
  String _mensagemDeErro(http.Response response) {
    final corpo = _decodificar(response);
    final erro = corpo?['error'];
    final mensagem = corpo?['mensagem'] ??
        corpo?['message'] ??
        corpo?['erro'] ??
        (erro is Map ? erro['message'] : null);
    return mensagem?.toString() ??
        'Erro na requisição (${response.statusCode}).';
  }

  Map<String, dynamic>? _decodificar(http.Response response) {
    try {
      final corpo = jsonDecode(response.body);
      return corpo is Map<String, dynamic> ? corpo : null;
    } catch (_) {
      return null;
    }
  }
}
