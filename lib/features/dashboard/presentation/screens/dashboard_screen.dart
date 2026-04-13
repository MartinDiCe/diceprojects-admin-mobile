import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_shell.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/fade_in_slide.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ─── Stats providers ──────────────────────────────────────────────────────────
final _tenantsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final r = await ref.watch(dioProvider).get('/v1/tenants/count');
    return (r.data['count'] as num?)?.toInt() ?? 0;
  } catch (_) { return -1; }
});

final _usersCountProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final r = await ref.watch(dioProvider).get('/v1/users/count');
    return (r.data['count'] as num?)?.toInt() ?? 0;
  } catch (_) { return -1; }
});

// ─── Feature catalog for search ─────────────────────────────────────────────
class _Feature {
  final String route, label, description;
  final IconData icon;
  const _Feature({required this.route, required this.label, required this.description, required this.icon});
}

const _allFeatures = [
  _Feature(route: '/iam/users', label: 'Usuarios', description: 'Gestión de usuarios del sistema', icon: Icons.person_rounded),
  _Feature(route: '/iam/invitations', label: 'Invitaciones', description: 'Invitar nuevos usuarios', icon: Icons.mail_rounded),
  _Feature(route: '/iam/permissions', label: 'Permisos', description: 'Gestión de permisos del sistema', icon: Icons.lock_rounded),
  _Feature(route: '/authorization', label: 'Roles y Accesos', description: 'Definición de roles y políticas de acceso', icon: Icons.shield_rounded),
  _Feature(route: '/logs/audit', label: 'Auditoría', description: 'Registro de eventos del sistema', icon: Icons.history_rounded),
  _Feature(route: '/logs/apitraces', label: 'API Traces', description: 'Trazas de llamadas a la API', icon: Icons.api_rounded),
  _Feature(route: '/admin/tenants', label: 'Empresas', description: 'Gestión de tenants / empresas', icon: Icons.business_rounded),
  _Feature(route: '/admin/branches', label: 'Sucursales', description: 'Sucursales por empresa', icon: Icons.store_rounded),
  _Feature(route: '/organization/sellers', label: 'Vendedores', description: 'Gestión de vendedores', icon: Icons.store_mall_directory_rounded),
  _Feature(route: '/people', label: 'Personal', description: 'Gestión de personas / empleados', icon: Icons.badge_rounded),
  _Feature(route: '/products', label: 'Artículos', description: 'Productos, presentaciones, catálogo', icon: Icons.inventory_2_rounded),
  _Feature(route: '/products/types', label: 'Tipos de Producto', description: 'Clasificación de tipos de producto', icon: Icons.category_rounded),
  _Feature(route: '/products/brands', label: 'Marcas', description: 'Marcas registradas', icon: Icons.branding_watermark_rounded),
  _Feature(route: '/products/price-types', label: 'Tipos de Precio', description: 'Tipos de precios y monedas', icon: Icons.price_change_rounded),
  _Feature(route: '/products/stock-statuses', label: 'Estados de Stock', description: 'Configuración de estados de inventario', icon: Icons.inventory_rounded),
  _Feature(route: '/products/unit-of-measure', label: 'Unidades de Medida', description: 'Unidades para cantidades y dimensiones', icon: Icons.straighten_rounded),
  _Feature(route: '/warehouse', label: 'Depósitos', description: 'Gestión de depósitos y almacenes', icon: Icons.warehouse_rounded),
  _Feature(route: '/warehouse/stock', label: 'Stock', description: 'Niveles de stock por depósito', icon: Icons.inventory_2_rounded),
  _Feature(route: '/core/toggles', label: 'Feature Flags', description: 'Activar / desactivar funcionalidades', icon: Icons.toggle_on_rounded),
  _Feature(route: '/core/parameters', label: 'Parámetros', description: 'Configuración global del sistema', icon: Icons.settings_rounded),
  _Feature(route: '/core/currencies', label: 'Monedas', description: 'Monedas disponibles en el sistema', icon: Icons.attach_money_rounded),
  _Feature(route: '/marketing/leads', label: 'Leads', description: 'Gestión de leads de marketing', icon: Icons.trending_up_rounded),
  _Feature(route: '/marketing/destacados', label: 'Destacados', description: 'Contenido destacado en el catálogo', icon: Icons.star_rounded),
  _Feature(route: '/logs/notifications', label: 'Notificaciones enviadas', description: 'Historial de notificaciones del sistema', icon: Icons.notifications_rounded),
];

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final isDark = AppColors.isDark;
    final username = (auth.username?.trim().isNotEmpty ?? false)
        ? auth.username!.trim()
        : 'Usuario';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              pinned: false,
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: Icon(Icons.menu_rounded, color: AppColors.ink),
                onPressed: AppShell.openDrawer,
              ),
              actions: [
                IconButton(
                  tooltip: 'Notificaciones enviadas',
                  onPressed: () => context.push('/logs/notifications'),
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.notifications_none_rounded, color: AppColors.ink),
                      Positioned(
                        top: -1, right: -1,
                        child: Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: isDark ? AppColors.surface : AppColors.surfaceVariant,
                      child: Text(
                        username[0].toUpperCase(),
                        style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: FadeInSlide(
                  delay: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¡Buenos días, ${_friendlyFirstName(username)}!',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Panel de Control',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _DashboardSearchBar(),
                      const SizedBox(height: 16),
                      const _InfraHealthCard(),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ref.watch(_tenantsCountProvider).when(
                              data: (n) => _StatCard(
                                icon: Icons.business_rounded,
                                label: 'EMPRESAS',
                                value: n < 0 ? '—' : '$n',
                                footer: n < 0 ? 'Sin acceso' : 'Tenants activos',
                                footerColor: n < 0 ? AppColors.textMuted : AppColors.success,
                              ),
                              loading: () => const _StatCard(icon: Icons.business_rounded, label: 'EMPRESAS', value: '...', footer: '', footerColor: Colors.grey),
                              error: (_, __) => const _StatCard(icon: Icons.business_rounded, label: 'EMPRESAS', value: '—', footer: 'Error', footerColor: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ref.watch(_usersCountProvider).when(
                              data: (n) => _StatCard(
                                icon: Icons.people_rounded,
                                label: 'USUARIOS',
                                value: n < 0 ? '—' : '$n',
                                footer: n < 0 ? 'Sin acceso' : 'Usuarios registrados',
                                footerColor: n < 0 ? AppColors.textMuted : AppColors.accent,
                              ),
                              loading: () => const _StatCard(icon: Icons.people_rounded, label: 'USUARIOS', value: '...', footer: '', footerColor: Colors.grey),
                              error: (_, __) => const _StatCard(icon: Icons.people_rounded, label: 'USUARIOS', value: '—', footer: 'Error', footerColor: Colors.red),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Text(
                            'Actividad Reciente',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                            },
                            child: const Text('Ver todo'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.history_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text('Actividad Reciente', style: TextStyle(color: AppColors.ink, fontSize: 14, fontWeight: FontWeight.w800)),
                              const Spacer(),
                              TextButton(
                                onPressed: () => context.push('/logs/apitraces'),
                                child: const Text('Ver trazas'),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            Text(
                              'Utilizá los módulos de trazas y auditoría para ver la actividad en tiempo real.',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => context.push('/logs/apitraces'),
                                  icon: const Icon(Icons.api_rounded, size: 16),
                                  label: const Text('API Traces'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.accent,
                                    side: BorderSide(color: AppColors.border),
                                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => context.push('/logs/audit'),
                                  icon: const Icon(Icons.manage_search_rounded, size: 16),
                                  label: const Text('Auditoría'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.accent,
                                    side: BorderSide(color: AppColors.border),
                                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _friendlyFirstName(String username) {
  final normalized = username.trim();
  if (normalized.isEmpty) return 'Usuario';
  final base = normalized.contains('@')
      ? normalized.split('@').first
      : normalized.split(RegExp(r'\s+')).first;
  if (base.isEmpty) return 'Usuario';
  return base[0].toUpperCase() + base.substring(1);
}

class _DashboardSearchBar extends ConsumerStatefulWidget {
  const _DashboardSearchBar();

  @override
  ConsumerState<_DashboardSearchBar> createState() => _DashboardSearchBarState();
}

class _DashboardSearchBarState extends ConsumerState<_DashboardSearchBar> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  bool _open = false;
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _query.isEmpty) {
        setState(() => _open = false);
      } else if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 180), _closeOverlay);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    _closeOverlay();
    super.dispose();
  }

  List<_Feature> _filtered() {
    final perms = ref.read(permissionsProvider);
    final q = _query.toLowerCase().trim();
    return _allFeatures.where((f) {
      final allowed = perms.canAccessRoute(f.route);
      if (!allowed) return false;
      if (q.isEmpty) return true;
      return f.label.toLowerCase().contains(q) || f.description.toLowerCase().contains(q);
    }).toList();
  }

  void _openOverlay() {
    _closeOverlay();
    final results = _filtered();
    if (results.isEmpty) return;
    _overlay = OverlayEntry(builder: (ctx) {
      return Positioned(
        width: 340,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 48),
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(14),
            color: AppColors.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: results.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                itemBuilder: (_, i) {
                  final f = results[i];
                  return ListTile(
                    leading: Icon(f.icon, color: AppColors.accent, size: 20),
                    title: Text(f.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    subtitle: Text(f.description, style: TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    dense: true,
                    onTap: () {
                      _closeOverlay();
                      _ctrl.clear();
                      setState(() { _query = ''; _open = false; });
                      context.push(f.route);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
    });
    Overlay.of(context).insert(_overlay!);
    setState(() => _open = true);
  }

  void _closeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _onChanged(String v) {
    setState(() => _query = v);
    if (v.isNotEmpty) {
      _openOverlay();
    } else {
      _closeOverlay();
      setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _open ? AppColors.accent : AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: _open ? AppColors.accent : AppColors.textMuted, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'Buscar funcionalidad...',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
                  border: InputBorder.none,
                ),
                style: TextStyle(color: AppColors.ink, fontSize: 13.5),
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onTap: () { if (_query.isNotEmpty) _openOverlay(); },
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () { _ctrl.clear(); _onChanged(''); },
                child: Icon(Icons.clear_rounded, color: AppColors.textMuted, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfraHealthCard extends StatelessWidget {
  const _InfraHealthCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.hub_rounded, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Estado de Servicios',
                  style: TextStyle(color: AppColors.ink, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Monitoreá trazas y errores desde el módulo de logs.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/logs/apitraces'),
            child: const Text('Ver logs'),
          ),
        ],
      ),
    );
  }
}

class _ChartTick extends StatelessWidget {
  final String label;
  const _ChartTick(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: AppColors.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _MiniAreaChartPainter extends CustomPainter {
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  const _MiniAreaChartPainter({
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;

    for (var i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = <Offset>[
      Offset(0, size.height * 0.55),
      Offset(size.width * 0.18, size.height * 0.62),
      Offset(size.width * 0.32, size.height * 0.78),
      Offset(size.width * 0.46, size.height * 0.44),
      Offset(size.width * 0.62, size.height * 0.36),
      Offset(size.width * 0.78, size.height * 0.48),
      Offset(size.width, size.height * 0.58),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final c1 = Offset((prev.dx + curr.dx) / 2, prev.dy);
      final c2 = Offset((prev.dx + curr.dx) / 2, curr.dy);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, curr.dx, curr.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()..color = fillColor;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniAreaChartPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String footer;
  final Color footerColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.footer,
    required this.footerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accent, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            footer,
            style: TextStyle(
              color: footerColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCardList extends StatelessWidget {
  final List<_ActivityItem> items;
  const _ActivityCardList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            items[i],
            if (i != items.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Divider(
                  color: AppColors.border,
                  height: 16,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String? link;
  final String when;
  final String? subtitle;

  const _ActivityItem({
    required this.icon,
    required this.iconBg,
    required this.title,
    this.link,
    required this.when,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accentDark, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                    children: [
                      TextSpan(text: title),
                      if (link != null) ...[
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: link,
                          style: const TextStyle(color: AppColors.accent),
                        ),
                      ],
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  when,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
