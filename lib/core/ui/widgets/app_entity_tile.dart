import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:flutter/material.dart';

class AppEntityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> details;
  final String? status;
  final VoidCallback? onTap;
  final List<Widget> actions;

  const AppEntityTile({
    super.key,
    required this.icon,
    required this.title,
    this.details = const [],
    this.status,
    this.onTap,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = details
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && !_looksLikeUuid(value))
        .join(' · ');

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.accent, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.trim().isEmpty ? 'Sin nombre' : title.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (status != null) ...[
            const SizedBox(width: 8),
            StatusBadge(status: status!),
          ],
          ...actions,
        ],
      ),
    );

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: onTap == null
          ? content
          : InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: content,
            ),
    );
  }
}

bool _looksLikeUuid(String value) {
  final text = value.trim();
  if (text.length != 36) return false;
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(text);
}
