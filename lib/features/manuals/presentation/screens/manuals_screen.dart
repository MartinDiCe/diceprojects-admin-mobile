import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ManualsScreen extends StatelessWidget {
  final String? moduleId;

  const ManualsScreen({super.key, this.moduleId});

  @override
  Widget build(BuildContext context) {
    final manual = _manualById(moduleId);

    if (manual == null) {
      return AppPageScaffold(
        title: 'Manuales de uso',
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
            title: 'Para que sirve',
            lines: [manual.purpose],
          ),
          _SectionCard(
            icon: Icons.lightbulb_rounded,
            title: 'Ejemplo clave',
            lines: [manual.keyExample],
            highlighted: true,
          ),
          _SectionCard(
            icon: Icons.checklist_rounded,
            title: 'Pasos habituales',
            lines: manual.quickStart,
            numbered: true,
          ),
          _SectionCard(
            icon: Icons.link_rounded,
            title: 'Se relaciona con',
            lines: manual.related,
          ),
        ],
      ),
    );
  }
}

class ChatComingSoonScreen extends StatelessWidget {
  const ChatComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Chat IA',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    color: AppColors.accent,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Chat IA disponible proximamente',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'La APK ya muestra el acceso para dejar preparada la navegacion. El uso queda deshabilitado hasta activar el asistente por tenant y permisos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => context.go('/dashboard'),
                  icon: const Icon(Icons.dashboard_rounded),
                  label: const Text('Volver al inicio'),
                ),
              ],
            ),
          ),
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
              Icon(icon,
                  color: highlighted ? AppColors.accent : AppColors.ink,
                  size: 20),
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
            final prefix = numbered ? '${entry.key + 1}. ' : '• ';
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

const _manuals = [
  _ManualDefinition(
    id: 'projects',
    title: 'Manual Obras y Proyectos',
    subtitle: 'Alcance, presupuesto, recursos, propuesta y avance de obra.',
    icon: Icons.engineering_rounded,
    purpose:
        'Ordena una obra desde el alta comercial hasta el seguimiento operativo, con cliente, responsable, template, recursos, presupuesto y costos reales.',
    keyExample:
        'Una reforma de local puede tener cliente, responsable, template, recursos, presupuesto, propuesta publica, avances y costos reales; Productos mantiene articulos y Compras pide precios cuando falta validar insumos.',
    quickStart: [
      'Creá la obra con empresa, cliente, responsable y tipo.',
      'Elegí un template o agregá partidas manuales.',
      'Cargá recursos, cantidades y precios estimados.',
      'Generá presupuesto o propuesta para compartir.',
      'Registrá avances y costos reales para comparar contra lo previsto.',
    ],
    related: [
      'Productos define articulos y presentaciones.',
      'Compras consulta proveedores cuando falta costo validado.',
      'Ventas puede convertir o acompañar oportunidades comerciales.',
    ],
  ),
  _ManualDefinition(
    id: 'purchases',
    title: 'Manual Compras',
    subtitle: 'Solicitud de precios, comparativa y adjudicacion.',
    icon: Icons.assignment_turned_in_rounded,
    purpose:
        'Permite pedir precios a proveedores, comparar respuestas y adjudicar la mejor opcion con trazabilidad por tenant.',
    keyExample:
        'Si una cotizacion o una obra necesita saber cuanto cuesta un insumo, Compras arma la solicitud, consulta proveedores, compara respuestas y deja trazabilidad de la adjudicacion.',
    quickStart: [
      'Creá la solicitud o revisá la que nace desde Ventas/Obras.',
      'Agregá productos o items manuales.',
      'Seleccioná proveedores.',
      'Cargá o recibí respuestas.',
      'Compará importes, condiciones y adjudicá.',
    ],
    related: [
      'Ventas puede disparar una compra cuando falta validar costo.',
      'Obras usa compras para presupuestos de insumos.',
      'Organizacion mantiene proveedores y contactos.',
    ],
  ),
  _ManualDefinition(
    id: 'sales',
    title: 'Manual Ventas',
    subtitle: 'Cotizaciones publicas y manuales para clientes.',
    icon: Icons.request_quote_rounded,
    purpose:
        'Centraliza cotizaciones, items, totales, vencimientos y canales de envio para transformar consultas en oportunidades vendibles.',
    keyExample:
        'Si un cliente pide precio por productos, Ventas arma la cotizacion, calcula totales y la comparte; si falta validar costo, puede generar una solicitud para Compras sin frenar la venta.',
    quickStart: [
      'Entrá en Ventas y presioná Nueva.',
      'Elegí o cargá el cliente.',
      'Agregá articulos o items manuales.',
      'Revisá totales, vigencia y notas.',
      'Compartí por link, PDF, email o WhatsApp.',
    ],
    related: [
      'Productos aporta catalogo, precios e imagenes.',
      'Compras valida costos pendientes.',
      'Organizacion define clientes y vendedores.',
    ],
  ),
  _ManualDefinition(
    id: 'products',
    title: 'Manual Productos',
    subtitle: 'Catalogo, SKU, precios, imagenes y presentaciones.',
    icon: Icons.inventory_2_rounded,
    purpose:
        'Mantiene el catalogo maestro que consumen ventas, compras, obras, almacenes y marketing.',
    keyExample:
        'Un articulo como Griferia modelo X vive en Productos con SKU, precio, imagen y unidad; si se usa en una obra, Proyectos lo referencia, pero el catalogo se mantiene aca.',
    quickStart: [
      'Creá o importá articulos.',
      'Completá SKU, nombre, tipo, marca y unidad.',
      'Cargá precios, imagenes y presentaciones.',
      'Marcá estado, destacado o condiciones de almacenamiento si aplica.',
      'Usá el articulo desde Ventas, Compras u Obras.',
    ],
    related: [
      'Ventas usa productos para cotizar.',
      'Almacenes controla stock fisico.',
      'Marketing puede destacar productos publicados.',
    ],
  ),
  _ManualDefinition(
    id: 'ai-orchestrator',
    title: 'Manual AI Orchestrator',
    subtitle: 'Proyectos IA, memoria segura y configuración por empresa.',
    icon: Icons.auto_awesome_rounded,
    purpose:
        'Define como el asistente usa manuales, permisos, herramientas, memoria y conocimiento curado sin mezclar empresas ni usuarios.',
    keyExample:
        'Si un usuario pregunta como generar una propuesta de obra, el asistente combina manual de Obras, permisos, empresa activa y conocimiento curado; si aprende una regla de una empresa, esa memoria queda asociada a esa empresa, no global.',
    quickStart: [
      'Mantené globales los proyectos base y reglas comunes.',
      'Creá proyecto por empresa cuando haya memoria, tono, limites o integraciones propias.',
      'Guardá memoria privada por empresa, usuario y conversación.',
      'Promové a global solo reglas validadas por un admin.',
      'Medí consumo de tokens por conversacion, usuario y empresa.',
    ],
    related: [
      'Manuales aportan contexto funcional.',
      'IAM limita herramientas y visibilidad.',
      'Backoffice usa el tenant activo para separar memoria y configuracion.',
    ],
  ),
];
