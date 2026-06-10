import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/confirm_dialog.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QuoteDto {
  final String id;
  final String number;
  final String status;
  final String? publicToken;
  final String? sellerName;
  final String customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? source;
  final String? notes;
  final String currency;
  final double total;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final List<QuoteItemDto> items;

  const QuoteDto({
    required this.id,
    required this.number,
    required this.status,
    this.publicToken,
    this.sellerName,
    required this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.source,
    this.notes,
    required this.currency,
    required this.total,
    this.createdAt,
    this.expiresAt,
    required this.items,
  });

  factory QuoteDto.fromJson(Map<String, dynamic> json) {
    final first = (json['customerFirstName'] ?? '').toString().trim();
    final last = (json['customerLastName'] ?? '').toString().trim();
    final fullName = [
      if (first.isNotEmpty) first,
      if (last.isNotEmpty) last,
    ].join(' ');
    final rawItems = (json['items'] as List?) ?? const [];
    return QuoteDto(
      id: (json['quoteId'] ?? json['id'] ?? '').toString(),
      number: (json['quoteNumber'] ?? json['number'] ?? '').toString(),
      status: (json['status'] ?? 'DRAFT').toString(),
      publicToken: json['publicToken']?.toString(),
      sellerName: json['sellerName']?.toString(),
      customerName: fullName.isNotEmpty ? fullName : 'Cliente sin nombre',
      customerEmail: _nonEmpty(json['customerEmail']),
      customerPhone: _nonEmpty(json['customerPhone']),
      source: _nonEmpty(json['source']),
      notes: _nonEmpty(json['notes']),
      currency: (json['currencyCode'] ?? json['currency'] ?? 'ARS').toString(),
      total: _parseDouble(json['totalAmount'] ?? json['total']),
      createdAt: _parseDate(json['createdDate'] ?? json['createdAt']),
      expiresAt: _parseDate(json['expiresAt'] ?? json['validUntil']),
      items: rawItems
          .map((item) => QuoteItemDto.fromJson(
                item is Map<String, dynamic>
                    ? item
                    : Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
    );
  }

  bool get hasPublicLink =>
      publicToken != null && publicToken!.trim().isNotEmpty && status == 'SENT';

  String get publicUrl =>
      'https://backoffice.diceprojects.com/public/quotes/${publicToken ?? ''}';

  static String? _nonEmpty(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static DateTime? _parseDate(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}

class QuoteItemDto {
  final String productName;
  final String? sku;
  final String? color;
  final String? presentation;
  final String? purchaseMode;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double lineTotal;

  const QuoteItemDto({
    required this.productName,
    this.sku,
    this.color,
    this.presentation,
    this.purchaseMode,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory QuoteItemDto.fromJson(Map<String, dynamic> json) => QuoteItemDto(
        productName: (json['productName'] ?? json['name'] ?? 'Producto')
            .toString(),
        sku: json['sku']?.toString(),
        color: json['color']?.toString(),
        presentation: json['presentation']?.toString(),
        purchaseMode: json['purchaseMode']?.toString(),
        quantity: QuoteDto._parseDouble(json['quantity']),
        unit: (json['unit'] ?? 'U').toString(),
        unitPrice: QuoteDto._parseDouble(json['unitPrice']),
        lineTotal: QuoteDto._parseDouble(json['lineTotal'] ?? json['total']),
      );
}

class QuotesNotifier extends ListNotifier<QuoteDto> {
  final Dio _dio;
  String? _status;

  QuotesNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<QuoteDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/quotes',
      queryParameters: {
        ...params.toQueryParams(),
        if (_status != null && _status!.isNotEmpty) 'status': _status,
      },
    );
    return PaginatedResponse.fromJson(resp.data, QuoteDto.fromJson);
  }

  void setStatus(String? status) {
    _status = status;
    loadPage(0);
  }

  Future<void> updateStatus(QuoteDto quote, String status) async {
    await _dio.patch(
      '/v1/quotes/${quote.id}/status',
      data: {'status': status},
    );
    reload();
  }

  Future<void> delete(QuoteDto quote) async {
    await _dio.delete('/v1/quotes/${quote.id}');
    reload();
  }
}

final quotesNotifierProvider =
    StateNotifierProvider.autoDispose<QuotesNotifier, ListState<QuoteDto>>(
  (ref) => QuotesNotifier(ref.watch(dioProvider)),
);

class QuotesScreen extends ConsumerWidget {
  const QuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quotesNotifierProvider);
    final notifier = ref.read(quotesNotifierProvider.notifier);
    final perms = ref.watch(permissionsProvider);
    final canCreate =
        perms.hasAnyPermission(['Sales.Quotes.Create', 'Sales.Admin']);

    return AppPageScaffold(
      title: 'Cotizaciones',
      searchHint: 'Buscar cliente o número…',
      onSearch: notifier.setSearch,
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: notifier.reload,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateSoon(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva'),
            )
          : null,
      body: Column(
        children: [
          _StatusFilters(onChanged: notifier.setStatus),
          Expanded(child: _QuotesBody(state: state, notifier: notifier)),
        ],
      ),
    );
  }

  void _showCreateSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alta manual: usar web hasta cerrar el formulario móvil.'),
      ),
    );
  }
}

