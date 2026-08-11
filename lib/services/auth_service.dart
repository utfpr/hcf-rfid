import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

class AuthUser {
  final String id;
  final String nome;
  final String email;
  final String? funcao;
  final String? permitionNome;

  const AuthUser({
    required this.id,
    required this.nome,
    required this.email,
    this.funcao,
    this.permitionNome,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        nome: json['nome'] as String,
        email: json['email'] as String,
        funcao: json['funcao'] as String?,
        permitionNome:
            (json['permition'] as Map<String, dynamic>?)?['nome'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'email': email,
        'funcao': funcao,
        'permitionNome': permitionNome,
      };

  factory AuthUser.fromStorage(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        nome: json['nome'] as String,
        email: json['email'] as String,
        funcao: json['funcao'] as String?,
        permitionNome: json['permitionNome'] as String?,
      );
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _storageKey = 'auth_user';

  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        _currentUser = AuthUser.fromStorage(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _currentUser = null;
        await prefs.remove(_storageKey);
      }
    }
  }

  Future<AuthUser> login(String email, String senha) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim(), 'senha': senha}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 401) {
      throw Exception('E-mail ou senha inválidos.');
    }
    if (response.statusCode != 200) {
      throw Exception('Erro ao autenticar (${response.statusCode}).');
    }

    final user = AuthUser.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
    _currentUser = user;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(user.toJson()));

    return user;
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
