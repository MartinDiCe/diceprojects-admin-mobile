import 'dart:async';
import 'dart:io';

import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Models
// ──────────────────────────────────────────────────────────────────────────────

class _JobTemplate {
  final String id;
  final String templateCode;
  final String? name;
  final String fileFormat;

  const _JobTemplate({
    required this.id,
    required this.templateCode,
    this.name,
    required this.fileFormat,
  });

  factory _JobTemplate.fromJson(Map<String, dynamic> j) => _JobTemplate(
        id: j['id']?.toString() ?? '',
        templateCode: j['templateCode']?.toString() ?? '',
        name: j['name']?.toString() ?? j['templateCode']?.toString(),
        fileFormat: j['fileFormat']?.toString() ?? 'CSV',
      );

  String get displayName => name?.isNotEmpty == true ? name! : templateCode;
}

class _TenantOption {
  final String id;
  final String name;
  const _TenantOption({required this.id, required this.name});
}

typedef _JobStatus = String; // PENDING | PROCESSING | DONE | PARTIAL | FAILED

class _JobReport {
  final int total;
  final int ok;
  final int rejected;
  final List<_RowResult> rows;

  const _JobReport({
    required this.total,
    required this.ok,
    required this.rejected,
    required this.rows,
  });
}

class _RowResult {
  final int rowIndex;
  final String status;
  final String? message;

  const _RowResult({
    required this.rowIndex,
    required this.status,
    this.message,
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// Screen State
// ──────────────────────────────────────────────────────────────────────────────

enum _Step { form, processing, done }

// ──────────────────────────────────────────────────────────────────────────────
// Screen
// ──────────────────────────────────────────────────────────────────────────────

class ProductImportScreen extends ConsumerStatefulWidget {
  const ProductImportScreen({super.key});

  @override
  ConsumerState<ProductImportScreen> createState() =>
      _ProductImportScreenState();
}

class _ProductImportScreenState extends ConsumerState<ProductImportScreen> {
  _Step _step = _Step.form;

  // Templates
  List<_JobTemplate> _templates = [];
  _JobTemplate? _selectedTemplate;
  bool _templatesLoading = true;
  String? _templatesError;
  bool _downloadingSample = false;

  // Tenants (admin global only)
  List<_TenantOption> _tenants = [];
  String? _selectedTenantId;
  bool _tenantsLoading = false;

  // File
  PlatformFile? _pickedFile;

  // Job
  String? _jobId;
  _JobStatus _jobStatus = 'PENDING';
  Timer? _pollTimer;
  String? _submitError;

  // Report
  _JobReport? _report;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    final auth = ref.read(authNotifierProvider);
    if (auth.isAdminGlobal) _loadTenants();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Dio get _dio => ref.read(dioProvider);

  // ── Sample download ────────────────────────────────────────────────────────

  Future<void> _downloadSample() async {
    final template = _selectedTemplate;
    if (template == null) return;
    setState(() => _downloadingSample = true);
    try {
      final resp = await _dio.get(
        '/v1/job-templates/${template.templateCode}/sample',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = resp.data as List<int>;
      final dir  = Directory.systemTemp;
      final file = File('${dir.path}/${template.templateCode}_sample.csv');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Plantilla de ejemplo: ${template.displayName}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar muestra: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingSample = false);
    }
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadTemplates() async {
    setState(() {
      _templatesLoading = true;
      _templatesError = null;
    });
    try {
      final resp = await _dio.get('/v1/job-templates');
      final list = (resp.data as List? ?? [])
          .map((e) => _JobTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _templates = list;
          _selectedTemplate = list.isNotEmpty ? list.first : null;
          _templatesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _templatesError = 'No se pudieron cargar las plantillas.';
          _templatesLoading = false;
        });
      }
    }
  }

  Future<void> _loadTenants() async {
    setState(() => _tenantsLoading = true);
    try {
      final resp = await _dio.get('/v1/tenants', queryParameters: {
        'page': 0,
        'size': 200,
        'status': 'ACTIVE',
      });
      final items = (resp.data['content'] ?? resp.data as List? ?? []) as List;
      if (mounted) {
        setState(() {
          _tenants = items
              .map((e) => _TenantOption(
                    id: e['id']?.toString() ?? '',
                    name: e['name']?.toString() ?? '',
                  ))
              .toList();
          _tenantsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _tenantsLoading = false);
    }
  }

  // ── File picker ────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xls', 'xlsx'],
      withReadStream: false,
      withData: false, // use path on Android
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final auth = ref.read(authNotifierProvider);
    final companyId =
        auth.isAdminGlobal ? (_selectedTenantId ?? '') : (auth.tenantId ?? '');

    if (_pickedFile == null) return;
    if (_selectedTemplate == null) return;
    if (companyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná una empresa primero.')),
      );
      return;
    }

    setState(() {
      _step = _Step.processing;
      _jobStatus = 'PENDING';
      _submitError = null;
    });

    try {
      final filePath = _pickedFile!.path!;
      final fileName = _pickedFile!.name;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
        'companyId': companyId,
        'importType': 'PRODUCTS',
        'templateCode': _selectedTemplate!.templateCode,
      });

      final resp = await _dio.post('/v1/jobs', data: formData);
      final jobId = resp.data['jobId']?.toString() ?? '';

      setState(() => _jobId = jobId);
      _startPolling();
    } catch (e) {
      final msg = e is DioException
          ? (e.response?.data?['message'] ?? e.message ?? 'Error al iniciar.')
          : e.toString();
      setState(() {
        _step = _Step.form;
        _submitError = msg.toString();
      });
    }
  }

