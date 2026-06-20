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
    final canSecurity = perms.canAccessRoute('/iam/users') ||
        perms.canAccessRoute('/authorization') ||
        perms.canAccessRoute('/iam/invitations');
    final canLogs = perms.canAccessRoute('/logs/audit') ||
        perms.canAccessRoute('/logs/apitraces') ||
        perms.canAccessRoute('/logs/notifications');
    final canOrganization = perms.canAccessRoute('/admin/tenants') ||
        perms.canAccessRoute('/admin/branches') ||
        perms.canAccessRoute('/organization/sellers') ||
        perms.canAccessRoute('/partners') ||
        perms.canAccessRoute('/customers') ||
        perms.canAccessRoute('/people');
    final canWarehouse = perms.canAccessRoute('/warehouse') ||
        perms.canAccessRoute('/warehouse/stock') ||
        perms.canAccessRoute('/warehouse/operations') ||
        perms.canAccessRoute('/warehouse/types');
    final canProducts = perms.canAccessRoute('/products') ||
        perms.canAccessRoute('/products/import') ||
        perms.canAccessRoute('/products/types') ||
        perms.canAccessRoute('/products/brands') ||
        perms.canAccessRoute('/products/storage-conditions') ||
        perms.canAccessRoute('/products/statuses') ||
        perms.canAccessRoute('/products/stock-statuses') ||
        perms.canAccessRoute('/products/price-types') ||
        perms.canAccessRoute('/products/publication-channels') ||
        perms.canAccessRoute('/products/unit-of-measure') ||
        perms.canAccessRoute('/products/stock-strategies') ||
        perms.canAccessRoute('/products/presentation-types');
    final canSales = perms.canAccessRoute('/dashboard/sales') ||
        perms.canAccessRoute('/sales/quotes');
    final canGeneralDashboard = perms.canAccessRoute('/dashboard');
    final canPurchases = perms.canAccessRoute('/purchases/dashboard') ||
        perms.canAccessRoute('/purchases/requests');
    final canWorkProjects = perms.canAccessRoute('/projects/management') ||
        perms.canAccessRoute('/projects/types') ||
        perms.canAccessRoute('/projects/resources') ||
        perms.canAccessRoute('/projects/templates');
    final canIntegralProjects =
        perms.canAccessRoute('/integral-projects/management') ||
            perms.canAccessRoute('/integral-projects/types') ||
            perms.canAccessRoute('/integral-projects/resources') ||
            perms.canAccessRoute('/integral-projects/templates');
    final canMarketing = perms.canAccessRoute('/marketing/dashboard') ||
        perms.canAccessRoute('/marketing/campaigns') ||
        perms.canAccessRoute('/marketing/coupons') ||
        perms.canAccessRoute('/marketing/leads') ||
        perms.canAccessRoute('/marketing/destacados');

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
                if (canGeneralDashboard)
                  _navItem(context, '/dashboard', Icons.dashboard_rounded,
                      'Dashboard',
                      primary: true),
                if (perms.canAccessRoute('/products/dashboard'))
                  _navItem(context, '/products/dashboard',
                      Icons.inventory_2_rounded, 'Dashboard Productos'),
                if (perms.canAccessRoute('/dashboard/sales'))
                  _navItem(context, '/dashboard/sales',
                      Icons.request_quote_rounded, 'Dashboard Ventas'),
                if (perms.canAccessRoute('/marketing/dashboard'))
                  _navItem(context, '/marketing/dashboard',
                      Icons.campaign_rounded, 'Dashboard Marketing'),
                if (perms.canAccessRoute('/dashboard/warehouse'))
                  _navItem(context, '/dashboard/warehouse',
                      Icons.warehouse_rounded, 'Dashboard Almacenes'),
                if (perms.canAccessRoute('/purchases/dashboard'))
                  _navItem(context, '/purchases/dashboard',
                      Icons.assignment_turned_in_rounded, 'Dashboard Compras'),
                if (perms.canAccessRoute('/projects/dashboard'))
                  _navItem(context, '/projects/dashboard',
                      Icons.engineering_rounded, 'Dashboard Obras'),
                if (perms.canAccessRoute('/integral-projects/dashboard'))
                  _navItem(context, '/integral-projects/dashboard',
                      Icons.account_tree_rounded, 'Dashboard Servicios'),

                // ── Seguridad ───────────────────────────────────
                if (canSecurity) ...[
                  const _SectionHeader(label: 'Seguridad'),
                  if (perms.canAccessRoute('/iam/users'))
                    _navItem(
                        context, '/iam/users', Icons.people_rounded, 'Usuarios',
                        primary: true),
                  if (perms.canAccessRoute('/authorization'))
                    _navItem(context, '/authorization',
                        Icons.admin_panel_settings_rounded, 'Roles'),
                  if (perms.canAccessRoute('/iam/invitations'))
                    _navItem(context, '/iam/invitations',
                        Icons.mark_email_unread_rounded, 'Invitaciones'),
                ],

                // ── Logs ────────────────────────────────────────
                if (canLogs) ...[
                  const _SectionHeader(label: 'Logs'),
                  if (perms.canAccessRoute('/logs/audit'))
                    _navItem(context, '/logs/audit', Icons.fact_check_rounded,
                        'Auditoría',
                        primary: true),
                  if (perms.canAccessRoute('/logs/apitraces'))
                    _navItem(context, '/logs/apitraces', Icons.route_rounded,
                        'API traces'),
                  if (perms.canAccessRoute('/logs/notifications'))
                    _navItem(context, '/logs/notifications',
                        Icons.notifications_active_rounded, 'Notificaciones'),
                ],

                // ── Organización ────────────────────────────────
                if (canOrganization) ...[
                  const _SectionHeader(label: 'Organización'),
                  if (perms.canAccessRoute('/admin/tenants'))
                    _navItem(context, '/admin/tenants', Icons.business_rounded,
                        'Empresas',
                        primary: true),
                  if (perms.canAccessRoute('/admin/branches'))
                    _navItem(context, '/admin/branches', Icons.store_rounded,
                        'Sucursales'),
                  if (perms.canAccessRoute('/organization/sellers'))
                    _navItem(context, '/organization/sellers',
                        Icons.storefront_rounded, 'Vendedores'),
                  if (perms.canAccessRoute('/partners'))
                    _navItem(context, '/partners', Icons.local_shipping_rounded,
                        'Proveedores'),
                  if (perms.canAccessRoute('/customers'))
                    _navItem(context, '/customers', Icons.handshake_rounded,
                        'Clientes'),
                  if (perms.canAccessRoute('/people'))
                    _navItem(
                        context, '/people', Icons.badge_rounded, 'Personas',
                        primary: true),
                ],

                // ── Depósitos ───────────────────────────────────
                if (canWarehouse) ...[
                  const _SectionHeader(label: 'Depósitos'),
                  if (perms.canAccessRoute('/warehouse'))
                    _navItem(context, '/warehouse', Icons.warehouse_rounded,
                        'Depósitos',
                        primary: true),
                  if (perms.canAccessRoute('/warehouse/stock'))
                    _navItem(context, '/warehouse/stock',
                        Icons.inventory_2_rounded, 'Stock'),
                  if (perms.canAccessRoute('/warehouse/operations'))
                    _navItem(context, '/warehouse/operations',
                        Icons.sync_alt_rounded, 'Operaciones'),
                  if (perms.canAccessRoute('/warehouse/types'))
                    _navItem(context, '/warehouse/types',
                        Icons.category_rounded, 'Tipos de depósito'),
                ],

                // ── Productos ────────────────────────────────────
                if (canProducts) ...[
                  const _SectionHeader(label: 'Productos'),
                  if (perms.canAccessRoute('/products'))
                    _navItem(context, '/products', Icons.inventory_2_rounded,
                        'Artículos',
                        primary: true),
                  if (perms.canAccessRoute('/products/import'))
                    _navItem(context, '/products/import',
                        Icons.file_upload_rounded, 'Importar productos'),
                  if (perms.canAccessRoute('/products/types'))
                    _navItem(context, '/products/types', Icons.category_rounded,
                        'Tipos de producto'),
                  if (perms.canAccessRoute('/products/brands'))
                    _navItem(context, '/products/brands', Icons.sell_rounded,
                        'Marcas'),
                  if (perms.canAccessRoute('/products/storage-conditions'))
                    _navItem(context, '/products/storage-conditions',
                        Icons.ac_unit_rounded, 'Condiciones de guarda'),
                  if (perms.canAccessRoute('/products/statuses'))
                    _navItem(context, '/products/statuses', Icons.flag_rounded,
                        'Estados de producto'),
                  if (perms.canAccessRoute('/products/stock-statuses'))
                    _navItem(context, '/products/stock-statuses',
                        Icons.inventory_rounded, 'Estados de stock'),
                  if (perms.canAccessRoute('/products/price-types'))
                    _navItem(context, '/products/price-types',
                        Icons.price_change_rounded, 'Tipos de precio'),
                  if (perms.canAccessRoute('/products/publication-channels'))
                    _navItem(context, '/products/publication-channels',
                        Icons.public_rounded, 'Canales de publicación'),
                  if (perms.canAccessRoute('/products/unit-of-measure'))
                    _navItem(context, '/products/unit-of-measure',
                        Icons.straighten_rounded, 'Unidades de medida'),
                  if (perms.canAccessRoute('/products/stock-strategies'))
                    _navItem(context, '/products/stock-strategies',
                        Icons.account_tree_rounded, 'Estrategias de stock'),
                  if (perms.canAccessRoute('/products/presentation-types'))
                    _navItem(context, '/products/presentation-types',
                        Icons.view_in_ar_rounded, 'Tipos de presentación'),
                ],
                // ── Ventas ──────────────────────────────────────
                if (canSales) ...[
                  const _SectionHeader(label: 'Ventas'),
                  if (perms.canAccessRoute('/sales/quotes'))
                    _navItem(context, '/sales/quotes',
                        Icons.request_quote_rounded, 'Cotizaciones',
                        primary: true),
                ],

                // ── Compras ─────────────────────────────────────
                if (canPurchases) ...[
                  const _SectionHeader(label: 'Compras'),
                  if (perms.canAccessRoute('/purchases/requests'))
                    _navItem(
                        context,
                        '/purchases/requests',
                        Icons.assignment_turned_in_rounded,
                        'Presupuestos proveedor',
                        primary: true),
                ],

                // ── Proyectos ───────────────────────────────────
                if (canWorkProjects) ...[
                  const _SectionHeader(label: 'Proyectos'),
                  if (perms.canAccessRoute('/projects/management'))
                    _navItem(context, '/projects/management',
                        Icons.engineering_rounded, 'Obras y proyectos',
                        primary: true),
                  if (perms.canAccessRoute('/projects/types'))
                    _navItem(context, '/projects/types', Icons.layers_rounded,
                        'Tipos de obra'),
                  if (perms.canAccessRoute('/projects/templates'))
                    _navItem(context, '/projects/templates',
                        Icons.view_list_rounded, 'Templates de obra'),
                  if (perms.canAccessRoute('/projects/resources'))
                    _navItem(context, '/projects/resources',
                        Icons.inventory_2_rounded, 'Recursos de obra'),
                ],

                // ── Servicios integrales ───────────────────────
                if (canIntegralProjects) ...[
                  const _SectionHeader(label: 'Servicios integrales'),
                  if (perms.canAccessRoute('/integral-projects/management'))
                    _navItem(context, '/integral-projects/management',
                        Icons.account_tree_rounded, 'Proyectos integrales',
                        primary: true),
                  if (perms.canAccessRoute('/integral-projects/types'))
                    _navItem(context, '/integral-projects/types',
                        Icons.layers_rounded, 'Tipos'),
                  if (perms.canAccessRoute('/integral-projects/templates'))
                    _navItem(context, '/integral-projects/templates',
                        Icons.view_list_rounded, 'Templates'),
                  if (perms.canAccessRoute('/integral-projects/resources'))
                    _navItem(context, '/integral-projects/resources',
                        Icons.inventory_2_rounded, 'Recursos'),
                ],

                // ── Marketing ────────────────────────────────────
                if (canMarketing) ...[
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

                // ── Ayuda ───────────────────────────────────────
                const _SectionHeader(label: 'Ayuda'),
                _navItem(context, '/manual', Icons.menu_book_rounded,
                    'Manuales de uso',
                    primary: true),
                _navItem(context, '/chat', Icons.forum_rounded, 'Chat IA'),
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
    final textMuted =
        isDarkTheme ? AppColors.sidebarTextMuted : AppColors.textSecondary;
    final activeBg = isDarkTheme ? AppColors.accentDark : AppColors.accentLight;
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
            color: isActive ? activeText : (primary ? textPrimary : textMuted),
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
    data: (name) => (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : 'Empresa asignada',
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
