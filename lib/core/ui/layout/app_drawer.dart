import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/app/theme_mode_provider.dart';
import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _tenantNameProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, tenantId) async {
    if (tenantId.trim().isEmpty) return null;
    final dio = ref.watch(dioProvider);
    try {
      final resp = await dio.get('/v1/tenants/$tenantId');
      final data = resp.data;
      if (data is Map && data['name'] != null) return data['name'].toString();
      return null;
    } catch (_) {
      return null;
    }
  },
);

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final perms = ref.watch(permissionsProvider);
    final isDarkTheme = ref.watch(themeModeProvider) == ThemeMode.dark;

    final bg = isDarkTheme ? AppColors.sidebar : AppColors.surface;
    final dividerColor = isDarkTheme
        ? AppColors.white.withValues(alpha: 0.10)
        : AppColors.border.withValues(alpha: 0.80);
    final textPrimary = isDarkTheme ? AppColors.sidebarText : AppColors.ink;

    final headerSubtleBorder = isDarkTheme
        ? AppColors.white.withValues(alpha: 0.10)
        : AppColors.border.withValues(alpha: 0.70);

    Widget logoWidget = Image.asset(
      'assets/logo_lineal.png',
      height: 44,
      fit: BoxFit.contain,
      alignment: Alignment.center,
    );
    if (isDarkTheme) {
      logoWidget = ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        child: logoWidget,
      );
    }

    return Drawer(
      backgroundColor: bg,
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: BoxDecoration(
              color: bg,
              border: Border(
                bottom: BorderSide(color: headerSubtleBorder),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.92,
                      child: logoWidget,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isDarkTheme
                          ? AppColors.white.withValues(alpha: 0.18)
                          : AppColors.accentLight,
                      child: Text(
                        (auth.username?.trim().isNotEmpty ?? false)
                            ? auth.username!.trim()[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: isDarkTheme ? AppColors.white : AppColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.username ?? 'Usuario',
                            style: TextStyle(
                              color:
                                  isDarkTheme ? AppColors.white : AppColors.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            auth.isAdminGlobal
                                ? 'Admin Global'
                                : _resolveTenantLabel(ref, auth.tenantId),
                            style: TextStyle(
                              color: isDarkTheme
                                  ? AppColors.white.withValues(alpha: 0.75)
                                  : AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),

          // ── Nav items ─────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              children: [
                // Primary: Dashboard
                _navItem(context, '/dashboard',
                    Icons.dashboard_rounded, 'Dashboard', primary: true),
                _navItem(context, '/notifications/center',
                    Icons.notifications_rounded, 'Notificaciones',
                    primary: true),
                if (perms.canAccessRoute('/dashboard/products'))
                  _navItem(context, '/dashboard/products',
                      Icons.inventory_2_rounded, 'Dashboard Productos'),
                if (perms.canAccessRoute('/dashboard/sales'))
                  _navItem(context, '/dashboard/sales',
                      Icons.request_quote_rounded, 'Dashboard Ventas'),
                if (perms.canAccessRoute('/dashboard/marketing'))
                  _navItem(context, '/dashboard/marketing',
                      Icons.campaign_rounded, 'Dashboard Marketing'),
                if (perms.canAccessRoute('/dashboard/warehouse'))
                  _navItem(context, '/dashboard/warehouse',
                      Icons.warehouse_rounded, 'Dashboard Almacenes'),

                // ── Seguridad ───────────────────────────────────
                const _SectionHeader(label: 'Seguridad'),
                if (perms.canAccessRoute('/iam/users'))
                  _navItem(context, '/iam/users',
                      Icons.people_rounded, 'Usuarios', primary: true),

                // ── Organización ────────────────────────────────
                const _SectionHeader(label: 'Organización'),
                if (perms.canAccessRoute('/admin/tenants'))
                  _navItem(context, '/admin/tenants',
                      Icons.business_rounded, 'Empresas', primary: true),
                if (perms.canAccessRoute('/admin/branches'))
                  _navItem(context, '/admin/branches',
                      Icons.store_rounded, 'Sucursales'),
                if (perms.canAccessRoute('/organization/sellers'))
                  _navItem(context, '/organization/sellers',
                    Icons.storefront_rounded, 'Vendedores'),
                if (perms.canAccessRoute('/organization/suppliers'))
                  _navItem(context, '/organization/suppliers',
                    Icons.local_shipping_rounded, 'Proveedores'),
                if (perms.canAccessRoute('/organization/customers'))
                  _navItem(context, '/organization/customers',
                    Icons.handshake_rounded, 'Clientes'),
                if (perms.canAccessRoute('/people'))
                  _navItem(context, '/people',
                      Icons.badge_rounded, 'Personas', primary: true),

                // ── Depósitos ───────────────────────────────────
                const _SectionHeader(label: 'Depósitos'),
                if (perms.canAccessRoute('/warehouse'))
                  _navItem(context, '/warehouse',
                    Icons.warehouse_rounded, 'Depósitos', primary: true),
                if (perms.canAccessRoute('/warehouse/stock'))
                  _navItem(context, '/warehouse/stock',
                    Icons.inventory_2_rounded, 'Stock'),

                // ── Productos ────────────────────────────────────
                const _SectionHeader(label: 'Productos'),
                if (perms.canAccessRoute('/products'))
                  _navItem(context, '/products',
                      Icons.inventory_2_rounded, 'Artículos', primary: true),
                // ── Ventas ──────────────────────────────────────
                const _SectionHeader(label: 'Ventas'),
                if (perms.canAccessRoute('/sales/quotes'))
                  _navItem(context, '/sales/quotes',
                      Icons.request_quote_rounded, 'Cotizaciones',
                      primary: true),

                // ── Compras ─────────────────────────────────────
                const _SectionHeader(label: 'Compras'),
                if (perms.canAccessRoute('/purchases/requests'))
                  _navItem(context, '/purchases/requests',
                      Icons.assignment_turned_in_rounded, 'Presupuestos proveedor',
                      primary: true),

                // ── Proyectos ───────────────────────────────────
                const _SectionHeader(label: 'Proyectos'),
                if (perms.canAccessRoute('/projects'))
                  _navItem(context, '/projects',
                      Icons.engineering_rounded, 'Obras y proyectos',
                      primary: true),

                // ── Marketing ────────────────────────────────────
                const _SectionHeader(label: 'Marketing'),
                if (perms.canAccessRoute('/marketing/campaigns'))
                  _navItem(context, '/marketing/campaigns',
                      Icons.campaign_rounded, 'Campañas'),
                if (perms.canAccessRoute('/marketing/coupons'))
                  _navItem(context, '/marketing/coupons',
                      Icons.confirmation_number_rounded, 'Cupones'),
                if (perms.canAccessRoute('/marketing/leads'))
                  _navItem(context, '/marketing/leads',
                      Icons.leaderboard_rounded, 'Leads'),
                if (perms.canAccessRoute('/marketing/destacados'))
                  _navItem(context, '/marketing/destacados',
                      Icons.star_rounded, 'Destacados'),
              ],
            ),
          ),

          // ── Footer: logout ─────────────────────────────────
          Divider(color: dividerColor, height: 1),
          SafeArea(
            top: false,
            child: ListTile(
              leading: Icon(
                isDarkTheme
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                color: textPrimary,
                size: 19,
              ),
              title: Text(
                'Modo Oscuro',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Switch(
                value: isDarkTheme,
                onChanged: (value) {
                  ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                },
                activeThumbColor: AppColors.white,
                activeTrackColor: AppColors.accent.withValues(alpha: 0.55),
                inactiveThumbColor: AppColors.white,
                inactiveTrackColor: isDarkTheme
                    ? AppColors.white.withValues(alpha: 0.20)
                    : AppColors.border.withValues(alpha: 0.45),
              ),
              onTap: () {
                ref.read(themeModeProvider.notifier).toggle();
              },
            ),
          ),
          Divider(color: dividerColor, height: 1),
          SafeArea(
            top: false,
            child: ListTile(
              leading: Icon(
                Icons.logout_rounded,
                color: isDarkTheme ? Colors.redAccent : textPrimary,
                size: 19,
              ),
              title: Text(
                'Cerrar sesión',
                style: TextStyle(
                  color: isDarkTheme ? Colors.redAccent : Colors.redAccent,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(authNotifierProvider.notifier).logout();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    String route,
    IconData icon,
    String label, {
    bool primary = false,
  }) {
    final current = GoRouterState.of(context).matchedLocation;
    final isActive = current == route ||
        (route != '/dashboard' && current.startsWith(route));

    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    const activeColor = AppColors.accent;
    final textPrimary = isDarkTheme ? AppColors.sidebarText : AppColors.ink;
    final textMuted = isDarkTheme
        ? AppColors.sidebarTextMuted
        : AppColors.textSecondary;
    final activeBg =
      isDarkTheme ? AppColors.accentDark : AppColors.accentLight;
    final activeText = isDarkTheme ? AppColors.white : AppColors.ink;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isActive ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      border: null,
      ),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
        leading: Icon(
          icon,
          color: isActive
              ? (isDarkTheme ? AppColors.white : activeColor)
              : (primary ? textPrimary : textMuted),
          size: 19,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive
                ? activeText
                : (primary ? textPrimary : textMuted),
            fontSize: primary ? 14 : 13.5,
            fontWeight: isActive
                ? FontWeight.w600
                : (primary ? FontWeight.w500 : FontWeight.w400),
          ),
        ),
        onTap: () {
          Navigator.of(context).pop();
          if (isActive) return;
          if (route == '/dashboard') {
            context.go(route);
            return;
          }
          context.push(route);
        },
      ),
    );
  }
}

String _resolveTenantLabel(WidgetRef ref, String? tenantId) {
  final id = tenantId?.trim();
  if (id == null || id.isEmpty) return 'Empresa asignada';
  final async = ref.watch(_tenantNameProvider(id));
  return async.maybeWhen(
    data: (name) => (name != null && name.trim().isNotEmpty) ? name.trim() : 'Empresa asignada',
    loading: () => 'Cargando empresa…',
    orElse: () => 'Empresa asignada',
  );
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final color = isDarkTheme
        ? AppColors.white.withValues(alpha: 0.55)
        : AppColors.textMuted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}