  // ── Polling ────────────────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkStatus());
    _checkStatus(); // immediate first check
  }

  Future<void> _checkStatus() async {
    final jobId = _jobId;
    if (jobId == null) return;
    try {
      final resp = await _dio.get('/v1/jobs/$jobId');
      final status = resp.data['status']?.toString() ?? 'PROCESSING';
      if (mounted) setState(() => _jobStatus = status);
      if (status == 'DONE' || status == 'PARTIAL' || status == 'FAILED') {
        _pollTimer?.cancel();
        await _loadReport(jobId);
      }
    } catch (_) {}
  }

  Future<void> _loadReport(String jobId) async {
    try {
      final resp = await _dio.get('/v1/jobs/$jobId/report');
      final rows = (resp.data['rows'] as List? ?? [])
          .map((e) => _RowResult(
                rowIndex: (e['rowIndex'] as num?)?.toInt() ?? 0,
                status: e['status']?.toString() ?? '',
                message: e['message']?.toString(),
              ))
          .toList();

      final ok = rows.where((r) => r.status == 'OK').length;
      final rejected =
          rows.where((r) => r.status == 'REJECTED' || r.status == 'WARNING').length;
      if (mounted) {
        setState(() {
          _report = _JobReport(
            total: rows.length,
            ok: ok,
            rejected: rejected,
            rows: rows,
          );
          _step = _Step.done;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _report = null;
          _step = _Step.done;
        });
      }
    }
  }

  void _reset() {
    setState(() {
      _step = _Step.form;
      _pickedFile = null;
      _jobId = null;
      _report = null;
      _submitError = null;
      _jobStatus = 'PENDING';
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (_step) {
      case _Step.form:
        return _buildForm(context, isDark);
      case _Step.processing:
        return _buildProcessing(context);
      case _Step.done:
        return _buildResult(context, isDark);
    }
  }

  // ── STEP 1: Form ───────────────────────────────────────────────────────────

  Widget _buildForm(BuildContext context, bool isDark) {
    final auth = ref.watch(authNotifierProvider);
    final cardBg = isDark ? AppColors.surface.withValues(alpha: 0.8) : Colors.white;
    final textSecondary = isDark ? AppColors.textSecondary : AppColors.textSecondary;

    final canSubmit =
        _pickedFile != null &&
        _selectedTemplate != null &&
        (!auth.isAdminGlobal || _selectedTenantId != null);

    return AppPageScaffold(
      title: 'Importar Productos',
      body: _templatesLoading
          ? const Center(child: CircularProgressIndicator())
          : _templatesError != null
              ? _ErrorRetry(message: _templatesError!, onRetry: _loadTemplates)
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ── Info banner ───────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.20)),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: AppColors.accent, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Seleccioná una plantilla, elegí el archivo CSV o Excel y presioná "Importar".',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.accent,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Template selector ─────────────────────────────────
                    _SectionLabel(label: 'Plantilla de importación'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<_JobTemplate>(
                          isExpanded: true,
                          value: _selectedTemplate,
                          hint: Text('Seleccioná una plantilla',
                              style: TextStyle(color: textSecondary)),
                          items: _templates
                              .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Row(
                                      children: [
                                        Icon(Icons.description_rounded,
                                            size: 16, color: AppColors.accent),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(t.displayName,
                                              style: const TextStyle(fontSize: 14)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.accentLight
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(t.fileFormat,
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.accent,
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                          onChanged: (t) =>
                              setState(() => _selectedTemplate = t),
                          dropdownColor: cardBg,
                        ),
                      ),
                    ),

                    // ── Download sample button ────────────────────────────
                    if (_selectedTemplate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton.icon(
                          onPressed: _downloadingSample ? null : _downloadSample,
                          icon: _downloadingSample
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(Icons.download_rounded, size: 16, color: AppColors.accent),
                          label: Text(
                            'Descargar archivo de ejemplo',
                            style: TextStyle(fontSize: 13, color: AppColors.accent),
                          ),
                        ),
                      ),

                    // ── Tenant selector (admin global) ────────────────────
                    if (auth.isAdminGlobal) ...[
                      const SizedBox(height: 20),
                      _SectionLabel(label: 'Empresa destino'),
                      const SizedBox(height: 8),
                      _tenantsLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color:
                                        AppColors.border.withValues(alpha: 0.5)),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 2),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedTenantId,
                                  hint: Text('Seleccioná una empresa',
                                      style:
                                          TextStyle(color: textSecondary)),
                                  items: _tenants
                                      .map((t) => DropdownMenuItem(
                                            value: t.id,
                                            child: Text(t.name,
                                                style: const TextStyle(
                                                    fontSize: 14)),
                                          ))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedTenantId = v),
                                  dropdownColor: cardBg,
                                ),
                              ),
                            ),
                    ],

                    const SizedBox(height: 20),

                    // ── File picker ───────────────────────────────────────
                    _SectionLabel(label: 'Archivo'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickFile,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _pickedFile != null
                                ? AppColors.accent.withValues(alpha: 0.5)
                                : AppColors.border.withValues(alpha: 0.5),
                            width: _pickedFile != null ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _pickedFile != null
                                    ? Icons.insert_drive_file_rounded
                                    : Icons.upload_file_rounded,
                                color: AppColors.accent,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pickedFile != null
                                        ? _pickedFile!.name
                                        : 'Elegir archivo CSV / XLS / XLSX',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: _pickedFile != null
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: _pickedFile != null
                                          ? (isDark
                                              ? Colors.white
                                              : AppColors.ink)
                                          : textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_pickedFile != null &&
                                      _pickedFile!.size > 0) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatSize(_pickedFile!.size),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: textSecondary),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: textSecondary),
                          ],
                        ),
                      ),
                    ),

                    // ── Error ─────────────────────────────────────────────
                    if (_submitError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Colors.red, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_submitError!,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ── Submit button ─────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: canSubmit ? _submit : null,
                        icon: const Icon(Icons.cloud_upload_rounded),
                        label: const Text('Importar',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.accent.withValues(alpha: 0.35),
                          disabledForegroundColor:
                              Colors.white.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  // ── STEP 2: Processing ─────────────────────────────────────────────────────

  Widget _buildProcessing(BuildContext context) {
    final statusColor = _jobStatus == 'FAILED'
        ? Colors.red
        : _jobStatus == 'DONE' || _jobStatus == 'PARTIAL'
            ? Colors.green
            : AppColors.accent;

    return AppPageScaffold(
      title: 'Importar Productos',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  strokeWidth: 5,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Procesando importación…',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : AppColors.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              _StatusBadge(status: _jobStatus),
              const SizedBox(height: 20),
              Text(
                'No cerrés esta pantalla. Esto puede demorar unos segundos.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── STEP 3: Result ─────────────────────────────────────────────────────────

  Widget _buildResult(BuildContext context, bool isDark) {
    final report = _report;
    final isSuccess = _jobStatus == 'DONE';
    final isPartial = _jobStatus == 'PARTIAL';

    final headerColor = isSuccess
        ? Colors.green
        : isPartial
            ? Colors.orange
            : Colors.red;

    final headerIcon = isSuccess
        ? Icons.check_circle_rounded
        : isPartial
            ? Icons.warning_amber_rounded
            : Icons.cancel_rounded;

    final headerTitle = isSuccess
        ? 'Importación completa'
        : isPartial
            ? 'Importación parcial'
            : 'Importación fallida';

    return AppPageScaffold(
      title: 'Resultado',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Result header ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: headerColor.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Icon(headerIcon, color: headerColor, size: 48),
                const SizedBox(height: 12),
                Text(
                  headerTitle,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: headerColor),
                ),
                if (_jobStatus == 'FAILED' && report == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'El job terminó con errores.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),

          if (report != null) ...[
            const SizedBox(height: 20),

            // ── Stats ─────────────────────────────────────────────────
            Row(
              children: [
                _StatCard(
                  label: 'Total',
                  value: '${report.total}',
                  color: AppColors.accent,
                  icon: Icons.table_rows_rounded,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  label: 'Exitosos',
                  value: '${report.ok}',
                  color: Colors.green,
                  icon: Icons.check_circle_rounded,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  label: 'Errores',
                  value: '${report.rejected}',
                  color: report.rejected > 0 ? Colors.red : AppColors.textSecondary,
                  icon: Icons.error_rounded,
                ),
              ],
            ),

            // ── Failed rows ────────────────────────────────────────────
            if (report.rejected > 0) ...[
              const SizedBox(height: 20),
              Text(
                'Filas con errores',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.ink),
              ),
              const SizedBox(height: 10),
              ...report.rows
                  .where((r) => r.status != 'OK')
                  .map((r) => _RowErrorTile(row: r, isDark: isDark)),
            ],
          ],

          const SizedBox(height: 28),

          // ── Nueva importación ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Nueva importación',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Helper Widgets
// ──────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.5),
      );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final map = {
      'PENDING': (Colors.grey.shade600, Colors.grey.shade100, 'PENDIENTE'),
      'PROCESSING': (Colors.blue.shade700, Colors.blue.shade50, 'PROCESANDO'),
      'DONE': (Colors.green.shade700, Colors.green.shade50, 'COMPLETADO'),
      'PARTIAL': (Colors.orange.shade700, Colors.orange.shade50, 'PARCIAL'),
      'FAILED': (Colors.red.shade700, Colors.red.shade50, 'FALLIDO'),
    };
    final entry = map[status] ?? (Colors.grey.shade600, Colors.grey.shade100, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: entry.$2,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(entry.$3,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: entry.$1,
              letterSpacing: 0.8)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _RowErrorTile extends StatefulWidget {
  final _RowResult row;
  final bool isDark;
  const _RowErrorTile({required this.row, required this.isDark});

  @override
  State<_RowErrorTile> createState() => _RowErrorTileState();
}

class _RowErrorTileState extends State<_RowErrorTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hasMsg = widget.row.message?.isNotEmpty == true;
    final isWarning = widget.row.status == 'WARNING';
    final color = isWarning ? Colors.orange : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Fila ${widget.row.rowIndex}',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color),
              ),
            ),
            title: Text(
              isWarning ? 'Advertencia' : 'Rechazado',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
            trailing: hasMsg
                ? Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  )
                : null,
            onTap: hasMsg ? () => setState(() => _expanded = !_expanded) : null,
          ),
          if (_expanded && hasMsg)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                widget.row.message!,
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(message,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
}
