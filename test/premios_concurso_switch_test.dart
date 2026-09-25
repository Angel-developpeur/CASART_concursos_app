import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:casart_concursos_desktop/models/concurso.dart';
import 'package:casart_concursos_desktop/models/premio.dart';
import 'package:casart_concursos_desktop/providers/database_provider.dart';
import 'package:casart_concursos_desktop/providers/concursos_provider.dart';
import 'package:casart_concursos_desktop/repositories/concurso_repository.dart';
import 'package:casart_concursos_desktop/repositories/premio_repository.dart';
import 'package:casart_concursos_desktop/views/premios/premios_view.dart';

class MockConcursoRepository extends ConcursoRepository {
  final Map<int, Concurso> concursos;
  MockConcursoRepository(this.concursos);

  @override
  Future<Concurso?> getConcursoById(int id) async => concursos[id];
}

class MockPremioRepository extends PremioRepository {
  final Map<int, List<Premio>> premiosPorConcurso;
  MockPremioRepository(this.premiosPorConcurso);

  @override
  Future<List<Premio>> getPremiosByConcurso(int idConcurso) async =>
      premiosPorConcurso[idConcurso] ?? [];

  @override
  Future<List<Map<String, dynamic>>> getGanadoresByConcurso(int idConcurso) async =>
      [];
}

void main() {
  testWidgets(
      'PremiosView actualiza y vacía la lista de premios al cambiar de concurso seleccionado',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final concurso1 = Concurso(
      id: 1,
      nombre: 'Concurso Con Premios',
      idTipoConcurso: 1,
      ejercicio: '2026',
    );
    final concurso2 = Concurso(
      id: 2,
      nombre: 'Concurso Vacio',
      idTipoConcurso: 1,
      ejercicio: '2026',
    );

    final mockConcursoRepo = MockConcursoRepository({
      1: concurso1,
      2: concurso2,
    });
    final mockPremioRepo = MockPremioRepository({
      1: [
        Premio(
          id: 1,
          idConcurso: 1,
          nombre: '1er Lugar Alfarería',
          monto: 5000.0,
        ),
        Premio(
          id: 2,
          idConcurso: 1,
          nombre: '2do Lugar Alfarería',
          monto: 3000.0,
        ),
      ],
      2: [],
    });

    final container = ProviderContainer(
      overrides: [
        concursoRepositoryProvider.overrideWithValue(mockConcursoRepo),
        premioRepositoryProvider.overrideWithValue(mockPremioRepo),
      ],
    );

    // 1. Inicialmente seleccionamos Concurso 1 (con 2 premios)
    container.read(selectedConcursoIdProvider.notifier).state = 1;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: PremiosView(),
        ),
      ),
    );

    // Permitir resolver FutureProvider y _loadData
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verificamos que se muestren los premios del Concurso 1
    expect(find.text('Bolsa de Premios - Concurso Con Premios'), findsOneWidget);
    expect(find.text('1er Lugar Alfarería'), findsOneWidget);
    expect(find.text('2do Lugar Alfarería'), findsOneWidget);
    expect(find.text('Premios Registrados (2)'), findsOneWidget);

    // 2. Cambiamos el concurso seleccionado al Concurso 2 (que NO tiene premios)
    container.read(selectedConcursoIdProvider.notifier).state = 2;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verificamos que la vista se haya actualizado al Concurso 2 y aparezca vacía
    expect(find.text('Bolsa de Premios - Concurso Vacio'), findsOneWidget);
    expect(find.text('1er Lugar Alfarería'), findsNothing);
    expect(find.text('2do Lugar Alfarería'), findsNothing);
    expect(
      find.text('No hay premios agregados a la bolsa de este concurso.'),
      findsOneWidget,
    );
    expect(find.text('Premios Registrados (0)'), findsOneWidget);

    // 3. Cambiamos de nuevo al Concurso 1
    container.read(selectedConcursoIdProvider.notifier).state = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verificamos que vuelvan a aparecer los premios del Concurso 1
    expect(find.text('Bolsa de Premios - Concurso Con Premios'), findsOneWidget);
    expect(find.text('1er Lugar Alfarería'), findsOneWidget);
    expect(find.text('2do Lugar Alfarería'), findsOneWidget);
    expect(find.text('Premios Registrados (2)'), findsOneWidget);

    // 4. Deseleccionamos concurso (null)
    container.read(selectedConcursoIdProvider.notifier).state = null;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Selecciona un concurso para gestionar la bolsa de premios.'),
      findsOneWidget,
    );
    expect(find.text('1er Lugar Alfarería'), findsNothing);

    container.dispose();
  });
}
