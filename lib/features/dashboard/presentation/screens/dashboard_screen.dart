import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardMetrics {
  final int products;
  final int quotes;
  final int leads;

  const DashboardMetrics({
    required this.products,
    required this.quotes,
    required this.leads,
  });
}

final dashboardMetricsProvider = FutureProvider.autoDispose<DashboardMetrics>(
  (ref) async {
    final dio = ref.watch(dioProvider);
    final values = await Future.wait<int>([
      _count(dio, '/v1/products'),
      _count(dio, '/v1/quotes'),
      _count(dio, '/v1/leads'),
    ]);
    return DashboardMetrics(
      products: values[0],
      quotes: values[1],
      leads: values[2],
    );
  },
);

Future<int> _count(Dio dio, String path) async {
  try {
    final resp = await dio.get(
      path,
      queryParameters: const {'page': 0, 'size': 1, 'pageSize': 1},
    );
    final data = resp.data;
    if (data is Map) {
      return (data['totalElements'] as num?)?.toInt() ??
          (data['total'] as num?)?.toInt() ??
          ((data['content'] as List?) ?? (data['items'] as List?) ?? const [])
              .length;
    }
    if (data is List) return data.length;
  } catch (_) {
    return 0;
  }
  return 0;
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final perms = ref.watch(permissionsProvider);
    final metrics = ref.watch(dashboardMetricsProvider);
    final username = (auth.username?.trim().isNotEmpty ?? false)
        ? auth.username!.trim()
        : 'Usuario';

    final modules = [
      _ModuleShortcut(
        title: 'Productos',
        subtitle: 'Artículos, carga y publicación',
        icon: Icons.inventory_2_rounded,
        route: '/products',
        color: AppColors.accent,
        visible: perms.canAccessRoute('/products'),
      ),
      _ModuleShortcut(
        title: 'Cotizaciones',
        subtitle: 'Solicitudes, estados y QR',
        icon: Icons.request_quote_rounded,
        route: '/sales/quotes',
        color: AppColors.success,
        visible: perms.canAccessRoute('/sales/quotes'),
      ),
      _ModuleShortcut(
        title: 'Depósito',
        subtitle: 'Stock y movimientos',
        icon: Icons.warehouse_rounded,
        route: '/warehouse/stock',
        color: AppColors.warning,
        visible: perms.canAccessRoute('/warehouse/stock'),
      ),
      _ModuleShortcut(
        title: 'Marketing',
        subtitle: 'Leads y destacados',
        icon: Icons.campaign_rounded,
        route: '/marketing/leads',
        color: AppColors.error,
        visible: perms.canAccessRoute('/marketing/leads') ||
            perms.canAccessRoute('/marketing/destacados'),
      ),
      _ModuleShortcut(
        title: 'Usuarios',
        subtitle: 'Accesos operativos',
        icon: Icons.people_rounded,
        route: '/iam/users',
        color: const Color(0xFF6554F0),
        visible: perms.canAccessRoute('/iam/users'),
      ),
      _ModuleShortcut(
        title: 'Organización',
        subtitle: 'Empresa, sellers y personas',
        icon: Icons.business_rounded,
        route: perms.canAccessRoute('/organization/sellers')
            ? '/organization/sellers'
            : '/admin/tenants',
        color: const Color(0xFF0EA5E9),
        visible: perms.canAccessRoute('/admin/tenants') ||
            perms.canAccessRoute('/organization/sellers') ||
            perms.canAccessRoute('/people'),
      ),
    ].where((module) => module.visible).toList();

    return AppPageScaffold(
      title: 'Dashboard',
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () => ref.invalidate(dashboardMetricsProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardMetricsProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
          children: [
            Text(
              'Hola, ${_friendlyFirstName(username)}',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Operación diaria',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            metrics.when(
              data: (value) => Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.inventory_2_rounded,
                      label: 'Productos',
                      value: value.products,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.request_quote_rounded,
                      label: 'Cotizaciones',
                      value: value.quotes,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.leaderboard_rounded,
                      label: 'Leads',
                      value: value.leads,
                    ),
                  ),
                ],
              ),
              loading: () => const _MetricsSkeleton(),
              error: (_, __) => const _MetricsSkeleton(),
            ),
            const SizedBox(height: 22),
            Text(
              'Módulos operativos',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: modules.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.98,
              ),
              itemBuilder: (_, index) => _ModuleCard(module: modules[index]),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsSkeleton extends StatelessWidget {
  const _MetricsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == 2 ? 0 : 10),
            height: 104,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        );
      }),
    );
  }
}

class _ModuleShortcut {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final Color color;
  final bool visible;

  const _ModuleShortcut({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.color,
    required this.visible,
  });
}

class _ModuleCard extends StatelessWidget {
  final _ModuleShortcut module;

  const _ModuleCard({required this.module});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(module.route),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: module.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(module.icon, color: module.color, size: 22),
              ),
              const Spacer(),
              Text(
                module.title,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                module.subtitle,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _friendlyFirstName(String username) {
  final normalized = username.trim();
  if (normalized.isEmpty) return 'Usuario';
  final base = normalized.contains('@')
      ? normalized.split('@').first
      : normalized.split(RegExp(r'\s+')).first;
  if (base.isEmpty) return 'Usuario';
  return base[0].toUpperCase() + base.substring(1);
}
