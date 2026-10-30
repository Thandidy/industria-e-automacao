// lib/models/usuario.dart


import '../utils/constants.dart';

class Usuario {
  final String id;
  final String nome;
  final String email;
  final String senha;
  final PerfilUsuario perfil;

  Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.senha,
    required this.perfil,
  });

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
    switch (perfil) {
      case PerfilUsuario.operador:
        return 'Operador';
      case PerfilUsuario.tecnico:
        return 'Técnico';
      case PerfilUsuario.supervisor:
        return 'Supervisor';
      case PerfilUsuario.gestor:
        return 'Gestor';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'perfil': perfil.index,
    };
  }

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] ?? '',
      nome: json['nome'] ?? '',
      email: json['email'] ?? '',
      senha: json['senha'] ?? '',
      perfil: PerfilUsuario.values[json['perfil'] ?? 0],
    );
  }
}