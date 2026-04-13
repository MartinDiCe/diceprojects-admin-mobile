import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status.toUpperCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: config.$1.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        config.$2,
        style: TextStyle(
          color: config.$1,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  (Color, String) _getConfig(String s) {
    switch (s) {
      case 'ACTIVE':
      case 'ACTIVO':
      case 'ENABLED':
      case 'HABILITADO':
      case 'DISPONIBLE':
        return (AppColors.success, _label(s));
      case 'INACTIVE':
      case 'INACTIVO':
      case 'DISABLED':
      case 'DESHABILITADO':
        return (AppColors.error, _label(s));
      case 'PENDING':
      case 'PENDIENTE':
        return (AppColors.warning, _label(s));
      case 'CONSULTAR':
        return (AppColors.textSecondary, _label(s));
      default:
        return (AppColors.textSecondary, status);
    }
  }

  String _label(String s) {
    switch (s) {
      case 'ACTIVE':
        return 'Activo';
      case 'INACTIVE':
        return 'Inactivo';
      case 'PENDING':
        return 'Pendiente';
      case 'ENABLED':
        return 'Habilitado';
      case 'DISABLED':
        return 'Deshabilitado';
      default:
        return status;
    }
  }
}
