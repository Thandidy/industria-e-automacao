// lib/models/equipamento.dart

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import '../models/usuario.dart';
import '../utils/constants.dart';

class Equipamento {
  final String id;
  final String tag;
  final String nome;
  final String localizacao;
  final StatusEquipamento status;
  final bool grauCritico;
  final bool aprovadaManutencao;
  final String? tecnicoDesignado;
  final String? tecnicoDesignadoId;
  final DateTime ultimoAtualizacao;
  final DateTime? ultimaParada;
  final String? motivoParada;
  final PerfilUsuario? responsavel;
  final double tempoOperacaoTotal;
  final int numeroParadas;
  final int tempoParado;
  final bool solicitouMaterial;

  Equipamento({
    required this.id,
    required this.tag,
    required this.nome,
    required this.localizacao,
    required this.status,
    this.grauCritico = false,
    this.aprovadaManutencao = false,
    this.tecnicoDesignado,
    this.tecnicoDesignadoId,
    required this.ultimoAtualizacao,
    this.ultimaParada,
    this.motivoParada,
    this.responsavel,
    this.tempoOperacaoTotal = 0.0,
    this.numeroParadas = 0,
    this.tempoParado = 0,
    this.solicitouMaterial = false,
  });

  factory Equipamento.vazio(String id) {
    return Equipamento(
      id: id,
      tag: 'MTG-$id',
      nome: 'Equipamento $id',
      localizacao: 'Setor 1',
      status: StatusEquipamento.operando,
      grauCritico: false,
      aprovadaManutencao: false,
      tecnicoDesignado: null,
      tecnicoDesignadoId: null,
      ultimoAtualizacao: DateTime.now(),
      ultimaParada: null,
      motivoParada: null,
      responsavel: null,
      tempoOperacaoTotal: 0.0,
      numeroParadas: 0,
      tempoParado: 0,
    );
  }

  Equipamento copyWith({
    String? id,
    String? tag,
    String? nome,
    String? localizacao,
    StatusEquipamento? status,
    bool? grauCritico,
    bool? aprovadaManutencao,
    String? tecnicoDesignado,
    String? tecnicoDesignadoId,
    DateTime? ultimoAtualizacao,
    DateTime? ultimaParada,
    String? motivoParada,
    PerfilUsuario? responsavel,
    double? tempoOperacaoTotal,
    int? numeroParadas,
    int? tempoParado,
    bool? solicitouMaterial,
  }) {
    return Equipamento(
      id: id ?? this.id,
      tag: tag ?? this.tag,
      nome: nome ?? this.nome,
      localizacao: localizacao ?? this.localizacao,
      status: status ?? this.status,
      grauCritico: grauCritico ?? this.grauCritico,
      aprovadaManutencao: aprovadaManutencao ?? this.aprovadaManutencao,
      tecnicoDesignado: tecnicoDesignado ?? this.tecnicoDesignado,
      tecnicoDesignadoId: tecnicoDesignadoId ?? this.tecnicoDesignadoId,
      ultimoAtualizacao: ultimoAtualizacao ?? this.ultimoAtualizacao,
      ultimaParada: ultimaParada ?? this.ultimaParada,
      motivoParada: motivoParada ?? this.motivoParada,
      responsavel: responsavel ?? this.responsavel,
      tempoOperacaoTotal: tempoOperacaoTotal ?? this.tempoOperacaoTotal,
      numeroParadas: numeroParadas ?? this.numeroParadas,
      tempoParado: tempoParado ?? this.tempoParado,
      solicitouMaterial: solicitouMaterial ?? this.solicitouMaterial,
    );
  }

  /// Verifica se há um técnico especificamente designado para este equipamento
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

  /// Nome formatado do status com destaque para o estado crítico
  String get statusNome {
    // Estado X: Parada crítica pendente de aprovação do supervisor
    if (status == StatusEquipamento.aguardandoAprovacao ||
        (grauCritico && !aprovadaManutencao && status != StatusEquipamento.operando)) {
      return 'Aguardando Aprovação';
    }
    // Estado Y: Parada crítica já aprovada com técnico designado
    if (grauCritico && aprovadaManutencao && status == StatusEquipamento.parada) {
      if (tecnicoDesignado != null && tecnicoDesignado!.isNotEmpty) {
        return 'Aprovada ($tecnicoDesignado)';
      }
      return 'Aprovada p/ Manutenção';
    }
    return status.nome;
  }

