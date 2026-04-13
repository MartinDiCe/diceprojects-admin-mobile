import 'package:app_diceprojects_admin/core/errors/error_handler.dart';
import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────── Models ─────────────────────────

class _CatOption {
  final String code;
  final String name;
  const _CatOption({required this.code, required this.name});
}

class _PresentationDto {
  final String id;
  final String sku;
  final String? barcode;
  final String presentationTypeCode;
  final String uomCode;
  final double conversionFactor;
  final double? basePrice;
  final bool isDefault;
  final bool active;
  final bool hasMovements;

  const _PresentationDto({
    required this.id,
    required this.sku,
    this.barcode,
    required this.presentationTypeCode,
    required this.uomCode,
    required this.conversionFactor,
    this.basePrice,
    required this.isDefault,
    required this.active,
    required this.hasMovements,
  });

  factory _PresentationDto.fromJson(Map<String, dynamic> json) =>
      _PresentationDto(
        id: json['presentationId']?.toString() ?? '',
        sku: json['sku']?.toString() ?? '',
        barcode: json['barcode']?.toString(),
        presentationTypeCode: json['presentationTypeCode']?.toString() ?? '',
        uomCode: json['uomCode']?.toString() ?? '',
        conversionFactor: (json['conversionFactor'] as num?)?.toDouble() ?? 1.0,
        basePrice: (json['basePrice'] as num?)?.toDouble(),
        isDefault: json['isDefault'] == true,
        active: json['active'] == true,
        hasMovements: json['hasMovements'] == true,
      );
}

// ────────────────────────────── Catalog providers ───────────────────────────

final _presTypesProvider =
    FutureProvider.autoDispose<List<_CatOption>>((ref) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get('/v1/presentation-types');
  final list = resp.data is List ? resp.data as List : [];
  return list
      .map((e) => _CatOption(
            code: e['code']?.toString() ?? '',
            name: e['name']?.toString() ?? '',
          ))
      .where((o) => o.code.isNotEmpty)
      .toList();
});

final _uomListProvider =
    FutureProvider.autoDispose<List<_CatOption>>((ref) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get('/v1/unit-of-measure');
  final list = resp.data is List ? resp.data as List : [];
  return list
      .map((e) => _CatOption(
            code: e['code']?.toString() ?? '',
            name: '${e["name"] ?? ""} (${e["code"] ?? ""})',
          ))
      .where((o) => o.code.isNotEmpty)
      .toList();
});

// ─────────────────────────────────────────── Screen ─────────────────────────

class ProductPresentationsScreen extends ConsumerStatefulWidget {
  final String productId;
  final String? productName;

  const ProductPresentationsScreen({
    super.key,
    required this.productId,
    this.productName,
  });

  @override
  ConsumerState<ProductPresentationsScreen> createState() =>
      _ProductPresentationsScreenState();
}

