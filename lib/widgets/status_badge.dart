// lib/widgets/status_badge.dart

import 'package:material_ui/material_ui.dart';
import '../utils/constants.dart';
import '../models/equipamento.dart';

/// Widget de badge de status com cores temáticas e suporte a Estados X e Y industriais.
class StatusBadge extends StatelessWidget {
  final StatusEquipamento status;
  final String? label;
  final double size;
  final IconData? iconOverride;
  final Color? colorOverride;
  final Equipamento? equipamento;

  const StatusBadge({
    super.key,
    required this.status,
    this.label,
    this.size = 20,
    this.iconOverride,
    this.colorOverride,
    this.equipamento,
  });

  @override
  Widget build(BuildContext context) {
    final cor = colorOverride ?? equipamento?.statusColor ?? status.cor(status);
    final icone = iconOverride ?? equipamento?.statusIcon ?? status.icon;
    final texto = label ?? equipamento?.statusNome ?? status.nome;
    final textoCor = _calculaCorTexto(cor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.6), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icone,
            color: cor,
            size: size,
          ),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              color: textoCor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  static Color _calculaCorTexto(Color cor) {
    final lum = (0.299 * (cor.r * 255.0).round().clamp(0, 255) +
            0.587 * (cor.g * 255.0).round().clamp(0, 255) +
            0.114 * (cor.b * 255.0).round().clamp(0, 255)) /
        255;
    return lum > 0.6 ? Colors.black87 : Colors.white;
  }
}
