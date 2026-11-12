// lib/providers/ocorrencia_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/equipamento.dart';
import '../models/historico.dart';
import '../models/ocorrencia.dart';
import '../models/usuario.dart';
import '../utils/constants.dart';

class OcorrenciaProvider extends ChangeNotifier {
  List<Ocorrencia> _ocorrencias = [];
  List<Equipamento> _equipamentos = [];
  List<Map<String, String>> _tecnicosDisponiveis = [];
  bool _isLoading = false;

  List<Ocorrencia> get ocorrencias => _ocorrencias;
  List<Equipamento> get equipamentos => _equipamentos;
  List<Map<String, String>> get tecnicosDisponiveis => _tecnicosDisponiveis;
  bool get isLoading => _isLoading;

  Map<String, Equipamento> get equipamentosPorId => {
        for (final e in _equipamentos) e.id: e,
      };

  OcorrenciaProvider() {
    _listenToMaquinas();
    _listenToOcorrencias();
    _listenToUsuarios();
  }

  void _listenToMaquinas() {
    FirebaseFirestore.instance.collection('maquinas').snapshots().listen((snapshot) {
      _equipamentos = snapshot.docs.map((doc) {
        final data = doc.data();

        DateTime ultimoAtualizacao = DateTime.now();
        if (data['ultimoAtualizacao'] is Timestamp) {
          ultimoAtualizacao = (data['ultimoAtualizacao'] as Timestamp).toDate();
        } else if (data['ultimoAtualizacao'] is String) {
          ultimoAtualizacao = DateTime.tryParse(data['ultimoAtualizacao']) ?? DateTime.now();
        }

        DateTime? ultimaParada;
        if (data['ultimaParada'] is Timestamp) {
          ultimaParada = (data['ultimaParada'] as Timestamp).toDate();
        } else if (data['ultimaParada'] is String) {
          ultimaParada = DateTime.tryParse(data['ultimaParada']);
        }

        final tag = (data['tag'] ?? data['codigo'] ?? 'EQ-${doc.id.substring(0, doc.id.length >= 4 ? 4 : doc.id.length)}').toString();
        final nome = (data['nome'] ?? data['nome '] ?? 'Equipamento').toString();
        final localizacao = (data['localizacao'] ?? 'Parque Industrial').toString();

        return Equipamento(
          id: doc.id,
          tag: tag,
          nome: nome,
          localizacao: localizacao,
          status: _parseStatus(data['status']?.toString()),
          grauCritico: data['grauCritico'] == true,
          aprovadaManutencao: data['aprovadaManutencao'] == true,
          tecnicoDesignado: data['tecnicoDesignado']?.toString(),
          tecnicoDesignadoId: data['tecnicoDesignadoId']?.toString(),
          ultimoAtualizacao: ultimoAtualizacao,
          ultimaParada: ultimaParada,
          motivoParada: data['motivoParada']?.toString(),
          responsavel: _parsePerfil(data['responsavel']?.toString()),
          tempoOperacaoTotal: (data['tempoOperacaoTotal'] as num?)?.toDouble() ?? 0.0,
          numeroParadas: (data['numeroParadas'] as num?)?.toInt() ?? 0,
          tempoParado: (data['tempoParado'] as num?)?.toInt() ?? 0,
        );
      }).toList();
      notifyListeners();
    });
  }

