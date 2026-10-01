import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/concurso.dart';
import '../../providers/concursos_provider.dart';
import '../../providers/database_provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/theme/app_theme.dart';
import 'concurso_form_dialog.dart';
import 'estadisticas_concurso_view.dart';

class ConcursosListView extends ConsumerWidget {
  final Function(int idConcurso) onSelectConcurso;

  const ConcursosListView({super.key, required this.onSelectConcurso});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(concursosFilterProvider);
    final concursosAsync = ref.watch(concursosListProvider);
    final selectedConcursoId = ref.watch(selectedConcursoIdProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // HEADER BAR: Título, Filtros y Botón Nuevo
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gestión de Concursos',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Administración de convocatorias, categorías, aportaciones e inscripciones',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo Concurso'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.verdeSuccess,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => const ConcursoFormDialog(),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // BARRA DE BÚSQUEDA Y FILTROS
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, filterConstraints) {
                    final isCompact = filterConstraints.maxWidth < 650;
                    if (isCompact) {
                      return Column(
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              hintText: 'Buscar concurso por nombre o sede...',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                            onChanged: (val) {
                              ref.read(concursosFilterProvider.notifier).update((s) => s.copyWith(search: val));
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String?>(
                                  initialValue: filter.ejercicio,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Año (Ejercicio)', isDense: true),
                                  items: [
                                    const DropdownMenuItem<String?>(value: null, child: Text('Todos los años')),
                                    ...List.generate(6, (i) {
                                      final y = (DateTime.now().year - 2 + i).toString();
                                      return DropdownMenuItem<String?>(value: y, child: Text(y));
                                    }),
                                  ],
                                  onChanged: (val) {
                                    ref.read(concursosFilterProvider.notifier).update((s) => s.copyWith(ejercicio: val, clearEjercicio: val == null));
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<bool?>(
                                  initialValue: filter.finalizado,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Estatus', isDense: true),
                                  items: const [
                                    DropdownMenuItem<bool?>(value: null, child: Text('Todos')),
                                    DropdownMenuItem<bool?>(value: false, child: Text('En Proceso')),
                                    DropdownMenuItem<bool?>(value: true, child: Text('Finalizados')),
                                  ],
                                  onChanged: (val) {
                                    ref.read(concursosFilterProvider.notifier).update((s) => s.copyWith(finalizado: val, clearFinalizado: val == null));
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Buscar concurso por nombre o sede...',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                            onChanged: (val) {
                              ref.read(concursosFilterProvider.notifier).update((s) => s.copyWith(search: val));
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String?>(
                            initialValue: filter.ejercicio,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Año (Ejercicio)', isDense: true),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Todos los años')),
                              ...List.generate(6, (i) {
                                final y = (DateTime.now().year - 2 + i).toString();
                                return DropdownMenuItem<String?>(value: y, child: Text(y));
                              }),
                            ],
                            onChanged: (val) {
                              ref.read(concursosFilterProvider.notifier).update((s) => s.copyWith(ejercicio: val, clearEjercicio: val == null));
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<bool?>(
                            initialValue: filter.finalizado,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Estatus', isDense: true),
                            items: const [
                              DropdownMenuItem<bool?>(value: null, child: Text('Todos')),
                              DropdownMenuItem<bool?>(value: false, child: Text('En Proceso')),
                              DropdownMenuItem<bool?>(value: true, child: Text('Finalizados')),
                            ],
                            onChanged: (val) {
                              ref.read(concursosFilterProvider.notifier).update((s) => s.copyWith(finalizado: val, clearFinalizado: val == null));
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // LISTA DE CONCURSOS
            Expanded(
              child: concursosAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error al cargar concursos: $err')),
                data: (concursos) {
                  if (concursos.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text('No se encontraron concursos registrados.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) => const ConcursoFormDialog(),
                              );
                            },
                            child: const Text('Crear Primer Concurso'),
                          )
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: concursos.length,
                    itemBuilder: (context, index) {
                      final c = concursos[index];
                      final isSelected = c.id == selectedConcursoId;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).dividerColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            ref.read(selectedConcursoIdProvider.notifier).state = c.id;
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icono / Estado
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: c.finalizado
                                        ? Colors.grey.withValues(alpha: 0.1)
                                        : AppTheme.casart50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    c.finalizado ? Icons.check_circle_outline : Icons.workspace_premium,
                                    color: c.finalizado ? Colors.grey : AppTheme.casart800,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Contenido central
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              c.tipoConcursoNombre?.toUpperCase() ?? 'CONCURSO',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context).colorScheme.secondary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Ejercicio ${c.ejercicio}',
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                          const Spacer(),
                                          if (c.finalizado)
                                            ActionChip(
                                              avatar: const Icon(Icons.check_circle, size: 15, color: Colors.white),
                                              label: const Text('Finalizado', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                              backgroundColor: Colors.blueGrey.shade600,
                                              tooltip: 'Clic para reabrir concurso (Poner En Proceso)',
                                              visualDensity: VisualDensity.compact,
                                              onPressed: () => _confirmToggleFinalizado(context, ref, c),
                                            )
                                          else
                                            ActionChip(
                                              avatar: const Icon(Icons.play_circle_fill, size: 15, color: AppTheme.verdeSuccess),
                                              label: const Text('En Proceso', style: TextStyle(fontSize: 11, color: AppTheme.verdeSuccess, fontWeight: FontWeight.bold)),
                                              backgroundColor: AppTheme.verdeLight,
                                              side: const BorderSide(color: AppTheme.verdeBorder),
                                              tooltip: 'Clic para marcar concurso como Finalizado',
                                              visualDensity: VisualDensity.compact,
                                              onPressed: () => _confirmToggleFinalizado(context, ref, c),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        c.nombre,
                                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 16,
                                        runSpacing: 4,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text(c.lugar ?? 'Sede no especificada', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                            ],
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.calendar_today_outlined, size: 15, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text('Registro: ${Formatters.formatDate(c.fechaInicioRegistro)} al ${Formatters.formatDate(c.fechaLimiteRegistro)}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      // Resumen rápido de categorías y aportaciones
                                      Wrap(
                                        spacing: 12,
                                        children: [
                                          Text('${c.categorias.length} Categorías', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                          Text('Bolsa: ${Formatters.formatCurrency(c.totalAportaciones)} (${c.aportaciones.length} aportaciones)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.verdeSuccess)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 16),

                                // Acciones
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 175,
                                      child: ElevatedButton.icon(
                                        icon: Icon(c.finalizado ? Icons.visibility_outlined : Icons.app_registration, size: 18),
                                        label: Text(c.finalizado ? 'Ver Inscripciones' : 'Inscribir Pieza'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: c.finalizado
                                              ? (Theme.of(context).brightness == Brightness.dark
                                                  ? const Color(0xFF334155)
                                                  : Colors.blueGrey.shade700)
                                              : AppTheme.verdeSuccess,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () {
                                          ref.read(selectedConcursoIdProvider.notifier).state = c.id;
                                          onSelectConcurso(c.id!);
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: 175,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.analytics_outlined, size: 17),
                                        label: const Text('Estadísticas'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.casart800,
                                          side: const BorderSide(color: AppTheme.casart800),
                                        ),
                                        onPressed: () {
                                          ref.read(selectedConcursoIdProvider.notifier).state = c.id;
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => EstadisticasConcursoView(concurso: c),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            c.finalizado ? Icons.replay_outlined : Icons.task_alt,
                                            color: c.finalizado ? Colors.orange.shade700 : AppTheme.verdeSuccess,
                                          ),
                                          tooltip: c.finalizado
                                              ? 'Reabrir Concurso (Poner En Proceso)'
                                              : 'Marcar como Finalizado',
                                          onPressed: () => _confirmToggleFinalizado(context, ref, c),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          tooltip: 'Editar Concurso',
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (ctx) => ConcursoFormDialog(concursoToEdit: c),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmToggleFinalizado(BuildContext context, WidgetRef ref, Concurso c) async {
    final willFinalize = !c.finalizado;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              willFinalize ? Icons.task_alt : Icons.replay,
              color: willFinalize ? AppTheme.casart800 : Colors.orange,
              size: 26,
            ),
            const SizedBox(width: 12),
            Text(willFinalize ? 'Finalizar Concurso' : 'Reabrir Concurso'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Concurso: "${c.nombre}"',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text(
                willFinalize
                    ? '¿Deseas marcar este concurso como FINALIZADO?\n\nEsto indicará que el periodo de inscripciones y evaluación ha concluido formalmente. Podrás consultar sus datos y reportes en cualquier momento o reabrirlo si se requiere.'
                    : '¿Deseas cambiar el estatus de este concurso a "EN PROCESO"?\n\nEl concurso volverá a estar abierto para el registro de piezas y captura.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            style: AppTheme.cancelButtonStyle,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: AppTheme.acceptButtonStyle,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              willFinalize ? 'Marcar Finalizado' : 'Reabrir Concurso',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(concursoRepositoryProvider).setFinalizado(c.id!, willFinalize);
      ref.invalidate(concursosListProvider);
      ref.invalidate(selectedConcursoProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  willFinalize ? Icons.check_circle : Icons.replay,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    willFinalize
                        ? 'El concurso "${c.nombre}" ha sido marcado como FINALIZADO.'
                        : 'El concurso "${c.nombre}" está ahora EN PROCESO.',
                  ),
                ),
              ],
            ),
            backgroundColor: willFinalize ? AppTheme.casart800 : Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
