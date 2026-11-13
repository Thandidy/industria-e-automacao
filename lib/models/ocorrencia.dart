// lib/models/ocorrencia.dart

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/historico.dart';
import '../models/usuario.dart';
import '../utils/constants.dart';

class Ocorrencia {
  final String id;
  final String equipamentoId;
  final String equipamentoTag;
  final String motivo;
  final String descricao;
  final String prioridade;
  final StatusOcorrencia status;
  final bool aprovadaManutencao;
  final String? tecnicoDesignado;
  final String? tecnicoDesignadoId;
  final DateTime dataAbertura;
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final String? tecnicoResponsavel;
  final String? tecnicoFinalizou;
  final String? observacaoFinal;
  final String? laudoTecnico;
  final List<String> pecasTrocadas;
  final DateTime? proximaManutencao;
  final List<HistoricoItem> historico;
  final bool solicitouMaterial;
  final String? motivoPausaMaterial;

  Ocorrencia({
    String? id,
    required this.equipamentoId,
    required this.equipamentoTag,
    required this.motivo,
    required this.descricao,
    required this.prioridade,
    this.status = StatusOcorrencia.aberta,
    this.aprovadaManutencao = false,
    this.tecnicoDesignado,
    this.tecnicoDesignadoId,
    required this.dataAbertura,
    this.dataInicio,
    this.dataFim,
    this.tecnicoResponsavel,
    this.tecnicoFinalizou,
    this.observacaoFinal,
    this.laudoTecnico,
    this.pecasTrocadas = const [],
    this.proximaManutencao,
    List<HistoricoItem>? historico,
    this.solicitouMaterial = false,
    this.motivoPausaMaterial,
  }) : id = id ?? const Uuid().v4(),
       historico = historico ?? [];

  bool get ehCritica => prioridade.toLowerCase().trim() == 'crítica' || prioridade.toLowerCase().trim() == 'critica';
  bool get precisaAprovacao => ehCritica && !aprovadaManutencao && status != StatusOcorrencia.finalizada;

  /// Verifica se há um técnico especificamente designado para esta manutenção
  bool get temTecnicoDesignado =>
      (tecnicoDesignadoId != null && tecnicoDesignadoId!.trim().isNotEmpty) ||
      (tecnicoDesignado != null && tecnicoDesignado!.trim().isNotEmpty);

  /// Verifica se o usuário informado é o técnico especificamente designado
  bool ehTecnicoDesignado(Usuario? usuario) {
    if (usuario == null || !temTecnicoDesignado) return false;
    final idBate = tecnicoDesignadoId != null &&
        tecnicoDesignadoId!.trim().isNotEmpty &&
        tecnicoDesignadoId == usuario.id;
    final nomeBate = tecnicoDesignado != null &&
        tecnicoDesignado!.trim().isNotEmpty &&
        tecnicoDesignado!.trim().toLowerCase() == usuario.nome.trim().toLowerCase();
    return idBate || nomeBate;
  }

  String get duracaoSegundos {
    if (dataInicio == null) return '0';
    if (dataFim == null) {
      return DateTime.now().difference(dataInicio!).inSeconds.toString();
    }
    return dataFim!.difference(dataInicio!).inSeconds.toString();
  }

  String get duracaoFormatada {
    if (dataFim == null && dataInicio == null) return 'Não iniciado';
    if (dataFim == null) {
      return _formatarDuracao(DateTime.now().difference(dataInicio!).inSeconds);
    }
    return _formatarDuracao(dataFim!.difference(dataInicio!).inSeconds);
  }

  String get tempoAbertoFormatado {
    return _formatarDuracao(DateTime.now().difference(dataAbertura).inSeconds);
  }

