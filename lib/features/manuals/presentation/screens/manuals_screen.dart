import 'package:app_diceprojects_admin/app/locale_provider.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ManualsScreen extends ConsumerWidget {
  final String? moduleId;

  const ManualsScreen({super.key, this.moduleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider).languageCode;
    final manual = _manualById(moduleId);

    if (manual == null) {
      return AppPageScaffold(
        title: _t(locale, 'Manuales de uso', 'User guides', 'Manuais de uso'),
        body: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: _manuals.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = _manuals[index];
            return _ManualListTile(manual: item);
          },
        ),
      );
    }

    return AppPageScaffold(
      title: manual.title,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _HeroBlock(manual: manual),
          const SizedBox(height: 14),
          _SectionCard(
            icon: Icons.flag_rounded,
            title:
                _t(locale, 'Para qué sirve', 'What it does', 'Para que serve'),
            lines: [manual.purpose],
          ),
          _SectionCard(
            icon: Icons.lightbulb_rounded,
            title: _t(locale, 'Ejemplo clave', 'Key example', 'Exemplo-chave'),
            lines: [manual.keyExample],
            highlighted: true,
          ),
          _SectionCard(
            icon: Icons.checklist_rounded,
            title: _t(locale, 'Paso a paso', 'Step by step', 'Passo a passo'),
            lines: manual.quickStart,
            numbered: true,
          ),
          _SectionCard(
            icon: Icons.link_rounded,
            title:
                _t(locale, 'Se relaciona con', 'Related to', 'Relacionado a'),
            lines: manual.related,
          ),
        ],
      ),
    );
  }
}

class ChatComingSoonScreen extends ConsumerWidget {
  const ChatComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider).languageCode;
    return AppPageScaffold(
      title: _t(locale, 'Chat IA', 'AI Chat', 'Chat IA'),
      body: const BackofficeCopilotPanel(),
    );
  }
}

class BackofficeCopilotPanel extends ConsumerStatefulWidget {
  final bool showHeader;
  final VoidCallback? onClose;
  final VoidCallback? onMinimize;

  const BackofficeCopilotPanel({
    super.key,
    this.showHeader = false,
    this.onClose,
    this.onMinimize,
  });

  @override
  ConsumerState<BackofficeCopilotPanel> createState() =>
      _BackofficeCopilotPanelState();
}

