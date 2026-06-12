import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/features/notifications/data/notification_inbox_models.dart';
import 'package:app_diceprojects_admin/features/notifications/data/notification_inbox_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationInboxProvider);
    final notifier = ref.read(notificationInboxProvider.notifier);

    return AppPageScaffold(
      title: 'Notificaciones',
      actions: [
        IconButton(
          tooltip: 'Configurar',
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => const _NotificationPreferencesSheet(),
          ),
          icon: const Icon(Icons.tune_rounded),
        ),
        IconButton(
          tooltip: 'Actualizar',
          onPressed: notifier.refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              _EmptyState(
                icon: Icons.notifications_off_rounded,
                title: 'No pudimos cargar la campana',
                subtitle: 'Deslizá para reintentar.',
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: const [
                  _EmptyState(
                    icon: Icons.done_all_rounded,
                    title: 'Estás al día',
                    subtitle: 'No hay novedades pendientes.',
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (_, index) {
                final item = items[index];
                return Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      await notifier.markRead(item);
                      if (context.mounted) context.go(_mobileTarget(item.targetPath));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.notifications_active_rounded, color: AppColors.accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                                if (item.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(item.description, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  item.createdDate == null ? 'Nueva' : DateFormat('dd/MM/yyyy HH:mm').format(item.createdDate!),
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: items.length,
            );
          },
        ),
      ),
    );
  }

  static String _mobileTarget(String targetPath) {
    if (targetPath.startsWith('/sales/quotes')) return '/sales/quotes';
    return targetPath.split('?').first;
  }
}

class _NotificationPreferencesSheet extends ConsumerWidget {
  const _NotificationPreferencesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationPreferencesProvider);
    final notifier = ref.read(notificationPreferencesProvider.notifier);

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Preferencias',
                    style: TextStyle(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              'Elegí qué avisos recibir por cada canal.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: state.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => ListView(
                  children: [
                    const SizedBox(height: 80),
                    const _EmptyState(
                      icon: Icons.notifications_off_rounded,
                      title: 'No pudimos cargar preferencias',
                      subtitle: 'Tocá actualizar para reintentar.',
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: notifier.refresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Actualizar'),
                      ),
                    ),
                  ],
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const _EmptyState(
                      icon: Icons.tune_rounded,
                      title: 'Sin tipos activos',
                      subtitle: 'Todavía no hay notificaciones configurables.',
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.typeCode, style: TextStyle(color: AppColors.ink, fontSize: 14, fontWeight: FontWeight.w800)),
                              if (item.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(item.description, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _PreferenceChip(icon: Icons.notifications_rounded, label: 'Campana', active: item.bellEnabled, onTap: () => _toggle(context, notifier, item, 'bell')),
                                  _PreferenceChip(icon: Icons.web_asset_rounded, label: 'Web', active: item.webPushEnabled, onTap: () => _toggle(context, notifier, item, 'web')),
                                  _PreferenceChip(icon: Icons.phone_android_rounded, label: 'App', active: item.mobilePushEnabled, onTap: () => _toggle(context, notifier, item, 'mobile')),
                                  _PreferenceChip(icon: Icons.mail_rounded, label: 'Email', active: item.emailEnabled, onTap: () => _toggle(context, notifier, item, 'email')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, NotificationPreferencesNotifier notifier, NotificationPreferenceItem item, String channel) async {
    try {
      await notifier.toggle(item, channel);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo guardar la preferencia.')));
      }
    }
  }
}

class _PreferenceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PreferenceChip({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: active,
      onSelected: (_) => onTap(),
      avatar: Icon(icon, size: 16, color: active ? AppColors.white : AppColors.textMuted),
      label: Text(label),
      selectedColor: AppColors.accent,
      checkmarkColor: AppColors.white,
      labelStyle: TextStyle(
        color: active ? AppColors.white : AppColors.textSecondary,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: active ? AppColors.accent : AppColors.border)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.accentLight,
            child: Icon(icon, size: 40, color: AppColors.accent),
          ),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        ],
      ),
    );
  }
}