  /// Ícone dinâmico: Estado X (precisa de aprovação) vs Estado Y (aprovada para manutenção)
  IconData get statusIcon {
    // Estado X: Precisa de aprovação pelo supervisor para manutenção
    if (status == StatusEquipamento.aguardandoAprovacao ||
        (grauCritico && !aprovadaManutencao && status != StatusEquipamento.operando)) {
      return Icons.pending_actions; // Ícone X: Aguardando aprovação
    }
    // Estado Y: Aprovada para manutenção com técnico designado
    if (grauCritico && aprovadaManutencao && status == StatusEquipamento.parada) {
      return Icons.assignment_turned_in; // Ícone Y: Aprovada com técnico designado
    }
    return status.icon;
  }

  /// Cor dinâmica de status
  Color get statusColor {
    // Estado X: Alerta em cor âmbar/roxo
    if (status == StatusEquipamento.aguardandoAprovacao ||
        (grauCritico && !aprovadaManutencao && status != StatusEquipamento.operando)) {
      return AppCores.aguardandoAprovacao;
    }
    // Estado Y: Destaque positivo em ciano/teal para aprovação concedida
    if (grauCritico && aprovadaManutencao && status == StatusEquipamento.parada) {
      return Colors.tealAccent.shade700;
    }
    return status.cor(status);
  }

  String get formatoUltimaAtualizacao =>
      DateFormat('dd/MM/yyyy HH:mm').format(ultimoAtualizacao);

  String get formatoTempoParado => _formatarDuracao(tempoParado);

  static String _formatarDuracao(int segundos) {
    if (segundos < 60) return '${segundos}s';
    final minutos = segundos ~/ 60;
    if (minutos < 60) return '${minutos}m';
    final horas = minutos ~/ 60;
    return '${horas}h';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tag': tag,
      'nome': nome,
      'localizacao': localizacao,
      'status': status.index,
      'grauCritico': grauCritico,
      'aprovadaManutencao': aprovadaManutencao,
      'tecnicoDesignado': tecnicoDesignado,
      'tecnicoDesignadoId': tecnicoDesignadoId,
      'ultimoAtualizacao': ultimoAtualizacao.toIso8601String(),
      'ultimaParada': ultimaParada?.toIso8601String(),
      'motivoParada': motivoParada,
      'responsavel': responsavel?.index,
      'tempoOperacaoTotal': tempoOperacaoTotal,
      'numeroParadas': numeroParadas,
      'tempoParado': tempoParado,
      'solicitouMaterial': solicitouMaterial,
    };
  }

  factory Equipamento.fromJson(Map<String, dynamic> json) {
    return Equipamento(
      id: json['id'] ?? '',
      tag: json['tag'] ?? '',
      nome: json['nome'] ?? '',
      localizacao: json['localizacao'] ?? '',
      status: StatusEquipamento.values[json['status'] ?? 0],
      grauCritico: json['grauCritico'] == true,
      aprovadaManutencao: json['aprovadaManutencao'] == true,
      tecnicoDesignado: json['tecnicoDesignado']?.toString(),
      tecnicoDesignadoId: json['tecnicoDesignadoId']?.toString(),
      ultimoAtualizacao: DateTime.parse(json['ultimoAtualizacao'] ?? DateTime.now().toIso8601String()),
      ultimaParada: json['ultimaParada'] != null ? DateTime.parse(json['ultimaParada']) : null,
      motivoParada: json['motivoParada'],
      responsavel: json['responsavel'] != null ? PerfilUsuario.values[json['responsavel']] : null,
      tempoOperacaoTotal: (json['tempoOperacaoTotal'] ?? 0).toDouble(),
      numeroParadas: json['numeroParadas'] ?? 0,
      tempoParado: json['tempoParado'] ?? 0,
      solicitouMaterial: json['solicitouMaterial'] == true ||
          json['status'] == StatusEquipamento.aguardandoMaterial.index ||
          json['status']?.toString() == 'aguardandoMaterial',
    );
  }
}
