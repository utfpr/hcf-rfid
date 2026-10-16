import 'package:flutter/foundation.dart';

import 'rfid_service.dart';

/// RFIDs `CONCLUIDO` mantidos em memória durante a sessão (carregados no login/abertura do app).
class CatalogoRfidService extends ChangeNotifier {
  static final CatalogoRfidService _instance = CatalogoRfidService._internal();
  factory CatalogoRfidService() => _instance;
  CatalogoRfidService._internal();

  final RfidService _rfidService = RfidService();

  List<Rfid> _rfids = const [];
  Map<String, Rfid> _porTid = const {};
  bool _carregado = false;
  String? _erro;
  Future<void>? _carregamento;
  // Incrementada em limpar() para descartar uma carga iniciada na sessão anterior.
  int _geracao = 0;

  List<Rfid> get rfids => _rfids;
  bool get carregando => _carregamento != null;
  bool get carregado => _carregado;
  String? get erro => _erro;

  static String normalizarTid(String tid) => tid.trim().toUpperCase();

  Rfid? buscarPorTid(String tid) => _porTid[normalizarTid(tid)];

  /// Não faz nada se a lista já está em memória, a menos que [forcar]. Nunca lança: o erro fica em [erro].
  Future<void> carregar({bool forcar = false}) {
    final emAndamento = _carregamento;
    if (emAndamento != null) return emAndamento;
    if (_carregado && !forcar) return Future.value();

    final carregamento = _executarCarga(_geracao);
    _carregamento = carregamento;
    notifyListeners();
    return carregamento;
  }

  Future<void> _executarCarga(int geracao) async {
    try {
      final rfids = (await _rfidService.listar(status: 'CONCLUIDO'))
          .where((r) => r.tidValido)
          .toList();
      if (geracao != _geracao) return;
      _rfids = List.unmodifiable(rfids);
      _porTid = {for (final r in rfids) normalizarTid(r.tid!): r};
      _carregado = true;
      _erro = null;
    } catch (e) {
      if (geracao != _geracao) return;
      _erro = e.toString();
    } finally {
      if (geracao == _geracao) {
        _carregamento = null;
        notifyListeners();
      }
    }
  }

  void limpar() {
    _geracao++;
    _rfids = const [];
    _porTid = const {};
    _carregado = false;
    _erro = null;
    _carregamento = null;
    notifyListeners();
  }
}
