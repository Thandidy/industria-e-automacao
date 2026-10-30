// lib/models/historico.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../utils/constants.dart';

class HistoricoItem {
  final String id;
  final DateTime data;
  final String tipo; // 'abertura', 'inicio', 'finalizacao', 'alteracao_status'
  final String descricao;
  final String? por; // nome do usuário
  final StatusOcorrencia? statusOcorrencia;
  final StatusEquipamento? statusEquipamento;

  HistoricoItem({
    String? id,
    required this.data,
    required this.tipo,
    required this.descricao,
    this.por,
    this.statusOcorrencia,
    this.statusEquipamento,
  }) : id = id ?? const Uuid().v4();

  String get dataFormatada => DateFormat('dd/MM/yyyy HH:mm').format(data);

  IconData get tipoIcon {
    switch (tipo) {
      case 'abertura':
        return Icons.report_problem;
      case 'inicio':
        return Icons.play_circle;
      case 'finalizacao':
        return Icons.check_circle;
      case 'alteracao_status':
        return Icons.update;
      default:
        return Icons.info;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'data': data.toIso8601String(),
      'tipo': tipo,
      'descricao': descricao,
      'por': por,
      'statusOcorrencia': statusOcorrencia?.index,
      'statusEquipamento': statusEquipamento?.index,
    };
  }

  factory HistoricoItem.fromJson(Map<String, dynamic> json) {
    return HistoricoItem(
      id: json['id'],
      data: DateTime.parse(json['data'] ?? DateTime.now().toIso8601String()),
      tipo: json['tipo'] ?? '',
      descricao: json['descricao'] ?? '',
      por: json['por'],
      statusOcorrencia: json['statusOcorrencia'] != null
          ? StatusOcorrencia.values[json['statusOcorrencia']]
          : null,
      statusEquipamento: json['statusEquipamento'] != null
          ? StatusEquipamento.values[json['statusEquipamento']]
          : null,
    );
  }
}