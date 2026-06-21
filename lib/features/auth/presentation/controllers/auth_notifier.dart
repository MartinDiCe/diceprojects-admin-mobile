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
      );

      debugPrint('[AUTH] login response: status=${response.statusCode}');

      // Defensive parsing — avoids hard-cast TypeError if response shape is unexpected
      final data = response.data;
      final token = data is Map ? data['token']?.toString() : null;
      if (token == null || token.isEmpty) {
        debugPrint('[AUTH] login failed — token field missing.');
        state = state.copyWith(
          isLoading: false,
          error: 'Respuesta inesperada del servidor. Contactá soporte.',
        );
        return false;
      }

      await _storage.write(AppConfig.tokenKey, token);
      await _storeRefreshTokenIfPresent(data);
      await _buildStateFromToken(token);
      return true;
    } on DioException catch (e) {
      debugPrint(
          '[AUTH] DioException: status=${e.response?.statusCode} msg=${e.message}');
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
    } catch (e, s) {
      debugPrint('[AUTH] unexpected login error: $e\n$s');
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
      );
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
    final roles = JwtDecoder.getRoles(token);
    final tenantId = JwtDecoder.getTenantId(token);
    final sellerId = JwtDecoder.getSellerId(token);
    final sellerScope = JwtDecoder.getSellerScope(token);
    final sellerIds = JwtDecoder.getSellerIds(token);
    final isAdminGlobal = tenantId == null || tenantId.trim().isEmpty;
    var hasAdministratorRole = _hasAdministratorRole(roles);

    // Prefer effective permissions for current principal.
    // Fallback to per-role permissions (legacy/web strategy) if backend doesn't support it.
    final allPermissions = <String>{};
    var mePermissionsFetched = false;
    try {
      final resp = await _dio.get('/v1/me/permissions');
      final data = resp.data;
      final perms = data is Map ? data['permissions'] as List? : null;
      if (perms != null) {
        allPermissions.addAll(_parsePermissionCodes(perms));
      }
      mePermissionsFetched = true;
    } catch (_) {
      // ignore — fallback below
    }

    if (!mePermissionsFetched) {
      final results = await Future.wait(
        roles.map((roleCode) async {
          try {
            final resp = await _dio.get('/v1/roles/$roleCode/permissions');
            final data = resp.data;
            // Response shape: { roleCode: string, permissions: [...] }
            final perms = data is Map ? data['permissions'] as List? : null;
            if (perms != null) {
              return _parsePermissionCodes(perms);
            }
          } catch (_) {
            // graceful degradation — same as web
          }
          return <String>{};
        }),
      );
      for (final set in results) {
        allPermissions.addAll(set);
      }
    }

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
          normalized == 'SUPER_ADMIN' ||
          normalized == 'SUPERADMIN';
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

  static Set<String> _parsePermissionCodes(List<dynamic> permissions) {
    return permissions
        .map((permission) {
          if (permission is String) return permission;
          if (permission is Map && permission['code'] != null) {
            return permission['code'].toString();
          }
          return null;
        })
        .whereType<String>()
        .map((code) => code.trim())
        .where((code) => code.isNotEmpty)
        .toSet();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(
    ref.read(secureStorageProvider),
    ref.read(dioProvider),
  ),
);
