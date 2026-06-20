import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OperationalContext {
  final String? tenantId;
  final String? sellerId;

  const OperationalContext({this.tenantId, this.sellerId});

  OperationalContext copyWith({
    String? tenantId,
    String? sellerId,
    bool clearTenant = false,
    bool clearSeller = false,
  }) {
    return OperationalContext(
      tenantId: clearTenant ? null : (tenantId ?? this.tenantId),
      sellerId: clearSeller ? null : (sellerId ?? this.sellerId),
    );
  }
}

class OperationalContextNotifier extends StateNotifier<OperationalContext> {
  OperationalContextNotifier() : super(const OperationalContext());

  void setTenant(String? tenantId) {
    final normalized = tenantId?.trim();
    state = OperationalContext(
      tenantId: normalized == null || normalized.isEmpty ? null : normalized,
      sellerId: null,
    );
  }

  void setSeller(String? sellerId) {
    final normalized = sellerId?.trim();
    state = state.copyWith(
      sellerId: normalized == null || normalized.isEmpty ? null : normalized,
      clearSeller: normalized == null || normalized.isEmpty,
    );
  }

  void clear() {
    state = const OperationalContext();
  }
}

final operationalContextProvider =
    StateNotifierProvider<OperationalContextNotifier, OperationalContext>(
  (ref) => OperationalContextNotifier(),
);

String? effectiveTenantId(WidgetRef ref) {
  final auth = ref.watch(authNotifierProvider);
  if (!auth.isAdminGlobal && auth.tenantId?.trim().isNotEmpty == true) {
    return auth.tenantId!.trim();
  }
  final tenantId = ref.watch(operationalContextProvider).tenantId;
  return tenantId?.trim().isNotEmpty == true ? tenantId!.trim() : null;
}

String? effectiveSellerId(WidgetRef ref) {
  final auth = ref.watch(authNotifierProvider);
  if (!auth.isAdminGlobal && auth.sellerId?.trim().isNotEmpty == true) {
    return auth.sellerId!.trim();
  }
  final sellerId = ref.watch(operationalContextProvider).sellerId;
  return sellerId?.trim().isNotEmpty == true ? sellerId!.trim() : null;
}

bool needsOperationalContext(AuthState auth, OperationalContext context) {
  if (!auth.isAuthenticated) return false;
  if (auth.isAdminGlobal) {
    return context.tenantId?.trim().isNotEmpty != true;
  }
  if (auth.sellerIds.length > 1 &&
      auth.sellerId?.trim().isNotEmpty != true &&
      context.sellerId?.trim().isNotEmpty != true) {
    return true;
  }
  return false;
}
