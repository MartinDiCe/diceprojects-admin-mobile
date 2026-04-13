import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/app/theme_mode_provider.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ─── Drawer section expanded state (persisted via StateProvider) ──────────────
final _drawerExpandedProvider = StateProvider<Map<String, bool>>((ref) => {
  'seguridad': true,
  'logs': false,
  'organizacion': false,
  'personas': false,
  'productos': true,
  'depositos': false,
  'marketing': false,
  'notificaciones': false,
  'maestros': false,
});

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final perms = ref.watch(permissionsProvider);
    final isDarkTheme = ref.watch(themeModeProvider) == ThemeMode.dark;
    final expanded = ref.watch(_drawerExpandedProvider);

    final bg = isDarkTheme ? AppColors.sidebar : AppColors.surface;
    final dividerColor = isDarkTheme
        ? AppColors.white.withValues(alpha: 0.10)
        : AppColors.border.withValues(alpha: 0.80);
    final textPrimary = isDarkTheme ? AppColors.sidebarText : AppColors.ink;

    final headerSubtleBorder = isDarkTheme
        ? AppColors.white.withValues(alpha: 0.10)
        : AppColors.border.withValues(alpha: 0.70);

    Widget logoWidget = Image.asset('assets/logo_lineal.png', height: 44, fit: BoxFit.contain, alignment: Alignment.center);
    if (isDarkTheme) {
      logoWidget = ColorFiltered(colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn), child: logoWidget);
    }

    void toggle(String key) {
      ref.read(_drawerExpandedProvider.notifier).update((old) {
        final copy = Map<String, bool>.from(old);
        copy[key] = !(copy[key] ?? false);
        return copy;
      });
    }

    bool isExp(String key) => expanded[key] ?? false;

    return Drawer(
      backgroundColor: bg,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: headerSubtleBorder))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: double.infinity, child: Center(child: FractionallySizedBox(widthFactor: 0.92, child: logoWidget))),
              const SizedBox(height: 16),
              Row(children: [
                CircleAvatar(radius: 18, backgroundColor: isDarkTheme ? AppColors.white.withValues(alpha: 0.18) : AppColors.accentLight,
                  child: Text((auth.username?.trim().isNotEmpty ?? false) ? auth.username!.trim()[0].toUpperCase() : 'U',
                    style: TextStyle(color: isDarkTheme ? AppColors.white : AppColors.ink, fontWeight: FontWeight.w800))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(auth.username ?? 'Usuario', style: TextStyle(color: isDarkTheme ? AppColors.white : AppColors.ink, fontSize: 14, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                  Text(auth.isAdminGlobal ? 'Admin Global' : (auth.tenantId ?? ''), style: TextStyle(color: isDarkTheme ? AppColors.white.withValues(alpha: 0.75) : AppColors.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis),
                ])),
              ]),
            ]),
          ),

          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              children: [
                _navItem(context, '/dashboard', Icons.dashboard_rounded, 'Dashboard', primary: true),

                // Seguridad
                if (perms.canAccessRoute('/iam/users') || perms.canAccessRoute('/authorization') || perms.canAccessRoute('/iam/invitations') || perms.canAccessRoute('/iam/permissions')) ...[
                  _CollapsibleHeader(label: 'Seguridad', sectionKey: 'seguridad', isExpanded: isExp('seguridad'), onTap: () => toggle('seguridad')),
                  if (isExp('seguridad')) ...[
                    if (perms.canAccessRoute('/iam/users')) _navItem(context, '/iam/users', Icons.people_rounded, 'Usuarios', primary: true),
                    if (perms.canAccessRoute('/authorization')) _navItem(context, '/authorization', Icons.shield_rounded, 'Roles & Accesos'),
                    if (perms.canAccessRoute('/iam/invitations')) _navItem(context, '/iam/invitations', Icons.mail_rounded, 'Invitaciones'),
                    if (perms.canAccessRoute('/iam/permissions')) _navItem(context, '/iam/permissions', Icons.shield_rounded, 'Permisos'),
                  ],
                ],

                // Logs
                if (perms.canAccessRoute('/logs/audit') || perms.canAccessRoute('/logs/apitraces') || perms.canAccessRoute('/logs/notifications')) ...[
                  _CollapsibleHeader(label: 'Logs', sectionKey: 'logs', isExpanded: isExp('logs'), onTap: () => toggle('logs')),
                  if (isExp('logs')) ...[
                    if (perms.canAccessRoute('/logs/audit')) _navItem(context, '/logs/audit', Icons.history_rounded, 'Auditoría'),
                    if (perms.canAccessRoute('/logs/apitraces')) _navItem(context, '/logs/apitraces', Icons.api_rounded, 'API Traces'),
                    if (perms.canAccessRoute('/logs/notifications')) _navItem(context, '/logs/notifications', Icons.notifications_active_rounded, 'Notif. Logs'),
                  ],
                ],

                // Organización
                _CollapsibleHeader(label: 'Organización', sectionKey: 'organizacion', isExpanded: isExp('organizacion'), onTap: () => toggle('organizacion')),
                if (isExp('organizacion')) ...[
                  if (perms.canAccessRoute('/admin/tenants')) _navItem(context, '/admin/tenants', Icons.business_rounded, 'Empresas', primary: true),
                  if (perms.canAccessRoute('/admin/branches')) _navItem(context, '/admin/branches', Icons.store_rounded, 'Sucursales'),
                  if (perms.canAccessRoute('/organization/sellers')) _navItem(context, '/organization/sellers', Icons.store_mall_directory_rounded, 'Vendedores'),
                ],

                // Personas
                if (perms.canAccessRoute('/people')) ...[
                  _CollapsibleHeader(label: 'Personas', sectionKey: 'personas', isExpanded: isExp('personas'), onTap: () => toggle('personas')),
                  if (isExp('personas')) ...[
                    _navItem(context, '/people', Icons.badge_rounded, 'Personal', primary: true),
                  ],
                ],

                // Productos
                _CollapsibleHeader(label: 'Productos', sectionKey: 'productos', isExpanded: isExp('productos'), onTap: () => toggle('productos')),
                if (isExp('productos')) ...[
                  if (perms.canAccessRoute('/products')) _navItem(context, '/products', Icons.inventory_2_rounded, 'Artículos', primary: true),
                  if (perms.canAccessRoute('/products/types')) _navItem(context, '/products/types', Icons.category_rounded, 'Tipos de producto'),
                  if (perms.canAccessRoute('/products/brands')) _navItem(context, '/products/brands', Icons.branding_watermark_rounded, 'Marcas'),
                  if (perms.canAccessRoute('/products/storage-conditions')) _navItem(context, '/products/storage-conditions', Icons.thermostat_rounded, 'Condiciones almac.'),
                  if (perms.canAccessRoute('/products/unit-of-measure')) _navItem(context, '/products/unit-of-measure', Icons.straighten_rounded, 'Unidades medida'),
                  if (perms.canAccessRoute('/products/price-types')) _navItem(context, '/products/price-types', Icons.price_change_rounded, 'Tipos de precio'),
                  if (perms.canAccessRoute('/products/stock-statuses')) _navItem(context, '/products/stock-statuses', Icons.inventory_rounded, 'Estados de stock'),
                  if (perms.canAccessRoute('/products/product-statuses')) _navItem(context, '/products/product-statuses', Icons.flag_rounded, 'Estados de producto'),
                  if (perms.canAccessRoute('/products/publication-channels')) _navItem(context, '/products/publication-channels', Icons.campaign_rounded, 'Canales publicación'),
                  if (perms.canAccessRoute('/products/stock-strategies')) _navItem(context, '/products/stock-strategies', Icons.account_tree_rounded, 'Estrategias stock'),
                  if (perms.canAccessRoute('/products/presentation-types')) _navItem(context, '/products/presentation-types', Icons.view_module_rounded, 'Tipos presentación'),
                  if (perms.canAccessRoute('/products/import')) _navItem(context, '/products/import', Icons.upload_file_rounded, 'Importar'),
                ],

                // Depósitos
                _CollapsibleHeader(label: 'Depósitos', sectionKey: 'depositos', isExpanded: isExp('depositos'), onTap: () => toggle('depositos')),
                if (isExp('depositos')) ...[
                  if (perms.canAccessRoute('/warehouse')) _navItem(context, '/warehouse', Icons.warehouse_rounded, 'Depósitos', primary: true),
                  if (perms.canAccessRoute('/warehouse/types')) _navItem(context, '/warehouse/types', Icons.category_rounded, 'Tipos'),
                  if (perms.canAccessRoute('/warehouse/stock')) _navItem(context, '/warehouse/stock', Icons.inventory_2_rounded, 'Stock'),
                ],

                // Marketing
                if (perms.canAccessRoute('/marketing/leads') || perms.canAccessRoute('/marketing/destacados')) ...[
                  _CollapsibleHeader(label: 'Marketing', sectionKey: 'marketing', isExpanded: isExp('marketing'), onTap: () => toggle('marketing')),
                  if (isExp('marketing')) ...[
                    if (perms.canAccessRoute('/marketing/leads')) _navItem(context, '/marketing/leads', Icons.leaderboard_rounded, 'Leads'),
                    if (perms.canAccessRoute('/marketing/destacados')) _navItem(context, '/marketing/destacados', Icons.star_rounded, 'Destacados'),
                  ],
                ],

                // Notificaciones
                if (perms.canAccessRoute('/notifications/types') || perms.canAccessRoute('/notifications/templates') || perms.canAccessRoute('/notifications/sender-profiles') || perms.canAccessRoute('/notifications/variables')) ...[
                  _CollapsibleHeader(label: 'Notificaciones', sectionKey: 'notificaciones', isExpanded: isExp('notificaciones'), onTap: () => toggle('notificaciones')),
                  if (isExp('notificaciones')) ...[
                    if (perms.canAccessRoute('/notifications/types')) _navItem(context, '/notifications/types', Icons.category_rounded, 'Tipos'),
                    if (perms.canAccessRoute('/notifications/templates')) _navItem(context, '/notifications/templates', Icons.description_rounded, 'Plantillas'),
                    if (perms.canAccessRoute('/notifications/sender-profiles')) _navItem(context, '/notifications/sender-profiles', Icons.send_rounded, 'Perfiles Envío'),
                    if (perms.canAccessRoute('/notifications/variables')) _navItem(context, '/notifications/variables', Icons.code_rounded, 'Variables'),
                  ],
                ],

                // Maestros
                if (perms.canAccessRoute('/core/currencies') || perms.canAccessRoute('/core/languages') || perms.canAccessRoute('/core/geo/countries') || perms.canAccessRoute('/core/toggles') || perms.canAccessRoute('/core/sectors') || perms.canAccessRoute('/core/parameters')) ...[
                  _CollapsibleHeader(label: 'Maestros', sectionKey: 'maestros', isExpanded: isExp('maestros'), onTap: () => toggle('maestros')),
                  if (isExp('maestros')) ...[
                    if (perms.canAccessRoute('/core/currencies')) _navItem(context, '/core/currencies', Icons.attach_money_rounded, 'Monedas'),
                    if (perms.canAccessRoute('/core/languages')) _navItem(context, '/core/languages', Icons.language_rounded, 'Idiomas'),
                    if (perms.canAccessRoute('/core/geo/countries')) _navItem(context, '/core/geo/countries', Icons.public_rounded, 'Países'),
                    if (perms.canAccessRoute('/core/toggles')) _navItem(context, '/core/toggles', Icons.toggle_on_rounded, 'Feature Flags'),
                    if (perms.canAccessRoute('/core/parameters')) _navItem(context, '/core/parameters', Icons.settings_rounded, 'Parámetros'),
                    if (perms.canAccessRoute('/core/sectors')) _navItem(context, '/core/sectors', Icons.grid_view_rounded, 'Sectores'),
                  ],
                ],
              ],
            ),
          ),

          // Footer
          Divider(color: dividerColor, height: 1),
          SafeArea(
            top: false,
            child: ListTile(
              leading: Icon(isDarkTheme ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: textPrimary, size: 19),
              title: Text('Modo Oscuro', style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500)),
              trailing: Switch(
                value: isDarkTheme,
                onChanged: (value) => ref.read(themeModeProvider.notifier).setThemeMode(value ? ThemeMode.dark : ThemeMode.light),
                activeThumbColor: AppColors.white,
                activeTrackColor: AppColors.accent.withValues(alpha: 0.55),
                inactiveThumbColor: AppColors.white,
                inactiveTrackColor: isDarkTheme ? AppColors.white.withValues(alpha: 0.20) : AppColors.border.withValues(alpha: 0.45),
              ),
              onTap: () => ref.read(themeModeProvider.notifier).toggle(),
            ),
          ),
          Divider(color: dividerColor, height: 1),
          SafeArea(
            top: false,
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 19),
              title: const Text('Cerrar sesión', style: TextStyle(color: Colors.redAccent, fontSize: 13.5, fontWeight: FontWeight.w500)),
              onTap: () { Navigator.of(context).pop(); ref.read(authNotifierProvider.notifier).logout(); },
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, String route, IconData icon, String label, {bool primary = false}) {
    final current = GoRouterState.of(context).matchedLocation;
    final isActive = current == route || (route != '/dashboard' && current.startsWith(route));
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    const activeColor = AppColors.accent;
    final textPrimary = isDarkTheme ? AppColors.sidebarText : AppColors.ink;
    final textMuted = isDarkTheme ? AppColors.sidebarTextMuted : AppColors.textSecondary;
    final activeBg = isDarkTheme ? AppColors.accentDark : AppColors.accentLight;
    final activeText = isDarkTheme ? AppColors.white : AppColors.ink;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(color: isActive ? activeBg : Colors.transparent, borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
        leading: Icon(icon, color: isActive ? (isDarkTheme ? AppColors.white : activeColor) : (primary ? textPrimary : textMuted), size: 19),
        title: Text(label, style: TextStyle(color: isActive ? activeText : (primary ? textPrimary : textMuted), fontSize: primary ? 14 : 13.5, fontWeight: isActive ? FontWeight.w600 : (primary ? FontWeight.w500 : FontWeight.w400))),
        onTap: () {
          Navigator.of(context).pop();
          if (isActive) return;
          if (route == '/dashboard') { context.go(route); return; }
          context.push(route);
        },
      ),
    );
  }
}

// ── Collapsible Section Header ─────────────────────────────────────────────────

class _CollapsibleHeader extends StatelessWidget {
  final String label;
  final String sectionKey;
  final bool isExpanded;
  final VoidCallback onTap;
  const _CollapsibleHeader({required this.label, required this.sectionKey, required this.isExpanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final color = isDarkTheme ? AppColors.white.withValues(alpha: 0.55) : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 4),
        child: Row(children: [
          Expanded(child: Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4))),
          Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: color, size: 16),
        ]),
      ),
    );
  }
}
