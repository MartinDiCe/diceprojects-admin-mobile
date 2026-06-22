import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/app/theme_mode_provider.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  static const _expandedGroupKey = 'drawer.lastExpandedGroup';
  String? _expandedGroupId;
  bool _loadedExpansion = false;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadExpandedGroup();
  }

  Future<void> _loadExpandedGroup() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _expandedGroupId = prefs.getString(_expandedGroupKey);
      _loadedExpansion = true;
    });
  }

  Future<void> _setExpandedGroup(String? groupId) async {
    setState(() => _expandedGroupId = groupId);
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    if (groupId == null || groupId.isEmpty) {
      await prefs.remove(_expandedGroupKey);
    } else {
      await prefs.setString(_expandedGroupKey, groupId);
    }
  }

  @override
  Widget build(BuildContext context) {
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
    final groups = _buildGroups(auth, perms);
    final activeGroupId = _activeGroupId(context, groups);
    final expandedGroupId = _loadedExpansion
        ? (_expandedGroupId ??
            activeGroupId ??
            (groups.isNotEmpty ? groups.first.id : null))
        : activeGroupId;

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
                                : _resolveTenantLabel(auth.tenantId),
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
              children: groups
                  .map(
                    (group) => _drawerGroup(
                      context,
                      group,
                      isExpanded: expandedGroupId == group.id,
                      isActive: activeGroupId == group.id,
                    ),
                  )
                  .toList(),
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

  Widget _drawerGroup(
    BuildContext context,
    _DrawerGroupData group, {
    required bool isExpanded,
    required bool isActive,
  }) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDarkTheme ? AppColors.sidebarText : AppColors.ink;
    final textMuted =
        isDarkTheme ? AppColors.sidebarTextMuted : AppColors.textSecondary;
    final activeBg = isDarkTheme ? AppColors.accentDark : AppColors.accentLight;
    final expandedBg = isDarkTheme
        ? AppColors.white.withValues(alpha: 0.04)
        : AppColors.accentLight.withValues(alpha: 0.45);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isExpanded
                ? expandedBg
                : (isActive ? activeBg : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            dense: true,
            visualDensity: const VisualDensity(vertical: -2),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: Icon(
              group.icon,
              color: isActive ? AppColors.accent : textMuted,
              size: 19,
            ),
            title: Text(
              group.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive ? textPrimary : textMuted,
                fontSize: 13.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
            trailing: Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: isActive ? textPrimary : textMuted,
              size: 21,
            ),
            onTap: () => _setExpandedGroup(isExpanded ? null : group.id),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: group.items
                  .map(
                    (item) => _navItem(
                      context,
                      item.route,
                      item.icon,
                      item.label,
                      primary: item.primary,
                      groupId: group.id,
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  List<_DrawerGroupData> _buildGroups(
    AuthState auth,
    PermissionsService perms,
  ) {
    List<_DrawerItemData> visible(List<_DrawerItemData> items) => items
        .where((item) => _canShowRouteForUser(auth, perms, item.route))
        .toList();

    final candidates = [
      _DrawerGroupData(
        id: 'dashboard',
        label: 'Dashboard',
        icon: Icons.dashboard_rounded,
        items: visible([
          const _DrawerItemData(
              '/dashboard', Icons.dashboard_rounded, 'General', true),
          const _DrawerItemData(
              '/products/dashboard', Icons.inventory_2_rounded, 'Productos'),
          const _DrawerItemData(
              '/dashboard/sales', Icons.request_quote_rounded, 'Ventas'),
          const _DrawerItemData(
              '/marketing/dashboard', Icons.campaign_rounded, 'Marketing'),
          const _DrawerItemData(
              '/dashboard/warehouse', Icons.warehouse_rounded, 'Almacenes'),
          const _DrawerItemData('/purchases/dashboard',
              Icons.assignment_turned_in_rounded, 'Compras'),
          const _DrawerItemData(
              '/projects/dashboard', Icons.engineering_rounded, 'Obras'),
          const _DrawerItemData('/integral-projects/dashboard',
              Icons.account_tree_rounded, 'Servicios'),
        ]),
      ),
      _DrawerGroupData(
        id: 'security',
        label: 'Seguridad',
        icon: Icons.admin_panel_settings_rounded,
        items: visible([
          const _DrawerItemData(
              '/iam/users', Icons.people_rounded, 'Usuarios', true),
          const _DrawerItemData(
              '/authorization', Icons.admin_panel_settings_rounded, 'Roles'),
          const _DrawerItemData('/iam/invitations',
              Icons.mark_email_unread_rounded, 'Invitaciones'),
        ]),
      ),
      _DrawerGroupData(
        id: 'logs',
        label: 'Logs',
        icon: Icons.route_rounded,
        items: visible([
          const _DrawerItemData(
              '/logs/audit', Icons.history_rounded, 'Histórico', true),
          const _DrawerItemData(
              '/logs/apitraces', Icons.route_rounded, 'API traces'),
          const _DrawerItemData('/logs/notifications',
              Icons.notifications_active_rounded, 'Notificaciones'),
        ]),
      ),
      _DrawerGroupData(
        id: 'organization',
        label: 'Organización',
        icon: Icons.business_rounded,
        items: visible([
          const _DrawerItemData(
              '/admin/tenants', Icons.business_rounded, 'Empresas', true),
          const _DrawerItemData(
              '/admin/branches', Icons.store_rounded, 'Sucursales'),
          const _DrawerItemData(
              '/organization/sellers', Icons.storefront_rounded, 'Vendedores'),
          const _DrawerItemData(
              '/partners', Icons.local_shipping_rounded, 'Proveedores'),
          const _DrawerItemData(
              '/customers', Icons.handshake_rounded, 'Clientes'),
          const _DrawerItemData(
              '/people', Icons.badge_rounded, 'Personas', true),
        ]),
      ),
      _DrawerGroupData(
        id: 'products',
        label: 'Productos',
        icon: Icons.inventory_2_rounded,
        items: visible([
          const _DrawerItemData(
              '/products', Icons.inventory_2_rounded, 'Artículos', true),
          const _DrawerItemData(
              '/products/import', Icons.file_upload_rounded, 'Importar'),
          const _DrawerItemData(
              '/products/types', Icons.category_rounded, 'Tipos'),
          const _DrawerItemData(
              '/products/brands', Icons.sell_rounded, 'Marcas'),
          const _DrawerItemData('/products/storage-conditions',
              Icons.ac_unit_rounded, 'Condiciones de guarda'),
          const _DrawerItemData(
              '/products/statuses', Icons.flag_rounded, 'Estados'),
          const _DrawerItemData('/products/stock-statuses',
              Icons.inventory_rounded, 'Estados de stock'),
          const _DrawerItemData('/products/price-types',
              Icons.price_change_rounded, 'Tipos de precio'),
          const _DrawerItemData('/products/publication-channels',
              Icons.public_rounded, 'Canales'),
          const _DrawerItemData('/products/unit-of-measure',
              Icons.straighten_rounded, 'Unidades'),
          const _DrawerItemData('/products/stock-strategies',
              Icons.account_tree_rounded, 'Estrategias de stock'),
          const _DrawerItemData('/products/presentation-types',
              Icons.view_in_ar_rounded, 'Presentaciones'),
        ]),
      ),
      _DrawerGroupData(
        id: 'sales',
        label: 'Ventas',
        icon: Icons.request_quote_rounded,
        items: visible([
          const _DrawerItemData('/sales/quotes', Icons.request_quote_rounded,
              'Cotizaciones', true),
        ]),
      ),
      _DrawerGroupData(
        id: 'purchases',
        label: 'Compras',
        icon: Icons.assignment_turned_in_rounded,
        items: visible([
          const _DrawerItemData('/purchases/requests',
              Icons.assignment_turned_in_rounded, 'Presupuestos', true),
        ]),
      ),
      _DrawerGroupData(
        id: 'marketing',
        label: 'Marketing',
        icon: Icons.campaign_rounded,
        items: visible([
          const _DrawerItemData(
              '/marketing/leads', Icons.leaderboard_rounded, 'Leads', true),
          const _DrawerItemData(
              '/marketing/campaigns', Icons.campaign_rounded, 'Campañas'),
          const _DrawerItemData('/marketing/coupons',
              Icons.confirmation_number_rounded, 'Cupones'),
          const _DrawerItemData(
              '/marketing/destacados', Icons.star_rounded, 'Destacados'),
        ]),
      ),
      _DrawerGroupData(
        id: 'warehouse',
        label: 'Depósitos',
        icon: Icons.warehouse_rounded,
        items: visible([
          const _DrawerItemData(
              '/warehouse', Icons.warehouse_rounded, 'Depósitos', true),
          const _DrawerItemData(
              '/warehouse/stock', Icons.inventory_2_rounded, 'Stock'),
          const _DrawerItemData(
              '/warehouse/operations', Icons.sync_alt_rounded, 'Operaciones'),
          const _DrawerItemData(
              '/warehouse/types', Icons.category_rounded, 'Tipos'),
        ]),
      ),
      _DrawerGroupData(
        id: 'projects',
        label: 'Proyectos',
        icon: Icons.engineering_rounded,
        items: visible([
          const _DrawerItemData('/projects/management',
              Icons.engineering_rounded, 'Obras y proyectos', true),
          const _DrawerItemData(
              '/projects/types', Icons.layers_rounded, 'Tipos de obra'),
          const _DrawerItemData(
              '/projects/templates', Icons.view_list_rounded, 'Templates'),
          const _DrawerItemData(
              '/projects/resources', Icons.inventory_2_rounded, 'Recursos'),
        ]),
      ),
      _DrawerGroupData(
        id: 'integral-projects',
        label: 'Servicios integrales',
        icon: Icons.account_tree_rounded,
        items: visible([
          const _DrawerItemData('/integral-projects/management',
              Icons.account_tree_rounded, 'Proyectos integrales', true),
          const _DrawerItemData(
              '/integral-projects/types', Icons.layers_rounded, 'Tipos'),
          const _DrawerItemData('/integral-projects/templates',
              Icons.view_list_rounded, 'Templates'),
          const _DrawerItemData('/integral-projects/resources',
              Icons.inventory_2_rounded, 'Recursos'),
        ]),
      ),
      const _DrawerGroupData(
        id: 'help',
        label: 'Ayuda',
        icon: Icons.menu_book_rounded,
        items: [
          _DrawerItemData(
              '/manual', Icons.menu_book_rounded, 'Manuales de uso', true),
        ],
      ),
    ];

    return candidates.where((group) => group.items.isNotEmpty).toList();
  }

  bool _canShowRouteForUser(
    AuthState auth,
    PermissionsService perms,
    String route,
  ) {
    if (_isSellerScopedUser(auth) &&
        !_isAllowedPathForSellerOperational(route)) {
      return false;
    }
    return perms.canShowMenuRoute(route);
  }

  bool _isSellerScopedUser(AuthState auth) =>
      !auth.isAdminGlobal &&
      (auth.tenantId?.trim().isNotEmpty ?? false) &&
      auth.sellerScope != 'NONE';

  bool _isAllowedPathForSellerOperational(String route) {
    const prefixes = [
      '/dashboard',
      '/profile',
      '/products',
      '/sales',
      '/purchases',
      '/projects',
      '/marketing',
      '/notifications',
      '/warehouse',
      '/manual',
      '/403',
    ];
    final normalized = route.trim().isEmpty ? '/' : route.trim();
    return prefixes.any(
      (prefix) => normalized == prefix || normalized.startsWith('$prefix/'),
    );
  }

  String? _activeGroupId(BuildContext context, List<_DrawerGroupData> groups) {
    final current = GoRouterState.of(context).matchedLocation;
    for (final group in groups) {
      for (final item in group.items) {
        if (current == item.route ||
            (item.route != '/dashboard' && current.startsWith(item.route))) {
          return group.id;
        }
      }
    }
    return null;
  }

  Widget _navItem(
    BuildContext context,
    String route,
    IconData icon,
    String label, {
    bool primary = false,
    String? groupId,
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
          if (groupId != null) {
            _setExpandedGroup(groupId);
          }
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

class _DrawerGroupData {
  final String id;
  final String label;
  final IconData icon;
  final List<_DrawerItemData> items;

  const _DrawerGroupData({
    required this.id,
    required this.label,
    required this.icon,
    required this.items,
  });
}

class _DrawerItemData {
  final String route;
  final IconData icon;
  final String label;
  final bool primary;

  const _DrawerItemData(
    this.route,
    this.icon,
    this.label, [
    this.primary = false,
  ]);
}

String _resolveTenantLabel(String? tenantId) {
  final id = tenantId?.trim();
  if (id == null || id.isEmpty) return 'Empresa asignada';
  return 'Empresa asignada';
}
