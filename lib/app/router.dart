import 'package:app_diceprojects_admin/core/ui/layout/app_shell.dart';
import 'package:app_diceprojects_admin/features/api_traces/presentation/screens/api_traces_screen.dart';
import 'package:app_diceprojects_admin/features/audit/presentation/screens/audit_list_screen.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/screens/login_screen.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/screens/splash_screen.dart';
import 'package:app_diceprojects_admin/features/core_masters/presentation/screens/currencies_screen.dart';
import 'package:app_diceprojects_admin/features/core_masters/presentation/screens/feature_toggles_screen.dart';
import 'package:app_diceprojects_admin/features/core_masters/presentation/screens/parameters_screen.dart';
import 'package:app_diceprojects_admin/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:app_diceprojects_admin/features/invitations/presentation/screens/invitations_screen.dart';
import 'package:app_diceprojects_admin/features/marketing_destacados/presentation/screens/destacados_screen.dart';
import 'package:app_diceprojects_admin/features/marketing_leads/presentation/screens/leads_list_screen.dart';
import 'package:app_diceprojects_admin/features/notifications/presentation/screens/notif_logs_screen.dart';
import 'package:app_diceprojects_admin/features/notifications/presentation/screens/notif_templates_screen.dart';
import 'package:app_diceprojects_admin/features/notifications/presentation/screens/notif_types_screen.dart';
import 'package:app_diceprojects_admin/features/notifications/presentation/screens/notif_variables_screen.dart';
import 'package:app_diceprojects_admin/features/notifications/presentation/screens/sender_profiles_screen.dart';
import 'package:app_diceprojects_admin/features/organization/presentation/screens/branches_list_screen.dart';
import 'package:app_diceprojects_admin/features/organization/presentation/screens/tenant_form_screen.dart';
import 'package:app_diceprojects_admin/features/organization/presentation/screens/tenants_list_screen.dart';
import 'package:app_diceprojects_admin/features/people/presentation/screens/people_list_screen.dart';
import 'package:app_diceprojects_admin/features/people/presentation/screens/person_form_screen.dart';
import 'package:app_diceprojects_admin/features/products/presentation/screens/brands_screen.dart';
import 'package:app_diceprojects_admin/features/products/presentation/screens/presentation_types_screen.dart';
import 'package:app_diceprojects_admin/features/products/presentation/screens/price_types_screen.dart';
import 'package:app_diceprojects_admin/features/products/presentation/screens/product_form_screen.dart';
import 'package:app_diceprojects_admin/features/products/presentation/screens/product_import_screen.dart';
import 'package:app_diceprojects_admin/features/products/presentation/screens/product_statuses_screen.dart';
import 'package:app_diceprojects_admin/features/products/presentation/screens/product_types_screen.dart';
import 'package:app_diceprojects_admin/features/products/presentation/screens/products_list_screen.dart';
import 'package:app_diceprojects_admin/features/products/presentation/screens/publication_channels_screen.dart';
import 'package:app_diceprojects_admin/features/products/presentation/screens/stock_statuses_screen.dart';
import 'package:app_diceprojects_admin/features/products/presentation/screens/stock_strategies_screen.dart';
import 'package:app_diceprojects_admin/features/products/presentation/screens/storage_conditions_screen.dart';
import 'package:app_diceprojects_admin/features/products/presentation/screens/unit_of_measure_screen.dart';
import 'package:app_diceprojects_admin/features/sellers/presentation/screens/seller_form_screen.dart';
import 'package:app_diceprojects_admin/features/sellers/presentation/screens/sellers_list_screen.dart';
import 'package:app_diceprojects_admin/features/warehouse/presentation/screens/movements_screen.dart';
import 'package:app_diceprojects_admin/features/warehouse/presentation/screens/stock_overview_screen.dart';
import 'package:app_diceprojects_admin/features/warehouse/presentation/screens/warehouse_types_screen.dart';
import 'package:app_diceprojects_admin/features/warehouse/presentation/screens/warehouses_list_screen.dart';
import 'package:app_diceprojects_admin/features/core_masters/presentation/screens/sectors_screen.dart';
import 'package:app_diceprojects_admin/features/roles/presentation/screens/role_detail_screen.dart';
import 'package:app_diceprojects_admin/features/roles/presentation/screens/roles_list_screen.dart';
import 'package:app_diceprojects_admin/features/permissions/presentation/screens/permissions_screen.dart';
import 'package:app_diceprojects_admin/features/users/presentation/screens/user_detail_screen.dart';
import 'package:app_diceprojects_admin/features/users/presentation/screens/user_form_screen.dart';
import 'package:app_diceprojects_admin/features/users/presentation/screens/users_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ─── Router Notifier ──────────────────────────────────────────────────────────

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  late final ProviderSubscription<AuthState> _sub;

  _RouterNotifier(this._ref) {
    _sub = _ref.listen<AuthState>(
      authNotifierProvider,
      (_, __) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }

  AuthState get authState => _ref.read(authNotifierProvider);
}

