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
  final List<Premio> premiosGuardados = [];
  final Map<int, List<Premio>> premiosPorConcurso;

  MockPremioRepository(this.premiosPorConcurso);

  @override
  Future<List<Premio>> getPremiosByConcurso(int idConcurso) async =>
      premiosPorConcurso[idConcurso] ?? [];

  @override
  Future<List<Map<String, dynamic>>> getTiposPremio() async => [
        {'id': 1, 'nombre': 'GALARDON'},
        {'id': 2, 'nombre': 'ESPECIAL'},
        {'id': 3, 'nombre': 'COMUN'},
      ];

  @override
  Future<List<Map<String, dynamic>>> getGanadoresByConcurso(int idConcurso) async =>
      [];

  @override
  Future<int> savePremio(Premio premio) async {
    premiosGuardados.add(premio);
    return premio.id ?? 999;
  }
}

void main() {
  testWidgets(
      'Formulario de registro de premio muestra input de límite de otorgación con valor default 1 y guarda correctamente',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final concurso = Concurso(
      id: 1,
      nombre: 'Concurso Prueba Límite',
      idTipoConcurso: 1,
      ejercicio: '2026',
      finalizado: false,
    );

    final mockConcursoRepo = MockConcursoRepository({1: concurso});
    final mockPremioRepo = MockPremioRepository({1: []});

    final container = ProviderContainer(
      overrides: [
        concursoRepositoryProvider.overrideWithValue(mockConcursoRepo),
        premioRepositoryProvider.overrideWithValue(mockPremioRepo),
      ],
    );

    container.read(selectedConcursoIdProvider.notifier).state = 1;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: PremiosView(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Abrir formulario de nuevo premio
    final btnNuevoPremio = find.widgetWithText(ElevatedButton, 'Nuevo Premio');
    expect(btnNuevoPremio, findsOneWidget);
    await tester.tap(btnNuevoPremio);
    await tester.pumpAndSettle();

    // Verificar que existe el campo Límite de Otorgación y su valor por defecto es '1'
    expect(find.text('Límite de Otorgación *'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    // Llenar campos requeridos
    // Monto
    final montoInput = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Monto (\$ MXN) *',
    );
    await tester.enterText(montoInput, '4500');

    // Nombre
    final nombreInput = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Nombre del Premio *',
    );
    await tester.enterText(nombreInput, 'Premio Especial Cerámica');

    // Cambiar el límite a 3
    final limiteInput = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.labelText == 'Límite de Otorgación *',
    );
    await tester.enterText(limiteInput, '3');
    await tester.pump();

    // Guardar
    final btnGuardar = find.widgetWithText(ElevatedButton, 'Guardar Premio');
    await tester.tap(btnGuardar);
    await tester.pumpAndSettle();

    // Verificar que el premio guardado tenga limiteOtorgacion = 3
    expect(mockPremioRepo.premiosGuardados.length, equals(1));
    final saved = mockPremioRepo.premiosGuardados.first;
    expect(saved.nombre, equals('Premio Especial Cerámica'));
    expect(saved.monto, equals(4500.0));
    expect(saved.limiteOtorgacion, equals(3));

    container.dispose();
  });
}
