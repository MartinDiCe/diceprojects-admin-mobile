import 'package:app_diceprojects_admin/core/config/app_config.dart';
import 'package:app_diceprojects_admin/core/errors/error_handler.dart';
import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/storage/secure_storage.dart';
import 'package:app_diceprojects_admin/core/utils/jwt_decoder.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Auth State ──────────────────────────────────────────────────────────────

class AuthState {
  final String? token;
  final String? username;
  final List<String> roles;
  final String? tenantId;
  final bool isAdminGlobal;
  final Set<String> permissions;
  final bool isLoading;
  final bool isInitialized;
  final String? error;

  const AuthState({
    this.token,
    this.username,
    this.roles = const [],
    this.tenantId,
    this.isAdminGlobal = false,
    this.permissions = const {},
    this.isLoading = false,
    this.isInitialized = false,
    this.error,
  });

  bool get isAuthenticated =>
      token != null && isInitialized && !isLoading;

  AuthState copyWith({
    String? token,
    String? username,
    List<String>? roles,
    String? tenantId,
    bool? isAdminGlobal,
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
      isAdminGlobal:
          clearToken ? false : (isAdminGlobal ?? this.isAdminGlobal),
      permissions:
          clearToken ? const {} : (permissions ?? this.permissions),
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
      if (token == null || JwtDecoder.isExpired(token)) {
        state = state.copyWith(
            isLoading: false,
            isInitialized: true,
            clearToken: true);
        return;
      }
      await _buildStateFromToken(token);
    } catch (_) {
      state = state.copyWith(
          isLoading: false, isInitialized: true, clearToken: true);
    }
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'username': username, 'password': password},
      );

      debugPrint('[AUTH] login response: status=${response.statusCode} data=${response.data}');

      // Defensive parsing — avoids hard-cast TypeError if response shape is unexpected
      final data = response.data;
      final token = data is Map ? data['token']?.toString() : null;
      if (token == null || token.isEmpty) {
        debugPrint('[AUTH] login failed — token field missing. Full response: $data');
        state = state.copyWith(
          isLoading: false,
          error: 'Respuesta inesperada del servidor. Contactá soporte.',
        );
        return;
      }

      await _storage.write(AppConfig.tokenKey, token);
      await _buildStateFromToken(token);
    } on DioException catch (e) {
      debugPrint('[AUTH] DioException: status=${e.response?.statusCode} data=${e.response?.data} msg=${e.message}');
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
            : (backendMsg?.isNotEmpty == true ? backendMsg! : 'Credenciales inválidas (HTTP 401). Verificá usuario/contraseña o estado de los servicios.');
      } else {
        message = backendMsg?.isNotEmpty == true ? backendMsg! : ErrorHandler.handle(e).message;
      }
      state = state.copyWith(isLoading: false, error: message);
    } catch (e, s) {
      debugPrint('[AUTH] unexpected login error: $e\n$s');
      state = state.copyWith(
        isLoading: false,
        error: kDebugMode
            ? 'Error: ${e.toString().split('\n').first}'
            : 'Error inesperado al iniciar sesión.',
      );
    }
  }

  Future<void> _buildStateFromToken(String token) async {
    final username = JwtDecoder.getUsername(token);
    final roles = JwtDecoder.getRoles(token);
    final tenantId = JwtDecoder.getTenantId(token);
    final isAdminGlobal = tenantId == null || tenantId.trim().isEmpty;

    // Prefer effective permissions for current principal.
    // Fallback to per-role permissions (legacy/web strategy) if backend doesn't support it.
    final allPermissions = <String>{};
    var mePermissionsFetched = false;
    try {
      final resp = await _dio.get('/v1/me/permissions');
      final data = resp.data;
      final perms = data is Map ? data['permissions'] as List? : null;
      if (perms != null) {
        allPermissions.addAll(
          perms
              .whereType<Map>()
              .where((p) => p['code'] != null)
              .map((p) => p['code'].toString()),
        );
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
              return perms
                  .whereType<Map>()
                  .where((p) => p['code'] != null)
                  .map((p) => p['code'].toString())
                  .toSet();
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

    state = AuthState(
      token: token,
      username: username,
      roles: roles,
      tenantId: tenantId,
      isAdminGlobal: isAdminGlobal,
      permissions: allPermissions,
      isLoading: false,
      isInitialized: true,
    );
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    state = const AuthState(isInitialized: true);
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(
    ref.read(secureStorageProvider),
    ref.read(dioProvider),
  ),
);
