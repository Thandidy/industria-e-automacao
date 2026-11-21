// lib/utils/constants.dart

import 'package:material_ui/material_ui.dart';

// ===== Enums =====

enum StatusEquipamento {
  operando,
  parada,
  manutencao,
  aguardandoMaterial,
  aguardandoAprovacao,
  indisponivel,
}

enum PerfilUsuario { operador, tecnico, supervisor, gestor }

enum StatusOcorrencia {
  aberta,
  emAndamento,
  aguardandoMaterial,
  aguardandoAprovacao,
  finalizada,
}

/// Permissões atômicas do sistema RBAC (Role-Based Access Control)
enum AppPermission {
  // 1. Operador (Chão de fábrica)
  visualizarMaquinas,
  registrarParadaCritica,
  solicitarAtendimento,

  // 2. Técnico de Manutenção (Equipe técnica)
  assumirManutencao,
  pausarAguardandoMaterial,
  finalizarComLaudo,

  // 3. Supervisor (Gestão de turno)
  filtrosAvancadosIndisponibilidade,
  reatribuirPrioridade,
  contraAssinarRetorno,
  entregarMaterial,
  atribuirTecnico,

  // 4. Gestor Industrial (Administrador/Macro)
  visualizarDashboardKpi,
  crudMaquinas, // Permissão EXCLUSIVA: cadastrar e remover máquinas
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
      case StatusEquipamento.aguardandoAprovacao:
        return 'Aguardando Aprovação';
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
      case StatusEquipamento.aguardandoAprovacao:
        return Icons.pending_actions;
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
      case StatusEquipamento.aguardandoAprovacao:
        return AppCores.aguardandoAprovacao;
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
        return 'Gestor Industrial';
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
        return Icons.admin_panel_settings;
    }
  }

  /// Matriz RBAC com as permissões atribuídas a cada cargo
  Set<AppPermission> get permissions {
    switch (this) {
      case PerfilUsuario.operador:
        return {
          AppPermission.visualizarMaquinas,
          AppPermission.registrarParadaCritica,
          AppPermission.solicitarAtendimento,
        };

      case PerfilUsuario.tecnico:
        return {
          AppPermission.visualizarMaquinas,
          AppPermission.assumirManutencao,
          AppPermission.pausarAguardandoMaterial,
          AppPermission.finalizarComLaudo,
        };

      case PerfilUsuario.supervisor:
        return {
          AppPermission.visualizarMaquinas,
          AppPermission.filtrosAvancadosIndisponibilidade,
          AppPermission.reatribuirPrioridade,
          AppPermission.contraAssinarRetorno,
          AppPermission.entregarMaterial,
          AppPermission.atribuirTecnico,
          AppPermission.visualizarDashboardKpi,
        };

      case PerfilUsuario.gestor:
        // Gestor Industrial: acesso exclusivo a Relatórios & KPIs, Gerenciamento de Máquinas (CRUD) e visualização
        return {
          AppPermission.visualizarMaquinas,
          AppPermission.visualizarDashboardKpi,
          AppPermission.crudMaquinas,
        };
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
      case StatusOcorrencia.aguardandoMaterial:
        return 'Aguardando Material';
      case StatusOcorrencia.aguardandoAprovacao:
        return 'Aguardando Aprovação';
      case StatusOcorrencia.finalizada:
        return 'Finalizada';
    }
  }

  Color get cor {
    switch (this) {
      case StatusOcorrencia.aberta:
        return Colors.orange;
      case StatusOcorrencia.emAndamento:
        return Colors.blue;
      case StatusOcorrencia.aguardandoMaterial:
        return Colors.amber;
      case StatusOcorrencia.aguardandoAprovacao:
        return Colors.purple;
      case StatusOcorrencia.finalizada:
        return Colors.green;
    }
  }

  IconData get icon {
    switch (this) {
      case StatusOcorrencia.aberta:
        return Icons.error_outline;
      case StatusOcorrencia.emAndamento:
        return Icons.play_circle;
      case StatusOcorrencia.aguardandoMaterial:
        return Icons.inventory_2_outlined;
      case StatusOcorrencia.aguardandoAprovacao:
        return Icons.verified_user_outlined;
      case StatusOcorrencia.finalizada:
        return Icons.check_circle;
    }
  }
}

// ===== Cores =====

class AppCores {
  // Base Branco e Roxo Corporativo (SIGE - Alta Legibilidade)
  static const Color background = Color(0xFFF8F9FD); // Fundo limpo, claro e suave
  static const Color surface = Color(0xFFFFFFFF); // Branco puro para cards e modais
  static const Color surfaceVariant = Color(0xFFF1F3F9); // Elementos secundários suaves
  static const Color border = Color(0xFFE2E8F0); // Borda sutil e elegante
  static const Color onBackground = Color(0xFF1E1B4B); // Texto escuro (Deep Indigo)
  static const Color onSurface = Color(0xFF1E1B4B); // Texto principal cristalino
  static const Color onSurfaceVariant = Color(0xFF64748B); // Texto secundário (Slate 500)

  // Roxo Corporativo SIGE (Identidade Visual dos Menus e Destaques)
  static const Color primary = Color(0xFF6D28D9); // Roxo vibrante e moderno (Purple 700)
  static const Color primaryVariant = Color(0xFF581C87); // Roxo profundo para contrastes (Purple 900)
  static const Color primaryLight = Color(0xFFEDE9FE); // Roxo pastel para badges e highlights

  // Detalhes e Alertas
  static const Color amareloAlerta = Color(0xFFF59E0B);
  static const Color laranjaAlerta = Color(0xFFEA580C);

  // Status Funcionais Preservados (Cores de cada função intactas)
  static const Color operando = Color(0xFF16A34A); // Verde
  static const Color parada = Color(0xFFDC2626); // Vermelho
  static const Color manutencao = Color(0xFF2563EB); // Azul
  static const Color aguardandoMaterial = Color(0xFFD97706); // Âmbar / Laranja
  static const Color aguardandoAprovacao = Color(0xFF7C3AED); // Roxo
  static const Color indisponivel = Color(0xFF64748B); // Cinza
}
