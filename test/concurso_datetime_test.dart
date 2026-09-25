import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:casart_concursos_desktop/core/utils/formatters.dart';
import 'package:casart_concursos_desktop/models/concurso.dart';
import 'package:casart_concursos_desktop/views/concursos/concurso_form_dialog.dart';
import 'package:casart_concursos_desktop/providers/database_provider.dart';
import 'package:casart_concursos_desktop/repositories/concurso_repository.dart';

class MockConcursoRepository extends ConcursoRepository {
  @override
  Future<List<Map<String, dynamic>>> getTiposConcurso() async {
    return [
      {'id': 1, 'nombre': 'Regional'},
      {'id': 2, 'nombre': 'Estatal'},
      {'id': 3, 'nombre': 'Nacional'},
    ];
  }
}

void main() {
  group('Pruebas de Formato de Dictamen y Premiación con Hora', () {
    test('Formatters.formatDateTime formatea fechas con hora correctamente', () {
      final formatted = Formatters.formatDateTime('2026-09-23 15:30');
      expect(formatted, '23/09/2026 15:30');
    });

    test('Formatters.formatDateTime preserva fechas sin hora como dd/MM/yyyy', () {
      final formatted = Formatters.formatDateTime('2026-09-23');
      expect(formatted, '23/09/2026');
    });

    test('Formatters.formatDateTime maneja cadenas nulas o vacías', () {
      expect(Formatters.formatDateTime(null), 'N/A');
      expect(Formatters.formatDateTime(''), 'N/A');
    });

    test('Concurso model almacena y serializa fechaDictamen y fechaPremiacion con hora', () {
      final concurso = Concurso(
        id: 1,
        nombre: 'Concurso Estatal 2026',
        idTipoConcurso: 1,
        ejercicio: '2026',
        fechaDictamen: '2026-10-15 16:00',
        fechaPremiacion: '2026-10-16 18:30',
      );

      final dbMap = concurso.toDbMap();
      expect(dbMap['fecha_dictamen'], '2026-10-15 16:00');
      expect(dbMap['fecha_premiacion'], '2026-10-16 18:30');

      final deserialized = Concurso.fromMap(dbMap);
      expect(deserialized.fechaDictamen, '2026-10-15 16:00');
      expect(deserialized.fechaPremiacion, '2026-10-16 18:30');
    });

    testWidgets('ConcursoFormDialog muestra campos Dictamen y Premiación con soporte de Fecha/Hora', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockRepo = MockConcursoRepository();
      final concursoPrueba = Concurso(
        id: 10,
        nombre: 'Concurso Textil 2026',
        idTipoConcurso: 1,
        lugar: 'Pátzcuaro',
        ejercicio: '2026',
        fechaDictamen: '2026-11-20 17:30',
        fechaPremiacion: '2026-11-21 19:00',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            concursoRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('es', 'MX'), Locale('en', 'US')],
            home: Scaffold(
              body: ConcursoFormDialog(concursoToEdit: concursoPrueba),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar que los labels de los campos con fecha/hora están presentes
      expect(find.text('Dictamen (Fecha/Hora) *'), findsOneWidget);
      expect(find.text('Premiación (Fecha/Hora) *'), findsOneWidget);

      // Verificar que los valores de fecha con hora se cargaron en los inputs
      expect(find.text('2026-11-20 17:30'), findsOneWidget);
      expect(find.text('2026-11-21 19:00'), findsOneWidget);
    });
  });
}
