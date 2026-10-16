import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'catalogo_rfid_service.dart';

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
        id: lerInt(json['id']),
        nome: json['nome'] as String,
        email: json['email'] as String,
        tipoUsuarioId: lerInt(json['tipo_usuario_id']),
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
  static const String _tokenKey = 'auth_token';
  static const Duration _timeout = Duration(seconds: 10);

  /// Chamado quando o token expira e o usuário precisa logar de novo.
  void Function()? aoExpirarSessao;

  Usuario? _usuario;
  String? _token;

  Usuario? get usuario => _usuario;
  String? get token => _token;
  bool get isLoggedIn => _usuario != null && _token != null;

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usuarioKey);
    _token = prefs.getString(_tokenKey);

    // Sessões da API antiga não têm token: força novo login.
    if (raw == null || _token == null) {
      await _limparSessao();
      return;
    }
    try {
      _usuario = Usuario.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await _limparSessao();
      return;
    }
    unawaited(CatalogoRfidService().carregar());
  }

  Future<Usuario> login(String email, String senha) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim(), 'senha': senha}),
        )
        .timeout(_timeout);

    // Credenciais inválidas: 400 (código 100).
    if (response.statusCode == 400 || response.statusCode == 401) {
      throw Exception('E-mail ou senha inválidos.');
    }
    // Validação do corpo (código 50): e-mail em formato inválido.
    if (response.statusCode == 422) {
      throw Exception('E-mail inválido.');
    }
    if (response.statusCode == 429) {
      throw Exception(
          'Muitas tentativas de login. Tente novamente em alguns minutos.');
    }
    if (response.statusCode != 200) {
      throw Exception('Erro ao autenticar (${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    _token = json['token'] as String;
    _usuario = Usuario.fromJson(json['usuario'] as Map<String, dynamic>);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usuarioKey, jsonEncode(_usuario!.toJson()));
    await prefs.setString(_tokenKey, _token!);

    unawaited(CatalogoRfidService().carregar());
    return _usuario!;
  }

  /// O token de /login não tem renovação: ao expirar, encerra a sessão e volta ao login.
  Future<void> expirarSessao() async {
    // Várias requisições podem expirar juntas; só a primeira notifica.
    if (_token == null) return;
    await _limparSessao();
    aoExpirarSessao?.call();
  }

  /// A API não tem logout para o token de /login: basta descartá-lo.
  Future<void> logout() => _limparSessao();

  Future<void> _limparSessao() async {
    _usuario = null;
    _token = null;
    CatalogoRfidService().limpar();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usuarioKey);
    await prefs.remove(_tokenKey);
  }
}
