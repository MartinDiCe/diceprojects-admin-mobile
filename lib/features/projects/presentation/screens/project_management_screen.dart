import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_button.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_text_field.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/create_fab.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _projectSearchProvider = StateProvider.autoDispose<String>((_) => '');

final _projectTypesProvider = FutureProvider.autoDispose<List<_ProjectTypeDto>>((ref) async {
  final response = await ref.watch(dioProvider).get('/v1/project-management/types');
  return _list(response.data).map(_ProjectTypeDto.fromJson).toList();
});

final _projectsProvider = FutureProvider.autoDispose<List<_ProjectDto>>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  final search = ref.watch(_projectSearchProvider).trim();
  final params = <String, dynamic>{};
  if (!auth.isAdminGlobal && auth.tenantId?.isNotEmpty == true) {
    params['tenantId'] = auth.tenantId;
  }
  if (!auth.isAdminGlobal && auth.sellerId?.isNotEmpty == true) {
    params['sellerId'] = auth.sellerId;
  }
  if (search.isNotEmpty) params['search'] = search;
  final response = await ref.watch(dioProvider).get('/v1/project-management/projects', queryParameters: params);
  return _list(response.data).map(_ProjectDto.fromJson).toList();
});

final _projectTasksProvider = FutureProvider.autoDispose.family<List<_ProjectTaskDto>, String>((ref, projectId) async {
  final response = await ref.watch(dioProvider).get('/v1/project-management/projects/$projectId/tasks');
  return _list(response.data).map(_ProjectTaskDto.fromJson).toList();
});

final _projectProgressProvider = FutureProvider.autoDispose.family<List<_ProjectProgressDto>, String>((ref, projectId) async {
  final response = await ref.watch(dioProvider).get('/v1/project-management/projects/$projectId/progress');
  return _list(response.data).map(_ProjectProgressDto.fromJson).toList();
});

class ProjectManagementScreen extends ConsumerWidget {
  const ProjectManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    final canCreate = perms.hasAnyPermission(['Projects.Projects.Create', 'Projects.Admin']);

