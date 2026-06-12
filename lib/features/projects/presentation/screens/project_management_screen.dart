import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _projectTypesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/v1/project-management/types');
  final data = response.data;
  if (data is List) {
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return const [];
});

class ProjectManagementScreen extends ConsumerWidget {
  const ProjectManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(_projectTypesProvider);

    return AppPageScaffold(
      title: 'Proyectos',
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () => ref.invalidate(_projectTypesProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: types.when(
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: 'No se pudo cargar la configuración de proyectos.',
          onRetry: () => ref.invalidate(_projectTypesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.engineering_rounded,
              title: 'Módulo preparado',
              message: 'La base de proyectos ya está creada para cargar tipos, templates y presupuestos.',
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: const Icon(Icons.account_tree_rounded),
                title: Text(item['name']?.toString() ?? 'Tipo de proyecto'),
                subtitle: Text(item['code']?.toString() ?? ''),
              );
            },
          );
        },
      ),
    );
  }
}