  void _listenToOcorrencias() {
    _isLoading = true;
    FirebaseFirestore.instance.collection('ocorrencias').snapshots().listen((snapshot) {
      _ocorrencias = snapshot.docs.map((doc) {
        final data = doc.data();

        DateTime dataAbertura = DateTime.now();
        if (data['dataAbertura'] is Timestamp) {
          dataAbertura = (data['dataAbertura'] as Timestamp).toDate();
        } else if (data['dataAbertura'] is String) {
          dataAbertura = DateTime.tryParse(data['dataAbertura']) ?? DateTime.now();
        }

        DateTime? dataInicio;
        if (data['dataInicio'] is Timestamp) {
          dataInicio = (data['dataInicio'] as Timestamp).toDate();
        } else if (data['dataInicio'] is String) {
          dataInicio = DateTime.tryParse(data['dataInicio']);
        }

        DateTime? dataFim;
        if (data['dataFim'] is Timestamp) {
          dataFim = (data['dataFim'] as Timestamp).toDate();
        } else if (data['dataFim'] is String) {
          dataFim = DateTime.tryParse(data['dataFim']);
        }

        DateTime? proximaManutencao;
        if (data['proximaManutencao'] is Timestamp) {
          proximaManutencao = (data['proximaManutencao'] as Timestamp).toDate();
        } else if (data['proximaManutencao'] is String) {
          proximaManutencao = DateTime.tryParse(data['proximaManutencao']);
        }

        List<HistoricoItem> historico = [];
        if (data['historico'] is List) {
          historico = (data['historico'] as List).map((h) {
            if (h is Map<String, dynamic>) {
              return HistoricoItem.fromJson(h);
            } else if (h is Map) {
              return HistoricoItem.fromJson(Map<String, dynamic>.from(h));
            }
            return null;
          }).whereType<HistoricoItem>().toList();
        }

        return Ocorrencia(
          id: doc.id,
          equipamentoId: (data['equipamentoId'] ?? '').toString(),
          equipamentoTag: (data['equipamentoTag'] ?? '').toString(),
          motivo: (data['motivo'] ?? '').toString(),
          descricao: (data['descricao'] ?? '').toString(),
          prioridade: (data['prioridade'] ?? 'Média').toString(),
          status: _parseStatusOcorrencia(data['status']),
          aprovadaManutencao: data['aprovadaManutencao'] == true,
          tecnicoDesignado: data['tecnicoDesignado']?.toString(),
          tecnicoDesignadoId: data['tecnicoDesignadoId']?.toString(),
          dataAbertura: dataAbertura,
          dataInicio: dataInicio,
          dataFim: dataFim,
          tecnicoResponsavel: data['tecnicoResponsavel']?.toString(),
          observacaoFinal: data['observacaoFinal']?.toString(),
          pecasTrocadas: List<String>.from(data['pecasTrocadas'] ?? []),
          proximaManutencao: proximaManutencao,
          historico: historico,
        );
      }).toList();

      _ocorrencias.sort((a, b) => b.dataAbertura.compareTo(a.dataAbertura));

      _isLoading = false;
      notifyListeners();
    }, onError: (_) {
      _isLoading = false;
      notifyListeners();
    });
  }