class _StatusFilters extends StatefulWidget {
  final ValueChanged<String?> onChanged;

  const _StatusFilters({required this.onChanged});

  @override
  State<_StatusFilters> createState() => _StatusFiltersState();
}

class _StatusFiltersState extends State<_StatusFilters> {
  String? _selected;
  static const _items = <String?>[
    null,
    'DRAFT',
    'SENT',
    'ANSWERED',
    'WON',
    'LOST',
    'EXPIRED',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) {
          final value = _items[index];
          final active = value == _selected;
          return ChoiceChip(
            selected: active,
            label: Text(value == null ? 'Todas' : _statusLabel(value)),
            onSelected: (_) {
              setState(() => _selected = value);
              widget.onChanged(value);
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _items.length,
      ),
    );
  }
}

class _QuotesBody extends ConsumerWidget {
  final ListState<QuoteDto> state;
  final QuotesNotifier notifier;

  const _QuotesBody({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar las cotizaciones',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.request_quote_outlined,
        title: 'Sin cotizaciones',
        message: 'No hay solicitudes para los filtros seleccionados.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => notifier.reload(),
      child: NotificationListener<ScrollNotification>(
        onNotification: notifier.onScrollNotification,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 92),
          itemBuilder: (_, index) {
            if (index == state.items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LoadingState(asSkeleton: false),
              );
            }
            return _QuoteCard(quote: state.items[index]);
          },
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        ),
      ),
    );
  }
}

class _QuoteCard extends ConsumerWidget {
  final QuoteDto quote;

  const _QuoteCard({required this.quote});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openDetail(context, ref),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      quote.number.isEmpty ? 'Cotización' : quote.number,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  StatusBadge(status: quote.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                quote.customerName,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (quote.sellerName != null) quote.sellerName,
                  if (quote.createdAt != null) _formatDate(quote.createdAt!),
                ].whereType<String>().join(' · '),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniMetric(label: 'Items', value: '${quote.items.length}'),
                  const SizedBox(width: 8),
                  _MiniMetric(label: 'Origen', value: quote.source ?? '-'),
                  const Spacer(),
                  Text(
                    _money(quote.total, quote.currency),
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _QuoteDetailSheet(quote: quote),
    );
  }
}

class _QuoteDetailSheet extends ConsumerStatefulWidget {
  final QuoteDto quote;

  const _QuoteDetailSheet({required this.quote});

  @override
  ConsumerState<_QuoteDetailSheet> createState() => _QuoteDetailSheetState();
}

