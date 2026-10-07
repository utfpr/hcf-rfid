import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

class Usuario {
  final int id;
  final String nome;
  final String email;
  final int tipoUsuarioId;

  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.tipoUsuarioId,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: (json['id'] as num).toInt(),
        nome: json['nome'] as String,
        email: json['email'] as String,
        tipoUsuarioId: (json['tipo_usuario_id'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'email': email,
        'tipo_usuario_id': tipoUsuarioId,
      };

  String get tipoUsuarioNome => switch (tipoUsuarioId) {
        1 => 'Curador',
        2 => 'Operador',
        3 => 'Identificador',
        _ => 'Desconhecido',
      };
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _usuarioKey = 'auth_user';
  static const String _accessTokenKey = 'auth_access_token';
  static const String _refreshTokenKey = 'auth_refresh_token';
  static const Duration _timeout = Duration(seconds: 10);

  /// Chamado quando o refresh token é rejeitado e o usuário precisa logar de novo.
  void Function()? aoExpirarSessao;

  Usuario? _usuario;
  String? _accessToken;
  String? _refreshToken;
  Future<bool>? _refreshEmAndamento;

  Usuario? get usuario => _usuario;
  String? get accessToken => _accessToken;
  bool get isLoggedIn => _usuario != null && _refreshToken != null;

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usuarioKey);
    _accessToken = prefs.getString(_accessTokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);

    // Sessões da API antiga não têm refresh token: força novo login.
    if (raw == null || _refreshToken == null) {
      await _limparSessao();
      return;
    }
    try {
      _usuario = Usuario.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await _limparSessao();
    }
  }

  Future<Usuario> login(String email, String senha) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim(), 'senha': senha}),
        )
        .timeout(_timeout);

    if (response.statusCode == 401) {
      throw Exception('E-mail ou senha inválidos.');
    }
    if (response.statusCode == 429) {
      throw Exception(
          'Muitas tentativas de login. Tente novamente em alguns minutos.');
    }
    if (response.statusCode != 200) {
      throw Exception('Erro ao autenticar (${response.statusCode}).');
    }

    await _salvarSessao(jsonDecode(response.body) as Map<String, dynamic>);
    return _usuario!;
  }

  /// Retorna `false` se o refresh token foi rejeitado.
  // Chamadas simultâneas compartilham a renovação: a API rotaciona o refresh token a cada uso.
  Future<bool> refresh() {
    return _refreshEmAndamento ??=
        _executarRefresh().whenComplete(() => _refreshEmAndamento = null);
  }

  Future<bool> _executarRefresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) {
      await _limparSessao();
      aoExpirarSessao?.call();
      return false;
    }

    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/api/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        )
        .timeout(_timeout);

    if (response.statusCode == 401) {
      await _limparSessao();
      aoExpirarSessao?.call();
      return false;
    }
    if (response.statusCode != 200) {
      throw Exception('Erro ao renovar a sessão (${response.statusCode}).');
    }

    await _salvarSessao(jsonDecode(response.body) as Map<String, dynamic>);
    return true;
  }

  Future<void> logout() async {
    final accessToken = _accessToken;
    final refreshToken = _refreshToken;
    await _limparSessao();
    if (refreshToken == null) return;

    // Melhor esforço: o logout local não depende da API estar acessível.
    unawaited(http
        .post(
          Uri.parse('$apiBaseUrl/api/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({'refresh_token': refreshToken}),
        )
        .timeout(_timeout)
        .then((_) {}, onError: (_) {}));
  }

  Future<void> _salvarSessao(Map<String, dynamic> json) async {
    _accessToken = json['access_token'] as String;
    _refreshToken = json['refresh_token'] as String;
    _usuario = Usuario.fromJson(json['user'] as Map<String, dynamic>);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usuarioKey, jsonEncode(_usuario!.toJson()));
    await prefs.setString(_accessTokenKey, _accessToken!);
    await prefs.setString(_refreshTokenKey, _refreshToken!);
  }

  Future<void> _limparSessao() async {
    _usuario = null;
    _accessToken = null;
    _refreshToken = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usuarioKey);
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }
}
