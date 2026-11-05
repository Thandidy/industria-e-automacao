// lib/views/painel_tecnico_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ocorrencia.dart';
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
    setState(() => _isLoading = true);
    try {
      final provider = context.read<OcorrenciaProvider>();
      await provider.iniciarAtendimento(ocorrencia.id);
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Atendimento da ocorrência #${ocorrencia.equipamentoTag} iniciado!',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Erro ao iniciar atendimento: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizarAtendimento(Ocorrencia ocorrencia) async {
    final observacaoController = TextEditingController(text: 'Manutenção concluída com sucesso.');

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar Atendimento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Equipamento: ${ocorrencia.equipamentoTag} - ${ocorrencia.motivo}'),
            const SizedBox(height: 16),
            TextField(
              controller: observacaoController,
              decoration: const InputDecoration(
                labelText: 'Observação Final / Relato Técnico',
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
            child: const Text('Concluir'),
          ),
        ],
      ),
    );

    if (confirmou != true) return;
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final provider = context.read<OcorrenciaProvider>();
      await provider.finalizarAtendimento(
        ocorrencia.id,
        observacaoController.text.trim(),
      );
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Atendimento finalizado com sucesso!',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Erro ao finalizar atendimento: $e',
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

    final ocorrenciasFiltradas = _obterOcorrenciasFiltradas(ocorrenciaProvider.ocorrencias);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Painel Técnico',
        usuario: authProvider.usuario,
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
                _FilterSection(
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
                    ocorrencias: ocorrenciasFiltradas,
                    onIniciarAtendimento: _iniciarAtendimento,
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

class _FilterSection extends StatelessWidget {
  final String? filtroAtual;
  final ValueChanged<String?> onFiltrarPorStatus;

  const _FilterSection({
    required this.filtroAtual,
    required this.onFiltrarPorStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
  final List<Ocorrencia> ocorrencias;
  final ValueChanged<Ocorrencia> onIniciarAtendimento;
  final ValueChanged<Ocorrencia> onFinalizarAtendimento;

  const _ListaOcorrencias({
    required this.ocorrencias,
    required this.onIniciarAtendimento,
    required this.onFinalizarAtendimento,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ocorrencias.map((ocorrencia) {
        final estaEmAndamento = ocorrencia.status == StatusOcorrencia.emAndamento;
        final estaFinalizada = ocorrencia.status == StatusOcorrencia.finalizada;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _statusColor(ocorrencia.status),
                child: Icon(
                  _getStatusIcon(ocorrencia.status),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ocorrencia.equipamentoTag,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ocorrencia.motivo,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    ocorrencia.descricao,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Aberto há: ${ocorrencia.tempoAbertoFormatado}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '@${ocorrencia.tecnicoResponsavel ?? "Pendente"}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: estaFinalizada
                  ? const Chip(
                      label: Text('Concluído', style: TextStyle(fontSize: 11)),
                      backgroundColor: Colors.transparent,
                    )
                  : _ActionButton(
                      icon: estaEmAndamento ? Icons.stop_circle : Icons.play_circle,
                      label: estaEmAndamento ? 'Finalizar' : 'Iniciar',
                      color: estaEmAndamento ? Colors.red : Theme.of(context).colorScheme.primary,
                      onPressed: () {
                        if (estaEmAndamento) {
                          onFinalizarAtendimento(ocorrencia);
                        } else {
                          onIniciarAtendimento(ocorrencia);
                        }
                      },
                    ),
            ),
          ),
        );
      }).toList(),
    );
  }

  static Color _statusColor(StatusOcorrencia status) {
    switch (status) {
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

  static IconData _getStatusIcon(StatusOcorrencia status) {
    switch (status) {
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.work_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum atendimento ativo',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'As ocorrências serão listadas aqui.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
