import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PermissionsService {
  final Set<String> _permissions;
  final bool _isAdminGlobal;
  final bool _hasAdministratorRole;

  const PermissionsService(
    this._permissions,
    this._isAdminGlobal,
    this._hasAdministratorRole,
  );

  bool hasPermission(String code) {
    if (_canBypassPermissionChecks) return true;
    if (_permissions.contains(code)) return true;

    final normalized = _normalizePermission(code);
    if (_normalizedPermissions.contains(normalized)) return true;

    return _hasModuleAdminFor(normalized);
  }

  bool hasAnyPermission(List<String> codes) =>
      _canBypassPermissionChecks || codes.any(hasPermission);

  bool hasAllPermissions(List<String> codes) =>
      _canBypassPermissionChecks || codes.every(hasPermission);

  bool canAccessRoute(String route) {
    if (_canBypassPermissionChecks) return true;
    if (_isAlwaysAllowedRoute(route)) return true;

    final gates = permissionGates.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in gates) {
      if (route == entry.key || route.startsWith('${entry.key}/')) {
        return hasAnyPermission(entry.value);
      }
    }
    return false;
  }

  String firstAllowedRoute() {
    const preferredRoutes = [
      '/dashboard',
      '/products/dashboard',
      '/dashboard/sales',
      '/marketing/dashboard',
      '/dashboard/warehouse',
      '/purchases/dashboard',
      '/projects/dashboard',
      '/integral-projects/dashboard',
      '/products',
      '/sales/quotes',
      '/purchases/requests',
      '/projects/management',
      '/integral-projects/management',
      '/warehouse',
      '/people',
      '/customers',
      '/partners',
      '/organization/sellers',
      '/marketing/campaigns',
      '/notifications/center',
      '/manual',
      '/chat',
    ];
    for (final route in preferredRoutes) {
      if (canAccessRoute(route)) return route;
    }
    return '/manual';
  }

  bool get _canBypassPermissionChecks =>
      _isAdminGlobal || _hasAdministratorRole;

  Set<String> get _normalizedPermissions =>
      _permissions.map(_normalizePermission).toSet();

  bool _hasModuleAdminFor(String normalizedPermission) {
    final separator = normalizedPermission.indexOf('.');
    if (separator <= 0) return false;

    final module = normalizedPermission.substring(0, separator);
    return _normalizedPermissions.contains('$module.ADMIN') ||
        _normalizedPermissions.contains('$module.ADMINISTRADOR');
  }

  static String _normalizePermission(String value) =>
      value.trim().toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');

  bool _isAlwaysAllowedRoute(String route) =>
      route == '/403' ||
      route == '/chat' ||
      route == '/manual' ||
      route.startsWith('/manual/') ||
      route.startsWith('/profile') ||
      route.startsWith('/notifications/center');
}

final permissionsProvider = Provider<PermissionsService>((ref) {
  final auth = ref.watch(authNotifierProvider);
  return PermissionsService(
    auth.permissions,
    auth.isAdminGlobal,
    auth.hasAdministratorRole,
  );
});
