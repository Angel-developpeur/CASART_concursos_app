import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/registro_concurso.dart';
import 'database_provider.dart';
import 'concursos_provider.dart';

class RegistrosSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  @override
  set state(String value) => super.state = value;
}

final registrosSearchProvider =
    NotifierProvider<RegistrosSearchNotifier, String>(RegistrosSearchNotifier.new);

final registrosConcursoProvider = FutureProvider.autoDispose<List<RegistroConcurso>>((ref) async {
  final idConcurso = ref.watch(selectedConcursoIdProvider);
  if (idConcurso == null) return [];

  final repo = ref.watch(registroRepositoryProvider);
  final search = ref.watch(registrosSearchProvider);

  return await repo.getRegistrosByConcurso(idConcurso, search: search);
});

final nextFolioProvider = FutureProvider.autoDispose<int>((ref) async {
  final idConcurso = ref.watch(selectedConcursoIdProvider);
  if (idConcurso == null) return 1;

  final repo = ref.watch(registroRepositoryProvider);
  return await repo.getNextFolio(idConcurso);
});
