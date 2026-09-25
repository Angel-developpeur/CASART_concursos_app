import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/concurso_estadisticas.dart';
import 'database_provider.dart';

final concursoEstadisticasProvider =
    FutureProvider.autoDispose.family<ConcursoEstadisticas, int>((ref, concursoId) async {
  final concursoRepo = ref.watch(concursoRepositoryProvider);
  final registroRepo = ref.watch(registroRepositoryProvider);
  final premioRepo = ref.watch(premioRepositoryProvider);

  final concurso = await concursoRepo.getConcursoById(concursoId);
  if (concurso == null) {
    throw StateError('Concurso #$concursoId no encontrado');
  }

  final registros = await registroRepo.getRegistrosByConcurso(concursoId);
  final premios = await premioRepo.getPremiosByConcurso(concursoId);

  return ConcursoEstadisticas.calcular(
    concurso: concurso,
    registros: registros,
    premios: premios,
  );
});
