import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:flutter/material.dart';

class ListPageSizeControl extends StatelessWidget {
  final int pageSize;
  final int totalElements;
  final ValueChanged<int> onChanged;

  const ListPageSizeControl({
    super.key,
    required this.pageSize,
    required this.totalElements,
    required this.onChanged,
  });

  static const sizes = [10, 20, 50, 100];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$totalElements registros',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            'Filas',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: sizes.contains(pageSize) ? pageSize : 10,
              isDense: true,
              borderRadius: BorderRadius.circular(12),
              items: [
                for (final size in sizes)
                  DropdownMenuItem(value: size, child: Text('$size')),
              ],
              onChanged: (value) {
                if (value != null && value != pageSize) onChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
