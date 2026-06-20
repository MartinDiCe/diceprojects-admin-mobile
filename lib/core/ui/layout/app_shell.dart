import 'package:app_diceprojects_admin/core/ui/layout/app_drawer.dart';
import 'package:app_diceprojects_admin/core/ui/layout/copilot_floating_widget.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_button.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/context/operational_context_provider.dart';
import 'package:app_diceprojects_admin/features/organization/presentation/widgets/tenant_scope_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  static final _scaffoldKey = GlobalKey<ScaffoldState>();

  const AppShell({super.key, required this.child});

  static void openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final auth = ref.watch(authNotifierProvider);
    final opContext = ref.watch(operationalContextProvider);
    final mustPickContext = !_isGlobalManagementRoute(location) &&
        needsOperationalContext(auth, opContext);

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          child,
          const CopilotFloatingWidget(),
          if (mustPickContext) const _OperationalContextBlockingDialog(),
        ],
      ),
    );
  }
}

bool _isGlobalManagementRoute(String route) {
  return route == '/dashboard' ||
      route == '/manual' ||
      route.startsWith('/manual/') ||
      route == '/chat' ||
      route.startsWith('/iam/') ||
      route == '/authorization' ||
      route.startsWith('/logs/') ||
      route.startsWith('/admin/tenants') ||
      route.startsWith('/core/') ||
      route.startsWith('/notifications/') ||
      route == '/403';
}

class _OperationalContextBlockingDialog extends ConsumerWidget {
  const _OperationalContextBlockingDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final selected = ref.watch(operationalContextProvider);
    final tenants = ref.watch(tenantScopeOptionsProvider);
    final sellers = ref.watch(sellerScopeOptionsProvider(
      auth.isAdminGlobal ? selected.tenantId : auth.tenantId,
    ));
    final canContinue = !needsOperationalContext(auth, selected);

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seleccioná contexto',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      auth.isAdminGlobal
                          ? 'Para operar datos desde la APK elegí una empresa. Los módulos globales no requieren contexto.'
                          : 'Tu usuario tiene más de un vendedor habilitado. Elegí con cuál querés operar.',
                    ),
                    const SizedBox(height: 18),
                    if (auth.isAdminGlobal)
                      tenants.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) =>
                            const Text('No pudimos cargar empresas.'),
                        data: (items) => DropdownButtonFormField<String>(
                          initialValue:
                              items.any((item) => item.id == selected.tenantId)
                                  ? selected.tenantId
                                  : null,
                          decoration:
                              const InputDecoration(labelText: 'Empresa *'),
                          isExpanded: true,
                          items: items
                              .map(
                                (tenant) => DropdownMenuItem<String>(
                                  value: tenant.id,
                                  child: Text(
                                    tenant.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => ref
                              .read(operationalContextProvider.notifier)
                              .setTenant(value),
                        ),
                      ),
                    const SizedBox(height: 12),
                    sellers.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (items) {
                        if (items.isEmpty) return const SizedBox.shrink();
                        return DropdownButtonFormField<String?>(
                          initialValue:
                              items.any((item) => item.id == selected.sellerId)
                                  ? selected.sellerId
                                  : null,
                          decoration:
                              const InputDecoration(labelText: 'Vendedor'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Todos los vendedores'),
                            ),
                            ...items.map(
                              (seller) => DropdownMenuItem<String?>(
                                value: seller.id,
                                child: Text(
                                  seller.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) => ref
                              .read(operationalContextProvider.notifier)
                              .setSeller(value),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: AppButton(
                        label: 'Continuar',
                        icon: Icons.check_rounded,
                        onPressed: canContinue ? () {} : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
