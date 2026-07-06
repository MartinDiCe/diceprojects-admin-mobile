import 'dart:async';
import 'dart:math';

import 'package:app_diceprojects_admin/core/config/app_config.dart';
import 'package:app_diceprojects_admin/core/errors/error_handler.dart';
import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/storage/secure_storage.dart';
import 'package:app_diceprojects_admin/core/utils/jwt_decoder.dart';
import 'package:app_diceprojects_admin/features/notifications/data/mobile_push_registration_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Auth State ──────────────────────────────────────────────────────────────

class AuthState {
  final String? token;
  final String? username;
  final List<String> roles;
  final String? tenantId;
  final String? sellerId;
  final String sellerScope;
  final List<String> sellerIds;
  final bool isAdminGlobal;
  final bool hasAdministratorRole;
  final Set<String> permissions;
  final bool isLoading;
  final bool isInitialized;
  final String? error;

  const AuthState({
    this.token,
    this.username,
    this.roles = const [],
    this.tenantId,
    this.sellerId,
    this.sellerScope = 'NONE',
    this.sellerIds = const [],
    this.isAdminGlobal = false,
    this.hasAdministratorRole = false,
    this.permissions = const {},
    this.isLoading = false,
    this.isInitialized = false,
    this.error,
  });

  bool get isAuthenticated => token != null && isInitialized && !isLoading;

  AuthState copyWith({
    String? token,
    String? username,
    List<String>? roles,
    String? tenantId,
    String? sellerId,
    String? sellerScope,
    List<String>? sellerIds,
    bool? isAdminGlobal,
    bool? hasAdministratorRole,
    Set<String>? permissions,
    bool? isLoading,
    bool? isInitialized,
    String? error,
    bool clearToken = false,
    bool clearError = false,
  }) {
    return AuthState(
      token: clearToken ? null : (token ?? this.token),
      username: clearToken ? null : (username ?? this.username),
      roles: clearToken ? const [] : (roles ?? this.roles),
      tenantId: clearToken ? null : (tenantId ?? this.tenantId),
      sellerId: clearToken ? null : (sellerId ?? this.sellerId),
      sellerScope: clearToken ? 'NONE' : (sellerScope ?? this.sellerScope),
      sellerIds: clearToken ? const [] : (sellerIds ?? this.sellerIds),
      isAdminGlobal: clearToken ? false : (isAdminGlobal ?? this.isAdminGlobal),
      hasAdministratorRole: clearToken
          ? false
          : (hasAdministratorRole ?? this.hasAdministratorRole),
      permissions: clearToken ? const {} : (permissions ?? this.permissions),
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ─── Auth Notifier ────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  static const Duration _authRequestTimeout = Duration(seconds: 18);
  static const Duration _permissionRequestTimeout = Duration(seconds: 6);

  final SecureStorageService _storage;
  final Dio _dio;

  AuthNotifier(this._storage, this._dio) : super(const AuthState()) {
    _hydrate();
  }

  Future<void> _hydrate() async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await _storage.read(AppConfig.tokenKey);
      if (token == null ||
          token.trim().isEmpty ||
          JwtDecoder.isExpired(token)) {
        await _storage.delete(AppConfig.tokenKey);
        state = state.copyWith(
            isLoading: false, isInitialized: true, clearToken: true);
        return;
      }
      await _buildStateFromToken(token);
    } catch (_) {
      state = state.copyWith(
          isLoading: false, isInitialized: true, clearToken: true);
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
          'clientType': 'mobile',
          'deviceId': await _getOrCreateDeviceId(),
          'deviceName': 'DiceProjects mobile',
        },
      ).timeout(_authRequestTimeout);

