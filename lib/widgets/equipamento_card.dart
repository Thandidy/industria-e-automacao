// lib/widgets/equipamento_card.dart

import 'package:flutter/material.dart';
import 'status_badge.dart';
import '../models/equipamento.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

/// Card visual de um equipamento para a listagem no dashboard.
class EquipamentoCard extends StatelessWidget {
  final Equipamento equipamento;
  final bool showActions;

  const EquipamentoCard({
    super.key,
    required this.equipamento,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho com tag e status
            Row(
              children: [
                Expanded(
                  child: Text(
                    equipamento.tag,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFamily: 'monospace',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
                StatusBadge(
                  status: equipamento.status,
                  equipamento: equipamento,
                ),
              ],
            ),
            if (equipamento.grauCritico && !equipamento.aprovadaManutencao && equipamento.status != StatusEquipamento.operando) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700, width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pending_actions, size: 14, color: Colors.amber),
                    SizedBox(width: 6),
                    Text(
                      'Parada Crítica — Exige aprovação do Supervisor',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber),
                    ),
                  ],
                ),
              ),
            ] else if (equipamento.grauCritico && equipamento.aprovadaManutencao && equipamento.tecnicoDesignado != null && equipamento.status != StatusEquipamento.operando) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade700, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.assignment_ind, size: 14, color: Colors.teal),
                    const SizedBox(width: 6),
                    Text(
                      'Designada ao técnico: ${equipamento.tecnicoDesignado}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Título
            Text(
              equipamento.nome,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            // Localização
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  equipamento.localizacao,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Métricas em linhas
            Row(
              children: [
                _MetricItem(
                  icone: Icons.timer,
                  valor: Helpers.formatDuration(
                    equipamento.tempoOperacaoTotal.toInt(),
                  ),
                  label: 'Horas',
                ),
                const SizedBox(width: 16),
                _MetricItem(
                  icone: Icons.pause_circle_outline,
                  valor: equipamento.numeroParadas.toString(),
                  label: 'Paradas',
                ),
                const SizedBox(width: 16),
                _MetricItem(
                  icone: Icons.access_time,
                  valor: equipamento.formatoTempoParado,
                  label: 'T. Parado',
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Footer com data e ações
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Atualizado: ${equipamento.formatoUltimaAtualizacao}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                if (showActions)
                  IconButton(
                    onPressed: () {
                      // Navegar para detalhes
                    },
                    icon: const Icon(Icons.arrow_forward_ios),
                    iconSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Item de métrica individual dentro do card.
class _MetricItem extends StatelessWidget {
  final IconData icone;
  final String valor;
  final String label;

  const _MetricItem({
    required this.icone,
    required this.valor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icone,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
