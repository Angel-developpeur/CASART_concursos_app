import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:casart_concursos_desktop/models/concurso.dart';
import 'package:casart_concursos_desktop/models/categoria.dart';
import 'package:casart_concursos_desktop/models/artesano.dart';
import 'package:casart_concursos_desktop/models/artesania.dart';
import 'package:casart_concursos_desktop/models/registro_concurso.dart';
import 'package:casart_concursos_desktop/repositories/artesano_repository.dart';
import 'package:casart_concursos_desktop/repositories/concurso_repository.dart';
import 'package:casart_concursos_desktop/repositories/registro_repository.dart';
import 'package:casart_concursos_desktop/providers/database_provider.dart';
import 'package:casart_concursos_desktop/providers/concursos_provider.dart';
import 'package:casart_concursos_desktop/providers/inscripcion_provider.dart';
import 'package:casart_concursos_desktop/views/inscripcion/inscripcion_view.dart';
import 'package:casart_concursos_desktop/views/inscripcion/comprobante_dialog.dart';

class _MockConcursoRepo extends ConcursoRepository {
  final Concurso concurso;
  _MockConcursoRepo(this.concurso);

  @override
  Future<Concurso?> getConcursoById(int id) async =>
      concurso.id == id ? concurso : null;
}

class _MockArtesanoRepo extends ArtesanoRepository {
  final List<Artesano> artesanos;
  _MockArtesanoRepo(this.artesanos);

  @override
  Future<List<Map<String, dynamic>>> getRamasArtesanales() async => [
        {'id': 1, 'nombre': 'Alfarería'},
      ];

  @override
  Future<List<Map<String, dynamic>>> getEtnias() async => [
        {'id': 1, 'nombre': 'Purépecha'},
        {'id': 2, 'nombre': 'Otomí'},
      ];

  @override
  Future<List<Map<String, dynamic>>> getEstadosCiviles() async => [
        {'id': 1, 'nombre': 'Casado(a)'},
      ];

  @override
  Future<Map<String, List<String>>> getSugerenciasFormulario() async => {};

  @override
  Future<List<Artesano>> searchArtesanos({
    String? query,
    int limit = 50,
  }) async {
    final q = (query ?? '').trim().toUpperCase();
    return artesanos
        .where((a) => a.id?.toString() == q || a.curp.toUpperCase().contains(q))
        .take(limit)
        .toList();
  }
}

class _MockRegistroRepo extends RegistroRepository {
  int savedCount = 0;
  Artesano? lastSavedArtesano;

  @override
  Future<int> getNextFolio(int idConcurso) async => savedCount + 1;

  @override
  Future<RegistroConcurso?> getRegistroByCurp({
    required int idConcurso,
    required String curp,
  }) async =>
      null;

  @override
  Future<List<RegistroConcurso>> getRegistrosByConcurso(
    int idConcurso, {
    String? search,
  }) async =>
      [];

  @override
  Future<RegistroConcurso> registrarInscripcion({
    required int idConcurso,
    required Artesano artesano,
    required bool esNuevoArtesano,
    required Artesania pieza1,
    Artesania? pieza2,
  }) async {
    savedCount++;
    lastSavedArtesano = artesano;
    return RegistroConcurso(
      id: savedCount,
      folio: savedCount,
      idArtesano: artesano.id ?? 1,
      idConcurso: idConcurso,
      idArtesania1: 1,
      artesano: artesano,
      artesania1: pieza1,
      artesania2: pieza2,
    );
  }
}

class _FixedConcursoIdNotifier extends SelectedConcursoIdNotifier {
  final int? initialId;
  _FixedConcursoIdNotifier(this.initialId);

  @override
  int? build() => initialId;
}