  IconData get prioridadeIcon {
    switch (prioridade) {
      case 'Baixa':
        return Icons.arrow_downward;
      case 'Média':
        return Icons.remove_circle_outline;
      case 'Alta':
        return Icons.error_outline;
      case 'Crítica':
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  Color get prioridadeColor {
    switch (prioridade) {
      case 'Baixa':
        return Colors.green;
      case 'Média':
        return Colors.amber;
      case 'Alta':
        return Colors.orange;
      case 'Crítica':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool get podeIniciar {
    if (status == StatusOcorrencia.emAndamento || status == StatusOcorrencia.finalizada) {
      return false;
    }
    if (ehCritica) {
      return aprovadaManutencao;
    }
    return status == StatusOcorrencia.aberta;
  }

  bool get podeFinalizar => status == StatusOcorrencia.emAndamento;

  static String _formatarDuracao(int segundos) {
    if (segundos < 60) return '${segundos}s';
    final minutos = segundos ~/ 60;
    if (minutos < 60) return '${minutos}m';
    final horas = minutos ~/ 60;
    final minutosRestantes = minutos % 60;
    return '${horas}h ${minutosRestantes}m';
  }

  Ocorrencia copyWith({
    String? id,
    String? equipamentoId,
    String? equipamentoTag,
    String? motivo,
    String? descricao,
    String? prioridade,
    StatusOcorrencia? status,
    bool? aprovadaManutencao,
    String? tecnicoDesignado,
    String? tecnicoDesignadoId,
    DateTime? dataAbertura,
    DateTime? dataInicio,
    DateTime? dataFim,
    String? tecnicoResponsavel,
    String? tecnicoFinalizou,
    String? observacaoFinal,
    String? laudoTecnico,
    List<String>? pecasTrocadas,
    DateTime? proximaManutencao,
    List<HistoricoItem>? historico,
    bool? solicitouMaterial,
    String? motivoPausaMaterial,
  }) {
    return Ocorrencia(
      id: id ?? this.id,
      equipamentoId: equipamentoId ?? this.equipamentoId,
      equipamentoTag: equipamentoTag ?? this.equipamentoTag,
      motivo: motivo ?? this.motivo,
      descricao: descricao ?? this.descricao,
      prioridade: prioridade ?? this.prioridade,
      status: status ?? this.status,
      aprovadaManutencao: aprovadaManutencao ?? this.aprovadaManutencao,
      tecnicoDesignado: tecnicoDesignado ?? this.tecnicoDesignado,
      tecnicoDesignadoId: tecnicoDesignadoId ?? this.tecnicoDesignadoId,
      dataAbertura: dataAbertura ?? this.dataAbertura,
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
      tecnicoResponsavel: tecnicoResponsavel ?? this.tecnicoResponsavel,
      tecnicoFinalizou: tecnicoFinalizou ?? this.tecnicoFinalizou,
      observacaoFinal: observacaoFinal ?? this.observacaoFinal,
      laudoTecnico: laudoTecnico ?? this.laudoTecnico,
      pecasTrocadas: pecasTrocadas ?? this.pecasTrocadas,
      proximaManutencao: proximaManutencao ?? this.proximaManutencao,
      historico: historico ?? this.historico,
      solicitouMaterial: solicitouMaterial ?? this.solicitouMaterial,
      motivoPausaMaterial: motivoPausaMaterial ?? this.motivoPausaMaterial,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'equipamentoId': equipamentoId,
      'equipamentoTag': equipamentoTag,
      'motivo': motivo,
      'descricao': descricao,
      'prioridade': prioridade,
      'status': status.index,
      'aprovadaManutencao': aprovadaManutencao,
      'tecnicoDesignado': tecnicoDesignado,
      'tecnicoDesignadoId': tecnicoDesignadoId,
      'dataAbertura': dataAbertura.toIso8601String(),
      'dataInicio': dataInicio?.toIso8601String(),
      'dataFim': dataFim?.toIso8601String(),
      'tecnicoResponsavel': tecnicoResponsavel,
      'tecnicoFinalizou': tecnicoFinalizou ?? tecnicoResponsavel,
      'observacaoFinal': observacaoFinal,
      'laudoTecnico': laudoTecnico ?? observacaoFinal,
      'parecerTecnico': laudoTecnico ?? observacaoFinal,
      'pecasTrocadas': pecasTrocadas,
      'proximaManutencao': proximaManutencao?.toIso8601String(),
      'historico': historico.map((h) => h.toJson()).toList(),
      'solicitouMaterial': solicitouMaterial,
      'motivoPausaMaterial': motivoPausaMaterial,
    };
  }

  factory Ocorrencia.fromJson(Map<String, dynamic> json) {
    return Ocorrencia(
      id: json['id'],
      equipamentoId: json['equipamentoId'] ?? '',
      equipamentoTag: json['equipamentoTag'] ?? '',
      motivo: json['motivo'] ?? '',
      descricao: json['descricao'] ?? '',
      prioridade: json['prioridade'] ?? 'Média',
      status: StatusOcorrencia.values[json['status'] ?? 0],
      aprovadaManutencao: json['aprovadaManutencao'] == true,
      tecnicoDesignado: json['tecnicoDesignado']?.toString(),
      tecnicoDesignadoId: json['tecnicoDesignadoId']?.toString(),
      dataAbertura: DateTime.parse(json['dataAbertura'] ?? DateTime.now().toIso8601String()),
      dataInicio: json['dataInicio'] != null ? DateTime.parse(json['dataInicio']) : null,
      dataFim: json['dataFim'] != null ? DateTime.parse(json['dataFim']) : null,
      tecnicoResponsavel: json['tecnicoResponsavel']?.toString(),
      tecnicoFinalizou: json['tecnicoFinalizou']?.toString() ?? json['tecnicoResponsavel']?.toString(),
      observacaoFinal: json['observacaoFinal']?.toString(),
      laudoTecnico: json['laudoTecnico']?.toString() ?? json['parecerTecnico']?.toString() ?? json['observacaoFinal']?.toString(),
      pecasTrocadas: List<String>.from(json['pecasTrocadas'] ?? []),
      proximaManutencao: json['proximaManutencao'] != null ? DateTime.parse(json['proximaManutencao']) : null,
      historico: (json['historico'] as List? ?? [])
          .map((h) => HistoricoItem.fromJson(h))
          .toList(),
      solicitouMaterial: json['solicitouMaterial'] == true ||
          json['status'] == StatusOcorrencia.aguardandoMaterial.index ||
          json['status']?.toString() == 'aguardandoMaterial',
      motivoPausaMaterial: json['motivoPausaMaterial']?.toString(),
    );
  }
}
