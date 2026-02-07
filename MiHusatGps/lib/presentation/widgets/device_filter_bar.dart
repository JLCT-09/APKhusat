import 'package:flutter/material.dart';

// Color corporativo HusatGps
const Color _colorCorporativo = Color(0xFFEF1A2D);

/// Widget que representa la barra de filtros segmentada para dispositivos
/// Permite filtrar por: Todos, En Línea, Fuera de Línea
class DeviceFilterBar extends StatelessWidget {
  final String selectedFilter;
  final Function(String) onFilterChanged;
  final Function(String) getFilterCount;

  const DeviceFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.getFilterCount,
  });

  @override
  Widget build(BuildContext context) {
    final filters = ['Todos', 'En Línea', 'Fuera de Línea'];
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: List.generate(filters.length, (index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter;
          final isLast = index == filters.length - 1;
          
          return Expanded(
            child: GestureDetector(
              onTap: () => onFilterChanged(filter),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: isLast ? null : Border(
                    right: BorderSide(
                      color: Colors.grey[300]!,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    '${filter} (${getFilterCount(filter)})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? _colorCorporativo : Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