  void _listenToUsuarios() {
    FirebaseFirestore.instance.collection('usuarios').snapshots().listen((snapshot) {
      _tecnicosDisponiveis = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final perfil = (data['perfil'] ?? '').toString().toLowerCase();
            return perfil.contains('tecnic') || perfil.contains('técnic') || perfil == '1';
          })
          .map((doc) {
            final data = doc.data();
            final nome = (data['nome'] ?? data['nomeFuncionario'] ?? doc.id).toString();
            return {
              'id': doc.id,
              'nome': nome,
            };
          })
          .toList();
      notifyListeners();
    });
  }

  StatusEquipamento _parseStatus(String? status) {
    if (status == null) return StatusEquipamento.operando;
    final s = status.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    if (s.contains('parada') || s.contains('parado')) return StatusEquipamento.parada;
    if (s.contains('manutenc')) return StatusEquipamento.manutencao;
    if (s.contains('material') || s.contains('aguardando')) return StatusEquipamento.aguardandoMaterial;
    if (s.contains('aprovac')) return StatusEquipamento.aguardandoAprovacao;
    if (s.contains('indisponivel')) return StatusEquipamento.indisponivel;
    return StatusEquipamento.operando;
  }

  PerfilUsuario? _parsePerfil(String? perfil) {
    if (perfil == null) return null;
    final p = perfil.toLowerCase();
    if (p.contains('operad')) return PerfilUsuario.operador;
    if (p.contains('tecnic') || p.contains('técnic')) return PerfilUsuario.tecnico;
    if (p.contains('supervis')) return PerfilUsuario.supervisor;
    if (p.contains('gestor') || p.contains('admin')) return PerfilUsuario.gestor;
    return null;
  }

  StatusOcorrencia _parseStatusOcorrencia(dynamic status) {
    if (status == null) return StatusOcorrencia.aberta;
    if (status is int) {
      if (status >= 0 && status < StatusOcorrencia.values.length) {
        return StatusOcorrencia.values[status];
      }
    }
    final s = status.toString().toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    if (s.contains('andamento') || s == '1') return StatusOcorrencia.emAndamento;
    if (s.contains('material') || s == '2') return StatusOcorrencia.aguardandoMaterial;
    if (s.contains('aprovac') || s == '3') return StatusOcorrencia.aguardandoAprovacao;
    if (s.contains('finaliz') || s == '4' || s == 'conclu') return StatusOcorrencia.finalizada;
    return StatusOcorrencia.aberta;
  }

  Future<void> carregarOcorrencias() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    _isLoading = false;
    notifyListeners();
  }

  // =========================================================================
  // 1. AÇÕES DO OPERADOR (Com validações de RBAC e Integridade)
  // =========================================================================

  /// REGRA DE NEGÓCIO: Operadores podem registrar paradas incluindo críticas.
  /// Se a parada for de grau crítico:
  /// - A máquina entra em 'Aguardando Aprovação' (Estado X).
  /// - Necessita de aprovação do supervisor e designação de técnico antes de ser consertada.
  /// Se NÃO for crítica (Baixa, Média, Alta):
  /// - A máquina entra em 'Parada' e qualquer técnico pode livremente arrumar a máquina.
  Future<void> registrarParadaCritica({
    required String equipamentoId,
    required String motivo,
    required String prioridade,
    required Usuario usuario,
  }) async {
    if (!usuario.can(AppPermission.registrarParadaCritica)) {
      throw Exception('Acesso negado: Perfil não autorizado a registrar paradas de máquina.');
    }

    // Validação de parada ativa simultânea
    final paradaAtivaExistente = _ocorrencias.any((o) =>
        o.equipamentoId == equipamentoId &&
        (o.status == StatusOcorrencia.aberta ||
            o.status == StatusOcorrencia.emAndamento ||
            o.status == StatusOcorrencia.aguardandoMaterial ||
            o.status == StatusOcorrencia.aguardandoAprovacao));

    if (paradaAtivaExistente) {
      throw Exception('Esta máquina já possui uma ocorrência ativa não finalizada!');
    }

    final eqIndex = _equipamentos.indexWhere((e) => e.id == equipamentoId);
    if (eqIndex == -1) {
      throw Exception('Equipamento não localizado no parque industrial.');
    }

    final eq = _equipamentos[eqIndex];
    final agora = DateTime.now();

    final ehCritica = prioridade.toLowerCase().trim() == 'crítica' || prioridade.toLowerCase().trim() == 'critica';
    final statusEquipamento = ehCritica
        ? StatusEquipamento.aguardandoAprovacao
        : StatusEquipamento.parada;
    final statusOcorrencia = ehCritica
        ? StatusOcorrencia.aguardandoAprovacao
        : StatusOcorrencia.aberta;

    final novaOcorrencia = Ocorrencia(
      equipamentoId: eq.id,
      equipamentoTag: eq.tag,
      motivo: motivo,
      descricao: ehCritica
          ? 'Parada Crítica registrada no chão de fábrica por ${usuario.nome}. Necessita de aprovação e designação do Supervisor.'
          : 'Parada registrada no chão de fábrica por ${usuario.nome}.',
      prioridade: prioridade,
      status: statusOcorrencia,
      aprovadaManutencao: !ehCritica,
      dataAbertura: agora,
      historico: [
        HistoricoItem(
          data: agora,
          tipo: 'abertura',
          descricao: ehCritica
              ? 'Parada Crítica registrada: $motivo. Aguardando aprovação do supervisor.'
              : 'Parada registrada: $motivo (Prioridade: $prioridade). Liberada para manutenção técnica.',
          por: usuario.nome,
          statusOcorrencia: statusOcorrencia,
          statusEquipamento: statusEquipamento,
        ),
      ],
    );

    // Salvar no Firestore (coleção ocorrencias)
    await FirebaseFirestore.instance
        .collection('ocorrencias')
        .doc(novaOcorrencia.id)
        .set(novaOcorrencia.toJson());

    // Atualizar máquina no Firestore (coleção maquinas)
    await FirebaseFirestore.instance.collection('maquinas').doc(eq.id).update({
      'status': statusEquipamento.name,
      'motivoParada': motivo,
      'responsavel': PerfilUsuario.operador.name,
      'grauCritico': ehCritica,
      'aprovadaManutencao': !ehCritica,
      'tecnicoDesignado': null,
      'tecnicoDesignadoId': null,
      'ultimaParada': FieldValue.serverTimestamp(),
      'ultimoAtualizacao': FieldValue.serverTimestamp(),
      'numeroParadas': FieldValue.increment(1),
    });
  }

  /// Solicitar Atendimento de Manutenção (Operador)
  Future<void> solicitarAtendimento({
    required String ocorrenciaId,
    required Usuario usuario,
  }) async {
    if (!usuario.can(AppPermission.solicitarAtendimento)) {
      throw Exception('Acesso negado: Perfil não autorizado a solicitar atendimento.');
    }

    final index = _ocorrencias.indexWhere((o) => o.id == ocorrenciaId);
    if (index != -1) {
      final o = _ocorrencias[index];
      final historico = List<HistoricoItem>.from(o.historico)
        ..add(
          HistoricoItem(
            data: DateTime.now(),
            tipo: 'solicitacao',
            descricao: 'Atendimento de emergência solicitado pelo operador.',
            por: usuario.nome,
            statusOcorrencia: o.status,
          ),
        );

      await FirebaseFirestore.instance.collection('ocorrencias').doc(ocorrenciaId).update({
        'historico': historico.map((h) => h.toJson()).toList(),
      });
    }
  }

  // =========================================================================
  // 2. AÇÕES DO SUPERVISOR (Aprovação Crítica, Atribuição e Suprimento)
  // =========================================================================

  /// Aprovar parada crítica e designar o técnico responsável exclusivo
  Future<void> aprovarEDesignarTecnico({
    required String ocorrenciaId,
    required String tecnicoId,
    required String tecnicoNome,
    required Usuario usuario,
  }) async {
    if (!usuario.can(AppPermission.atribuirTecnico)) {
      throw Exception('Acesso negado: Apenas supervisores podem aprovar manutenções críticas e designar técnicos.');
    }

    final index = _ocorrencias.indexWhere((o) => o.id == ocorrenciaId);
    if (index == -1) throw Exception('Ocorrência não encontrada.');

    final o = _ocorrencias[index];
    final agora = DateTime.now();

    final historicoAtualizado = List<HistoricoItem>.from(o.historico)
      ..add(
        HistoricoItem(
          data: agora,
          tipo: 'aprovacao_designacao',
          descricao: 'Manutenção aprovada pelo Supervisor ${usuario.nome}. Técnico designado: $tecnicoNome.',
          por: usuario.nome,
          statusOcorrencia: StatusOcorrencia.aberta,
          statusEquipamento: StatusEquipamento.parada,
        ),
      );

    // Ocorrência passa a estar aprovada para o técnico designado
    await FirebaseFirestore.instance.collection('ocorrencias').doc(ocorrenciaId).update({
      'status': StatusOcorrencia.aberta.index,
      'aprovadaManutencao': true,
      'tecnicoDesignado': tecnicoNome,
      'tecnicoDesignadoId': tecnicoId,
      'tecnicoResponsavel': tecnicoNome,
      'historico': historicoAtualizado.map((h) => h.toJson()).toList(),
    });

    // Máquina: Estado Y (Aprovada para manutenção com técnico designado)
    await FirebaseFirestore.instance.collection('maquinas').doc(o.equipamentoId).update({
      'status': StatusEquipamento.parada.name,
      'aprovadaManutencao': true,
      'tecnicoDesignado': tecnicoNome,
      'tecnicoDesignadoId': tecnicoId,
      'motivoParada': '${o.motivo} (Aprovado p/ técnico $tecnicoNome)',
      'ultimoAtualizacao': FieldValue.serverTimestamp(),
    });
  }

  /// Supervisor entrega o material solicitado pelo técnico
  Future<void> entregarMaterial({
    required String ocorrenciaId,
    required String descricaoEntrega,
    required Usuario usuario,
  }) async {
    if (!usuario.can(AppPermission.entregarMaterial)) {
      throw Exception('Acesso negado: Apenas o Supervisor pode registrar entrega de materiais.');
    }

    final index = _ocorrencias.indexWhere((o) => o.id == ocorrenciaId);
    if (index == -1) throw Exception('Ocorrência não encontrada.');

    final o = _ocorrencias[index];
    if (o.status != StatusOcorrencia.aguardandoMaterial) {
      throw Exception('Esta ocorrência não está aguardando material (status atual: ${o.status.nome}).');
    }

    final agora = DateTime.now();

    final historicoAtualizado = List<HistoricoItem>.from(o.historico)
      ..add(
        HistoricoItem(
          data: agora,
          tipo: 'entrega_material',
          descricao: 'Material entregue pelo Supervisor ${usuario.nome}: $descricaoEntrega',
          por: usuario.nome,
          statusOcorrencia: StatusOcorrencia.emAndamento,
          statusEquipamento: StatusEquipamento.manutencao,
        ),
      );

    await FirebaseFirestore.instance.collection('ocorrencias').doc(ocorrenciaId).update({
      'status': StatusOcorrencia.emAndamento.index,
      'historico': historicoAtualizado.map((h) => h.toJson()).toList(),
    });

    await FirebaseFirestore.instance.collection('maquinas').doc(o.equipamentoId).update({
      'status': StatusEquipamento.manutencao.name,
      'motivoParada': 'Material entregue — manutenção retomada',
      'ultimoAtualizacao': FieldValue.serverTimestamp(),
    });
  }

  /// Supervisor reatribui a prioridade de uma ocorrência
  Future<void> reatribuirPrioridade({
    required String ocorrenciaId,
    required String novaPrioridade,
    required Usuario usuario,
  }) async {
    if (!usuario.can(AppPermission.reatribuirPrioridade)) {
      throw Exception('Acesso negado: Apenas supervisores podem redefinir a prioridade.');
    }

    final index = _ocorrencias.indexWhere((o) => o.id == ocorrenciaId);
    if (index == -1) throw Exception('Ocorrência não localizada.');

    final o = _ocorrencias[index];
    final agora = DateTime.now();

    final historicoAtualizado = List<HistoricoItem>.from(o.historico)
      ..add(
        HistoricoItem(
          data: agora,
          tipo: 'prioridade',
          descricao: 'Prioridade redefinida de "${o.prioridade}" para "$novaPrioridade" por ${usuario.nome}.',
          por: usuario.nome,
          statusOcorrencia: o.status,
        ),
      );

    await FirebaseFirestore.instance.collection('ocorrencias').doc(ocorrenciaId).update({
      'prioridade': novaPrioridade,
      'historico': historicoAtualizado.map((h) => h.toJson()).toList(),
    });
  }

  /// Supervisor contra-assina liberação formal
  Future<void> contraAssinarRetorno({
    required String ocorrenciaId,
    required String parecerSupervisor,
    required Usuario usuario,
  }) async {
    if (!usuario.can(AppPermission.contraAssinarRetorno)) {
      throw Exception('Acesso negado: Contra-assinatura reservada para o perfil de Supervisor.');
    }

    final index = _ocorrencias.indexWhere((o) => o.id == ocorrenciaId);
    if (index == -1) throw Exception('Ocorrência não localizada.');

    final o = _ocorrencias[index];
    final agora = DateTime.now();

    final historicoAtualizado = List<HistoricoItem>.from(o.historico)
      ..add(
        HistoricoItem(
          data: agora,
          tipo: 'aprovacao',
          descricao: 'Liberação formal contra-assinada pelo Supervisor: $parecerSupervisor',
          por: usuario.nome,
          statusOcorrencia: StatusOcorrencia.finalizada,
          statusEquipamento: StatusEquipamento.operando,
        ),
      );

    await FirebaseFirestore.instance.collection('ocorrencias').doc(ocorrenciaId).update({
      'status': StatusOcorrencia.finalizada.index,
      'historico': historicoAtualizado.map((h) => h.toJson()).toList(),
    });

    await FirebaseFirestore.instance.collection('maquinas').doc(o.equipamentoId).update({
      'status': StatusEquipamento.operando.name,
      'motivoParada': null,
      'grauCritico': false,
      'aprovadaManutencao': false,
      'tecnicoDesignado': null,
      'tecnicoDesignadoId': null,
      'ultimoAtualizacao': FieldValue.serverTimestamp(),
    });
  }

  /// Método compatível para atribuir técnico
  Future<void> atribuirTecnico({
    required String ocorrenciaId,
    required String tecnicoId,
    required String tecnicoNome,
    required Usuario usuario,
  }) async {
    await aprovarEDesignarTecnico(
      ocorrenciaId: ocorrenciaId,
      tecnicoId: tecnicoId,
      tecnicoNome: tecnicoNome,
      usuario: usuario,
    );
  }

  // =========================================================================
  // 3. AÇÕES DO TÉCNICO DE MANUTENÇÃO (Com validações de RBAC e Exclusividade)
  // =========================================================================

  /// Assumir / Iniciar atendimento técnico
  /// REGRA DE NEGÓCIO:
  /// - Se a máquina for CRÍTICA: necessita de aprovação prévia do supervisor E
  ///   somente o técnico designado pode começar a manutenção!
  /// - Se NÃO for crítica: qualquer técnico pode livremente arrumar a máquina.
  Future<void> assumirAtendimento({
    required String ocorrenciaId,
    required Usuario usuario,
  }) async {
    if (!usuario.can(AppPermission.assumirManutencao)) {
      throw Exception('Acesso negado: Apenas a equipe técnica pode assumir ocorrências.');
    }

    final index = _ocorrencias.indexWhere((o) => o.id == ocorrenciaId);
    if (index == -1) throw Exception('Ocorrência não encontrada.');

    final o = _ocorrencias[index];

    // 1. Validação se a ocorrência é crítica
    if (o.ehCritica) {
      if (!o.aprovadaManutencao) {
        throw Exception('Esta ocorrência é de grau Crítico e ainda necessita de APROVAÇÃO e designação do Supervisor antes de iniciar.');
      }

      // Validação do técnico designado exclusivo
      final idBate = o.tecnicoDesignadoId != null && o.tecnicoDesignadoId == usuario.id;
      final nomeBate = o.tecnicoDesignado != null &&
          o.tecnicoDesignado!.trim().toLowerCase() == usuario.nome.trim().toLowerCase();

      if (!idBate && !nomeBate) {
        throw Exception('Acesso restrito: Esta manutenção crítica foi designada exclusivamente para o técnico "${o.tecnicoDesignado ?? 'Designado'}".');
      }
    }

    // 2. Validação de status para início
    if (o.status != StatusOcorrencia.aberta &&
        o.status != StatusOcorrencia.aguardandoAprovacao &&
        o.status != StatusOcorrencia.aguardandoMaterial) {
      throw Exception('Esta ocorrência não pode ser assumida no status atual (${o.status.nome}).');
    }

    final agora = DateTime.now();
    final historicoAtualizado = List<HistoricoItem>.from(o.historico)
      ..add(
        HistoricoItem(
          data: agora,
          tipo: 'inicio',
          descricao: 'Atendimento de manutenção iniciado pelo técnico ${usuario.nome}.',
          por: usuario.nome,
          statusOcorrencia: StatusOcorrencia.emAndamento,
          statusEquipamento: StatusEquipamento.manutencao,
        ),
      );

    await FirebaseFirestore.instance.collection('ocorrencias').doc(ocorrenciaId).update({
      'status': StatusOcorrencia.emAndamento.index,
      'dataInicio': (o.dataInicio ?? agora).toIso8601String(),
      'tecnicoResponsavel': usuario.nome,
      'historico': historicoAtualizado.map((h) => h.toJson()).toList(),
    });

    await FirebaseFirestore.instance.collection('maquinas').doc(o.equipamentoId).update({
      'status': StatusEquipamento.manutencao.name,
      'responsavel': PerfilUsuario.tecnico.name,
      'ultimoAtualizacao': FieldValue.serverTimestamp(),
    });
  }

  /// Pausar atendimento para status 'Aguardando Material'
  Future<void> pausarAguardandoMaterial({
    required String ocorrenciaId,
    required String motivoPausa,
    required Usuario usuario,
  }) async {
    if (!usuario.can(AppPermission.pausarAguardandoMaterial)) {
      throw Exception('Acesso negado: Apenas técnicos podem pausar por falta de material.');
    }

    final index = _ocorrencias.indexWhere((o) => o.id == ocorrenciaId);
    if (index == -1) throw Exception('Ocorrência não encontrada.');

    final o = _ocorrencias[index];
    final agora = DateTime.now();

    final historicoAtualizado = List<HistoricoItem>.from(o.historico)
      ..add(
        HistoricoItem(
          data: agora,
          tipo: 'pausa',
          descricao: 'Atendimento pausado: $motivoPausa',
          por: usuario.nome,
          statusOcorrencia: StatusOcorrencia.aguardandoMaterial,
          statusEquipamento: StatusEquipamento.aguardandoMaterial,
        ),
      );

    await FirebaseFirestore.instance.collection('ocorrencias').doc(ocorrenciaId).update({
      'status': StatusOcorrencia.aguardandoMaterial.index,
      'historico': historicoAtualizado.map((h) => h.toJson()).toList(),
    });

    await FirebaseFirestore.instance.collection('maquinas').doc(o.equipamentoId).update({
      'status': StatusEquipamento.aguardandoMaterial.name,
      'ultimoAtualizacao': FieldValue.serverTimestamp(),
    });
  }

  /// Finalizar atendimento com laudo técnico detalhado
  /// Após receber os materiais ou concluir os reparos, a máquina volta a Operando!
  Future<void> finalizarAtendimentoComLaudo({
    required String ocorrenciaId,
    required String laudoTecnico,
    required List<String> pecasTrocadas,
    required Usuario usuario,
  }) async {
    if (!usuario.can(AppPermission.finalizarComLaudo)) {
      throw Exception('Acesso negado: Apenas a equipe técnica pode emitir laudo de finalização.');
    }

    if (laudoTecnico.trim().length < 10) {
      throw Exception('Validação do Laudo: É obrigatório detalhar o procedimento com no mínimo 10 caracteres.');
    }

    final index = _ocorrencias.indexWhere((o) => o.id == ocorrenciaId);
    if (index == -1) throw Exception('Ocorrência não encontrada.');

    final o = _ocorrencias[index];
    final agora = DateTime.now();

    final historicoAtualizado = List<HistoricoItem>.from(o.historico)
      ..add(
        HistoricoItem(
          data: agora,
          tipo: 'finalizacao',
          descricao: 'Laudo Técnico de Liberação: ${laudoTecnico.trim()}',
          por: usuario.nome,
          statusOcorrencia: StatusOcorrencia.finalizada,
          statusEquipamento: StatusEquipamento.operando,
        ),
      );

    await FirebaseFirestore.instance.collection('ocorrencias').doc(ocorrenciaId).update({
      'status': StatusOcorrencia.finalizada.index,
      'dataFim': agora.toIso8601String(),
      'observacaoFinal': laudoTecnico.trim(),
      'pecasTrocadas': pecasTrocadas,
      'historico': historicoAtualizado.map((h) => h.toJson()).toList(),
    });

    // Retorna a máquina ao estado Operando e reseta os controles de parada crítica
    await FirebaseFirestore.instance.collection('maquinas').doc(o.equipamentoId).update({
      'status': StatusEquipamento.operando.name,
      'motivoParada': null,
      'grauCritico': false,
      'aprovadaManutencao': false,
      'tecnicoDesignado': null,
      'tecnicoDesignadoId': null,
      'ultimoAtualizacao': FieldValue.serverTimestamp(),
    });
  }

  /// Método compatível para iniciar atendimento
  Future<void> iniciarAtendimento(String ocorrenciaId, [Usuario? usuario]) async {
    final user = usuario ??
        Usuario(
          id: 'tec-padrao',
          nome: 'Técnico Responsável',
          email: 'tecnico@empresa.com',
          senha: '',
          perfil: PerfilUsuario.tecnico,
        );
    await assumirAtendimento(ocorrenciaId: ocorrenciaId, usuario: user);
  }

  /// Método compatível para finalizar atendimento
  Future<void> finalizarAtendimento(String ocorrenciaId, String observacaoFinal, [Usuario? usuario]) async {
    final user = usuario ??
        Usuario(
          id: 'tec-padrao',
          nome: 'Técnico Responsável',
          email: 'tecnico@empresa.com',
          senha: '',
          perfil: PerfilUsuario.tecnico,
        );
    final laudo = observacaoFinal.trim().length >= 10
        ? observacaoFinal.trim()
        : 'Manutenção técnica executada com sucesso e liberada.';
    await finalizarAtendimentoComLaudo(
      ocorrenciaId: ocorrenciaId,
      laudoTecnico: laudo,
      pecasTrocadas: const [],
      usuario: user,
    );
  }
}
