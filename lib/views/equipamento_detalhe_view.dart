// lib/views/equipamento_detalhe_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/equipamento.dart';
import '../models/historico.dart';
import '../models/ocorrencia.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../providers/auth_provider.dart';
import '../providers/ocorrencia_provider.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/status_badge.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/timeline_item.dart';

/// Tela de detalhes de um equipamento com timeline e histórico de manutenções.
class EquipamentoDetalheView extends StatefulWidget {
  final String equipamentoId;

  const EquipamentoDetalheView({
    super.key,
    required this.equipamentoId,
  });

  @override
  State<EquipamentoDetalheView> createState() =>
      _EquipamentoDetalheViewState();
}

class _EquipamentoDetalheViewState extends State<EquipamentoDetalheView> {
  final _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _registrarParada(Equipamento equipamento) async {
    final motivoController = TextEditingController();

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Parada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Equipamento: ${equipamento.tag} - ${equipamento.nome}'),
            const SizedBox(height: 12),
            TextField(
              controller: motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo da Parada',
                hintText: 'Ex.: Vazamento de óleo, ruído anormal...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar Parada', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmou != true) return;
    if (!mounted) return;

    final ocorrenciaProvider = context.read<OcorrenciaProvider>();
    final nomeUsuario = context.read<AuthProvider>().nome ?? 'Operador';

    setState(() => _isLoading = true);
    try {
      final motivo = motivoController.text.trim().isNotEmpty
          ? motivoController.text.trim()
          : 'Parada não programada';

      final eqIndex = ocorrenciaProvider.equipamentos.indexWhere((e) => e.id == equipamento.id);
      if (eqIndex != -1) {
        ocorrenciaProvider.equipamentos[eqIndex] = equipamento.copyWith(
          status: StatusEquipamento.parada,
          motivoParada: motivo,
          ultimaParada: DateTime.now(),
          ultimoAtualizacao: DateTime.now(),
        );
      }

      final novaOcorrencia = Ocorrencia(
        equipamentoId: equipamento.id,
        equipamentoTag: equipamento.tag,
        motivo: motivo,
        descricao: 'Parada registrada diretamente pela tela de detalhes do equipamento.',
        prioridade: 'Alta',
        status: StatusOcorrencia.aberta,
        dataAbertura: DateTime.now(),
        historico: [
          HistoricoItem(
            data: DateTime.now(),
            tipo: 'abertura',
            descricao: 'Parada registrada: $motivo',
            por: nomeUsuario,
            statusOcorrencia: StatusOcorrencia.aberta,
            statusEquipamento: StatusEquipamento.parada,
          ),
        ],
      );

      ocorrenciaProvider.ocorrencias.insert(0, novaOcorrencia);
      await ocorrenciaProvider.carregarOcorrencias();

      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Parada do equipamento registrada com sucesso.',
        isWarning: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _iniciarAtendimento(Ocorrencia ocorrencia) async {
    setState(() => _isLoading = true);
    try {
      await context.read<OcorrenciaProvider>().iniciarAtendimento(ocorrencia.id);
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Atendimento técnico iniciado.',
        isSuccess: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizarAtendimento(Ocorrencia ocorrencia) async {
    final relatoController = TextEditingController(text: 'Manutenção corretiva concluída.');

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar Atendimento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Equipamento: ${ocorrencia.equipamentoTag}'),
            const SizedBox(height: 12),
            TextField(
              controller: relatoController,
              decoration: const InputDecoration(
                labelText: 'Relato da Manutenção',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );

    if (confirmou != true) return;
    if (!mounted) return;

    final provider = context.read<OcorrenciaProvider>();

    setState(() => _isLoading = true);
    try {
      await provider.finalizarAtendimento(
            ocorrencia.id,
            relatoController.text.trim(),
          );
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Manutenção finalizada com sucesso!',
        isSuccess: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final ocorrenciaProvider = context.watch<OcorrenciaProvider>();

    final equipamento = ocorrenciaProvider.equipamentosPorId[widget.equipamentoId];

    final ocorrenciasDoEquipamento = ocorrenciaProvider.ocorrencias
        .where((o) => o.equipamentoId == widget.equipamentoId)
        .toList();

    final ocorrenciaAbertaOuEmAndamento = ocorrenciasDoEquipamento.cast<Ocorrencia?>().firstWhere(
          (o) =>
              o?.status == StatusOcorrencia.aberta ||
              o?.status == StatusOcorrencia.emAndamento,
          orElse: () => null,
        );

    return Scaffold(
      appBar: CustomAppBar(
        title: equipamento?.nome ?? 'Detalhes do Equipamento',
        usuario: authProvider.usuario,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : equipamento == null
              ? const _EmptyState()
              : RefreshIndicator(
                  onRefresh: () async {
                    await ocorrenciaProvider.carregarOcorrencias();
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeaderEquipamento(
                          equipamento: equipamento,
                        ),
                        const SizedBox(height: 20),
                        _MetricasEquipamento(
                          equipamento: equipamento,
                        ),
                        const SizedBox(height: 20),
                        _AcoesEquipamento(
                          equipamento: equipamento,
                          ocorrenciaAtiva: ocorrenciaAbertaOuEmAndamento,
                          perfil: authProvider.perfil ?? PerfilUsuario.operador,
                          onRegistrarParada: () => _registrarParada(equipamento),
                          onIniciarAtendimento: ocorrenciaAbertaOuEmAndamento != null
                              ? () => _iniciarAtendimento(ocorrenciaAbertaOuEmAndamento)
                              : null,
                          onFinalizarAtendimento: ocorrenciaAbertaOuEmAndamento != null
                              ? () => _finalizarAtendimento(ocorrenciaAbertaOuEmAndamento)
                              : null,
                        ),
                        const SizedBox(height: 24),
                        _TimelineEquipamento(
                          ocorrencias: ocorrenciasDoEquipamento,
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

/// Header com gradiente e informações principais
class _HeaderEquipamento extends StatelessWidget {
  final Equipamento equipamento;

  const _HeaderEquipamento({required this.equipamento});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                equipamento.statusIcon,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      equipamento.nome,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      equipamento.tag,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                status: equipamento.status,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoLabel(
                icone: Icons.location_on,
                label: equipamento.localizacao,
              ),
              const SizedBox(width: 16),
              _InfoLabel(
                icone: Icons.access_time,
                label: 'Atualizado: ${equipamento.formatoUltimaAtualizacao}',
              ),
            ],
          ),
          if (equipamento.motivoParada != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Motivo: ${equipamento.motivoParada}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoLabel extends StatelessWidget {
  final IconData icone;
  final String label;

  const _InfoLabel({required this.icone, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 14, color: Colors.white.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MetricasEquipamento extends StatelessWidget {
  final Equipamento equipamento;

  const _MetricasEquipamento({required this.equipamento});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icone: Icons.timer,
            valor: Helpers.formatDuration(equipamento.tempoOperacaoTotal.toInt()),
            label: 'Horas operando',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icone: Icons.pause_circle_outline,
            valor: equipamento.numeroParadas.toString(),
            label: 'Paradas registradas',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icone: Icons.access_time,
            valor: equipamento.formatoTempoParado,
            label: 'Tempo parado',
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icone;
  final String valor;
  final String label;

  const _MetricCard({
    required this.icone,
    required this.valor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Icon(icone, size: 26, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            valor,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}

class _AcoesEquipamento extends StatelessWidget {
  final Equipamento equipamento;
  final Ocorrencia? ocorrenciaAtiva;
  final PerfilUsuario perfil;
  final VoidCallback onRegistrarParada;
  final VoidCallback? onIniciarAtendimento;
  final VoidCallback? onFinalizarAtendimento;

  const _AcoesEquipamento({
    required this.equipamento,
    required this.ocorrenciaAtiva,
    required this.perfil,
    required this.onRegistrarParada,
    required this.onIniciarAtendimento,
    required this.onFinalizarAtendimento,
  });

  @override
  Widget build(BuildContext context) {
    final podeRegistrar =
        perfil == PerfilUsuario.operador ||
        perfil == PerfilUsuario.supervisor ||
        perfil == PerfilUsuario.gestor;

    final isTecnicoOuGestor =
        perfil == PerfilUsuario.tecnico || perfil == PerfilUsuario.gestor;

    final podeIniciar = isTecnicoOuGestor &&
        ocorrenciaAtiva != null &&
        ocorrenciaAtiva!.status == StatusOcorrencia.aberta;

    final podeFinalizar = isTecnicoOuGestor &&
        ocorrenciaAtiva != null &&
        ocorrenciaAtiva!.status == StatusOcorrencia.emAndamento;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ações Operacionais',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icone: Icons.stop_circle,
                    texto: 'Registrar Parada',
                    cor: Colors.red,
                    onPressed: podeRegistrar ? onRegistrarParada : null,
                  ),
                ),
              ],
            ),
            if (isTecnicoOuGestor) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icone: Icons.play_circle,
                      texto: 'Iniciar Atendimento',
                      cor: Colors.green,
                      onPressed: podeIniciar ? onIniciarAtendimento : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icone: Icons.check_circle,
                      texto: 'Finalizar Atendimento',
                      cor: Colors.blue,
                      onPressed: podeFinalizar ? onFinalizarAtendimento : null,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icone;
  final String texto;
  final Color cor;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icone,
    required this.texto,
    required this.cor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: cor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      icon: Icon(icone, size: 18),
      label: Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _TimelineEquipamento extends StatelessWidget {
  final List<Ocorrencia> ocorrencias;

  const _TimelineEquipamento({required this.ocorrencias});

  @override
  Widget build(BuildContext context) {
    final todosHistoricos = <HistoricoItem>[];

    for (final ocorrencia in ocorrencias) {
      if (ocorrencia.historico.isNotEmpty) {
        todosHistoricos.addAll(ocorrencia.historico);
      } else {
        todosHistoricos.add(
          HistoricoItem(
            data: ocorrencia.dataAbertura,
            tipo: ocorrencia.status == StatusOcorrencia.finalizada
                ? 'finalizacao'
                : (ocorrencia.status == StatusOcorrencia.emAndamento
                    ? 'inicio'
                    : 'abertura'),
            descricao: '${ocorrencia.motivo}: ${ocorrencia.descricao}',
            por: ocorrencia.tecnicoResponsavel,
            statusOcorrencia: ocorrencia.status,
          ),
        );
      }
    }

    // Ordenar do mais recente para o mais antigo
    todosHistoricos.sort((a, b) => b.data.compareTo(a.data));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.history,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Histórico e Timeline de Manutenção',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (todosHistoricos.isEmpty)
          const _NoDataMessage()
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: todosHistoricos.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return TimelineItem(item: todosHistoricos[index]);
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _NoDataMessage extends StatelessWidget {
  const _NoDataMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Text(
        'Nenhuma ocorrência registrada para este equipamento.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Equipamento não encontrado',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Este equipamento não está cadastrado no sistema.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
