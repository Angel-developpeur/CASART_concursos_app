import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:casart_concursos_desktop/core/database/app_database.dart';
import 'package:casart_concursos_desktop/models/concurso.dart';
import 'package:casart_concursos_desktop/models/categoria.dart';
import 'package:casart_concursos_desktop/models/artesano.dart';
import 'package:casart_concursos_desktop/repositories/artesano_repository.dart';
import 'package:casart_concursos_desktop/repositories/concurso_repository.dart';
import 'package:casart_concursos_desktop/repositories/registro_repository.dart';
import 'package:casart_concursos_desktop/providers/database_provider.dart';
import 'package:casart_concursos_desktop/providers/concursos_provider.dart';
import 'package:casart_concursos_desktop/providers/inscripcion_provider.dart';

class MockConcursoIdNotifier extends SelectedConcursoIdNotifier {
  final int? initialId;
  MockConcursoIdNotifier(this.initialId);
  @override
  int? build() => initialId;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Inscripción - Búsqueda y Edición de Artesano en UI', () {
    testWidgets('Al buscar un artesano existente se muestran los inputs del formulario llenos y editables', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 9,
          onCreate: AppDatabase().onCreate,
          onUpgrade: AppDatabase().onUpgrade,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );

      final dbHelper = AppDatabase.withDatabase(db);
      final concursoRepo = ConcursoRepository(dbHelper: dbHelper);
      final artesanoRepo = ArtesanoRepository(dbHelper: dbHelper);
      final registroRepo = RegistroRepository(dbHelper: dbHelper);

      // 1. Crear concurso de prueba
      final concursoId = await concursoRepo.createConcurso(
        Concurso(
          nombre: 'Concurso Estatal Michoacán 2026',
          idTipoConcurso: 1,
          iva: 16.0,
          utilidad: 10.0,
          categorias: [
            Categoria(
              nombre: 'Textiles',
              subcategorias: [],
            ),
          ],
        ),
      );
      final concurso = await concursoRepo.getConcursoById(concursoId);

      // 2. Crear artesano previo en la base de datos
      final artesanoId = await artesanoRepo.createArtesano(
        Artesano(
          nombre: 'Gabriel',
          apPaterno: 'Hernández',
          curp: 'HERG850101MNZRRP01',
          genero: 'M',
          fechaNacimiento: '1985-01-01',
          municipio: 'Morelia',
          localidad: 'Morelia',
          codigoPostal: '58000',
          idEtnia: 1,
          idEstadoCivil: 1,
          nivelEducativo: '3',
        ),
      );

      // 3. Montar la vista InscripcionView con Providers sobreescritos
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(dbHelper),
            artesanoRepositoryProvider.overrideWithValue(artesanoRepo),
            registroRepositoryProvider.overrideWithValue(registroRepo),
            concursoRepositoryProvider.overrideWithValue(concursoRepo),
            selectedConcursoIdProvider.overrideWith(() => 1),
            selectedConcursoProvider.overrideWith((ref) => concurso),
            nextFolioProvider.overrideWith((ref) => 1),
            registrosConcursoProvider.overrideWith((ref) => []),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: InscripcionView(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verificar que inicialmente "Buscar Registrado" está seleccionado y muestra el buscador
      expect(find.text('1. Datos del Artesano'), findsOneWidget);
      expect(find.text('Buscar Registrado'), findsOneWidget);
      expect(find.text('Ingresa ID o CURP del artesano...'), findsOneWidget);
      expect(find.textContaining('Ingresa la CURP o ID del artesano registrado'), findsOneWidget);

      // Los campos de texto del formulario aún no están visibles
      expect(find.text('Primer Apellido *'), findsNothing);

      // 4. Buscar el artesano por CURP
      await tester.enterText(
        find.widgetWithText(TextField, 'Ingresa ID o CURP del artesano...'),
        'HERG850101MNZRRP01',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Buscar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 5. Verificar que ahora SÍ se muestran los inputs del formulario y están prellenados con su información
      expect(find.text('Artesano Registrado (ID: $artesanoId)'), findsOneWidget);
      expect(find.textContaining('Los datos del artesano han sido cargados en los campos de abajo'), findsOneWidget);
      expect(find.text('Cambiar'), findsOneWidget);

      // Inputs de registro visibles con los valores cargados
      expect(find.text('Gabriel'), findsOneWidget);
      expect(find.text('Hernández'), findsOneWidget);
      expect(find.text('HERG850101MNZRRP01'), findsOneWidget);
      expect(find.text('1985-01-01'), findsOneWidget);
      expect(find.text('58000'), findsOneWidget);

      // 6. El usuario edita la información en los inputs (ej. agrega segundo nombre y teléfono)
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre(s) *'),
        'Gabriel Antonio',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Teléfono de Contacto (Opcional)'),
        '4431234567',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Gabriel Antonio'), findsOneWidget);
      expect(find.text('4431234567'), findsOneWidget);

      // 7. Probar botón "Cambiar": debe limpiar los datos y volver a la búsqueda
      await tester.tap(find.text('Cambiar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Gabriel Antonio'), findsNothing);
      expect(find.textContaining('Ingresa la CURP o ID del artesano registrado'), findsOneWidget);
    });
  });
}
