import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/concurso.dart';
import 'database_provider.dart';

class ConcursosFilter {
  final String search;
  final String? ejercicio;
  final bool? finalizado;

  const ConcursosFilter({
    this.search = '',
    this.ejercicio,
    this.finalizado,
  });

  ConcursosFilter copyWith({
    String? search,
    String? ejercicio,
    bool? finalizado,
    bool clearEjercicio = false,
    bool clearFinalizado = false,
  }) {
    return ConcursosFilter(
      search: search ?? this.search,
      ejercicio: clearEjercicio ? null : (ejercicio ?? this.ejercicio),
      finalizado: clearFinalizado ? null : (finalizado ?? this.finalizado),
    );
  }
}

class ConcursosFilterNotifier extends Notifier<ConcursosFilter> {
  @override
  ConcursosFilter build() {
    return ConcursosFilter(ejercicio: DateTime.now().year.toString());
  }

  @override
  set state(ConcursosFilter value) => super.state = value;

  void update(ConcursosFilter Function(ConcursosFilter) cb) {
    state = cb(state);
  }
}

final concursosFilterProvider =
    NotifierProvider<ConcursosFilterNotifier, ConcursosFilter>(ConcursosFilterNotifier.new);

final concursosListProvider = FutureProvider.autoDispose<List<Concurso>>((ref) async {
  final repo = ref.watch(concursoRepositoryProvider);
  final filter = ref.watch(concursosFilterProvider);

  return await repo.getConcursos(
    search: filter.search,
    ejercicio: filter.ejercicio,
    finalizado: filter.finalizado,
  );
});

class SelectedConcursoIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  @override
  set state(int? value) => super.state = value;
}

final selectedConcursoIdProvider =
    NotifierProvider<SelectedConcursoIdNotifier, int?>(SelectedConcursoIdNotifier.new);

final selectedConcursoProvider = FutureProvider.autoDispose<Concurso?>((ref) async {
  final id = ref.watch(selectedConcursoIdProvider);
  if (id == null) return null;
  final repo = ref.watch(concursoRepositoryProvider);
  return await repo.getConcursoById(id);
});
