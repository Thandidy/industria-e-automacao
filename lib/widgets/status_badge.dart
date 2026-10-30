// lib/widgets/status_badge.dart

import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Widget de badge de status com cores temáticas para o contexto industrial.
class StatusBadge extends StatelessWidget {
  final StatusEquipamento status;
  final String? label;
  final double size;

  const StatusBadge({
    super.key,
    required this.status,
    this.label,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final cor = status.cor(status);
    final textoCor = _calculaCorTexto(cor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.icon,
            color: cor,
            size: size,
          ),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(
              label!,
              style: TextStyle(
                color: textoCor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color _calculaCorTexto(Color cor) {
    final lum = (0.299 * cor.red + 0.587 * cor.green + 0.114 * cor.blue) / 255;
    return lum > 0.5 ? Colors.black : Colors.white;
  }
}
