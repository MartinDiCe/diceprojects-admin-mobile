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
    final roles = payload['roles'];
    if (roles is List) return roles.map((r) => r.toString()).toList();
    return [];
  }

    static String? getTenantId(String token) =>
      decode(token)['tenantId']?.toString();

  static String? getSellerId(String token) =>
      decode(token)['sellerId']?.toString();

  static String getSellerScope(String token) =>
      decode(token)['sellerScope']?.toString().toUpperCase() ?? 'NONE';

  static List<String> getSellerIds(String token) {
    final payload = decode(token);
    final ids = payload['sellerIds'];
    if (ids is List) return ids.map((id) => id.toString()).where((id) => id.trim().isNotEmpty).toList();
    final sellerId = payload['sellerId']?.toString();
    if (sellerId != null && sellerId.trim().isNotEmpty) return [sellerId];
    return [];
  }
}
