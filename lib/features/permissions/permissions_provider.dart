import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PermissionsService {
  final Set<String> _permissions;
  final bool _isAdminGlobal;

  const PermissionsService(
    this._permissions,
    this._isAdminGlobal,
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
        return hasAnyPermission(entry.value) ||
            _hasRouteModuleAccess(route, entry.value);
      }
    }
    return false;
  }

  bool canShowMenuRoute(String route) {
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
    if (!hasLocalPermissionData) return '/dashboard';

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

  bool get _canBypassPermissionChecks => _isAdminGlobal;

  bool get hasLocalPermissionData =>
      _canBypassPermissionChecks || _permissions.isNotEmpty;

  Set<String> get _normalizedPermissions =>
      _permissions.map(_normalizePermission).toSet();

  bool _hasModuleAdminFor(String normalizedPermission) {
    final module = _moduleToken(normalizedPermission);
    if (module == null) return false;
    return _normalizedPermissions.contains('$module.ADMIN') ||
        _normalizedPermissions.contains('$module.ADMINISTRADOR');
  }

  bool _hasRouteModuleAccess(String route, List<String> requiredCodes) {
    if (!_allowsModuleFallback(route)) return false;

    final requiredModules = requiredCodes
        .map(_normalizePermission)
        .map(_moduleToken)
        .whereType<String>()
        .toSet();
    if (requiredModules.isEmpty) return false;

    return _normalizedPermissions.any((permission) {
      final module = _moduleToken(permission);
      return module != null && requiredModules.contains(module);
    });
  }

  bool _allowsModuleFallback(String route) {
    final normalized = route.toLowerCase();
    if (_isSensitiveRoute(normalized)) return false;
    return !normalized.contains('/new') &&
        !normalized.contains('/edit') &&
        !normalized.contains('/import');
  }

  bool _isSensitiveRoute(String normalizedRoute) {
    return normalizedRoute.startsWith('/iam') ||
        normalizedRoute.startsWith('/authorization') ||
        normalizedRoute.startsWith('/logs') ||
        normalizedRoute.startsWith('/admin/tenants') ||
        normalizedRoute.startsWith('/admin/branches');
  }

  String? _moduleToken(String normalizedPermission) {
    final first = normalizedPermission.split('.').first.trim();
    if (first.isEmpty) return null;
    return switch (first) {
      'PRODUCTO' => 'PRODUCTS',
      'PRODUCTOS' => 'PRODUCTS',
      'VENTA' => 'SALES',
      'VENTAS' => 'SALES',
      _ => first,
    };
  }

  static String _normalizePermission(String value) => value
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[-_:\s]+'), '.')
      .replaceAll(RegExp(r'\.+'), '.');

  bool _isAlwaysAllowedRoute(String route) =>
      route == '/403' ||
      route == '/dashboard' ||
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
  );
});
