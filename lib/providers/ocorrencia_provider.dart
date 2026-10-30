// lib/providers/ocorrencia_provider.dart

import 'package:flutter/material.dart';
import '../models/equipamento.dart';
import '../models/historico.dart';
import '../models/ocorrencia.dart';
import '../utils/constants.dart';

class OcorrenciaProvider extends ChangeNotifier {
  List<Ocorrencia> _ocorrencias = [];
  List<Equipamento> _equipamentos = [];
  bool _isLoading = false;

  List<Ocorrencia> get ocorrencias => _ocorrencias;
  List<Equipamento> get equipamentos => _equipamentos;
  bool get isLoading => _isLoading;

  Map<String, Equipamento> get equipamentosPorId => {
        for (final e in _equipamentos) e.id: e,
      };

  OcorrenciaProvider() {
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
    ];

    _ocorrencias = [
      Ocorrencia(
        id: 'oc-1',
        equipamentoId: 'eq-2',
        equipamentoTag: 'PR-02',
        motivo: 'Superaquecimento de Bomba',
        descricao: 'Temperatura ultrapassou 85°C na bomba hidráulica principal.',
        prioridade: 'Alta',
        status: StatusOcorrencia.aberta,
        dataAbertura: DateTime.now().subtract(const Duration(hours: 1)),
        historico: [
          HistoricoItem(
            data: DateTime.now().subtract(const Duration(hours: 1)),
            tipo: 'abertura',
            descricao: 'Parada registrada pelo operador.',
            por: 'João Silva',
            statusOcorrencia: StatusOcorrencia.aberta,
            statusEquipamento: StatusEquipamento.parada,
          ),
        ],
      ),
      Ocorrencia(
        id: 'oc-2',
        equipamentoId: 'eq-3',
        equipamentoTag: 'INJ-03',
        motivo: 'Troca de Vedação de Pistão',
        descricao: 'Vazamento de óleo detectado no cilindro injetor secundário.',
        prioridade: 'Média',
        status: StatusOcorrencia.emAndamento,
        dataAbertura: DateTime.now().subtract(const Duration(hours: 4)),
        dataInicio: DateTime.now().subtract(const Duration(hours: 2)),
        tecnicoResponsavel: 'Carlos Mendes',
        pecasTrocadas: ['Anel O-Ring 45mm', 'Retentor de alta pressão'],
        historico: [
          HistoricoItem(
            data: DateTime.now().subtract(const Duration(hours: 4)),
            tipo: 'abertura',
            descricao: 'Ocorrência registrada no sistema.',
            por: 'Ana Costa',
            statusOcorrencia: StatusOcorrencia.aberta,
          ),
          HistoricoItem(
            data: DateTime.now().subtract(const Duration(hours: 2)),
            tipo: 'inicio',
            descricao: 'Início do atendimento técnico.',
            por: 'Carlos Mendes',
            statusOcorrencia: StatusOcorrencia.emAndamento,
            statusEquipamento: StatusEquipamento.manutencao,
          ),
        ],
      ),
      Ocorrencia(
        id: 'oc-3',
        equipamentoId: 'eq-1',
        equipamentoTag: 'CNC-01',
        motivo: 'Calibração de Eixo Z',
        descricao: 'Desvio de 0.05mm nas peças usinadas durante o lote matutino.',
        prioridade: 'Baixa',
        status: StatusOcorrencia.finalizada,
        dataAbertura: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
        dataInicio: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        dataFim: DateTime.now().subtract(const Duration(days: 1)),
        tecnicoResponsavel: 'Carlos Mendes',
        observacaoFinal: 'Eixo recalibrado e testado com peça padrão. Tolerância OK.',
        historico: [
          HistoricoItem(
            data: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
            tipo: 'abertura',
            descricao: 'Abertura para ajuste de tolerância.',
            por: 'João Silva',
            statusOcorrencia: StatusOcorrencia.aberta,
          ),
          HistoricoItem(
            data: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
            tipo: 'inicio',
            descricao: 'Início dos ensaios de calibração.',
            por: 'Carlos Mendes',
            statusOcorrencia: StatusOcorrencia.emAndamento,
          ),
          HistoricoItem(
            data: DateTime.now().subtract(const Duration(days: 1)),
            tipo: 'finalizacao',
            descricao: 'Serviço finalizado e aprovado.',
            por: 'Carlos Mendes',
            statusOcorrencia: StatusOcorrencia.finalizada,
            statusEquipamento: StatusEquipamento.operando,
          ),
        ],
      ),
    ];
  }

  Future<void> carregarOcorrencias() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 600));
    _isLoading = false;
    notifyListeners();
  }

  Future<void> iniciarAtendimento(String ocorrenciaId) async {
    final index = _ocorrencias.indexWhere((o) => o.id == ocorrenciaId);
    if (index != -1) {
      final o = _ocorrencias[index];
      final historicoAtualizado = List<HistoricoItem>.from(o.historico)
        ..add(
          HistoricoItem(
            data: DateTime.now(),
            tipo: 'inicio',
            descricao: 'Atendimento técnico iniciado.',
            por: 'Carlos Mendes',
            statusOcorrencia: StatusOcorrencia.emAndamento,
            statusEquipamento: StatusEquipamento.manutencao,
          ),
        );

      _ocorrencias[index] = o.copyWith(
        status: StatusOcorrencia.emAndamento,
        dataInicio: DateTime.now(),
        tecnicoResponsavel: 'Carlos Mendes',
        historico: historicoAtualizado,
      );

      final eqIndex = _equipamentos.indexWhere((e) => e.id == o.equipamentoId);
      if (eqIndex != -1) {
        _equipamentos[eqIndex] = _equipamentos[eqIndex].copyWith(
          status: StatusEquipamento.manutencao,
          responsavel: PerfilUsuario.tecnico,
          ultimoAtualizacao: DateTime.now(),
        );
      }

      notifyListeners();
    }
  }

  Future<void> finalizarAtendimento(
    String ocorrenciaId,
    String observacaoFinal,
  ) async {
    final index = _ocorrencias.indexWhere((o) => o.id == ocorrenciaId);
    if (index != -1) {
      final o = _ocorrencias[index];
      final historicoAtualizado = List<HistoricoItem>.from(o.historico)
        ..add(
          HistoricoItem(
            data: DateTime.now(),
            tipo: 'finalizacao',
            descricao: observacaoFinal,
            por: o.tecnicoResponsavel ?? 'Carlos Mendes',
            statusOcorrencia: StatusOcorrencia.finalizada,
            statusEquipamento: StatusEquipamento.operando,
          ),
        );

      _ocorrencias[index] = o.copyWith(
        status: StatusOcorrencia.finalizada,
        dataFim: DateTime.now(),
        observacaoFinal: observacaoFinal,
        historico: historicoAtualizado,
      );

      final eqIndex = _equipamentos.indexWhere((e) => e.id == o.equipamentoId);
      if (eqIndex != -1) {
        _equipamentos[eqIndex] = _equipamentos[eqIndex].copyWith(
          status: StatusEquipamento.operando,
          ultimoAtualizacao: DateTime.now(),
        );
      }

      notifyListeners();
    }
  }
}

