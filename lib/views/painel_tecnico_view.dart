// lib/views/painel_tecnico_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ocorrencia.dart';
import '../models/usuario.dart';
import '../utils/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/ocorrencia_provider.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/loading_overlay.dart';

class PainelTecnicoView extends StatefulWidget {
  const PainelTecnicoView({super.key});

  @override
  State<PainelTecnicoView> createState() => _PainelTecnicoViewState();
}

class _PainelTecnicoViewState extends State<PainelTecnicoView> {
  final _scrollController = ScrollController();
  String? _filtroStatus;
  bool _isLoading = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Ocorrencia> _obterOcorrenciasFiltradas(List<Ocorrencia> ocorrencias) {
    if (_filtroStatus == null || _filtroStatus == 'TODOS') {
      return ocorrencias;
    }
    return ocorrencias.where((o) => o.status.name == _filtroStatus).toList();
  }

  Future<void> _iniciarAtendimento(Ocorrencia ocorrencia) async {
    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;

    setState(() => _isLoading = true);
    try {
      final provider = context.read<OcorrenciaProvider>();
      await provider.assumirAtendimento(
        ocorrenciaId: ocorrencia.id,
        usuario: usuario,
      );
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Atendimento do equipamento ${ocorrencia.equipamentoTag} iniciado com sucesso!',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pausarPorMaterial(Ocorrencia ocorrencia) async {
    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;

    final motivoController = TextEditingController();

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.inventory_2, color: Colors.amber),
            SizedBox(width: 8),
            Text('Pausar por Falta de Material'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Equipamento: ${ocorrencia.equipamentoTag}'),
            const SizedBox(height: 12),
            TextField(
              controller: motivoController,
              decoration: const InputDecoration(
                labelText: 'Peças/Insumos Necessários *',
                hintText: 'Ex.: Retentor 45mm, correia dentada...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar Pausa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmou != true) return;
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      await context.read<OcorrenciaProvider>().pausarAguardandoMaterial(
            ocorrenciaId: ocorrencia.id,
            motivoPausa: motivoController.text.trim().isNotEmpty
                ? motivoController.text.trim()
                : 'Aguardando peças do almoxarifado',
            usuario: usuario,
          );

      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Chamado pausado: Aguardando materiais serem fornecidos pelo Supervisor.',
        isWarning: true,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizarAtendimento(Ocorrencia ocorrencia) async {
    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;

    final formKey = GlobalKey<FormState>();
    final laudoController = TextEditingController(text: 'Manutenção corretiva executada e aprovada.');
    final pecasController = TextEditingController();

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in, color: Colors.green),
            SizedBox(width: 8),
            Text('Laudo Técnico de Liberação'),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Equipamento: ${ocorrencia.equipamentoTag} - ${ocorrencia.motivo}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: laudoController,
                  decoration: const InputDecoration(
                    labelText: 'Laudo / Parecer Técnico *',
                    hintText: 'Descreva os reparos realizados (mínimo 10 caracteres)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? 'Descreva o laudo detalhadamente (mínimo 10 caracteres)'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pecasController,
                  decoration: const InputDecoration(
                    labelText: 'Peças Trocadas (opcional, separadas por vírgula)',
                    hintText: 'Ex.: Retentor 45mm, Rolamento 6205',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Emitir Laudo & Liberar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmou != true) return;
    if (!mounted) return;

    final pecas = pecasController.text
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    setState(() => _isLoading = true);
    try {
      final provider = context.read<OcorrenciaProvider>();
      await provider.finalizarAtendimentoComLaudo(
        ocorrenciaId: ocorrencia.id,
        laudoTecnico: laudoController.text.trim(),
        pecasTrocadas: pecas,
        usuario: usuario,
      );
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Atendimento finalizado com sucesso! Máquina liberada para Operando.',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final ocorrenciaProvider = context.watch<OcorrenciaProvider>();
    final usuario = authProvider.usuario;

    final ocorrenciasFiltradas = _obterOcorrenciasFiltradas(ocorrenciaProvider.ocorrencias);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Painel Técnico de Manutenção',
        usuario: usuario,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: RefreshIndicator(
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
                _KPIsHeader(ocorrencias: ocorrenciaProvider.ocorrencias),
                const SizedBox(height: 16),
                _FilterBar(
                  filtroAtual: _filtroStatus,
                  onFiltrarPorStatus: (status) {
                    setState(() {
                      _filtroStatus = status;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (ocorrenciasFiltradas.isEmpty)
                  const _EmptyState()
                else
                  _ListaOcorrencias(
                    usuarioLogado: usuario,
                    ocorrencias: ocorrenciasFiltradas,
                    onIniciarAtendimento: _iniciarAtendimento,
                    onPausarAtendimento: _pausarPorMaterial,
                    onFinalizarAtendimento: _finalizarAtendimento,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KPIsHeader extends StatelessWidget {
  final List<Ocorrencia> ocorrencias;

  const _KPIsHeader({required this.ocorrencias});

  @override
  Widget build(BuildContext context) {
    final abertas = ocorrencias.where((o) => o.status == StatusOcorrencia.aberta).length;
    final aguardandoAprovacao = ocorrencias.where((o) => o.status == StatusOcorrencia.aguardandoAprovacao).length;
    final emAndamento = ocorrencias.where((o) => o.status == StatusOcorrencia.emAndamento).length;
    final aguardandoMaterial = ocorrencias.where((o) => o.status == StatusOcorrencia.aguardandoMaterial).length;

    return Row(
      children: [
        _KpiCard(
          label: 'Aguard. Aprovação',
          valor: aguardandoAprovacao.toString(),
          cor: Colors.purpleAccent,
          icone: Icons.pending_actions,
        ),
        const SizedBox(width: 8),
        _KpiCard(
          label: 'Abertas',
          valor: abertas.toString(),
          cor: Colors.orange,
          icone: Icons.error_outline,
        ),
        const SizedBox(width: 8),
        _KpiCard(
          label: 'Em Reparo',
          valor: emAndamento.toString(),
          cor: Colors.blue,
          icone: Icons.build_circle_outlined,
        ),
        const SizedBox(width: 8),
        _KpiCard(
          label: 'Falta Peças',
          valor: aguardandoMaterial.toString(),
          cor: Colors.amber,
          icone: Icons.inventory_2_outlined,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String valor;
  final Color cor;
  final IconData icone;

  const _KpiCard({
    required this.label,
    required this.valor,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icone, color: cor, size: 20),
            const SizedBox(height: 4),
            Text(
              valor,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cor,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String? filtroAtual;
  final ValueChanged<String?> onFiltrarPorStatus;

  const _FilterBar({
    required this.filtroAtual,
    required this.onFiltrarPorStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtrar por status',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'TODOS',
                  isSelected: filtroAtual == null || filtroAtual == 'TODOS',
                  onTap: () => onFiltrarPorStatus('TODOS'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Aguardando Aprovação',
                  isSelected: filtroAtual == StatusOcorrencia.aguardandoAprovacao.name,
                  onTap: () => onFiltrarPorStatus(StatusOcorrencia.aguardandoAprovacao.name),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Abertas',
                  isSelected: filtroAtual == StatusOcorrencia.aberta.name,
                  onTap: () => onFiltrarPorStatus(StatusOcorrencia.aberta.name),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Em Andamento',
                  isSelected: filtroAtual == StatusOcorrencia.emAndamento.name,
                  onTap: () => onFiltrarPorStatus(StatusOcorrencia.emAndamento.name),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Aguardando Material',
                  isSelected: filtroAtual == StatusOcorrencia.aguardandoMaterial.name,
                  onTap: () => onFiltrarPorStatus(StatusOcorrencia.aguardandoMaterial.name),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Finalizadas',
                  isSelected: filtroAtual == StatusOcorrencia.finalizada.name,
                  onTap: () => onFiltrarPorStatus(StatusOcorrencia.finalizada.name),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary
            : Colors.transparent,
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? Colors.white
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

class _ListaOcorrencias extends StatelessWidget {
  final Usuario? usuarioLogado;
  final List<Ocorrencia> ocorrencias;
  final ValueChanged<Ocorrencia> onIniciarAtendimento;
  final ValueChanged<Ocorrencia> onPausarAtendimento;
  final ValueChanged<Ocorrencia> onFinalizarAtendimento;

  const _ListaOcorrencias({
    required this.usuarioLogado,
    required this.ocorrencias,
    required this.onIniciarAtendimento,
    required this.onPausarAtendimento,
    required this.onFinalizarAtendimento,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ocorrencias.map((ocorrencia) {
        final estaEmAndamento = ocorrencia.status == StatusOcorrencia.emAndamento;
        final estaAguardandoMaterial = ocorrencia.status == StatusOcorrencia.aguardandoMaterial;
        final estaFinalizada = ocorrencia.status == StatusOcorrencia.finalizada;

        // Regra de Aprovação Crítica:
        final precisaAprovacao = ocorrencia.precisaAprovacao;
        final ehCritica = ocorrencia.ehCritica;

        // Se for crítica e aprovada, verificar se o usuário logado é o técnico designado:
        bool ehTecnicoDesignado = false;
        if (ehCritica && ocorrencia.aprovadaManutencao && usuarioLogado != null) {
          final idBate = ocorrencia.tecnicoDesignadoId != null &&
              ocorrencia.tecnicoDesignadoId == usuarioLogado!.id;
          final nomeBate = ocorrencia.tecnicoDesignado != null &&
              ocorrencia.tecnicoDesignado!.trim().toLowerCase() == usuarioLogado!.nome.trim().toLowerCase();
          ehTecnicoDesignado = idBate || nomeBate;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: precisaAprovacao
                  ? Colors.purpleAccent.shade400
                  : (ehCritica && ocorrencia.aprovadaManutencao
                      ? Colors.tealAccent.shade400
                      : Colors.transparent),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header do card
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ocorrencia.equipamentoTag,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (ehCritica)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.redAccent),
                            ),
                            child: const Text('CRÍTICA', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    _buildStatusChip(ocorrencia),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  ocorrencia.motivo,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  ocorrencia.descricao,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade400),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('Aberto há: ${ocorrencia.tempoAbertoFormatado}', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 12),
                    if (ocorrencia.tecnicoDesignado != null)
                      Text(
                        'Designado: ${ocorrencia.tecnicoDesignado}',
                        style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                  ],
                ),
                const Divider(height: 20),
                // Botões de ação
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (estaFinalizada)
                      const Chip(
                        avatar: Icon(Icons.check, size: 14, color: Colors.green),
                        label: Text('Concluído', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.transparent,
                      )
                    else if (estaEmAndamento) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amber,
                          side: const BorderSide(color: Colors.amber),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.pause, size: 16),
                        label: const Text('Pausar (Falta Peças)', style: TextStyle(fontSize: 12)),
                        onPressed: () => onPausarAtendimento(ocorrencia),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        icon: const Icon(Icons.assignment_turned_in, size: 16, color: Colors.white),
                        label: const Text('Finalizar c/ Laudo', style: TextStyle(color: Colors.white, fontSize: 12)),
                        onPressed: () => onFinalizarAtendimento(ocorrencia),
                      ),
                    ] else if (estaAguardandoMaterial) ...[
                      const Chip(
                        avatar: Icon(Icons.inventory_2, size: 14, color: Colors.amber),
                        label: Text('Aguardando Entrega de Material', style: TextStyle(color: Colors.amber, fontSize: 12)),
                        backgroundColor: Colors.transparent,
                      ),
                    ] else if (precisaAprovacao) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.withValues(alpha: 0.3),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.lock_clock, size: 16, color: Colors.purpleAccent),
                        label: const Text('Aguardando Aprovação do Supervisor', style: TextStyle(color: Colors.purpleAccent, fontSize: 12)),
                        onPressed: null,
                      ),
                    ] else if (ehCritica && ocorrencia.aprovadaManutencao && !ehTecnicoDesignado) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.withValues(alpha: 0.2),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.person, size: 16, color: Colors.white70),
                        label: Text('Exclusivo: ${ocorrencia.tecnicoDesignado}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Esta manutenção crítica foi designada exclusivamente para o técnico "${ocorrencia.tecnicoDesignado}".'),
                              backgroundColor: Colors.orange.shade800,
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        icon: const Icon(Icons.play_circle_fill, size: 16, color: Colors.white),
                        label: const Text('Iniciar Atendimento', style: TextStyle(color: Colors.white, fontSize: 12)),
                        onPressed: () => onIniciarAtendimento(ocorrencia),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusChip(Ocorrencia o) {
    if (o.precisaAprovacao) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purpleAccent),
        ),
        child: const Text('Aguardando Aprovação', style: TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
    if (o.ehCritica && o.aprovadaManutencao && o.status == StatusOcorrencia.aberta) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.tealAccent),
        ),
        child: const Text('Aprovada p/ Início', style: TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: o.status.cor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(o.status.nome, style: TextStyle(color: o.status.cor, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            const Text('Nenhuma ocorrência encontrada com o filtro selecionado.'),
          ],
        ),
      ),
    );
  }
}