class _BackofficeCopilotPanelState
    extends ConsumerState<BackofficeCopilotPanel> {
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[
    const _ChatMessage(
      fromUser: false,
      title: 'Copiloto Backoffice',
      body:
          'Puedo orientarte con manuales, permisos y contexto activo. Trabajo sin LLM: uso reglas, guías curadas y accesos del usuario. Si más adelante se activa IA, esta misma base sirve como contexto seguro.',
      actions: [
        _ChatAction('Qué puedo hacer', null, 'que podes hacer'),
        _ChatAction('Crear proyecto', null, 'crear proyecto'),
        _ChatAction('Buscar producto', null, 'buscar producto'),
      ],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;
    _controller.clear();
    final auth = ref.read(authNotifierProvider);
    final perms = ref.read(permissionsProvider);
    final answer = _answerFor(text, auth, perms);
    setState(() {
      _messages.add(_ChatMessage(fromUser: true, body: text));
      _messages.add(answer);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final locale = ref.watch(appLocaleProvider).languageCode;

    return Column(
      children: [
        if (widget.showHeader)
          _CopilotPanelHeader(
            onClose: widget.onClose,
            onMinimize: widget.onMinimize,
          ),
        _CopilotContextCard(auth: auth),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              return _MessageBubble(
                message: _messages[index],
                onAction: (action) {
                  if (action.route != null) {
                    context.go(action.route!);
                    widget.onMinimize?.call();
                  } else if (action.prompt != null) {
                    _send(action.prompt);
                  }
                },
              );
            },
          ),
        ),
        _QuickPromptBar(onPrompt: _send),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: InputDecoration(
                      hintText: _t(
                        locale,
                        'Preguntá por módulos, acciones o permisos...',
                        'Ask about modules, actions or permissions...',
                        'Pergunte sobre módulos, ações ou permissões...',
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(52, 52),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _send,
                  child: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  _ChatMessage _answerFor(
    String raw,
    AuthState auth,
    PermissionsService perms,
  ) {
    final text = _normalize(raw);
    final contextLine = _contextLine(auth);

    if (auth.isAdminGlobal && auth.tenantId == null) {
      return const _ChatMessage(
        fromUser: false,
        title: 'Necesito contexto operativo',
        body:
            'Estás en modo global. Para consultar datos o ejecutar acciones reales, primero elegí una empresa desde el selector de contexto. Puedo explicar funcionalidades globales, pero no debo mezclar información de tenants.',
        actions: [
          _ChatAction('Ver manuales', '/manual', null),
          _ChatAction('Ir al dashboard', '/dashboard', null),
        ],
      );
    }

    if (_hasAny(text, ['token', 'tokens', 'costo ia', 'gastar'])) {
      return _ChatMessage(
        fromUser: false,
        title: 'Cómo cuidamos tokens',
        body:
            '$contextLine\n\nEl copiloto primero usa manuales, permisos, memoria curada y reglas determinísticas. Recién si la consulta exige razonamiento abierto se puede escalar a LLM. Esto baja costo, evita respuestas fuera de scope y mantiene trazabilidad por empresa, seller y usuario.',
        actions: [
          const _ChatAction(
              'Manual AI Orchestrator', '/manual/ai-orchestrator', null),
          const _ChatAction('Ver manuales', '/manual', null),
        ],
      );
    }

    if (_hasAny(text, ['proyecto integral', 'integral'])) {
      return _moduleAnswer(
        contextLine: contextLine,
        perms: perms,
        manualId: 'integral-projects',
        route: '/integral-projects/management',
        action:
            'Podés crear un proyecto integral, cargar tipos, recursos y templates. Si el usuario tiene permisos, abrí el módulo y confirmá el alta en pantalla.',
      );
    }

    if (_hasAny(text, ['obra', 'proyecto', 'partida', 'recurso'])) {
      return _moduleAnswer(
        contextLine: contextLine,
        perms: perms,
        manualId: 'projects',
        route: '/projects/management',
        action:
            'Para dar de alta una obra: elegí cliente, tipo, responsable, template y partidas. El copiloto puede guiar el armado, pero el guardado se confirma en el formulario del módulo.',
      );
    }

    if (_hasAny(text, ['proveedor', 'partner', 'supplier'])) {
      return _moduleAnswer(
        contextLine: contextLine,
        perms: perms,
        manualId: 'partners',
        route: '/partners',
        action:
            'Buscá proveedores por nombre, CUIT, email o estado. Para presupuestos, el proveedor queda referenciado y se guarda snapshot para no depender en caliente.',
      );
    }

    if (_hasAny(text, ['cliente', 'customer'])) {
      return _moduleAnswer(
        contextLine: contextLine,
        perms: perms,
        manualId: 'customers',
        route: '/customers',
        action:
            'Buscá o creá clientes por empresa y seller cuando corresponda. Ventas y proyectos usan referencia más snapshot para mantener trazabilidad.',
      );
    }

    if (_hasAny(text, ['producto', 'articulo', 'sku', 'catalogo'])) {
      return _moduleAnswer(
        contextLine: contextLine,
        perms: perms,
        manualId: 'products',
        route: '/products',
        action:
            'Podés buscar productos por nombre, SKU, categoría o atributos. Desde el detalle se administran presentaciones, precios, imágenes y publicación web.',
      );
    }

    if (_hasAny(text, ['cotizacion', 'cotizar', 'venta'])) {
      return _moduleAnswer(
        contextLine: contextLine,
        perms: perms,
        manualId: 'sales',
        route: '/sales/quotes',
        action:
            'Para cotizar: elegí cliente, agregá productos o ítems manuales, revisá totales y compartí link/PDF/WhatsApp. Si falta costo, podés disparar compra.',
      );
    }

    if (_hasAny(text, ['presupuesto', 'compra', 'compras'])) {
      return _moduleAnswer(
        contextLine: contextLine,
        perms: perms,
        manualId: 'purchases',
        route: '/purchases/requests',
        action:
            'Compras permite pedir precios, comparar respuestas y adjudicar. Es ideal para validar costo antes de cerrar una venta u obra.',
      );
    }

    if (_hasAny(text, ['turno', 'agenda', 'salud', 'paciente'])) {
      return _moduleAnswer(
        contextLine: contextLine,
        perms: perms,
        manualId: text.contains('salud') || text.contains('paciente')
            ? 'health'
            : 'appointments',
        route: '/manual/appointments',
        action:
            'En mobile hoy queda como guía operativa. Agenda genérica sirve para servicios simples; Salud especializa pacientes, profesionales, coberturas y recomendaciones.',
      );
    }

    if (_hasAny(text, ['permiso', 'rol', 'usuario', 'invitar'])) {
      return _moduleAnswer(
        contextLine: contextLine,
        perms: perms,
        manualId: 'security',
        route: '/iam/users',
        action:
            'Seguridad trabaja con IAM. Invitá usuarios, asigná accesos por empresa/seller y roles estables. El usuario solo ve módulos permitidos.',
      );
    }

    if (_hasAny(text, ['marketing', 'campaña', 'lead', 'bot', 'spam'])) {
      return _moduleAnswer(
        contextLine: contextLine,
        perms: perms,
        manualId: 'marketing',
        route: '/marketing/campaigns',
        action:
            'Marketing administra campañas, formularios, leads, bots y protección antiabuso. Los eventos permiten medir vistas, clicks, productos y conversiones.',
      );
    }

    final matches = _manuals
        .where((m) =>
            _normalize('${m.title} ${m.subtitle} ${m.purpose}').contains(text))
        .take(3)
        .toList();
    if (matches.isNotEmpty) {
      return _ChatMessage(
        fromUser: false,
        title: 'Encontré manuales relacionados',
        body:
            '$contextLine\n\nTe dejo los manuales más cercanos. Abrilos para ver pasos, ejemplos y módulos relacionados.',
        actions: [
          for (final manual in matches)
            _ChatAction(manual.title, '/manual/${manual.id}', null),
        ],
      );
    }

    return _ChatMessage(
      fromUser: false,
      title: 'Te puedo guiar mejor si me das una pista',
      body:
          '$contextLine\n\nPuedo responder sobre usuarios, permisos, clientes, proveedores, productos, cotizaciones, compras, obras, proyectos integrales, marketing, notificaciones, almacenes, agenda, salud y AI Orchestrator.',
      actions: [
        const _ChatAction('Qué puedo hacer', null, 'que podes hacer'),
        const _ChatAction('Ver manuales', '/manual', null),
        const _ChatAction('Buscar producto', null, 'buscar producto'),
      ],
    );
  }

  _ChatMessage _moduleAnswer({
    required String contextLine,
    required PermissionsService perms,
    required String manualId,
    required String route,
    required String action,
  }) {
    final manual = _manualById(manualId);
    final allowed = perms.canAccessRoute(route);
    return _ChatMessage(
      fromUser: false,
      title: manual?.title ?? 'Guía operativa',
      body:
          '$contextLine\n\n$action\n\n${manual?.keyExample ?? ''}\n\n${allowed ? 'Tenés permisos para abrir el módulo desde esta sesión.' : 'No veo permisos para abrir ese módulo. Puedo mostrarte el manual, pero no navegar a la operación.'}',
      actions: [
        if (allowed) _ChatAction('Abrir módulo', route, null),
        if (manual != null)
          _ChatAction('Ver manual', '/manual/${manual.id}', null),
      ],
    );
  }
}

class _CopilotContextCard extends StatelessWidget {
  final AuthState auth;

  const _CopilotContextCard({required this.auth});

  @override
  Widget build(BuildContext context) {
    final label = _contextLine(auth);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_rounded, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF234B6B),
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopilotPanelHeader extends StatelessWidget {
  final VoidCallback? onClose;
  final VoidCallback? onMinimize;

  const _CopilotPanelHeader({this.onClose, this.onMinimize});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF101828),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.accent,
            child: Icon(Icons.auto_awesome_rounded,
                color: AppColors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Copiloto Backoffice',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Asistente contextual',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Minimizar',
            onPressed: onMinimize,
            icon: const Icon(Icons.remove_rounded, color: AppColors.white),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: AppColors.white),
          ),
        ],
      ),
    );
  }
}

