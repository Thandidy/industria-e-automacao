// lib/utils/helpers.dart


import 'package:intl/intl.dart';
import 'constants.dart';

class Helpers {
  /// Converte um tempo em segundos para uma string formatada
  static String formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final minutosRestantes = minutes % 60;
    return '${hours}h ${minutosRestantes}m';
  }

  /// Formata uma data para o formato DD/MM/YYYY
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Formata uma data para o formato DD/MM/YYYY HH:mm
  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  /// Converte segundos para o formato HH:MM:SS
  static String formatHMS(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Extensão para converter String em StatusEquipamento (compatibilidade)
extension StringToStatusEquipamento on String {
  StatusEquipamento toStatusEquipamento() {
    switch (toLowerCase()) {
      case 'operando':
        return StatusEquipamento.operando;
      case 'parada':
        return StatusEquipamento.parada;
      case 'manutencao':
        return StatusEquipamento.manutencao;
      case 'aguardandomaterial':
        return StatusEquipamento.aguardandoMaterial;
      case 'aguardandoaprovacao':
        return StatusEquipamento.aguardandoAprovacao;
      case 'indisponivel':
        return StatusEquipamento.indisponivel;
      default:
        return StatusEquipamento.operando;
    }
  }
}