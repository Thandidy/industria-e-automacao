// lib/providers/equipamento_provider.dart

import 'package:flutter/material.dart';
import '../models/equipamento.dart';
import '../utils/constants.dart';

class EquipamentoProvider extends ChangeNotifier {
  List<Equipamento> _equipamentos = [];
  bool _isLoading = false;

  List<Equipamento> get equipamentos => _equipamentos;
  bool get isLoading => _isLoading;

  Map<String, Equipamento> get equipamentosPorId => {
        for (final e in _equipamentos) e.id: e,
      };

  Map<StatusEquipamento, int> get statusCounts {
    final counts = <StatusEquipamento, int>{
      for (final s in StatusEquipamento.values) s: 0,
    };
    for (final e in _equipamentos) {
      counts[e.status] = (counts[e.status] ?? 0) + 1;
    }
    return counts;
  }

  EquipamentoProvider() {
    _carregarMockData();
  }

  void _carregarMockData() {
    _equipamentos = [
      Equipamento(
        id: 'eq-1',
        tag: 'CNC-01',
        nome: 'Torno CNC Operacional',
        localizacao: 'Setor de Usinagem A',
        status: StatusEquipamento.operando,
        ultimoAtualizacao: DateTime.now().subtract(const Duration(minutes: 15)),
        tempoOperacaoTotal: 1240.0,
        numeroParadas: 2,
        tempoParado: 1800,
      ),
      Equipamento(
        id: 'eq-2',
        tag: 'PR-02',
        nome: 'Prensa Hidráulica 50T',
        localizacao: 'Setor de Estamparia',
        status: StatusEquipamento.parada,
        ultimoAtualizacao: DateTime.now().subtract(const Duration(hours: 1)),
        ultimaParada: DateTime.now().subtract(const Duration(hours: 1)),
        motivoParada: 'Superaquecimento da bomba de pressão',
        responsavel: PerfilUsuario.operador,
        tempoOperacaoTotal: 860.0,
        numeroParadas: 5,
        tempoParado: 5400,
      ),
      Equipamento(
        id: 'eq-3',
        tag: 'INJ-03',
        nome: 'Injetora de Termoplásticos',
        localizacao: 'Pavilhão de Plásticos',
        status: StatusEquipamento.manutencao,
        ultimoAtualizacao: DateTime.now().subtract(const Duration(hours: 3)),
        ultimaParada: DateTime.now().subtract(const Duration(hours: 4)),
        motivoParada: 'Manutenção preventiva dos cilindros',
        responsavel: PerfilUsuario.tecnico,
        tempoOperacaoTotal: 2150.0,
        numeroParadas: 3,
        tempoParado: 14400,
      ),
      Equipamento(
        id: 'eq-4',
        tag: 'EST-04',
        nome: 'Esteira Transportadora Central',
        localizacao: 'Linha de Montagem 2',
        status: StatusEquipamento.aguardandoMaterial,
        ultimoAtualizacao: DateTime.now().subtract(const Duration(hours: 2)),
        ultimaParada: DateTime.now().subtract(const Duration(hours: 2)),
        motivoParada: 'Aguardando correia dentada de reposição',
        responsavel: PerfilUsuario.supervisor,
        tempoOperacaoTotal: 3400.0,
        numeroParadas: 8,
        tempoParado: 7200,
      ),
      Equipamento(
        id: 'eq-5',
        tag: 'SOL-05',
        nome: 'Robô de Solda Robotizada',
        localizacao: 'Célula de Solda Automática',
        status: StatusEquipamento.operando,
        ultimoAtualizacao: DateTime.now().subtract(const Duration(minutes: 5)),
        tempoOperacaoTotal: 1780.0,
        numeroParadas: 1,
        tempoParado: 600,
      ),
    ];
  }

  Future<void> carregarEquipamentos() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 600));
    _isLoading = false;
    notifyListeners();
  }

  void atualizarStatusEquipamento(
    String id,
    StatusEquipamento novoStatus, {
    String? motivo,
  }) {
    final index = _equipamentos.indexWhere((e) => e.id == id);
    if (index != -1) {
      final atual = _equipamentos[index];
      _equipamentos[index] = atual.copyWith(
        status: novoStatus,
        ultimoAtualizacao: DateTime.now(),
        motivoParada: motivo ?? atual.motivoParada,
        ultimaParada: novoStatus == StatusEquipamento.parada
            ? DateTime.now()
            : atual.ultimaParada,
      );
      notifyListeners();
    }
  }
}