    return DefaultTabController(
      length: 2,
      child: AppPageScaffold(
        title: 'Proyectos',
        searchHint: 'Buscar proyecto...',
        onSearch: (value) => ref.read(_projectSearchProvider.notifier).state = value,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () {
              ref.invalidate(_projectsProvider);
              ref.invalidate(_projectTypesProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        floatingActionButton: canCreate
            ? CreateFab(
                label: 'Nuevo proyecto',
                onPressed: () async {
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => const _ProjectCreateSheet(),
                  );
                  ref.invalidate(_projectsProvider);
                },
              )
            : null,
        body: Column(
          children: [
            Material(
              color: AppColors.surface,
              child: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.account_tree_rounded), text: 'Proyectos'),
                  Tab(icon: Icon(Icons.tune_rounded), text: 'Tipos'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ProjectsTab(),
                  _ProjectTypesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectsTab extends ConsumerWidget {
  const _ProjectsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(_projectsProvider);
    return projects.when(
      loading: () => const LoadingState(),
      error: (_, __) => ErrorState(
        message: 'No se pudieron cargar los proyectos.',
        onRetry: () => ref.invalidate(_projectsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.engineering_rounded,
            title: 'Sin proyectos',
            message: 'Todavia no hay obras o proyectos cargados.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_projectsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _ProjectTile(project: items[index]),
          ),
        );
      },
    );
  }
}

class _ProjectTile extends ConsumerWidget {
  final _ProjectDto project;

  const _ProjectTile({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _ProjectDetailDialog(project: project),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.construction_rounded, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.ink, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${project.code}${project.typeName == null ? '' : ' - ${project.typeName}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: project.status),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectTypesTab extends ConsumerWidget {
  const _ProjectTypesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(_projectTypesProvider);
    final perms = ref.watch(permissionsProvider);
    final canCreate = perms.hasAnyPermission(['Projects.ProjectTypes.Create', 'Projects.Admin']);
    return types.when(
      loading: () => const LoadingState(),
      error: (_, __) => ErrorState(
        message: 'No se pudo cargar la configuracion de proyectos.',
        onRetry: () => ref.invalidate(_projectTypesProvider),
      ),
      data: (items) => Column(
        children: [
          if (canCreate)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: AppButton.secondary(
                  label: 'Nuevo tipo',
                  icon: Icons.add_rounded,
                  onPressed: () async {
                    await showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => const _ProjectTypeCreateSheet(),
                    );
                    ref.invalidate(_projectTypesProvider);
                  },
                ),
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(
                    icon: Icons.tune_rounded,
                    title: 'Sin tipos',
                    message: 'Carga los tipos base para clasificar obras y servicios.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        leading: const Icon(Icons.category_rounded),
                        title: Text(item.name),
                        subtitle: Text(item.code),
                        trailing: StatusBadge(status: item.active ? 'ACTIVO' : 'INACTIVO'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCreateSheet extends ConsumerStatefulWidget {
  const _ProjectCreateSheet();

  @override
  ConsumerState<_ProjectCreateSheet> createState() => _ProjectCreateSheetState();
}

class _ProjectCreateSheetState extends ConsumerState<_ProjectCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  String? _typeId;
  String _status = 'PLANNED';
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(_projectTypesProvider).valueOrNull ?? const <_ProjectTypeDto>[];
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nuevo proyecto', style: TextStyle(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              AppTextField(label: 'Codigo *', controller: _code, validator: _required),
              const SizedBox(height: 12),
              AppTextField(label: 'Nombre *', controller: _name, validator: _required),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _typeId,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: types
                    .map((type) => DropdownMenuItem<String>(value: type.id, child: Text(type.name)))
                    .toList(),
                onChanged: (value) => setState(() => _typeId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: const [
                  DropdownMenuItem(value: 'DRAFT', child: Text('Borrador')),
                  DropdownMenuItem(value: 'PLANNED', child: Text('Planificado')),
                  DropdownMenuItem(value: 'IN_PROGRESS', child: Text('En curso')),
                ],
                onChanged: (value) => setState(() => _status = value ?? 'PLANNED'),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: _saving ? 'Guardando...' : 'Guardar',
                icon: Icons.save_rounded,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authNotifierProvider);
    if (auth.tenantId?.isNotEmpty != true && !auth.isAdminGlobal) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una empresa para crear proyectos.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(dioProvider).post('/v1/project-management/projects', data: {
        'tenantId': auth.tenantId ?? 'global',
        'sellerId': auth.sellerId,
        'projectTypeId': _typeId,
        'code': _code.text.trim(),
        'name': _name.text.trim(),
        'status': _status,
      });
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ProjectTypeCreateSheet extends ConsumerStatefulWidget {
  const _ProjectTypeCreateSheet();

  @override
  ConsumerState<_ProjectTypeCreateSheet> createState() => _ProjectTypeCreateSheetState();
}

class _ProjectTypeCreateSheetState extends ConsumerState<_ProjectTypeCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nuevo tipo', style: TextStyle(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            AppTextField(label: 'Codigo *', controller: _code, validator: _required),
            const SizedBox(height: 12),
            AppTextField(label: 'Nombre *', controller: _name, validator: _required),
            const SizedBox(height: 16),
            AppButton(
              label: _saving ? 'Guardando...' : 'Guardar',
              icon: Icons.save_rounded,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(dioProvider).post('/v1/project-management/types', data: {
        'code': _code.text.trim(),
        'name': _name.text.trim(),
        'active': true,
      });
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ProjectDetailDialog extends ConsumerWidget {
  final _ProjectDto project;

  const _ProjectDetailDialog({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(_projectTasksProvider(project.id));
    final progress = ref.watch(_projectProgressProvider(project.id));
    final perms = ref.watch(permissionsProvider);
    final canCreateTask = perms.hasAnyPermission(['Projects.Tasks.Create', 'Projects.Admin']);
    final canCreateProgress = perms.hasAnyPermission(['Projects.Progress.Create', 'Projects.Admin']);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.name, style: TextStyle(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(project.code, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  StatusBadge(status: project.status),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    _SectionHeader(
                      title: 'Tareas',
                      action: canCreateTask
                          ? IconButton(
                              tooltip: 'Agregar tarea',
                              onPressed: () async {
                                await showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  useSafeArea: true,
                                  builder: (_) => _TaskCreateSheet(projectId: project.id),
                                );
                                ref.invalidate(_projectTasksProvider(project.id));
                              },
                              icon: const Icon(Icons.add_task_rounded),
                            )
                          : null,
                    ),
                    tasks.when(
                      loading: () => const Padding(padding: EdgeInsets.all(16), child: LoadingState()),
                      error: (_, __) => const Text('No se pudieron cargar las tareas.'),
                      data: (items) => items.isEmpty
                          ? const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Sin tareas cargadas.'))
                          : Column(children: items.map((item) => _TaskRow(task: item)).toList()),
                    ),
                    const SizedBox(height: 18),
                    _SectionHeader(
                      title: 'Avances',
                      action: canCreateProgress
                          ? IconButton(
                              tooltip: 'Registrar avance',
                              onPressed: () async {
                                await showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  useSafeArea: true,
                                  builder: (_) => _ProgressCreateSheet(projectId: project.id),
                                );
                                ref.invalidate(_projectProgressProvider(project.id));
                                ref.invalidate(_projectTasksProvider(project.id));
                              },
                              icon: const Icon(Icons.trending_up_rounded),
                            )
                          : null,
                    ),
                    progress.when(
                      loading: () => const Padding(padding: EdgeInsets.all(16), child: LoadingState()),
                      error: (_, __) => const Text('No se pudieron cargar los avances.'),
                      data: (items) => items.isEmpty
                          ? const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Sin avances registrados.'))
                          : Column(children: items.map((item) => _ProgressRow(progress: item)).toList()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: TextStyle(color: AppColors.ink, fontSize: 15, fontWeight: FontWeight.w800))),
        if (action != null) action!,
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  final _ProjectTaskDto task;

  const _TaskRow({required this.task});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.checklist_rounded),
      title: Text(task.name),
      subtitle: LinearProgressIndicator(value: (task.progressPercent.clamp(0, 100) / 100).toDouble()),
      trailing: StatusBadge(status: task.status),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final _ProjectProgressDto progress;

  const _ProgressRow({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.insights_rounded),
      title: Text('${progress.progressPercent.toStringAsFixed(0)}%'),
      subtitle: Text(progress.notes?.isNotEmpty == true ? progress.notes! : 'Sin notas'),
    );
  }
}

class _TaskCreateSheet extends ConsumerStatefulWidget {
  final String projectId;

  const _TaskCreateSheet({required this.projectId});

  @override
  ConsumerState<_TaskCreateSheet> createState() => _TaskCreateSheetState();
}

class _TaskCreateSheetState extends ConsumerState<_TaskCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _progress = TextEditingController(text: '0');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nueva tarea', style: TextStyle(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            AppTextField(label: 'Nombre *', controller: _name, validator: _required),
            const SizedBox(height: 12),
            AppTextField(label: 'Avance %', controller: _progress, keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            AppButton(label: _saving ? 'Guardando...' : 'Guardar', icon: Icons.save_rounded, onPressed: _saving ? null : _save),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(dioProvider).post('/v1/project-management/projects/${widget.projectId}/tasks', data: {
        'name': _name.text.trim(),
        'status': 'PENDING',
        'progressPercent': double.tryParse(_progress.text.replaceAll(',', '.')) ?? 0,
      });
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ProgressCreateSheet extends ConsumerStatefulWidget {
  final String projectId;

  const _ProgressCreateSheet({required this.projectId});

  @override
  ConsumerState<_ProgressCreateSheet> createState() => _ProgressCreateSheetState();
}

class _ProgressCreateSheetState extends ConsumerState<_ProgressCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _percent = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _percent.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Registrar avance', style: TextStyle(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            AppTextField(label: 'Avance % *', controller: _percent, keyboardType: TextInputType.number, validator: _required),
            const SizedBox(height: 12),
            AppTextField(label: 'Notas', controller: _notes, maxLines: 3),
            const SizedBox(height: 16),
            AppButton(label: _saving ? 'Guardando...' : 'Guardar', icon: Icons.save_rounded, onPressed: _saving ? null : _save),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(dioProvider).post('/v1/project-management/projects/${widget.projectId}/progress', data: {
        'progressDate': DateTime.now().toIso8601String(),
        'progressPercent': double.tryParse(_percent.text.replaceAll(',', '.')) ?? 0,
        'notes': _notes.text.trim(),
      });
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ProjectDto {
  final String id;
  final String code;
  final String name;
  final String status;
  final String? typeName;

  const _ProjectDto({required this.id, required this.code, required this.name, required this.status, this.typeName});

  factory _ProjectDto.fromJson(Map<String, dynamic> json) => _ProjectDto(
        id: _str(json, 'id'),
        code: _str(json, 'code'),
        name: _str(json, 'name'),
        status: _str(json, 'status', fallback: 'DRAFT'),
        typeName: _nullableStr(json, 'project_type_name'),
      );
}

class _ProjectTypeDto {
  final String id;
  final String code;
  final String name;
  final bool active;

  const _ProjectTypeDto({required this.id, required this.code, required this.name, required this.active});

  factory _ProjectTypeDto.fromJson(Map<String, dynamic> json) => _ProjectTypeDto(
        id: _str(json, 'id'),
        code: _str(json, 'code'),
        name: _str(json, 'name'),
        active: json['active'] != false,
      );
}

class _ProjectTaskDto {
  final String name;
  final String status;
  final double progressPercent;

  const _ProjectTaskDto({required this.name, required this.status, required this.progressPercent});

  factory _ProjectTaskDto.fromJson(Map<String, dynamic> json) => _ProjectTaskDto(
        name: _str(json, 'name'),
        status: _str(json, 'status', fallback: 'PENDING'),
        progressPercent: _num(json, 'progress_percent'),
      );
}

class _ProjectProgressDto {
  final double progressPercent;
  final String? notes;

  const _ProjectProgressDto({required this.progressPercent, this.notes});

  factory _ProjectProgressDto.fromJson(Map<String, dynamic> json) => _ProjectProgressDto(
        progressPercent: _num(json, 'progress_percent'),
        notes: _nullableStr(json, 'notes'),
      );
}

List<Map<String, dynamic>> _list(Object? data) {
  if (data is! List) return const [];
  return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
}

String _str(Map<String, dynamic> json, String key, {String fallback = ''}) => json[key]?.toString() ?? fallback;

String? _nullableStr(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString();
  return value == null || value.trim().isEmpty ? null : value;
}

double _num(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String? _required(String? value) => value == null || value.trim().isEmpty ? 'Requerido' : null;
