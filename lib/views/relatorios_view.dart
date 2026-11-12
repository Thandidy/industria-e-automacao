// lib/views/relatorios_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ocorrencia.dart';
import '../models/equipamento.dart';
import '../utils/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/ocorrencia_provider.dart';
import '../widgets/custom_app_bar.dart';

class RelatoriosView extends StatefulWidget {
  const RelatoriosView({super.key});

  @override
  State<RelatoriosView> createState() => _RelatoriosViewState();
}

class _RelatoriosViewState extends State<RelatoriosView> {
  String _selectedPeriod = '7 dias';
  StatusOcorrencia? _selectedStatus;

  List<Ocorrencia> _filtrarOcorrencias(List<Ocorrencia> ocorrencias) {
    DateTime? limiteData;
    switch (_selectedPeriod) {
      case '7 dias':
        limiteData = DateTime.now().subtract(const Duration(days: 7));
        break;
      case '30 dias':
        limiteData = DateTime.now().subtract(const Duration(days: 30));
        break;
      case '90 dias':
        limiteData = DateTime.now().subtract(const Duration(days: 90));
        break;
      case '1 ano':
        limiteData = DateTime.now().subtract(const Duration(days: 365));
        break;
      case 'Todos':
      default:
        limiteData = null;
        break;
    }

    return ocorrencias.where((o) {
      final matchesPeriod = limiteData == null || o.dataAbertura.isAfter(limiteData);
      final matchesStatus = _selectedStatus == null || o.status == _selectedStatus;
      return matchesPeriod && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final ocorrenciaProvider = context.watch<OcorrenciaProvider>();

    final ocorrenciasFiltradas = _filtrarOcorrencias(ocorrenciaProvider.ocorrencias);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Relatórios & Gestão',
        usuario: authProvider.usuario,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ocorrenciaProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _FilterSection(
                    selectedPeriod: _selectedPeriod,
                    selectedStatus: _selectedStatus,
                    onPeriodChanged: (period) {
                      setState(() {
                        _selectedPeriod = period;
                      });
                    },
                    onStatusChanged: (status) {
                      setState(() {
                        _selectedStatus = status;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _KPIsSection(
                    ocorrencias: ocorrenciasFiltradas,
                    equipamentos: ocorrenciaProvider.equipamentos,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ocorrenciasFiltradas.isEmpty
                        ? const _EmptyState()
                        : _TabelaOcorrencias(
                            ocorrencias: ocorrenciasFiltradas,
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String selectedPeriod;
  final StatusOcorrencia? selectedStatus;
  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<StatusOcorrencia?> onStatusChanged;

  const _FilterSection({
    required this.selectedPeriod,
    required this.selectedStatus,
    required this.onPeriodChanged,
    required this.onStatusChanged,
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
            'Filtros de Relatório',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedPeriod,
                  decoration: const InputDecoration(
                    labelText: 'Período',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: ['7 dias', '30 dias', '90 dias', '1 ano', 'Todos'].map((period) {
                    return DropdownMenuItem<String>(
                      value: period,
                      child: Text(period),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) onPeriodChanged(val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<StatusOcorrencia?>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem<StatusOcorrencia?>(
                      value: null,
                      child: Text('Todos os Status'),
                    ),
                    DropdownMenuItem<StatusOcorrencia?>(
                      value: StatusOcorrencia.aguardandoAprovacao,
                      child: Text('Aguardando Aprovação'),
                    ),
                    DropdownMenuItem<StatusOcorrencia?>(
                      value: StatusOcorrencia.aberta,
                      child: Text('Abertas'),
                    ),
                    DropdownMenuItem<StatusOcorrencia?>(
                      value: StatusOcorrencia.emAndamento,
                      child: Text('Em Andamento'),
                    ),
                    DropdownMenuItem<StatusOcorrencia?>(
                      value: StatusOcorrencia.aguardandoMaterial,
                      child: Text('Aguardando Material'),
                    ),
                    DropdownMenuItem<StatusOcorrencia?>(
                      value: StatusOcorrencia.finalizada,
                      child: Text('Finalizadas'),
                    ),
                  ],
                  onChanged: onStatusChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KPIsSection extends StatelessWidget {
  final List<Ocorrencia> ocorrencias;
  final List<Equipamento> equipamentos;

  const _KPIsSection({
    required this.ocorrencias,
    required this.equipamentos,
  });

  @override
  Widget build(BuildContext context) {
    final totalOcorrencias = ocorrencias.length;
    final emAndamento = ocorrencias
        .where((o) => o.status == StatusOcorrencia.emAndamento)
        .length;
    final finalizadas = ocorrencias
        .where((o) => o.status == StatusOcorrencia.finalizada)
        .length;
    final tempoMedio = _calcularTempoMedio(ocorrencias);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _KpiCard(
            icone: Icons.report_outlined,
            valor: totalOcorrencias.toString(),
            label: 'Total Ocorrências',
            cor: Colors.blue,
          ),
          const SizedBox(width: 8),
          _KpiCard(
            icone: Icons.play_circle_outline,
            valor: emAndamento.toString(),
            label: 'Em Andamento',
            cor: Colors.amber,
          ),
          const SizedBox(width: 8),
          _KpiCard(
            icone: Icons.check_circle_outline,
            valor: finalizadas.toString(),
            label: 'Finalizadas',
            cor: Colors.green,
          ),
          const SizedBox(width: 8),
          _KpiCard(
            icone: Icons.schedule,
            valor: tempoMedio,
            label: 'Tempo Médio',
            cor: Colors.purple,
          ),
        ],
      ),
    );
  }

  static String _calcularTempoMedio(List<Ocorrencia> ocorrencias) {
    if (ocorrencias.isEmpty) return '0h';
    final soma = ocorrencias.fold(
      0,
      (sum, o) => sum + (int.tryParse(o.duracaoSegundos) ?? 0),
    );
    final media = soma / ocorrencias.length;
    if (media < 60) return '${media.toInt()}s';
    final minutos = media ~/ 60;
    if (minutos < 60) return '${minutos}m';
    final horas = minutos ~/ 60;
    return '${horas}h';
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icone;
  final String valor;
  final String label;
  final Color cor;

  const _KpiCard({
    required this.icone,
    required this.valor,
    required this.label,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icone, size: 24, color: cor),
            const SizedBox(height: 6),
            Text(
              valor,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cor,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabelaOcorrencias extends StatelessWidget {
  final List<Ocorrencia> ocorrencias;

  const _TabelaOcorrencias({
    required this.ocorrencias,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: ocorrencias.length,
      itemBuilder: (context, index) {
        final ocorrencia = ocorrencias[index];
        return _OcorrenciaRow(ocorrencia: ocorrencia);
      },
    );
  }
}

class _OcorrenciaRow extends StatelessWidget {
  final Ocorrencia ocorrencia;

  const _OcorrenciaRow({required this.ocorrencia});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ocorrencia.equipamentoTag,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (ocorrencia.ehCritica) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red, width: 0.8),
                          ),
                          child: const Text(
                            'CRÍTICA',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ),
                      ],
                      if (ocorrencia.tecnicoDesignado != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.teal, width: 0.8),
                          ),
                          child: Text(
                            'Designado: ${ocorrencia.tecnicoDesignado}',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ocorrencia.motivo,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ocorrencia.descricao,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Duração: ${ocorrencia.duracaoFormatada}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusBadgeOcorrencia(status: ocorrencia.status),
                const SizedBox(height: 6),
                if (ocorrencia.tecnicoResponsavel != null)
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      ocorrencia.tecnicoResponsavel![0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadgeOcorrencia extends StatelessWidget {
  final StatusOcorrencia status;

  const _StatusBadgeOcorrencia({required this.status});

  @override
  Widget build(BuildContext context) {
    final cor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.nome,
        style: TextStyle(
          color: cor,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
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
            Icons.dashboard_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum dado para exibir',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajuste o período ou os filtros de status selecionados.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
