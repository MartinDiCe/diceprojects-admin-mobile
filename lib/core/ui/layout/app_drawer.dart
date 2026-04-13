import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/app/theme_mode_provider.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                                : (auth.tenantId ?? ''),
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

                // ── Seguridad ───────────────────────────────────
                const _SectionHeader(label: 'Seguridad'),
                if (perms.canAccessRoute('/iam/users'))
                  _navItem(context, '/iam/users',
                      Icons.people_rounded, 'Usuarios', primary: true),
                if (perms.canAccessRoute('/authorization'))
                  _navItem(context, '/authorization',
                      Icons.shield_rounded, 'Roles & Accesos'),
                if (perms.canAccessRoute('/iam/invitations'))
                  _navItem(context, '/iam/invitations',
                      Icons.mail_rounded, 'Invitaciones'),

                // ── Logs ───────────────────────────────────────
                if (perms.canAccessRoute('/logs/audit') ||
                    perms.canAccessRoute('/logs/apitraces') ||
                    perms.canAccessRoute('/logs/notifications')) ...[
                  const _SectionHeader(label: 'Logs'),
                  if (perms.canAccessRoute('/logs/audit'))
                    _navItem(context, '/logs/audit',
                        Icons.history_rounded, 'Auditoría'),
                  if (perms.canAccessRoute('/logs/apitraces'))
                    _navItem(context, '/logs/apitraces',
                        Icons.api_rounded, 'API Traces'),
                  if (perms.canAccessRoute('/logs/notifications'))
                    _navItem(context, '/logs/notifications',
                        Icons.notifications_active_rounded, 'Notif. Logs'),
                ],

                // ── Organización ────────────────────────────────
                const _SectionHeader(label: 'Organización'),
                if (perms.canAccessRoute('/admin/tenants'))
                  _navItem(context, '/admin/tenants',
                      Icons.business_rounded, 'Empresas', primary: true),
                if (perms.canAccessRoute('/admin/branches'))
                  _navItem(context, '/admin/branches',
                      Icons.store_rounded, 'Sucursales'),

                // ── Personas ────────────────────────────────────
                const _SectionHeader(label: 'Personas'),
                if (perms.canAccessRoute('/people'))
                  _navItem(context, '/people',
                      Icons.badge_rounded, 'Personal', primary: true),

                // ── Productos ────────────────────────────────────
                const _SectionHeader(label: 'Productos'),
                if (perms.canAccessRoute('/products'))
                  _navItem(context, '/products',
                      Icons.inventory_2_rounded, 'Catálogo', primary: true),

                // ── Marketing ────────────────────────────────────
                const _SectionHeader(label: 'Marketing'),
                if (perms.canAccessRoute('/marketing/leads'))
                  _navItem(context, '/marketing/leads',
                      Icons.leaderboard_rounded, 'Leads'),
                if (perms.canAccessRoute('/marketing/destacados'))
                  _navItem(context, '/marketing/destacados',
                      Icons.star_rounded, 'Destacados'),

                // ── Notificaciones ──────────────────────────────
                if (perms.canAccessRoute('/notifications/types') ||
                    perms.canAccessRoute('/notifications/templates') ||
                    perms.canAccessRoute('/notifications/sender-profiles') ||
                    perms.canAccessRoute('/notifications/variables')) ...[
                  const _SectionHeader(label: 'Notificaciones'),
                  if (perms.canAccessRoute('/notifications/types'))
                    _navItem(context, '/notifications/types',
                        Icons.category_rounded, 'Tipos'),
                  if (perms.canAccessRoute('/notifications/templates'))
                    _navItem(context, '/notifications/templates',
                        Icons.description_rounded, 'Plantillas'),
                  if (perms.canAccessRoute('/notifications/sender-profiles'))
                    _navItem(context, '/notifications/sender-profiles',
                        Icons.send_rounded, 'Perfiles Envío'),
                  if (perms.canAccessRoute('/notifications/variables'))
                    _navItem(context, '/notifications/variables',
                        Icons.code_rounded, 'Variables'),
                ],

                // ── Maestros ────────────────────────────────────
                if (perms.canAccessRoute('/core/currencies') ||
                    perms.canAccessRoute('/core/languages') ||
                    perms.canAccessRoute('/core/geo/countries') ||
                    perms.canAccessRoute('/core/toggles') ||
                    perms.canAccessRoute('/core/parameters')) ...[
                  const _SectionHeader(label: 'Maestros'),
                  if (perms.canAccessRoute('/core/currencies'))
                    _navItem(context, '/core/currencies',
                        Icons.attach_money_rounded, 'Monedas'),
                  if (perms.canAccessRoute('/core/languages'))
                    _navItem(context, '/core/languages',
                        Icons.language_rounded, 'Idiomas'),
                  if (perms.canAccessRoute('/core/geo/countries'))
                    _navItem(context, '/core/geo/countries',
                        Icons.public_rounded, 'Países'),
                  if (perms.canAccessRoute('/core/toggles'))
                    _navItem(context, '/core/toggles',
                        Icons.toggle_on_rounded, 'Feature Flags'),
                  if (perms.canAccessRoute('/core/parameters'))
                    _navItem(context, '/core/parameters',
                        Icons.settings_rounded, 'Parámetros'),
                ],
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
