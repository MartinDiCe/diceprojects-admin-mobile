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
    // Check exact match or prefix match
    for (final entry in permissionGates.entries) {
      if (route.startsWith(entry.key)) {
        return hasAnyPermission(entry.value);
      }
    }
    return true; // no gate = accessible
  }
}

final permissionsProvider = Provider<PermissionsService>((ref) {
  final auth = ref.watch(authNotifierProvider);
  return PermissionsService(auth.permissions, auth.isAdminGlobal);
});
