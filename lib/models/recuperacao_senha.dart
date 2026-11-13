// lib/models/recuperacao_senha.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo que representa o registro de recuperação de senha salvo
/// na coleção dedicada 'recuperacoes_senha' no Firestore.
class RecuperacaoSenha {
  final String? id;
  final String usuarioId;
  final String nome;
  final String email;
  final String? telefone;
  final String identificador;
  final String canal; // 'whatsapp' | 'email'
  final String codigo; // 6 dígitos
  final String status; // 'pendente' | 'enviado' | 'concluido' | 'expirado' | 'cancelado'
  final bool usado;
  final int tentativas;
  final DateTime criadoEm;
  final DateTime expiraEm;
  final DateTime? enviadoEm;
  final DateTime? concluidoEm;

  RecuperacaoSenha({
    this.id,
    required this.usuarioId,
    required this.nome,
    required this.email,
    this.telefone,
    required this.identificador,
    required this.canal,
    required this.codigo,
    this.status = 'pendente',
    this.usado = false,
    this.tentativas = 0,
    required this.criadoEm,
    required this.expiraEm,
    this.enviadoEm,
    this.concluidoEm,
  });

  bool get isExpirado => DateTime.now().isAfter(expiraEm);

  bool get isValido => !usado && !isExpirado && tentativas < 5 && status != 'cancelado';

  Map<String, dynamic> toMap() {
    return {
      'usuarioId': usuarioId,
      'nome': nome,
      'email': email,
      'telefone': telefone,
      'identificador': identificador,
      'canal': canal,
      'codigo': codigo,
      'status': status,
      'usado': usado,
      'tentativas': tentativas,
      'criadoEm': Timestamp.fromDate(criadoEm),
      'expiraEm': Timestamp.fromDate(expiraEm),
      if (enviadoEm != null) 'enviadoEm': Timestamp.fromDate(enviadoEm!),
      if (concluidoEm != null) 'concluidoEm': Timestamp.fromDate(concluidoEm!),
    };
  }

  factory RecuperacaoSenha.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    DateTime parseData(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    return RecuperacaoSenha(
      id: doc.id,
      usuarioId: data['usuarioId'] ?? '',
      nome: data['nome'] ?? '',
      email: data['email'] ?? '',
      telefone: data['telefone'],
      identificador: data['identificador'] ?? '',
      canal: data['canal'] ?? 'whatsapp',
      codigo: data['codigo'] ?? '',
      status: data['status'] ?? 'pendente',
      usado: data['usado'] ?? false,
      tentativas: (data['tentativas'] as num?)?.toInt() ?? 0,
      criadoEm: parseData(data['criadoEm'], DateTime.now()),
      expiraEm: parseData(data['expiraEm'], DateTime.now().add(const Duration(minutes: 15))),
      enviadoEm: data['enviadoEm'] != null ? parseData(data['enviadoEm'], DateTime.now()) : null,
      concluidoEm: data['concluidoEm'] != null ? parseData(data['concluidoEm'], DateTime.now()) : null,
    );
  }
}
