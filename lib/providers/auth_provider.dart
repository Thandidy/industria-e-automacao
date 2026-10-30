// lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../utils/constants.dart';

class AuthProvider extends ChangeNotifier {
  PerfilUsuario? _perfil;
  String? _userId;
  String? _nome;
  bool _autenticado = false;

  PerfilUsuario? get perfil => _perfil;
  String? get userId => _userId;
  String? get nome => _nome;
  bool get autenticado => _autenticado;

  Usuario? get usuario => _autenticado && _perfil != null
      ? Usuario(
          id: _userId ?? '',
          nome: _nome ?? 'Usuário',
          email: '${_userId ?? "usuario"}@empresa.com',
          senha: '',
          perfil: _perfil!,
        )
      : null;

  // Usuários mockados para testes
  static final Map<String, PerfilUsuario> usuariosMock = {
    'operador1': PerfilUsuario.operador,
    'tecnico1': PerfilUsuario.tecnico,
    'supervisor1': PerfilUsuario.supervisor,
    'gestor1': PerfilUsuario.gestor,
  };

  Future<void> login(String userId, String password, PerfilUsuario perfil) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Simulação de atraso de rede
    _userId = userId;
    _perfil = perfil;
    _nome = _obterNome(perfil);
    _autenticado = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _userId = null;
    _perfil = null;
    _nome = null;
    _autenticado = false;
    notifyListeners();
  }

  // Login rápido com perfis mockados
  Future<void> loginRapido(PerfilUsuario perfil) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _userId = 'user_${perfil.index + 1}';
    _perfil = perfil;
    _nome = _obterNome(perfil);
    _autenticado = true;
    notifyListeners();
  }

  String _obterNome(PerfilUsuario perfil) {
    switch (perfil) {
      case PerfilUsuario.operador:
        return 'João Silva - Operador';
      case PerfilUsuario.tecnico:
        return 'Carlos Mendes - Técnico';
      case PerfilUsuario.supervisor:
        return 'Ana Costa - Supervisor';
      case PerfilUsuario.gestor:
        return 'Roberto Lima - Gestor';
    }
  }

  bool temAcesso(PerfilUsuario perfilNecessario) {
    if (!_autenticado) return false;
    // Gestor tem acesso a tudo
    if (_perfil == PerfilUsuario.gestor) return true;
    return _perfil == perfilNecessario;
  }
}
