import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_shell.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/fade_in_slide.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                  onPressed: () {
                  },
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          color: AppColors.ink),
                      Positioned(
                        top: -1,
                        right: -1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        isDark ? AppColors.surface : AppColors.surfaceVariant,
                    child: Text(
                      username[0].toUpperCase(),
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
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
                      const Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.view_list_rounded,
                              label: 'MICROSERVICIOS',
                              value: '42',
                              footer: '+2 nuevos',
                              footerColor: AppColors.success,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.mail_outline_rounded,
                              label: 'INVITACIONES',
                              value: '15',
                              footer: '0 Pendientes',
                              footerColor: AppColors.warning,
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
                      _ActivityCardList(
                        items: [
                          _ActivityItem(
                            icon: Icons.login_rounded,
                            iconBg: AppColors.accentLight,
                            title: 'Logins de $username',
                            subtitle: 'HOY: 3',
                            when: 'HACE 1M',
                          ),
                          const _ActivityItem(
                            icon: Icons.bolt_rounded,
                            iconBg: AppColors.errorLight,
                            title: 'Sistema detectó alta carga en',
                            link: 'Auth-Service',
                            when: 'HACE 2M',
                          ),
                          const _ActivityItem(
                            icon: Icons.check_circle_rounded,
                            iconBg: AppColors.successLight,
                            title: 'Carlos Ruiz aceptó la invitación',
                            link: 'Módulo Marketing',
                            when: 'HACE 15M',
                          ),
                          const _ActivityItem(
                            icon: Icons.rocket_launch_rounded,
                            iconBg: AppColors.accentLight,
                            title: 'Martín Diaz desplegó versión 2.4',
                            link: 'API-Gateway',
                            when: 'HACE 1H',
                          ),
                        ],
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

class _DashboardSearchBar extends StatelessWidget {
  const _DashboardSearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar funcionalidad...',
                hintStyle:
                    TextStyle(color: AppColors.textMuted, fontSize: 13.5),
                border: InputBorder.none,
              ),
              style: TextStyle(color: AppColors.ink, fontSize: 13.5),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
              },
            ),
          ),
        ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Salud de\nInfraestructura',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Estado global de los sistemas',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '98.4%',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'ESTABLE',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            width: double.infinity,
            child: CustomPaint(
              painter: _MiniAreaChartPainter(
                lineColor: AppColors.accent,
                fillColor: AppColors.accent.withValues(alpha: 0.16),
                gridColor: AppColors.border,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ChartTick('04:00'),
              _ChartTick('08:00'),
              _ChartTick('12:00'),
              _ChartTick('16:00'),
              _ChartTick('20:00'),
              _ChartTick('23:59'),
            ],
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
