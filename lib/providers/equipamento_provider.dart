// lib/providers/equipamento_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/equipamento.dart';
import '../models/usuario.dart';
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
    _listenToMaquinas();
  }

  void _listenToMaquinas() {
    _isLoading = true;
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

        final grauCritico = data['grauCritico'] == true;
        final aprovadaManutencao = data['aprovadaManutencao'] == true;
        final tecnicoDesignado = data['tecnicoDesignado']?.toString();
        final tecnicoDesignadoId = data['tecnicoDesignadoId']?.toString();

        return Equipamento(
          id: doc.id,
          tag: tag,
          nome: nome,
          localizacao: localizacao,
          status: _parseStatus(data['status']?.toString()),
          grauCritico: grauCritico,
          aprovadaManutencao: aprovadaManutencao,
          tecnicoDesignado: tecnicoDesignado,
          tecnicoDesignadoId: tecnicoDesignadoId,
          ultimoAtualizacao: ultimoAtualizacao,
          ultimaParada: ultimaParada,
          motivoParada: data['motivoParada']?.toString(),
          responsavel: _parsePerfil(data['responsavel']?.toString()),
          tempoOperacaoTotal: (data['tempoOperacaoTotal'] as num?)?.toDouble() ?? 0.0,
          numeroParadas: (data['numeroParadas'] as num?)?.toInt() ?? 0,
          tempoParado: (data['tempoParado'] as num?)?.toInt() ?? 0,
        );
      }).toList();

      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      _isLoading = false;
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

  Future<void> carregarEquipamentos() async {
    _isLoading = true;
    notifyListeners();
    try {
      final snap = await FirebaseFirestore.instance.collection('maquinas').get();
      _equipamentos = snap.docs.map((doc) {
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
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  /// REGRA DE NEGÓCIO: Permissão EXCLUSIVA (CRUD total) do Gestor Industrial
  Future<void> adicionarEquipamento(Equipamento novo, Usuario usuario) async {
    if (!usuario.can(AppPermission.crudMaquinas)) {
      throw Exception('Acesso negado: Apenas o Gestor Industrial pode cadastrar novas máquinas.');
    }

    final tagExiste = _equipamentos.any((e) => e.tag.toUpperCase() == novo.tag.toUpperCase());
    if (tagExiste) {
      throw Exception('Já existe um equipamento cadastrado com a TAG "${novo.tag}".');
    }

    final docRef = novo.id.isNotEmpty
        ? FirebaseFirestore.instance.collection('maquinas').doc(novo.id)
        : FirebaseFirestore.instance.collection('maquinas').doc();

    await docRef.set({
      'tag': novo.tag,
      'codigo': novo.tag,
      'nome': novo.nome,
      'localizacao': novo.localizacao,
      'status': novo.status.name,
      'grauCritico': novo.grauCritico,
      'aprovadaManutencao': novo.aprovadaManutencao,
      'tecnicoDesignado': novo.tecnicoDesignado,
      'tecnicoDesignadoId': novo.tecnicoDesignadoId,
      'ultimoAtualizacao': FieldValue.serverTimestamp(),
      'tempoOperacaoTotal': novo.tempoOperacaoTotal,
      'numeroParadas': novo.numeroParadas,
      'tempoParado': novo.tempoParado,
      'motivoParada': novo.motivoParada,
      if (novo.responsavel != null) 'responsavel': novo.responsavel!.name,
    });
  }

  /// REGRA DE NEGÓCIO: Permissão EXCLUSIVA de Gestor Industrial para editar máquina
  Future<void> editarEquipamento({
    required String id,
    required String tag,
    required String nome,
    required String localizacao,
    required Usuario usuario,
  }) async {
    if (!usuario.can(AppPermission.crudMaquinas)) {
      throw Exception('Acesso negado: Apenas o Gestor Industrial pode editar equipamentos.');
    }

    final tagFormatada = tag.trim().toUpperCase();
    final tagExiste = _equipamentos.any(
      (e) => e.id != id && e.tag.trim().toUpperCase() == tagFormatada,
    );
    if (tagExiste) {
      throw Exception('Já existe outro equipamento cadastrado com o código/TAG "$tagFormatada".');
    }

    await FirebaseFirestore.instance.collection('maquinas').doc(id).update({
      'tag': tagFormatada,
      'codigo': tagFormatada,
      'nome': nome.trim(),
      'localizacao': localizacao.trim(),
      'ultimoAtualizacao': FieldValue.serverTimestamp(),
    });
  }

  /// REGRA DE NEGÓCIO: Permissão EXCLUSIVA (CRUD total) do Gestor Industrial
  Future<void> removerEquipamento(String id, Usuario usuario) async {
    if (!usuario.can(AppPermission.crudMaquinas)) {
      throw Exception('Acesso negado: Apenas o Gestor Industrial pode remover equipamentos.');
    }

    await FirebaseFirestore.instance.collection('maquinas').doc(id).delete();
  }

  Future<void> atualizarStatusEquipamento(
    String id,
    StatusEquipamento novoStatus, {
    String? motivo,
    PerfilUsuario? responsavel,
    bool? grauCritico,
    bool? aprovadaManutencao,
    String? tecnicoDesignado,
    String? tecnicoDesignadoId,
  }) async {
    final Map<String, dynamic> updateData = {
      'status': novoStatus.name,
      'ultimoAtualizacao': FieldValue.serverTimestamp(),
    };

    if (motivo != null) updateData['motivoParada'] = motivo;
    if (responsavel != null) updateData['responsavel'] = responsavel.name;
    if (grauCritico != null) updateData['grauCritico'] = grauCritico;
    if (aprovadaManutencao != null) updateData['aprovadaManutencao'] = aprovadaManutencao;
    if (tecnicoDesignado != null) updateData['tecnicoDesignado'] = tecnicoDesignado;
    if (tecnicoDesignadoId != null) updateData['tecnicoDesignadoId'] = tecnicoDesignadoId;

    if (novoStatus == StatusEquipamento.parada || novoStatus == StatusEquipamento.aguardandoAprovacao) {
      updateData['ultimaParada'] = FieldValue.serverTimestamp();
      updateData['numeroParadas'] = FieldValue.increment(1);
    }

    await FirebaseFirestore.instance.collection('maquinas').doc(id).update(updateData);
  }
}