      // Defensive parsing — avoids hard-cast TypeError if response shape is unexpected
      final data = response.data;
      var token = data is Map ? data['token']?.toString() : null;
      if ((token == null || token.isEmpty) &&
          data is Map &&
          data['status']?.toString() == 'SELECTION_REQUIRED') {
        token = await _selectDefaultContext(data);
      }
      if (token == null || token.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error:
              'No pudimos completar el contexto de acceso. Elegí empresa y vendedor desde la web o contactá soporte.',
        );
        return false;
      }

      await _storage.write(AppConfig.tokenKey, token);
      await _storeRefreshTokenIfPresent(data);
      await _buildStateFromToken(token);
      return true;
    } on DioException catch (e) {
      // Try to extract the real backend message for better diagnostics
      final responseData = e.response?.data;
      final backendMsg = responseData is Map
          ? (responseData['message'] ?? responseData['error'])?.toString()
          : null;
      final statusCode = e.response?.statusCode;

      String message;
      if (statusCode == 401) {
        // In non-release mode, show real backend error (could be service-down vs wrong password)
        message = kReleaseMode
            ? 'Credenciales inválidas. Verificá tu usuario y contraseña.'
            : (backendMsg?.isNotEmpty == true
                ? backendMsg!
                : 'Credenciales inválidas (HTTP 401). Verificá usuario/contraseña o estado de los servicios.');
      } else {
        message = backendMsg?.isNotEmpty == true
            ? backendMsg!
            : ErrorHandler.handle(e).message;
      }
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } on TimeoutException {
      state = state.copyWith(
        isLoading: false,
        error:
            'El inicio de sesión tardó demasiado. Revisá la conexión e intentá nuevamente.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: kDebugMode
            ? 'Error: ${e.toString().split('\n').first}'
            : 'Error inesperado al iniciar sesión.',
      );
      return false;
    }
  }

  Future<void> loginWithToken(String token) async {
    final safeToken = token.trim();
    if (safeToken.isEmpty || JwtDecoder.isExpired(safeToken)) {
      state = state.copyWith(
        isLoading: false,
        error: 'Token de Google inválido.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    await _storage.write(AppConfig.tokenKey, safeToken);
    await _buildStateFromToken(safeToken);
  }

  Future<bool> refreshMobileSession() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final refreshToken = await _storage.read(AppConfig.refreshTokenKey);
      final deviceId = await _storage.read(AppConfig.refreshDeviceIdKey);
      if (refreshToken == null ||
          refreshToken.trim().isEmpty ||
          deviceId == null ||
          deviceId.trim().isEmpty) {
        state = const AuthState(
          isInitialized: true,
          error: 'Sesión expirada. Iniciá sesión nuevamente.',
        );
        return false;
      }

      final response = await _dio.post(
        '/auth/mobile/refresh',
        options: Options(extra: const {'skipUnauthorizedHandler': true}),
        data: {
          'refreshToken': refreshToken,
          'deviceId': deviceId,
        },
      ).timeout(_authRequestTimeout);
      final data = response.data;
      final token = data is Map ? data['token']?.toString() : null;
      if (token == null || token.isEmpty || JwtDecoder.isExpired(token)) {
        await _storage.delete(AppConfig.tokenKey);
        state = const AuthState(
          isInitialized: true,
          error: 'Sesión expirada. Iniciá sesión nuevamente.',
        );
        return false;
      }

      await _storage.write(AppConfig.tokenKey, token);
      await _storeRefreshTokenIfPresent(data);
      await _buildStateFromToken(token);
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _storage.delete(AppConfig.refreshTokenKey);
      }
      await _storage.delete(AppConfig.tokenKey);
      state = const AuthState(
        isInitialized: true,
        error: 'Sesión expirada. Iniciá sesión nuevamente.',
      );
      return false;
    } on TimeoutException {
      await _storage.delete(AppConfig.tokenKey);
      state = const AuthState(
        isInitialized: true,
        error: 'No pudimos validar la sesión. Iniciá sesión nuevamente.',
      );
      return false;
    } catch (_) {
      await _storage.delete(AppConfig.tokenKey);
      state = const AuthState(
        isInitialized: true,
        error: 'Sesión expirada. Iniciá sesión nuevamente.',
      );
      return false;
    }
  }

  Future<void> _buildStateFromToken(String token) async {
    if (JwtDecoder.isExpired(token)) {
      await expireSession();
      return;
    }
    final username = JwtDecoder.getUsername(token);
    final tenantId = JwtDecoder.getTenantId(token);
    final roles = JwtDecoder.getRolesForTenant(token, tenantId);
    final sellerId = JwtDecoder.getSellerId(token);
    final sellerScope = JwtDecoder.getSellerScope(token);
    final sellerIds = JwtDecoder.getSellerIds(token);
    final isAdminGlobal = tenantId == null || tenantId.trim().isEmpty;
    var hasAdministratorRole = _hasAdministratorRole(roles);

    final allPermissions = await _resolveEffectivePermissions(
      token: token,
      tenantId: tenantId,
      roles: roles,
    );

    hasAdministratorRole =
        hasAdministratorRole || _hasAdministratorPermissions(allPermissions);

    state = AuthState(
      token: token,
      username: username,
      roles: roles,
      tenantId: tenantId,
      sellerId: sellerId,
      sellerScope: sellerScope,
      sellerIds: sellerIds,
      isAdminGlobal: isAdminGlobal,
      hasAdministratorRole: hasAdministratorRole,
      permissions: allPermissions,
      isLoading: false,
      isInitialized: true,
    );
    unawaited(MobilePushRegistrationService(_dio).registerDevice());
  }

  Future<void> logout() async {
    await _storage.delete(AppConfig.tokenKey);
    await _storage.delete(AppConfig.refreshTokenKey);
    await _storage.delete(AppConfig.refreshDeviceIdKey);
    state = const AuthState(isInitialized: true);
  }

  Future<String?> _selectDefaultContext(Map data) async {
    final contextSelectionId = data['contextSelectionId']?.toString().trim();
    final membershipsRaw = data['memberships'];
    if (contextSelectionId == null ||
        contextSelectionId.isEmpty ||
        membershipsRaw is! List ||
        membershipsRaw.isEmpty) {
      return null;
    }

    final defaultTenantId = data['defaultTenantId']?.toString().trim();
    Map? selected;
    for (final membership in membershipsRaw) {
      if (membership is! Map || _truthy(membership['deleted'])) continue;
      final tenantId = _mapTenantId(membership);
      if (tenantId == null || tenantId.isEmpty) continue;
      if (defaultTenantId != null &&
          defaultTenantId.isNotEmpty &&
          tenantId == defaultTenantId) {
        selected = membership;
        break;
      }
      selected ??= membership;
    }
    if (selected == null) return null;

    final tenantId = _mapTenantId(selected);
    if (tenantId == null || tenantId.isEmpty) return null;

    final sellerScope =
        selected['sellerScope']?.toString().trim().toUpperCase() ?? 'NONE';
    final sellerIds = _readStringList(selected['sellerIds']);
    String? sellerId;
    if (sellerScope != 'NONE' && sellerIds.length == 1) {
      sellerId = sellerIds.first;
    }

    final response = await _dio.post(
      '/v1/auth/select-context',
      data: {
        'contextSelectionId': contextSelectionId,
        'tenantId': tenantId,
        if (sellerId != null && sellerId.isNotEmpty) 'sellerId': sellerId,
      },
    ).timeout(_authRequestTimeout);

    final responseData = response.data;
    return responseData is Map ? responseData['token']?.toString() : null;
  }

  Future<void> expireSession() async {
    await _storage.delete(AppConfig.tokenKey);
    await _storage.delete(AppConfig.refreshTokenKey);
    state = const AuthState(
      isInitialized: true,
      error: 'Sesión expirada. Iniciá sesión nuevamente.',
    );
  }

  Future<void> _storeRefreshTokenIfPresent(dynamic data) async {
    if (data is! Map) return;
    final refreshToken = data['refreshToken']?.toString();
    if (refreshToken == null || refreshToken.isEmpty) return;
    await _storage.write(AppConfig.refreshTokenKey, refreshToken);
  }

  Future<String> _getOrCreateDeviceId() async {
    final existing = await _storage.read(AppConfig.refreshDeviceIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing;
    }
    final random = Random.secure();
    final suffix = List<int>.generate(8, (_) => random.nextInt(256))
        .map((v) => v.toRadixString(16).padLeft(2, '0'))
        .join();
    final deviceId = 'mobile-${DateTime.now().microsecondsSinceEpoch}-$suffix';
    await _storage.write(AppConfig.refreshDeviceIdKey, deviceId);
    return deviceId;
  }

  static bool _hasAdministratorRole(List<String> roles) {
    return roles.any((role) {
      final normalized = _normalizePrivilegeToken(role);
      return normalized == 'ADMINISTRADOR' ||
          normalized == 'ROLE_ADMINISTRADOR' ||
          normalized == 'ADMINISTRATOR' ||
          normalized == 'ROLE_ADMINISTRATOR' ||
          normalized == 'ADMIN' ||
          normalized == 'ROLE_ADMIN' ||
          normalized == 'TENANT_ADMIN' ||
          normalized == 'ROLE_TENANT_ADMIN' ||
          normalized == 'SUPER_ADMIN' ||
          normalized == 'SUPERADMIN' ||
          normalized.contains('ADMINISTRADOR') ||
          normalized.contains('ADMINISTRATOR');
    });
  }

  static bool _hasAdministratorPermissions(Set<String> permissions) {
    return permissions.any((permission) {
      final normalized = _normalizePrivilegeToken(permission);
      return normalized == 'ADMINISTRADOR' ||
          normalized == 'ROLE_ADMINISTRADOR' ||
          normalized == 'ADMINISTRATOR' ||
          normalized == 'ROLE_ADMINISTRATOR' ||
          normalized == 'ADMIN' ||
          normalized == 'SUPER_ADMIN' ||
          normalized == 'IAM_ADMIN' ||
          normalized == 'IAM.ADMIN' ||
          normalized == 'IAM.ADMINISTRADOR' ||
          normalized == 'IAM.ROLES.CREATE' ||
          normalized == 'IAM.ROLES.EDIT' ||
          normalized == 'IAM.USERS.CREATE' ||
          normalized == 'IAM.USERS.EDIT' ||
          normalized == 'AUTORIZACION.EDITARROLES' ||
          normalized == 'AUTORIZACION.ASIGNARROL' ||
          normalized.endsWith('.ADMIN');
    });
  }

  static String _normalizePrivilegeToken(String value) {
    return value.trim().toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  static Set<String> _parsePermissionCodes(dynamic permissions) {
    final out = <String>{};
    _collectPermissionCodes(permissions, out);
    return out;
  }

  Future<Set<String>> _resolveEffectivePermissions({
    required String token,
    required String? tenantId,
    required List<String> roles,
  }) async {
    final tokenPermissions = _parseTokenPermissionClaims(token, tenantId);

    final effective = await _fetchCurrentUserPermissions(token, tenantId);
    if (effective != null) {
      return {
        ...tokenPermissions,
        ...effective,
      };
    }

    return {
      ...tokenPermissions,
      ...await _fetchPermissionsByRoles(token, tenantId, roles),
    };
  }

  static Set<String> _parseTokenPermissionClaims(
    String token,
    String? tenantId,
  ) {
    final payload = JwtDecoder.decode(token);
    final scoped = _parseTenantAwarePermissionCodes(payload, tenantId);
    if (scoped.isNotEmpty) return scoped;
    return JwtDecoder.getPermissions(token)
        .map(_normalizePermissionCode)
        .where((code) => code.isNotEmpty)
        .toSet();
  }

  Future<Set<String>?> _fetchCurrentUserPermissions(
    String token,
    String? tenantId,
  ) async {
    for (final path in const [
      '/v1/me/permissions/compact',
      '/v1/me/permissions',
    ]) {
      try {
        final resp = await _dio
            .get(
              path,
              options: _tenantAwareOptions(token, tenantId),
            )
            .timeout(_permissionRequestTimeout);
        return _parseTenantAwarePermissionCodes(resp.data, tenantId);
      } catch (_) {
        // Fallback to the legacy endpoint while older backends finish rolling out.
      }
    }
    return null;
  }

  Future<Set<String>> _fetchPermissionsByRoles(
    String token,
    String? tenantId,
    List<String> roles,
  ) async {
    final roleCodes = roles
        .map((role) => role.trim())
        .where((role) => role.isNotEmpty)
        .toSet();
    if (roleCodes.isEmpty) return <String>{};

    final results = await Future.wait(
      roleCodes.map((roleCode) async {
        try {
          final safeRoleCode = Uri.encodeComponent(roleCode.trim());
          final resp = await _dio
              .get(
                '/v1/roles/$safeRoleCode/permissions',
                options: _tenantAwareOptions(token, tenantId),
              )
              .timeout(_permissionRequestTimeout);
          return _parseTenantAwarePermissionCodes(resp.data, tenantId);
        } catch (_) {
          // Fallback compatible con versiones anteriores del backend.
        }
        return <String>{};
      }),
    );

    return results.fold<Set<String>>(
      <String>{},
      (acc, set) => acc..addAll(set),
    );
  }

  Options _tenantAwareOptions(String token, String? tenantId) {
    final tenant = tenantId?.trim();
    return Options(
      headers: {
        'Authorization': 'Bearer $token',
        if (tenant != null && tenant.isNotEmpty) 'X-Tenant-Id': tenant,
      },
      extra: const {'skipUnauthorizedHandler': true},
    );
  }

  static Set<String> _parseTenantAwarePermissionCodes(
    dynamic raw,
    String? tenantId,
  ) {
    final scoped = _extractTenantScopedPermissions(raw, tenantId);
    if (scoped.found) return _parsePermissionCodes(scoped.value);

    if (raw is Map) {
      for (final key in const [
        'permissions',
        'permissionCodes',
        'codes',
        'grants',
        'access',
      ]) {
        final parsed = _parsePermissionCodes(raw[key]);
        if (parsed.isNotEmpty) return parsed;
      }
      return <String>{};
    }

    return _parsePermissionCodes(raw);
  }

  static _ScopedPermissions _extractTenantScopedPermissions(
    dynamic raw,
    String? tenantId,
  ) {
    final tenant = tenantId?.trim();
    if (tenant == null || tenant.isEmpty || raw is! Map) {
      return const _ScopedPermissions.notFound();
    }

    for (final key in const [
      'permissionsByTenant',
      'tenantPermissions',
      'permissionsByTenantId',
      'byTenant',
    ]) {
      final value = raw[key];
      if (value is Map) {
        final scoped = _lookupTenantEntry(value, tenant);
        if (scoped.found) return scoped;
      }
      if (value is List) {
        final scoped = _lookupTenantEntryList(value, tenant);
        if (scoped.found) return scoped;
      }
    }

    final tenants = raw['tenants'] ?? raw['memberships'];
    if (tenants is List) {
      final scoped = _lookupTenantEntryList(tenants, tenant);
      if (scoped.found) return scoped;
    }

    if (_mapTenantId(raw) == tenant) {
      return _ScopedPermissions(
        raw['permissions'] ?? raw['permissionCodes'] ?? raw['codes'] ?? raw,
      );
    }

    return const _ScopedPermissions.notFound();
  }

  static _ScopedPermissions _lookupTenantEntry(Map value, String tenantId) {
    for (final entry in value.entries) {
      if (entry.key.toString().trim() == tenantId) {
        return _ScopedPermissions(entry.value);
      }
    }
    return const _ScopedPermissions.notFound();
  }

  static _ScopedPermissions _lookupTenantEntryList(
      List value, String tenantId) {
    for (final item in value) {
      if (item is! Map || _mapTenantId(item) != tenantId) continue;
      return _ScopedPermissions(
        item['permissions'] ??
            item['permissionCodes'] ??
            item['codes'] ??
            item['grants'] ??
            item,
      );
    }
    return const _ScopedPermissions.notFound();
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

  static bool _truthy(dynamic value) {
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  static List<String> _readStringList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    }
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return const [];
    return text
        .split(RegExp(r'[\s,;]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  static void _collectPermissionCodes(dynamic raw, Set<String> out) {
    if (raw == null) return;
    if (raw is String) {
      for (final part in raw.split(RegExp(r'[\s,;]+'))) {
        final value = _normalizePermissionCode(part);
        if (value.isNotEmpty) out.add(value);
      }
      return;
    }
    if (raw is List) {
      for (final item in raw) {
        _collectPermissionCodes(item, out);
      }
      return;
    }
    if (raw is Map) {
      for (final key in const [
        'permissions',
        'permission',
        'perms',
        'privileges',
        'privilege',
        'code',
        'permissionCode',
        'name',
        'authority',
      ]) {
        _collectPermissionCodes(raw[key], out);
      }
    }
  }

  static String _normalizePermissionCode(String value) => value
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[-_:\s]+'), '.')
      .replaceAll(RegExp(r'\.+'), '.');
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(
    ref.read(secureStorageProvider),
    ref.read(dioProvider),
  ),
);

class _ScopedPermissions {
  final bool found;
  final dynamic value;

  const _ScopedPermissions(this.value) : found = true;
  const _ScopedPermissions.notFound()
      : found = false,
        value = null;
}
