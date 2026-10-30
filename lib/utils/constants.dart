// lib/utils/constants.dart

import 'package:flutter/material.dart';

// ===== Enums =====

enum StatusEquipamento {
  operando,
  parada,
  manutencao,
  aguardandoMaterial,
  indisponivel,
}

enum PerfilUsuario { operador, tecnico, supervisor, gestor }

enum StatusOcorrencia {
  aberta,
  emAndamento,
  finalizada,
}

// ===== Extensions =====

extension StatusEquipamentoExtension on StatusEquipamento {
  String get nome {
    switch (this) {
      case StatusEquipamento.operando:
        return 'Operando';
      case StatusEquipamento.parada:
        return 'Parada';
      case StatusEquipamento.manutencao:
        return 'Manutenção';
      case StatusEquipamento.aguardandoMaterial:
        return 'Aguardando Material';
      case StatusEquipamento.indisponivel:
        return 'Indisponível';
    }
  }

  IconData get icon {
    switch (this) {
      case StatusEquipamento.operando:
        return Icons.check_circle;
      case StatusEquipamento.parada:
        return Icons.stop_circle;
      case StatusEquipamento.manutencao:
        return Icons.build;
      case StatusEquipamento.aguardandoMaterial:
        return Icons.inventory_2;
      case StatusEquipamento.indisponivel:
        return Icons.cancel;
    }
  }

  Color cor(StatusEquipamento status) {
    switch (status) {
      case StatusEquipamento.operando:
        return AppCores.operando;
      case StatusEquipamento.parada:
        return AppCores.parada;
      case StatusEquipamento.manutencao:
        return AppCores.manutencao;
      case StatusEquipamento.aguardandoMaterial:
        return AppCores.aguardandoMaterial;
      case StatusEquipamento.indisponivel:
        return AppCores.indisponivel;
    }
  }
}

extension PerfilUsuarioExtension on PerfilUsuario {
  String get nome {
    switch (this) {
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

  IconData get icon {
    switch (this) {
      case PerfilUsuario.operador:
        return Icons.engineering;
      case PerfilUsuario.tecnico:
        return Icons.build_circle;
      case PerfilUsuario.supervisor:
        return Icons.supervisor_account;
      case PerfilUsuario.gestor:
        return Icons.dashboard;
    }
  }
}

extension StatusOcorrenciaExtension on StatusOcorrencia {
  String get nome {
    switch (this) {
      case StatusOcorrencia.aberta:
        return 'Aberta';
      case StatusOcorrencia.emAndamento:
        return 'Em Andamento';
      case StatusOcorrencia.finalizada:
        return 'Finalizada';
    }
  }
}

// ===== Cores =====

class AppCores {
  // Tema industrial escuro
  static const Color background = Color(0xFF1A1D23);
  static const Color surface = Color(0xFF252A33);
  static const Color surfaceVariant = Color(0xFF3A404D);
  static const Color onBackground = Color(0xFFE8ECEF);
  static const Color onSurface = Color(0xFFE8ECEF);
  static const Color onSurfaceVariant = Color(0xFFB8C1D0);

  // Azul petróleo
  static const Color primary = Color(0xFF1E3A5F);
  static const Color primaryVariant = Color(0xFF152A42);

  // Detalhes
  static const Color amareloAlerta = Color(0xFFFFC107);
  static const Color laranjaAlerta = Color(0xFFFF9800);

  // Status
  static const Color operando = Color(0xFF4CAF50);
  static const Color parada = Color(0xFFFF5722);
  static const Color manutencao = Color(0xFF2196F3);
  static const Color aguardandoMaterial = Color(0xFFFF9800);
  static const Color indisponivel = Color(0xFF9C27B0);
}
