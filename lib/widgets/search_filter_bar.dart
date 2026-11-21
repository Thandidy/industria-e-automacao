// lib/widgets/search_filter_bar.dart

import 'package:material_ui/material_ui.dart';

/// Barra de busca e filtros para listagens de equipamentos.
class SearchFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String? Function(String?)? searchValidator;
  final ValueChanged<String> onSearchChanged;
  final List<String> statusFilters;
  final ValueChanged<List<String>> onStatusFiltersChanged;
  final String? hintText;

  const SearchFilterBar({
    super.key,
    required this.searchController,
    this.searchValidator,
    required this.onSearchChanged,
    required this.statusFilters,
    required this.onStatusFiltersChanged,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo de busca
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: hintText ?? 'Buscar equipamento, localização...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: onSearchChanged,
          ),
          if (searchValidator != null && searchValidator!(searchController.text) != null) ...[
            const SizedBox(height: 8),
            _ValidationMessage(message: searchValidator!(searchController.text)!),
          ],
          const SizedBox(height: 12),
          // Filtros de status
          const Text(
            'Filtrar por status',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatusFilterChip(
                  label: 'TODOS',
                  isSelected: statusFilters.contains('TODOS'),
                  onTap: () => onStatusFiltersChanged(['TODOS']),
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: 'Operando',
                  isSelected: statusFilters.contains('operando'),
                  onTap: () => onStatusFiltersChanged(
                    statusFilters.contains('operando')
                        ? ['TODOS']
                        : [...statusFilters.where((s) => s != 'TODOS'), 'operando'],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: 'Parada',
                  isSelected: statusFilters.contains('parada'),
                  onTap: () => onStatusFiltersChanged(
                    statusFilters.contains('parada')
                        ? ['TODOS']
                        : [...statusFilters.where((s) => s != 'TODOS'), 'parada'],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: 'Manutenção',
                  isSelected: statusFilters.contains('manutencao'),
                  onTap: () => onStatusFiltersChanged(
                    statusFilters.contains('manutencao')
                        ? ['TODOS']
                        : [...statusFilters.where((s) => s != 'TODOS'), 'manutencao'],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: 'Aguardando Material',
                  isSelected: statusFilters.contains('aguardandoMaterial'),
                  onTap: () => onStatusFiltersChanged(
                    statusFilters.contains('aguardandoMaterial')
                        ? ['TODOS']
                        : [...statusFilters.where((s) => s != 'TODOS'), 'aguardandoMaterial'],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: 'Aguardando Aprovação',
                  isSelected: statusFilters.contains('aguardandoAprovacao'),
                  onTap: () => onStatusFiltersChanged(
                    statusFilters.contains('aguardandoAprovacao')
                        ? ['TODOS']
                        : [...statusFilters.where((s) => s != 'TODOS'), 'aguardandoAprovacao'],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: isSelected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isSelected
            ? const BorderSide(color: Colors.white, width: 2)
            : BorderSide.none,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

class _ValidationMessage extends StatelessWidget {
  final String message;

  const _ValidationMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        message,
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }
}
