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

  static void _collectRoleValues(dynamic raw, Set<String> values) {
    if (raw == null) return;
    if (raw is List) {
      for (final item in raw) {
        _collectRoleValues(item, values);
      }
      return;
    }
    if (raw is Map) {
      for (final key in const ['role', 'code', 'name', 'authority']) {
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
}