void main() {
  group('InscripcionView - Atajos de teclado y Autofocus inteligente', () {
    testWidgets(
      'Soporta autofocus inicial, Alt+N, Alt+B, F2, Alt+2, Ctrl+Enter y re-enfoque al cerrar ComprobanteDialog',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final concurso = Concurso(
          id: 1,
          nombre: 'Concurso de Alfarería 2026',
          ejercicio: '2026',
          lugar: 'Patamban, Michoacán',
          idTipoConcurso: 1,
          iva: 16.0,
          utilidad: 10.0,
          categorias: [
            Categoria(
              id: 1,
              idConcurso: 1,
              nombre: 'Barro Bruñido',
              subcategorias: [],
            ),
          ],
        );

        final artesanoExistente = Artesano(
          id: 7,
          nombre: 'Pedro',
          apPaterno: 'Martínez',
          apMaterno: 'López',
          curp: 'MALP800101HMNRRL09',
          fechaNacimiento: '1980-01-01',
          genero: 'M',
          telefono: '4521234567',
          municipio: 'Tangancícuaro',
          localidad: 'Patamban',
          codigoPostal: '59760',
          idEtnia: 1,
          idEstadoCivil: 1,
          nivelEducativo: '3',
        );

        final mockRegRepo = _MockRegistroRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              selectedConcursoIdProvider.overrideWith(
                () => _FixedConcursoIdNotifier(1),
              ),
              concursoRepositoryProvider.overrideWithValue(
                _MockConcursoRepo(concurso),
              ),
              artesanoRepositoryProvider.overrideWithValue(
                _MockArtesanoRepo([artesanoExistente]),
              ),
              registroRepositoryProvider.overrideWithValue(mockRegRepo),
              nextFolioProvider.overrideWith((ref) async => 1),
            ],
            child: const MaterialApp(
              home: InscripcionView(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verificar autofocus inicial en el buscador de CURP
        final searchFieldFinder = find.widgetWithText(
          TextField,
          'Ingresa ID o CURP del artesano...',
        );
        expect(searchFieldFinder, findsOneWidget);
        final searchField = tester.widget<TextField>(searchFieldFinder);
        expect(searchField.focusNode?.hasFocus, isTrue);

        // 2. Presionar Alt + N -> cambia a "Nuevo Artesano" y enfoca "Nombre(s) *"
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Captura los datos del nuevo artesano'),
          findsOneWidget,
        );
        final nombreEditableFinder = find.descendant(
          of: find.widgetWithText(TextFormField, 'Nombre(s) *'),
          matching: find.byType(EditableText),
        );
        expect(
          tester.widget<EditableText>(nombreEditableFinder).focusNode.hasFocus,
          isTrue,
        );

        // 3. Presionar Alt + B -> regresa a "Buscar Registrado" y enfoca el buscador de CURP
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyB);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pumpAndSettle();

        expect(
          tester.widget<TextField>(searchFieldFinder).focusNode?.hasFocus,
          isTrue,
        );

        // 4. Buscar artesano existente -> carga datos y salta el foco a "Nombre de la Artesanía *"
        await tester.enterText(searchFieldFinder, 'MALP800101HMNRRL09');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(find.text('Pedro Martínez López'), findsOneWidget);
        final p1EditableFinder = find.descendant(
          of: find.widgetWithText(TextFormField, 'Nombre de la Artesanía *'),
          matching: find.byType(EditableText),
        );
        expect(
          tester.widget<EditableText>(p1EditableFinder).focusNode.hasFocus,
          isTrue,
        );

        // 5. Presionar F2 -> enfoca el buscador de CURP inmediatamente
        await tester.sendKeyEvent(LogicalKeyboardKey.f2);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(searchFieldFinder).focusNode?.hasFocus,
          isTrue,
        );

        // 6. Presionar Alt + 2 -> activa Segunda Pieza y enfoca "Nombre de la Pieza 2 *"
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.digit2);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.digit2);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pumpAndSettle();

        final p2FieldFinder = find.widgetWithText(
          TextFormField,
          'Nombre de la Pieza 2 *',
        );
        expect(p2FieldFinder, findsOneWidget);
        final p2EditableFinder = find.descendant(
          of: p2FieldFinder,
          matching: find.byType(EditableText),
        );
        expect(
          tester.widget<EditableText>(p2EditableFinder).focusNode.hasFocus,
          isTrue,
        );

        // Presionar Alt + 2 de nuevo -> desactiva Segunda Pieza
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.digit2);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.digit2);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pumpAndSettle();
        expect(p2FieldFinder, findsNothing);

        // 7. Llenar datos de Pieza 1 y guardar usando el atajo Ctrl + Enter
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre de la Artesanía *'),
          'Olla de Barro Verde',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Costo Producción (\$ MXN) *'),
          '800',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Tiempo Elaboración *'),
          '2',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Material de Elaboración *'),
          'Barro natural',
        );

        // Seleccionar Rama Artesanal y Categoría de la Pieza 1
        final p1RamaFinder = find.byKey(const ValueKey('p1_rama'));
        await tester.ensureVisible(p1RamaFinder);
        await tester.pumpAndSettle();
        await tester.tap(p1RamaFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Alfarería').last);
        await tester.pumpAndSettle();

        final p1CatFinder = find.byKey(const ValueKey('p1_cat_1'));
        await tester.ensureVisible(p1CatFinder);
        await tester.pumpAndSettle();
        await tester.tap(p1CatFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Barro Bruñido').last);
        await tester.pumpAndSettle();

        // Disparar Ctrl + Enter para guardar e imprimir
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(mockRegRepo.savedCount, equals(1));
        expect(find.byType(ComprobanteDialog), findsOneWidget);

        // 8. Cerrar ComprobanteDialog y verificar que el foco regresa automáticamente al buscador de CURP
        final dialogContext = tester.element(find.byType(ComprobanteDialog));
        Navigator.of(dialogContext).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(ComprobanteDialog), findsNothing);
        expect(
          tester.widget<TextField>(searchFieldFinder).focusNode?.hasFocus,
          isTrue,
        );
      },
    );

    testWidgets(
      'Permite fijar (Pin) Municipio, Localidad y Etnia entre registros y cambiarlos cuando un artesano tiene otros datos',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final concurso = Concurso(
          id: 1,
          nombre: 'Concurso Regional de Patamban',
          ejercicio: '2026',
          lugar: 'Patamban, Michoacán',
          idTipoConcurso: 1,
          iva: 16.0,
          utilidad: 20.0,
          categorias: [
            Categoria(
              id: 1,
              idConcurso: 1,
              nombre: 'Barro Bruñido',
              subcategorias: [],
            ),
          ],
        );

        final artesanoOtroMunicipio = Artesano(
          id: 99,
          nombre: 'Lucía',
          apPaterno: 'Gómez',
          apMaterno: 'Ruiz',
          curp: 'GORL900505MMNRRL01',
          fechaNacimiento: '1990-05-05',
          genero: 'F',
          telefono: '4439876543',
          municipio: 'Morelia',
          localidad: 'Capula',
          codigoPostal: '58330',
          idEtnia: 2,
          idEstadoCivil: 1,
          nivelEducativo: '4',
        );

        final mockRegRepo = _MockRegistroRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              selectedConcursoIdProvider.overrideWith(
                () => _FixedConcursoIdNotifier(1),
              ),
              concursoRepositoryProvider.overrideWithValue(
                _MockConcursoRepo(concurso),
              ),
              artesanoRepositoryProvider.overrideWithValue(
                _MockArtesanoRepo([artesanoOtroMunicipio]),
              ),
              registroRepositoryProvider.overrideWithValue(mockRegRepo),
              nextFolioProvider.overrideWith((ref) async => 1),
            ],
            child: const MaterialApp(
              home: InscripcionView(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Cambiar a modo "Nuevo Artesano" (Alt + N)
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pumpAndSettle();

        // 2. Seleccionar Etnia = Purépecha y fijarla (Pin)
        final etniaFinder = find.byKey(const ValueKey('art_etnia'));
        await tester.ensureVisible(etniaFinder);
        await tester.pumpAndSettle();
        await tester.tap(etniaFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Purépecha').last);
        await tester.pumpAndSettle();
        expect(find.text('Purépecha'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('pin_etnia')));
        await tester.pumpAndSettle();
        expect(find.text('Fijados: Etnia'), findsOneWidget);

        // 3. Seleccionar Municipio y Localidad y fijar Localidad (lo cual auto-fija Municipio también)
        final munFinder = find.byKey(const ValueKey('art_mun'));
        await tester.ensureVisible(munFinder);
        await tester.pumpAndSettle();
        await tester.tap(munFinder);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(
            TextField,
            'Escribe una letra o nombre del municipio...',
          ),
          'Tangancicuaro',
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // Ahora seleccionar Localidad = Patamban
        final locFinder = find.byKey(const ValueKey('art_loc'));
        await tester.ensureVisible(locFinder);
        await tester.pumpAndSettle();
        await tester.tap(locFinder);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(
            TextField,
            'Escribe una letra o nombre de la localidad...',
          ),
          'Patamban',
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // Fijar Localidad (debe fijar automáticamente Municipio y Localidad)
        await tester.tap(find.byKey(const ValueKey('pin_localidad')));
        await tester.pumpAndSettle();
        expect(
          find.text('Fijados: Etnia, Municipio, Localidad'),
          findsOneWidget,
        );

        // 4. Si se busca un artesano de OTRO municipio/localidad/etnia (Morelia / Capula / Otomí),
        // debe permitir cambiar/mostrar sus propios datos y guardarlos correctamente
        await tester.sendKeyEvent(LogicalKeyboardKey.f2);
        await tester.pumpAndSettle();

        final searchFieldFinder = find.widgetWithText(
          TextField,
          'Ingresa ID o CURP del artesano...',
        );
        await tester.enterText(searchFieldFinder, 'GORL900505MMNRRL01');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(find.text('Lucía Gómez Ruiz'), findsOneWidget);
        expect(find.text('Capula'), findsOneWidget);

        // Llenar Pieza 1 y guardar con Ctrl + Enter
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre de la Artesanía *'),
          'Catrina de Capula',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Costo Producción (\$ MXN) *'),
          '1200',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Tiempo Elaboración *'),
          '3',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Material de Elaboración *'),
          'Barro policromado',
        );

        final p1RamaFinder = find.byKey(const ValueKey('p1_rama'));
        await tester.ensureVisible(p1RamaFinder);
        await tester.pumpAndSettle();
        await tester.tap(p1RamaFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Alfarería').last);
        await tester.pumpAndSettle();

        final p1CatFinder = find.byKey(const ValueKey('p1_cat_1'));
        await tester.ensureVisible(p1CatFinder);
        await tester.pumpAndSettle();
        await tester.tap(p1CatFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Barro Bruñido').last);
        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(mockRegRepo.savedCount, equals(1));
        expect(mockRegRepo.lastSavedArtesano?.localidad, equals('Capula'));
        expect(mockRegRepo.lastSavedArtesano?.idEtnia, equals(2));

        // Cerrar ComprobanteDialog
        final dialogContext = tester.element(find.byType(ComprobanteDialog));
        Navigator.of(dialogContext).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        // 5. Al pasar al siguiente "Nuevo Artesano" (Alt + N), los valores fijados
        // (Purépecha, Tangancícuaro y Patamban) siguen conservados automáticamente
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pumpAndSettle();

        expect(
          find.text('Fijados: Etnia, Municipio, Localidad'),
          findsOneWidget,
        );
        expect(find.text('Patamban'), findsOneWidget);
        expect(find.text('Purépecha'), findsWidgets);

        // 6. Probar botón "Desfijar todos" y limpiar formulario
        final desfijarFinder = find.byKey(const ValueKey('btn_desfijar_todos'));
        await tester.ensureVisible(desfijarFinder);
        await tester.pumpAndSettle();
        await tester.tap(desfijarFinder);
        await tester.pumpAndSettle();

        expect(
          find.text('Fijados: Etnia, Municipio, Localidad'),
          findsNothing,
        );
      },
    );
  });
}