final _routerNotifierProvider = Provider<_RouterNotifier>(
  (ref) => _RouterNotifier(ref),
);

// ─── Router Provider ─────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = notifier.authState;
      final loc = state.matchedLocation;

      if (!auth.isInitialized) {
        return loc == '/splash' ? null : '/splash';
      }

      if (!auth.isAuthenticated) {
        if (loc == '/login' || loc == '/splash') return null;
        return '/login';
      }

      if (loc == '/splash' || loc == '/login') {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/403',
        builder: (_, __) => const _ForbiddenScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          // IAM
          GoRoute(
            path: '/iam/users',
            builder: (_, __) => const UsersListScreen(),
          ),
          GoRoute(
            path: '/iam/users/new',
            builder: (_, __) => const UserFormScreen(),
          ),
          GoRoute(
            path: '/iam/users/:id',
            builder: (_, state) =>
                UserDetailScreen(userId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/iam/invitations',
            builder: (_, __) => const InvitationsScreen(),
          ),
          GoRoute(
            path: '/iam/permissions',
            builder: (_, __) => const PermissionsListScreen(),
          ),
          // Authorization
          GoRoute(
            path: '/authorization',
            builder: (_, __) => const RolesListScreen(),
          ),
          GoRoute(
            path: '/authorization/:id',
            builder: (_, state) =>
                RoleDetailScreen(roleId: state.pathParameters['id']!),
          ),
          // Logs
          GoRoute(
            path: '/logs/audit',
            builder: (_, __) => const AuditListScreen(),
          ),
          GoRoute(
            path: '/logs/apitraces',
            builder: (_, __) => const ApiTracesScreen(),
          ),
          GoRoute(
            path: '/logs/notifications',
            builder: (_, __) => const NotifLogsScreen(),
          ),
          // Organization
          GoRoute(
            path: '/admin/tenants',
            builder: (_, __) => const TenantsListScreen(),
          ),
          GoRoute(
            path: '/admin/tenants/new',
            builder: (_, __) =>
                const TenantFormScreen(tenantId: null),
          ),
          GoRoute(
            path: '/admin/tenants/:id/edit',
            builder: (_, state) => TenantFormScreen(
                tenantId: state.pathParameters['id']),
          ),
          GoRoute(
            path: '/admin/branches',
            builder: (_, state) => BranchesListScreen(
              tenantId: state.uri.queryParameters['tenantId'],
            ),
          ),
          // People
          GoRoute(
            path: '/people',
            builder: (_, __) => const PeopleListScreen(),
          ),
          GoRoute(
            path: '/people/new',
            builder: (_, __) =>
                const PersonFormScreen(personId: null),
          ),
          GoRoute(
            path: '/people/:id/edit',
            builder: (_, state) =>
                PersonFormScreen(personId: state.pathParameters['id']),
          ),
          // Products
          GoRoute(
            path: '/products',
            builder: (_, __) => const ProductsListScreen(),
          ),
          GoRoute(
            path: '/products/new',
            builder: (_, __) => const ProductFormScreen(),
          ),
          GoRoute(
            path: '/products/:id/edit',
            builder: (_, state) =>
                ProductFormScreen(productId: state.pathParameters['id']),
          ),
          GoRoute(
            path: '/products/types',
            builder: (_, __) => const ProductTypesScreen(),
          ),
          GoRoute(
            path: '/products/brands',
            builder: (_, __) => const BrandsScreen(),
          ),
          GoRoute(
            path: '/products/storage-conditions',
            builder: (_, __) => const StorageConditionsScreen(),
          ),
          GoRoute(
            path: '/products/import',
            builder: (_, __) => const ProductImportScreen(),
          ),
          GoRoute(
            path: '/products/price-types',
            builder: (_, __) => const PriceTypesScreen(),
          ),
          GoRoute(
            path: '/products/stock-statuses',
            builder: (_, __) => const StockStatusesScreen(),
          ),
          GoRoute(
            path: '/products/product-statuses',
            builder: (_, __) => const ProductStatusesScreen(),
          ),
          GoRoute(
            path: '/products/publication-channels',
            builder: (_, __) => const PublicationChannelsScreen(),
          ),
          GoRoute(
            path: '/products/stock-strategies',
            builder: (_, __) => const StockStrategiesScreen(),
          ),
          GoRoute(
            path: '/products/presentation-types',
            builder: (_, __) => const PresentationTypesScreen(),
          ),
          GoRoute(
            path: '/products/unit-of-measure',
            builder: (_, __) => const UnitOfMeasureScreen(),
          ),
          // Sellers
          GoRoute(
            path: '/organization/sellers',
            builder: (_, __) => const SellersListScreen(),
          ),
          GoRoute(
            path: '/organization/sellers/new',
            builder: (_, __) => const SellerFormScreen(sellerId: null),
          ),
          GoRoute(
            path: '/organization/sellers/:id/edit',
            builder: (_, state) =>
                SellerFormScreen(sellerId: state.pathParameters['id']),
          ),
          // Warehouse
          GoRoute(
            path: '/warehouse',
            builder: (_, __) => const WarehousesListScreen(),
          ),
          GoRoute(
            path: '/warehouse/types',
            builder: (_, __) => const WarehouseTypesScreen(),
          ),
          GoRoute(
            path: '/warehouse/stock',
            builder: (_, __) => const StockOverviewScreen(),
          ),
          GoRoute(
            path: '/warehouse/:warehouseId/movements',
            builder: (_, state) => MovementsScreen(
                warehouseId: state.pathParameters['warehouseId']!),
          ),
          // Sectors
          GoRoute(
            path: '/core/sectors',
            builder: (_, __) => const SectorsScreen(),
          ),
          // Marketing
          GoRoute(
            path: '/marketing/leads',
            builder: (_, __) => const LeadsListScreen(),
          ),
          GoRoute(
            path: '/marketing/destacados',
            builder: (_, __) => const DestacadosScreen(),
          ),
          // Notifications
          GoRoute(
            path: '/notifications/types',
            builder: (_, __) => const NotifTypesScreen(),
          ),
          GoRoute(
            path: '/notifications/templates',
            builder: (_, __) => const NotifTemplatesScreen(),
          ),
          GoRoute(
            path: '/notifications/sender-profiles',
            builder: (_, __) => const SenderProfilesScreen(),
          ),
          GoRoute(
            path: '/notifications/variables',
            builder: (_, __) => const NotifVariablesScreen(),
          ),
          // Core Masters
          GoRoute(
            path: '/core/currencies',
            builder: (_, __) => const CurrenciesScreen(),
          ),
          GoRoute(
            path: '/core/languages',
            builder: (_, __) => const LanguagesScreen(),
          ),
          GoRoute(
            path: '/core/geo/countries',
            builder: (_, __) => const CountriesScreen(),
          ),
          GoRoute(
            path: '/core/geo/states',
            builder: (_, state) => StatesScreen(
              countryId: state.uri.queryParameters['countryId'],
            ),
          ),
          GoRoute(
            path: '/core/geo/cities',
            builder: (_, state) => CitiesScreen(
              stateId: state.uri.queryParameters['stateId'],
            ),
          ),
          GoRoute(
            path: '/core/toggles',
            builder: (_, __) => const FeatureTogglesScreen(),
          ),
          GoRoute(
            path: '/core/parameters',
            builder: (_, __) => const ParametersScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (_, __) => const _NotFoundScreen(),
  );
});

// ─── Generic screens ─────────────────────────────────────────────────────────

class _ForbiddenScreen extends StatelessWidget {
  const _ForbiddenScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acceso denegado')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_rounded, size: 72, color: Colors.red),
            SizedBox(height: 16),
            Text('No tenés permisos para acceder a esta sección.'),
          ],
        ),
      ),
    );
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Página no encontrada')),
      body: const Center(
        child: Text('La página que buscás no existe.'),
      ),
    );
  }
}
