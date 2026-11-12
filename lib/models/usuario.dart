// lib/models/usuario.dart

import '../utils/constants.dart';

class Usuario {
  final String id;
  final String nome;
  final String email;
  final String senha;
  final PerfilUsuario perfil;
  final String? telefone;

  Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.senha,
    required this.perfil,
    this.telefone,
  });

  /// Verifica se o usuário possui a permissão especificada
  bool can(AppPermission permission) => perfil.permissions.contains(permission);

  /// Verifica se possui qualquer uma das permissões fornecidas
  bool canAny(Iterable<AppPermission> permissions) => permissions.any(can);

  /// Atalhos de papéis
  bool get ehOperador => perfil == PerfilUsuario.operador;
  bool get ehTecnico => perfil == PerfilUsuario.tecnico;
  bool get ehSupervisor => perfil == PerfilUsuario.supervisor;
  bool get ehGestor => perfil == PerfilUsuario.gestor;

  static PerfilUsuario getPerfilFromIndex(int index) {
    switch (index) {
      case 0:
        return PerfilUsuario.operador;
      case 1:
        return PerfilUsuario.tecnico;
      case 2:
        return PerfilUsuario.supervisor;
      case 3:
        return PerfilUsuario.gestor;
      default:
        return PerfilUsuario.operador;
    }
  }

  static String perfilToString(PerfilUsuario perfil) {
    return perfil.nome;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'perfil': perfil.index,
      'telefone': telefone,
    };
  }

  factory Usuario.fromJson(Map<String, dynamic> json) {
    PerfilUsuario perfil;
    if (json['perfil'] is int) {
      final idx = json['perfil'] as int;
      perfil = (idx >= 0 && idx < PerfilUsuario.values.length)
          ? PerfilUsuario.values[idx]
          : PerfilUsuario.operador;
    } else if (json['perfil'] is String) {
      final str = (json['perfil'] as String).toLowerCase().trim();
      perfil = PerfilUsuario.values.firstWhere(
        (p) => p.name.toLowerCase() == str,
        orElse: () => PerfilUsuario.operador,
      );
    } else {
      perfil = PerfilUsuario.operador;
    }

    return Usuario(
      id: json['id'] ?? '',
      nome: json['nome'] ?? json['nomeFuncionario'] ?? '',
      email: json['email'] ?? '',
      senha: json['senha'] ?? '',
      perfil: perfil,
      telefone: json['telefone']?.toString(),
    );
  }
}
