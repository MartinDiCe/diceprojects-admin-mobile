import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PermissionsService {
  final Set<String> _permissions;
  final bool _isAdminGlobal;

  const PermissionsService(this._permissions, this._isAdminGlobal);

  bool hasPermission(String code) =>
      _isAdminGlobal || _permissions.contains(code);

  bool hasAnyPermission(List<String> codes) =>
      _isAdminGlobal || codes.any(_permissions.contains);

  bool hasAllPermissions(List<String> codes) =>
      _isAdminGlobal || codes.every(_permissions.contains);

  bool canAccessRoute(String route) {
    if (_isAdminGlobal) return true;
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
  return PermissionsService(auth.permissions, auth.isAdminGlobal);
});