class _ProductPresentationsScreenState
    extends ConsumerState<ProductPresentationsScreen> {
  List<_PresentationDto> _presentations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final resp =
          await dio.get('/v1/products/${widget.productId}/presentations');
      final list = resp.data is List ? resp.data as List : [];
      setState(() {
        _presentations =
            list.map((e) => _PresentationDto.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = ErrorHandler.handle(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _delete(_PresentationDto pr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar presentación'),
        content: Text('¿Eliminar la presentación SKU: ${pr.sku}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.delete(
          '/v1/products/${widget.productId}/presentations/${pr.id}');
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ErrorHandler.handle(e).message),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openForm({_PresentationDto? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PresentationFormSheet(
        productId: widget.productId,
        existing: existing,
        onSaved: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title:
          widget.productName != null ? 'Presentaciones' : 'Presentaciones',
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: () => _openForm(),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_error != null && _presentations.isEmpty) {
      return ErrorState(
        title: 'Error al cargar presentaciones',
        message: _error!,
        onRetry: _load,
      );
    }
    if (_presentations.isEmpty) {
      return const EmptyState(
        icon: Icons.view_module_rounded,
        title: 'Sin presentaciones',
        message: 'Agregá la primera presentación con el botón +',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: _presentations.length,
        itemBuilder: (ctx, i) => _PresentationCard(
          item: _presentations[i],
          onEdit: () => _openForm(existing: _presentations[i]),
          onDelete: () => _delete(_presentations[i]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────── Card ───────────────────────────────

class _PresentationCard extends StatelessWidget {
  final _PresentationDto item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PresentationCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.sku,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                if (item.isDefault)
                  _Chip('Default', Colors.green.shade700,
                      Colors.green.shade50),
                if (!item.active)
                  _Chip('Inactiva', Colors.grey.shade600, Colors.grey.shade100),
                if (item.hasMovements)
                  _Chip('Con movimientos', Colors.orange.shade700,
                      Colors.orange.shade50),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${item.presentationTypeCode} · ${item.uomCode} · x${item.conversionFactor}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (item.barcode != null)
              Text(
                'Barcode: ${item.barcode}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            if (item.basePrice != null)
              Text(
                'Precio base: \$${item.basePrice!.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Editar'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4)),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Eliminar'),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  const _Chip(this.label, this.fg, this.bg);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      );
}

// ─────────────────────────────── Bottom Sheet Form ──────────────────────────

class _PresentationFormSheet extends ConsumerStatefulWidget {
  final String productId;
  final _PresentationDto? existing;
  final VoidCallback onSaved;

  const _PresentationFormSheet({
    required this.productId,
    this.existing,
    required this.onSaved,
  });

  @override
  ConsumerState<_PresentationFormSheet> createState() =>
      _PresentationFormSheetState();
}

class _PresentationFormSheetState
    extends ConsumerState<_PresentationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _skuCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _factorCtrl;
  late final TextEditingController _priceCtrl;

  String? _presentationTypeCode;
  String? _uomCode;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;
  bool get _hasMovements => widget.existing?.hasMovements == true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _skuCtrl = TextEditingController(text: e?.sku ?? '');
    _barcodeCtrl = TextEditingController(text: e?.barcode ?? '');
    _factorCtrl =
        TextEditingController(text: e?.conversionFactor.toString() ?? '1');
    _priceCtrl = TextEditingController(
        text: e?.basePrice != null ? e!.basePrice!.toString() : '');
    _presentationTypeCode = e?.presentationTypeCode;
    _uomCode = e?.uomCode;
  }

  @override
  void dispose() {
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _factorCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(
      List<_CatOption> presTypes, List<_CatOption> uomList) async {
    if (!_formKey.currentState!.validate()) return;

    // Auto-pick first option if not yet selected
    final typeCode =
        _presentationTypeCode ?? (presTypes.isNotEmpty ? presTypes.first.code : '');
    final uomCode =
        _uomCode ?? (uomList.isNotEmpty ? uomList.first.code : '');

    if (typeCode.isEmpty || uomCode.isEmpty) {
      setState(() => _error = 'Seleccioná tipo y unidad de medida.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final barcode = _barcodeCtrl.text.trim().isEmpty
          ? null
          : _barcodeCtrl.text.trim();
      final basePrice = double.tryParse(_priceCtrl.text.trim());

      if (!_isEdit) {
        final factor = double.tryParse(_factorCtrl.text.trim()) ?? 1.0;
        final body = <String, dynamic>{
          'sku': _skuCtrl.text.trim(),
          'presentationTypeCode': typeCode,
          'uomCode': uomCode,
          'conversionFactor': factor,
          if (barcode != null) 'barcode': barcode,
          if (basePrice != null) 'basePrice': basePrice,
        };
        await dio.post(
          '/v1/products/${widget.productId}/presentations',
          data: body,
        );
      } else {
        final body = <String, dynamic>{
          if (!_hasMovements) 'presentationTypeCode': typeCode,
          if (!_hasMovements) 'uomCode': uomCode,
          'barcode': barcode,
          if (basePrice != null) 'basePrice': basePrice else 'basePrice': null,
        };
        await dio.put(
          '/v1/products/${widget.productId}/presentations/${widget.existing!.id}',
          data: body,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      setState(() {
        _error = ErrorHandler.handle(e).message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final presTypesAsync = ref.watch(_presTypesProvider);
    final uomAsync = ref.watch(_uomListProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                _isEdit ? 'Editar presentación' : 'Nueva presentación',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: Color(0xFFC62828), fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],
              // SKU
              TextFormField(
                controller: _skuCtrl,
                enabled: !_isEdit,
                decoration: _dec('SKU *', 'Código de la presentación'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El SKU es obligatorio'
                    : null,
              ),
              const SizedBox(height: 12),
              // Tipo de presentación
              presTypesAsync.when(
                loading: () => TextFormField(
                  enabled: false,
                  decoration: _dec('Tipo *', 'Cargando…'),
                ),
                error: (_, __) => TextFormField(
                  enabled: false,
                  decoration: _dec('Tipo *', 'Error al cargar'),
                ),
                data: (types) {
                  // Ensure initial value is valid
                  if (_presentationTypeCode == null && types.isNotEmpty) {
                    _presentationTypeCode = types.first.code;
                  }
                  return DropdownButtonFormField<String>(
                    value: types.any((t) => t.code == _presentationTypeCode)
                        ? _presentationTypeCode
                        : (types.isNotEmpty ? types.first.code : null),
                    decoration: _dec('Tipo *', ''),
                    isExpanded: true,
                    items: types
                        .map((t) => DropdownMenuItem(
                            value: t.code,
                            child: Text(t.name,
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: _hasMovements
                        ? null
                        : (v) =>
                            setState(() => _presentationTypeCode = v),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Requerido' : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              // UOM
              uomAsync.when(
                loading: () => TextFormField(
                  enabled: false,
                  decoration: _dec('Unidad de medida *', 'Cargando…'),
                ),
                error: (_, __) => TextFormField(
                  enabled: false,
                  decoration: _dec('Unidad de medida *', 'Error al cargar'),
                ),
                data: (uomList) {
                  if (_uomCode == null && uomList.isNotEmpty) {
                    _uomCode = uomList.first.code;
                  }
                  return DropdownButtonFormField<String>(
                    value: uomList.any((u) => u.code == _uomCode)
                        ? _uomCode
                        : (uomList.isNotEmpty ? uomList.first.code : null),
                    decoration: _dec('Unidad de medida *', ''),
                    isExpanded: true,
                    items: uomList
                        .map((u) => DropdownMenuItem(
                            value: u.code,
                            child: Text(u.name,
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: _hasMovements
                        ? null
                        : (v) => setState(() => _uomCode = v),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Requerido' : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              // Barcode
              TextFormField(
                controller: _barcodeCtrl,
                decoration: _dec('Barcode', 'Opcional'),
              ),
              const SizedBox(height: 12),
              // Conversion factor (only create)
              if (!_isEdit) ...[
                TextFormField(
                  controller: _factorCtrl,
                  enabled: !_hasMovements,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _dec(
                      'Factor de conversión', '1',
                      helper: 'Multiplicador respecto a la unidad base'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    if (double.tryParse(v.trim()) == null) {
                      return 'Debe ser un número válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],
              // Base price
              TextFormField(
                controller: _priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _dec('Precio base', '0.00', helper: 'Opcional'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (double.tryParse(v.trim()) == null) {
                    return 'Debe ser un número válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Save button
              presTypesAsync.maybeWhen(
                data: (types) => uomAsync.maybeWhen(
                  data: (uomList) => ElevatedButton(
                    onPressed: _saving ? null : () => _save(types, uomList),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_saving
                        ? 'Guardando…'
                        : (_isEdit ? 'Guardar cambios' : 'Crear presentación')),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _dec(String label, String hint, {String? helper}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