class _QuoteDetailSheetState extends ConsumerState<_QuoteDetailSheet> {
  late String _status = widget.quote.status;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider);
    final canStatus =
        perms.hasAnyPermission(['Sales.Quotes.Status', 'Sales.Admin']);
    final canDelete =
        perms.hasAnyPermission(['Sales.Quotes.Delete', 'Sales.Admin']);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.96,
      minChildSize: 0.55,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.quote.number,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      widget.quote.customerName,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _money(widget.quote.total, widget.quote.currency),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _CustomerPanel(quote: widget.quote),
          if (widget.quote.expiresAt != null) ...[
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.event_available_rounded,
              label: 'Vigencia',
              value: _formatDate(widget.quote.expiresAt!),
            ),
          ],
          const SizedBox(height: 18),
          if (canStatus) ...[
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: const ['DRAFT', 'SENT', 'ANSWERED', 'WON', 'LOST']
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(_statusLabel(status)),
                    ),
                  )
                  .toList(),
              onChanged: _saving ? null : (value) => setState(() {
                if (value != null) _status = value;
              }),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving || _status == widget.quote.status
                    ? null
                    : _saveStatus,
                icon: const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Guardando...' : 'Guardar estado'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Items cotizados',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in widget.quote.items) ...[
            _QuoteItemCard(item: item, currency: widget.quote.currency),
            const SizedBox(height: 10),
          ],
          if (widget.quote.notes != null) ...[
            const SizedBox(height: 8),
            _NotesPanel(notes: widget.quote.notes!),
          ],
          const SizedBox(height: 14),
          if (widget.quote.hasPublicLink)
            _PublicQrPanel(url: widget.quote.publicUrl)
          else
            _LockedLinkPanel(status: widget.quote.status),
          if (canDelete) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _deleteQuote,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Eliminar cotización'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveStatus() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(quotesNotifierProvider.notifier)
          .updateStatus(widget.quote, _status);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteQuote() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Eliminar cotización',
      message: 'Se ocultará de la operación diaria. ¿Querés continuar?',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed) return;
    setState(() => _saving = true);
    try {
      await ref.read(quotesNotifierProvider.notifier).delete(widget.quote);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _CustomerPanel extends StatelessWidget {
  final QuoteDto quote;

  const _CustomerPanel({required this.quote});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.person_rounded,
            label: 'Cliente',
            value: quote.customerName,
          ),
          if (quote.customerPhone != null)
            _InfoRow(
              icon: Icons.phone_rounded,
              label: 'Teléfono',
              value: quote.customerPhone!,
            ),
          if (quote.customerEmail != null)
            _InfoRow(
              icon: Icons.mail_rounded,
              label: 'Email',
              value: quote.customerEmail!,
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: AppColors.ink, fontSize: 12.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteItemCard extends StatelessWidget {
  final QuoteItemDto item;
  final String currency;

  const _QuoteItemCard({required this.item, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _money(item.lineTotal, currency),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (item.sku != null) ...[
            const SizedBox(height: 2),
            Text(
              item.sku!,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill('Color', item.color ?? '-'),
              _Pill('Presentación', item.presentation ?? '-'),
              _Pill('Cantidad', '${_qty(item.quantity)} ${item.unit}'),
              _Pill('Modo', _purchaseModeLabel(item.purchaseMode)),
              _Pill('Unitario', _money(item.unitPrice, currency)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;

  const _Pill(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: AppColors.ink,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PublicQrPanel extends StatelessWidget {
  final String url;

  const _PublicQrPanel({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 94,
            height: 94,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: QrImageView(data: url),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aprobar online',
                  style: TextStyle(
                    color: AppColors.accentDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'QR habilitado porque la cotización está enviada.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copiado')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copiar link'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedLinkPanel extends StatelessWidget {
  final String status;

  const _LockedLinkPanel({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'El link público y QR se habilitan cuando la cotización está enviada.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesPanel extends StatelessWidget {
  final String notes;

  const _NotesPanel({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        notes,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'DRAFT':
      return 'Borrador';
    case 'SENT':
      return 'Enviada';
    case 'ANSWERED':
      return 'A revisar';
    case 'WON':
      return 'Ganada';
    case 'LOST':
      return 'Perdida';
    case 'EXPIRED':
      return 'Vencida';
    default:
      return status;
  }
}

String _purchaseModeLabel(String? value) {
  switch (value) {
    case 'WHOLESALE':
      return 'Por mayor';
    case 'RETAIL':
      return 'Por menor';
    case 'PENDING':
      return 'Pendiente';
    default:
      return value ?? '-';
  }
}

String _formatDate(DateTime date) => DateFormat('dd/MM/yyyy HH:mm').format(date);

String _money(double value, String currency) {
  final format = NumberFormat.currency(
    locale: 'es_AR',
    symbol: currency == 'ARS' ? r'$' : '$currency ',
    decimalDigits: 2,
  );
  return format.format(value);
}

String _qty(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}
