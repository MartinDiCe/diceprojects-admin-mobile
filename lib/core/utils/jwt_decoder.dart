import 'dart:convert';

class JwtDecoder {
  static Map<String, dynamic> decode(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static bool isExpired(String token) {
    final payload = decode(token);
    final exp = payload['exp'];
    if (exp == null) return true;
    final expSeconds = exp is num ? exp.toInt() : int.tryParse(exp.toString());
    if (expSeconds == null) return true;
    final expDate = DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000);
    return DateTime.now().isAfter(expDate);
  }

  static String? getUsername(String token) => decode(token)['sub']?.toString();

  static List<String> getRoles(String token) {
    final payload = decode(token);
    final values = <String>{};
    for (final key in const [
      'roles',
      'role',
      'authorities',
      'authority',
      'scope',
      'scp',
    ]) {
      _collectRoleValues(payload[key], values);
    }
    return values.toList(growable: false);
  }

  static List<String> getRolesForTenant(String token, String? tenantId) {
    final payload = decode(token);
    final values = <String>{...getRoles(token)};
    final tenant = tenantId?.trim();
    if (tenant == null || tenant.isEmpty) return values.toList(growable: false);

    final scoped = _findTenantScopedMap(payload, tenant);
    if (scoped != null) {
      for (final key in const [
        'roles',
        'roleCodes',
        'roleCode',
        'assignedRoles',
        'authorities',
      ]) {
        _collectRoleValues(scoped[key], values);
      }
    }
    return values.toList(growable: false);
  }

  static Set<String> getPermissions(String token) {
    final payload = decode(token);
    final values = <String>{};
    for (final key in const [
      'permissions',
      'permission',
      'perms',
      'privileges',
      'privilege',
      'access',
    ]) {
      _collectRoleValues(payload[key], values);
    }
    return values;
  }

  static void _collectRoleValues(dynamic raw, Set<String> values) {
    if (raw == null) return;
    if (raw is List) {
      for (final item in raw) {
        _collectRoleValues(item, values);
      }
      return;
    }
    if (raw is Map) {
      for (final key in const [
        'role',
        'roles',
        'roleCode',
        'roleCodes',
        'code',
        'name',
        'authority',
        'authorities',
      ]) {
        _collectRoleValues(raw[key], values);
      }
      return;
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return;
    for (final part in text.split(RegExp(r'[\s,;]+'))) {
      final normalized = part.trim();
      if (normalized.isNotEmpty) values.add(normalized);
    }
  }

  static String? getTenantId(String token) {
    final payload = decode(token);
    for (final key in const [
      'tenantId',
      'companyId',
      'tenant',
      'company',
      'organizationId',
    ]) {
      final value = payload[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String? getSellerId(String token) =>
      decode(token)['sellerId']?.toString();

  static String getSellerScope(String token) =>
      decode(token)['sellerScope']?.toString().toUpperCase() ?? 'NONE';

  static List<String> getSellerIds(String token) {
    final payload = decode(token);
    final ids = payload['sellerIds'];
    if (ids is List) {
      return ids
          .map((id) => id.toString())
          .where((id) => id.trim().isNotEmpty)
          .toList();
    }
    final sellerId = payload['sellerId']?.toString();
    if (sellerId != null && sellerId.trim().isNotEmpty) return [sellerId];
    return [];
  }

  static Map? _findTenantScopedMap(
      Map<String, dynamic> payload, String tenantId) {
    for (final key in const [
      'memberships',
      'tenants',
      'tenantMemberships',
      'accesses',
    ]) {
      final raw = payload[key];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map && _mapTenantId(item) == tenantId) return item;
        }
      }
    }

    for (final key in const [
      'rolesByTenant',
      'tenantRoles',
      'rolesByTenantId',
      'permissionsByTenant',
      'tenantPermissions',
      'permissionsByTenantId',
      'byTenant',
    ]) {
      final raw = payload[key];
      if (raw is Map) {
        for (final entry in raw.entries) {
          if (entry.key.toString().trim() != tenantId) continue;
          final value = entry.value;
          if (value is Map) return value;
          return {'roles': value, 'permissions': value};
        }
      }
    }
    return null;
  }

  static String? _mapTenantId(Map value) {
    for (final key in const ['tenantId', 'companyId', 'tenant', 'company']) {
      final raw = value[key];
      if (raw == null) continue;
      if (raw is Map) {
        final nested = _mapTenantId(raw);
        if (nested != null && nested.isNotEmpty) return nested;
        continue;
      }
      final text = raw.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