class _QuickPromptBar extends StatelessWidget {
  final ValueChanged<String> onPrompt;

  const _QuickPromptBar({required this.onPrompt});

  @override
  Widget build(BuildContext context) {
    const prompts = [
      'Crear proyecto',
      'Buscar proveedor',
      'Buscar cliente',
      'Buscar producto',
      'Cómo cuida tokens',
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = prompts[index];
          return OutlinedButton(
            onPressed: () => onPrompt(prompt),
            child: Text(prompt),
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final ValueChanged<_ChatAction> onAction;

  const _MessageBubble({required this.message, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final align =
        message.fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = message.fromUser ? AppColors.accent : AppColors.surface;
    final fg = message.fromUser ? AppColors.white : AppColors.ink;
    final border = message.fromUser ? AppColors.accent : AppColors.border;

    return Align(
      alignment: align,
      child: Container(
        width: message.fromUser ? null : double.infinity,
        constraints: BoxConstraints(
          maxWidth: message.fromUser ? 320 : 680,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.title != null) ...[
              Text(
                message.title!,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              message.body,
              style: TextStyle(
                color: message.fromUser
                    ? AppColors.white
                    : AppColors.textSecondary,
                height: 1.35,
                fontSize: 13.5,
              ),
            ),
            if (message.actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in message.actions)
                    OutlinedButton(
                      onPressed: () => onAction(action),
                      child: Text(action.label),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManualListTile extends StatelessWidget {
  final _ManualDefinition manual;

  const _ManualListTile({required this.manual});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/manual/${manual.id}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(manual.icon, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manual.title,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      manual.subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBlock extends StatelessWidget {
  final _ManualDefinition manual;

  const _HeroBlock({required this.manual});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(manual.icon, color: AppColors.accent, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manual.title,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  manual.subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.3,
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

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;
  final bool highlighted;
  final bool numbered;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.lines,
    this.highlighted = false,
    this.numbered = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlightedBackground =
        isDark ? AppColors.surface : AppColors.accentLight;
    final highlightedTitle = isDark ? AppColors.ink : const Color(0xFF0F2F4A);
    final highlightedText =
        isDark ? AppColors.textSecondary : const Color(0xFF31546D);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? highlightedBackground : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted
              ? AppColors.accent.withValues(alpha: 0.28)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: highlighted ? AppColors.accent : AppColors.ink,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: highlighted ? highlightedTitle : AppColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...lines.asMap().entries.map((entry) {
            final prefix = numbered ? '${entry.key + 1}. ' : '- ';
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(
                '$prefix${entry.value}',
                style: TextStyle(
                  color:
                      highlighted ? highlightedText : AppColors.textSecondary,
                  height: 1.35,
                  fontSize: 13.5,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final bool fromUser;
  final String? title;
  final String body;
  final List<_ChatAction> actions;

  const _ChatMessage({
    required this.fromUser,
    this.title,
    required this.body,
    this.actions = const [],
  });
}

class _ChatAction {
  final String label;
  final String? route;
  final String? prompt;

  const _ChatAction(this.label, this.route, this.prompt);
}

class _ManualDefinition {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String purpose;
  final String keyExample;
  final List<String> quickStart;
  final List<String> related;

  const _ManualDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.purpose,
    required this.keyExample,
    required this.quickStart,
    required this.related,
  });
}

_ManualDefinition? _manualById(String? id) {
  if (id == null || id.trim().isEmpty) return null;
  for (final manual in _manuals) {
    if (manual.id == id) return manual;
  }
  return null;
}

String _contextLine(AuthState auth) {
  final tenant = auth.tenantId?.trim();
  final seller = auth.sellerId?.trim();
  if (auth.isAdminGlobal && (tenant == null || tenant.isEmpty)) {
    return 'Contexto: Global. Para operar datos, elegí una empresa.';
  }
  if (seller != null && seller.isNotEmpty) {
    return 'Contexto: empresa $tenant y seller $seller. Las consultas se responden dentro de ese alcance.';
  }
  return 'Contexto: empresa ${tenant ?? 'seleccionada'} y todos los sellers permitidos.';
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n');
}

bool _hasAny(String text, List<String> terms) {
  return terms.any((term) => text.contains(_normalize(term)));
}

String _t(String locale, String es, String en, String pt) {
  switch (locale) {
    case 'en':
      return en;
    case 'pt':
      return pt;
    default:
      return es;
  }
}

const _manuals = [
  _ManualDefinition(
    id: 'dashboard',
    title: 'Manual Dashboard',
    subtitle: 'Indicadores por permisos, empresa y seller activo.',
    icon: Icons.dashboard_rounded,
    purpose:
        'Muestra el resumen operativo según el contexto elegido. Un usuario global debe elegir empresa para operar; un usuario con un seller queda acotado automáticamente.',
    keyExample:
        'Si entrás como vendedor, el dashboard muestra ventas y tareas del seller permitido. Si entrás como admin de empresa, podés ver la operación completa del tenant.',
    quickStart: [
      'Revisá el contexto activo en la barra superior.',
      'Elegí el dashboard de productos, ventas, compras, proyectos, marketing o almacenes.',
      'Usá actualizar cuando necesites refrescar métricas.',
      'Si un indicador no aparece, revisá permisos y alcance de seller.',
    ],
    related: [
      'IAM define permisos visibles.',
      'Organización define empresa y vendedores.',
      'Cada módulo aporta sus métricas propias.',
    ],
  ),
  _ManualDefinition(
    id: 'security',
    title: 'Manual Seguridad',
    subtitle: 'Usuarios, roles, invitaciones y accesos por empresa/seller.',
    icon: Icons.admin_panel_settings_rounded,
    purpose:
        'Administra quién entra, qué roles tiene y sobre qué empresa o vendedores puede operar. Usa IAM y permisos estables.',
    keyExample:
        'Un usuario de ALMICO puede tener acceso sólo al seller almico; un admin global puede elegir empresa, pero no debería operar datos sin contexto.',
    quickStart: [
      'Entrá en Usuarios para buscar, ver histórico o revisar accesos.',
      'Usá Invitaciones para crear un acceso nuevo con nombre, apellido, cargo, tenant, sellers y roles.',
      'En Roles & Accesos revisá permisos de cada rol antes de asignarlo.',
      'Si un usuario no ve un módulo, validá rol, tenant y sellerScope.',
    ],
    related: [
      'Todos los módulos dependen de permisos IAM.',
      'El selector de contexto usa tenant y seller del usuario.',
      'Auditoría registra cambios sensibles.',
    ],
  ),
  _ManualDefinition(
    id: 'organization',
    title: 'Manual Organización',
    subtitle: 'Empresas, sucursales, vendedores y datos base.',
    icon: Icons.business_rounded,
    purpose:
        'Define la estructura operativa: tenants, branches, sellers y datos que después usan ventas, compras, proyectos y marketing.',
    keyExample:
        'Una empresa puede operar con todos los sellers o con un seller puntual. Las sucursales sirven para agenda, salud, depósitos y operación territorial.',
    quickStart: [
      'Creá o editá empresa con código, nombre y estado.',
      'Agregá sucursales cuando haya sedes físicas o canales separados.',
      'Creá vendedores/sellers asociados a la empresa.',
      'Usá el contexto superior para operar dentro de la empresa correcta.',
    ],
    related: [
      'Clientes y proveedores dependen del tenant.',
      'Usuarios pueden tener acceso por seller.',
      'Marketing usa empresa/seller para campañas y métricas.',
    ],
  ),
  _ManualDefinition(
    id: 'customers',
    title: 'Manual Clientes',
    subtitle: 'Clientes por empresa y seller, contactos e historial.',
    icon: Icons.handshake_rounded,
    purpose:
        'Centraliza clientes para ventas, proyectos, marketing y atención. Cada operación usa referencia y snapshot para evitar dependencias frágiles.',
    keyExample:
        'Una cotización puede crear o seleccionar un cliente. El documento queda con snapshot del cliente para mantener trazabilidad aunque luego cambien sus datos.',
    quickStart: [
      'Elegí empresa desde el contexto operativo.',
      'Filtrá por nombre, documento, email o estado.',
      'Creá cliente con datos básicos y seller opcional.',
      'Revisá histórico antes de modificar datos comerciales sensibles.',
    ],
    related: [
      'Ventas usa clientes para cotizaciones.',
      'Marketing puede convertir leads en clientes.',
      'Proyectos usa cliente por referencia y snapshot.',
    ],
  ),
  _ManualDefinition(
    id: 'partners',
    title: 'Manual Proveedores',
    subtitle: 'Partners, proveedores, contactos, direcciones e historial.',
    icon: Icons.local_shipping_rounded,
    purpose:
        'Separa proveedores de la organización base para que compras, proyectos y presupuestos trabajen con partners dedicados.',
    keyExample:
        'Una solicitud de presupuesto consulta proveedores activos. El presupuesto guarda snapshot del proveedor para no depender de cambios posteriores.',
    quickStart: [
      'Elegí empresa desde el contexto operativo.',
      'Buscá proveedor por nombre, CUIT, email o estado.',
      'Creá proveedor con contacto y país para teléfonos.',
      'Usá histórico para auditar altas, bajas y cambios relevantes.',
    ],
    related: [
      'Compras consulta proveedores.',
      'Proyectos puede asignar proveedores por partida.',
      'Marketing puede captar proveedores para marketplaces.',
    ],
  ),
  _ManualDefinition(
    id: 'people',
    title: 'Manual Personas',
    subtitle: 'Personal interno, cargos y datos reutilizables.',
    icon: Icons.badge_rounded,
    purpose:
        'Administra personas internas: empleados, responsables, técnicos, administrativos y operadores. No mezcla pacientes ni clientes finales.',
    keyExample:
        'Un responsable de obra o comprador se carga como persona interna; un paciente pertenece al dominio Salud y un cliente al dominio Clientes.',
    quickStart: [
      'Creá persona con nombre, documento, contacto y cargo.',
      'Asociá empresa y estado.',
      'Usá histórico para revisar cambios.',
      'Usá cargos para ordenar responsabilidades internas.',
    ],
    related: [
      'Proyectos usa responsables.',
      'Agenda puede usar recursos humanos.',
      'Salud especializa profesionales médicos aparte.',
    ],
  ),
  _ManualDefinition(
    id: 'products',
    title: 'Manual Productos',
    subtitle: 'Catálogo, SKU, precios, imágenes y presentaciones.',
    icon: Icons.inventory_2_rounded,
    purpose:
        'Mantiene el catálogo maestro que consumen ventas, compras, obras, almacenes, marketing y sitios públicos.',
    keyExample:
        'Un artículo como Tafeta tiene SKU, imágenes, precio, atributos y presentaciones. El sitio público usa ese catálogo para mostrar productos y armar carritos de cotización.',
    quickStart: [
      'Creá o importá artículos.',
      'Completá SKU, nombre, tipo, marca y unidad.',
      'Cargá precios, imágenes y presentaciones.',
      'Marcá estado, web, destacado o condiciones de almacenamiento si aplica.',
      'Usá el artículo desde Ventas, Compras, Obras o sitios públicos.',
    ],
    related: [
      'Ventas usa productos para cotizar.',
      'Almacenes controla stock físico.',
      'Marketing mide vistas, likes y productos destacados.',
    ],
  ),
  _ManualDefinition(
    id: 'sales',
    title: 'Manual Ventas',
    subtitle: 'Cotizaciones públicas y manuales para clientes.',
    icon: Icons.request_quote_rounded,
    purpose:
        'Centraliza cotizaciones, ítems, totales, vencimientos y canales de envío para transformar consultas en oportunidades vendibles.',
    keyExample:
        'Si un cliente pide precio por productos, Ventas arma la cotización, calcula totales y la comparte. Si falta validar costo, puede generar una solicitud para Compras.',
    quickStart: [
      'Entrá en Ventas y presioná Nueva.',
      'Elegí o cargá el cliente.',
      'Agregá artículos o ítems manuales.',
      'Revisá totales, vigencia y notas.',
      'Compartí por link, PDF, email o WhatsApp.',
    ],
    related: [
      'Productos aporta catálogo, precios e imágenes.',
      'Compras valida costos pendientes.',
      'Clientes mantiene datos comerciales.',
    ],
  ),
  _ManualDefinition(
    id: 'purchases',
    title: 'Manual Compras',
    subtitle: 'Solicitud de precios, comparativa y adjudicación.',
    icon: Icons.assignment_turned_in_rounded,
    purpose:
        'Permite pedir precios a proveedores, comparar respuestas y adjudicar la mejor opción con trazabilidad por empresa.',
    keyExample:
        'Si una cotización o una obra necesita saber cuánto cuesta un insumo, Compras arma la solicitud, consulta proveedores, compara respuestas y deja trazabilidad.',
    quickStart: [
      'Creá la solicitud o revisá la que nace desde Ventas/Obras.',
      'Agregá productos o ítems manuales.',
      'Seleccioná proveedores.',
      'Cargá o recibí respuestas.',
      'Compará importes, condiciones y adjudicá.',
    ],
    related: [
      'Ventas puede disparar una compra cuando falta validar costo.',
      'Obras usa compras para presupuestos de insumos.',
      'Proveedores mantiene contactos y direcciones.',
    ],
  ),
  _ManualDefinition(
    id: 'projects',
    title: 'Manual Obras y Proyectos',
    subtitle: 'Alcance, presupuesto, recursos, propuesta y avance.',
    icon: Icons.engineering_rounded,
    purpose:
        'Ordena una obra desde el alta comercial hasta el seguimiento operativo, con cliente, responsable, template, recursos, presupuesto y costos reales.',
    keyExample:
        'Una reforma de local puede tener cliente, responsable, template, recursos, presupuesto, propuesta pública, avances y costos reales.',
    quickStart: [
      'Creá la obra con empresa, cliente, responsable y tipo.',
      'Elegí un template o agregá partidas manuales.',
      'Cargá recursos, cantidades y precios estimados.',
      'Generá presupuesto o propuesta para compartir.',
      'Registrá avances y costos reales para comparar contra lo previsto.',
    ],
    related: [
      'Productos define artículos y presentaciones.',
      'Compras consulta proveedores cuando falta costo validado.',
      'Clientes mantiene la relación comercial.',
    ],
  ),
  _ManualDefinition(
    id: 'integral-projects',
    title: 'Manual Proyectos integrales',
    subtitle: 'Servicios, hitos, recursos, costos y entregables.',
    icon: Icons.account_tree_rounded,
    purpose:
        'Gestiona proyectos de servicio o implementación que no son obra física: etapas, recursos, costos, avances y entregables.',
    keyExample:
        'Una integración entre sistemas puede dividirse en relevamiento, desarrollo, pruebas y puesta en marcha, con responsables y costos por etapa.',
    quickStart: [
      'Creá el proyecto integral con cliente, tipo y responsable.',
      'Seleccioná template si existe.',
      'Cargá hitos, recursos y costos estimados.',
      'Registrá avances, desvíos y entregables.',
      'Usá dashboard para controlar margen esperado.',
    ],
    related: [
      'Clientes define destinatario.',
      'Productos puede aportar licencias o insumos.',
      'Marketing puede originar leads de servicios.',
    ],
  ),
  _ManualDefinition(
    id: 'marketing',
    title: 'Manual Marketing',
    subtitle: 'Campañas, leads, formularios, bots y protección antiabuso.',
    icon: Icons.campaign_rounded,
    purpose:
        'Mide interacción pública, captura leads, organiza campañas y protege bots/formularios de spam o abuso.',
    keyExample:
        'Un sitio público puede enviar eventos de vista, clicks, productos, formularios y conversaciones de bot. Marketing consolida métricas por campaña.',
    quickStart: [
      'Creá campaña o revisá una automática.',
      'Configurá formulario, bot, productos destacados y protección.',
      'Publicá la key en el sitio externo.',
      'Revisá eventos, leads y conversiones.',
      'Ajustá reglas antiabuso si hay spam o uso anómalo.',
    ],
    related: [
      'Sitios públicos envían eventos.',
      'Clientes puede recibir conversiones.',
      'AI Orchestrator puede alimentar bots con KB curada.',
    ],
  ),
  _ManualDefinition(
    id: 'notifications',
    title: 'Manual Notificaciones',
    subtitle: 'Centro, plantillas, variables y perfiles de envío.',
    icon: Icons.notifications_rounded,
    purpose:
        'Administra mensajes operativos y comerciales por canal, con plantillas reutilizables y trazabilidad.',
    keyExample:
        'Una confirmación de turno o una cotización ganada puede disparar notificación al usuario, al cliente o a un equipo específico.',
    quickStart: [
      'Revisá el centro de notificaciones.',
      'Creá o ajustá plantillas.',
      'Configurá variables y perfiles de envío.',
      'Validá logs si un mensaje no llega.',
    ],
    related: [
      'Agenda usa confirmaciones y ausentismo.',
      'Ventas puede notificar cotizaciones.',
      'Marketing puede alertar nuevos leads.',
    ],
  ),
  _ManualDefinition(
    id: 'warehouse',
    title: 'Manual Almacenes',
    subtitle: 'Depósitos, stock, movimientos y operaciones.',
    icon: Icons.warehouse_rounded,
    purpose:
        'Controla depósitos, existencias, movimientos y operaciones logísticas básicas por empresa.',
    keyExample:
        'Un producto puede estar disponible en una sucursal y sin stock en otra. Almacenes permite ver existencias y registrar movimientos.',
    quickStart: [
      'Creá depósitos y tipos.',
      'Revisá stock por producto.',
      'Registrá movimientos cuando entra o sale mercadería.',
      'Usá operaciones para transferencias, reservas o reglas de reposición.',
    ],
    related: [
      'Productos define artículos.',
      'Ventas consulta disponibilidad.',
      'Compras repone stock.',
    ],
  ),
  _ManualDefinition(
    id: 'appointments',
    title: 'Manual Agenda',
    subtitle: 'Servicios agendables, recursos, disponibilidad y turnos.',
    icon: Icons.event_available_rounded,
    purpose:
        'Gestiona turnos genéricos para peluquería, soporte, retiro en sede, trámites o cualquier servicio reservable.',
    keyExample:
        'Una peluquería puede crear servicios, peluqueros como recursos, disponibilidad por sede y turnos públicos sin cuenta obligatoria.',
    quickStart: [
      'Definí servicios agendables.',
      'Creá recursos: persona, equipamiento o sucursal.',
      'Cargá disponibilidad por día y franja.',
      'Buscá slots, elegí día y horario.',
      'Confirmá, cancelá, marcá realizado o no asistió.',
    ],
    related: [
      'Salud especializa agenda médica.',
      'Clientes permite cliente liviano.',
      'Notificaciones confirma y reconfirma turnos.',
    ],
  ),
  _ManualDefinition(
    id: 'health',
    title: 'Manual Salud',
    subtitle: 'Pacientes, profesionales, seguros, estudios y agenda médica.',
    icon: Icons.health_and_safety_rounded,
    purpose:
        'Especializa la agenda para entidades de salud: pacientes, historia clínica, profesionales, coberturas, estudios, scoring y recomendaciones.',
    keyExample:
        'Una mamografía puede requerir paciente, cobertura, sede, estudio, equipamiento, profesional/técnico, scoring y reglas de recomendación por edad o sexo.',
    quickStart: [
      'Creá pacientes con datos de contacto y cobertura.',
      'Administrá profesionales, especialidades, equipos y equipamiento.',
      'Configurá estudios, CIE10, seguros y planes.',
      'Usá agenda médica para calcular slots por motivo, cobertura y prioridad.',
      'Registrá historia clínica y cierre de atención.',
    ],
    related: [
      'Agenda aporta motor de turnos.',
      'Clientes puede contener identidad comercial.',
      'Notificaciones gestiona confirmación, reconfirmación y ausentismo.',
    ],
  ),
  _ManualDefinition(
    id: 'configuration',
    title: 'Manual Configuración',
    subtitle: 'Parámetros, países, monedas, toggles y maestros base.',
    icon: Icons.settings_rounded,
    purpose:
        'Agrupa configuraciones transversales que afectan a todo el ecosistema: parámetros, idiomas, monedas, países, estados, ciudades y toggles.',
    keyExample:
        'corsAllowedOrigins o una feature flag no pertenecen a un módulo funcional: se administran como parámetros o toggles transversales.',
    quickStart: [
      'Revisá parámetros antes de hardcodear comportamientos.',
      'Usá países/estados/ciudades para formularios consistentes.',
      'Configurá toggles para activar funcionalidades por ambiente.',
      'Auditá cambios porque impactan en varias APIs.',
    ],
    related: [
      'Gateway usa parámetros de ecosistema.',
      'Organización y contactos usan geografía.',
      'Todos los módulos pueden depender de toggles.',
    ],
  ),
  _ManualDefinition(
    id: 'ai-orchestrator',
    title: 'Manual AI Orchestrator',
    subtitle: 'Proyectos IA, memoria segura, KB y configuración por empresa.',
    icon: Icons.auto_awesome_rounded,
    purpose:
        'Define cómo el asistente usa manuales, permisos, herramientas, memoria y conocimiento curado sin mezclar empresas ni usuarios.',
    keyExample:
        'Si un usuario pregunta cómo generar una propuesta de obra, el asistente combina manual de Obras, permisos, empresa activa y KB curada. Si aprende una regla de una empresa, esa memoria queda asociada a esa empresa.',
    quickStart: [
      'Mantené globales los proyectos base y reglas comunes.',
      'Creá proyecto por empresa cuando haya memoria, tono, límites o integraciones propias.',
      'Guardá memoria privada por empresa, usuario y conversación.',
      'Promové a global solo reglas validadas por un admin.',
      'Medí consumo de tokens por conversación, usuario y empresa.',
    ],
    related: [
      'Manuales aportan contexto funcional.',
      'IAM limita herramientas y visibilidad.',
      'Backoffice usa el tenant activo para separar memoria y configuración.',
    ],
  ),
];
