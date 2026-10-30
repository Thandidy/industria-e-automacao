// lib/widgets/timeline_item.dart

import 'package:flutter/material.dart';
import '../models/historico.dart';


/// Item de linha do timeline para exibir o histórico de uma ocorrência.
class TimelineItem extends StatelessWidget {
  final HistoricoItem item;

  const TimelineItem({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final cor = _getCorDoTipo(item.tipo);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Indicador do tipo
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cor.withValues(alpha: 0.5)),
            ),
            child: Icon(
              item.tipoIcon,
              color: cor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          // Conteúdo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.descricao,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ),
                    Text(
                      item.dataFormatada,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
                if (item.por != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@${item.por}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _getCorDoTipo(String tipo) {
    switch (tipo) {
      case 'abertura':
        return Colors.blue;
      case 'inicio':
        return Colors.green;
      case 'finalizacao':
        return Colors.green;
      case 'alteracao_status':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
