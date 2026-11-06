import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:casart_concursos_desktop/models/concurso.dart';
import 'package:casart_concursos_desktop/models/categoria.dart';
import 'package:casart_concursos_desktop/models/artesano.dart';
import 'package:casart_concursos_desktop/models/artesania.dart';
import 'package:casart_concursos_desktop/models/premio.dart';
import 'package:casart_concursos_desktop/models/registro_concurso.dart';
import 'package:casart_concursos_desktop/repositories/artesano_repository.dart';
import 'package:casart_concursos_desktop/repositories/concurso_repository.dart';
import 'package:casart_concursos_desktop/repositories/premio_repository.dart';
import 'package:casart_concursos_desktop/repositories/registro_repository.dart';
import 'package:casart_concursos_desktop/providers/database_provider.dart';
import 'package:casart_concursos_desktop/providers/concursos_provider.dart';
import 'package:casart_concursos_desktop/providers/inscripcion_provider.dart';
import 'package:casart_concursos_desktop/providers/ui_zoom_provider.dart';
import 'package:casart_concursos_desktop/views/shell/app_shell.dart';
import 'package:casart_concursos_desktop/views/inscripcion/premiar_pieza_dialog.dart';
import 'package:casart_concursos_desktop/views/inscripcion/editar_inscripcion_dialog.dart';

class _FakeConcursoRepo extends ConcursoRepository {
  final List<Concurso> items;
  _FakeConcursoRepo(this.items);

  @override
  Future<List<Concurso>> getConcursos({
    String? search,
    String? ejercicio,
    bool? finalizado,
  }) async =>
      items;

  @override
  Future<Concurso?> getConcursoById(int id) async =>
      items.where((c) => c.id == id).firstOrNull;
}

class _FakeArtesanoRepo extends ArtesanoRepository {
  @override
  Future<List<Map<String, dynamic>>> getRamasArtesanales() async => [
        {'id': 1, 'nombre': 'Alfarería Policromada y Vidriada Tradicional'},
      ];

  @override
  Future<List<Map<String, dynamic>>> getEtnias() async => [
        {'id': 1, 'nombre': 'Purépecha'},
      ];

  @override
  Future<List<Map<String, dynamic>>> getEstadosCiviles() async => [
        {'id': 1, 'nombre': 'Soltero(a)'},
      ];

  @override
  Future<Map<String, List<String>>> getSugerenciasFormulario() async => {};
}

class _FakeRegistroRepo extends RegistroRepository {
  final List<RegistroConcurso> registros;
  _FakeRegistroRepo(this.registros);

  @override
  Future<int> getNextFolio(int idConcurso) async => 1;

  @override
  Future<List<RegistroConcurso>> getRegistrosByConcurso(
    int idConcurso, {
    String? search,
  }) async =>
      registros;
}

class _FakePremioRepo extends PremioRepository {
  final List<Premio> premios;
  final List<Map<String, dynamic>> ganadores;
  _FakePremioRepo(this.premios, this.ganadores);

  @override
  Future<List<Premio>> getPremiosByConcurso(int idConcurso) async => premios;

  @override
  Future<List<Map<String, dynamic>>> getGanadoresByConcurso(
    int idConcurso,
  ) async =>
      ganadores;

  @override
  Future<Map<int, int>> getConteoPremiosOtorgados(int idConcurso) async => {
        1: 1,
      };
}

class _MaxZoomNotifier extends UiZoomNotifier {
  @override
  double build() => UiZoomNotifier.zoomSteps.last; // 1.35 (135%)
}

class _SelectedConcursoNotifier extends SelectedConcursoIdNotifier {
  final int? initialId;
  _SelectedConcursoNotifier(this.initialId);

  @override
  int? build() => initialId;
}

void main() {
  testWidgets(
    'Renderiza todas las vistas principales y diálogos en el zoom máximo (135%) sin errores de RenderFlex overflow ni ListTile',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final concurso = Concurso(
        id: 1,
        nombre:
            'LIV Concurso Estatal de Artesanías de Domingo de Ramos de Uruapan Michoacán',
        ejercicio: '2026',
        lugar:
            'Uruapan, Michoacán de Ocampo (Plaza Morelos y Centro Histórico)',
        idTipoConcurso: 1,
        tipoConcursoNombre: 'Concurso Estatal y Regional',
        fechaInicioRegistro: '2026-03-15',
        fechaLimiteRegistro: '2026-03-28',
        iva: 16.0,
        utilidad: 10.0,
        finalizado: false,
        categorias: [
          Categoria(
            id: 1,
            idConcurso: 1,
            nombre: 'Maestros Artesanos en Alfarería Policromada',
            subcategorias: [],
          ),
        ],
      );

      final artesano = Artesano(
        id: 10,
        nombre: 'María Guadalupe',
        apPaterno: 'Hernández',
        apMaterno: 'Solís',
        curp: 'HESG850515MMNRRL01',
        genero: 'F',
        fechaNacimiento: '1985-05-15',
        municipio: 'Uruapan',
        localidad: 'Capácuaro',
        idEtnia: 1,
        idEstadoCivil: 1,
        nivelEducativo: 'Secundaria comp.',
      );

      final pieza1 = Artesania(
        id: 100,
        nombre: 'Olla de Barro Bruñido con Decoración Floral al Pastillaje',
        costoProduccion: 1500,
        costoVenta: 1890,
        tiempoElaboracion: 3,
        plazoElaboracion: 'semanas',
        materialElaboracion: 'Barro natural y pigmentos minerales',
        descripcion: 'Olla tradicional policromada',
        idRamaArtesanal: 1,
        idCategoriaConcurso: 1,
      );

      final registro = RegistroConcurso(
        id: 1,
        folio: 1,
        idArtesano: 10,
        idConcurso: 1,
        idArtesania1: 100,
        artesano: artesano,
        artesania1: pieza1,
      );

      final premios = [
        Premio(
          id: 1,
          idConcurso: 1,
          nombre: 'Galardón Estatal de Alfarería Tradicional',
          monto: 25000,
          idCategoria: 1,
          categoriaNombre: 'Maestros Artesanos en Alfarería Policromada',
          limiteOtorgacion: 2,
        ),
      ];

      final ganadores = [
        {
          'premio_id': 1,
          'premio_nombre': 'Galardón Estatal de Alfarería Tradicional',
          'monto': 25000.0,
          'categoria_nombre': 'Maestros Artesanos en Alfarería Policromada',
          'folio': 1,
          'pieza_nombre': pieza1.nombre,
          'artesano_nombre': artesano.nombreCompleto,
          'localidad': 'Capácuaro',
          'municipio': 'Uruapan',
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uiZoomProvider.overrideWith(_MaxZoomNotifier.new),
            selectedConcursoIdProvider.overrideWith(
              () => _SelectedConcursoNotifier(1),
            ),
            concursoRepositoryProvider.overrideWithValue(
              _FakeConcursoRepo([concurso]),
            ),
            artesanoRepositoryProvider.overrideWithValue(_FakeArtesanoRepo()),
            registroRepositoryProvider.overrideWithValue(
              _FakeRegistroRepo([registro]),
            ),
            premioRepositoryProvider.overrideWithValue(
              _FakePremioRepo(premios, ganadores),
            ),
            nextFolioProvider.overrideWith((ref) async => 1),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final zoom = ref.watch(uiZoomProvider);
              return MaterialApp(
                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(zoom),
                    ),
                    child: child!,
                  );
                },
                home: const AppShell(),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Vista Concursos (abierta por defecto)
      expect(find.textContaining('LIV Concurso Estatal'), findsWidgets);

      // 2. Navegar a Inscripción de Piezas
      await tester.tap(find.text('Inscripción de Piezas'));
      await tester.pumpAndSettle();

      // Cambiar a "Nuevo Artesano" para mostrar el formulario completo
      await tester.tap(find.text('Nuevo Artesano'));
      await tester.pumpAndSettle();
      expect(find.text('Nombre(s) *'), findsOneWidget);

      // Cambiar a la pestaña de listado de piezas inscritas
      await tester.tap(find.textContaining('Piezas Inscritas'));
      await tester.pumpAndSettle();

      // 3. Navegar a Bolsa de Premios (en 1280x800 y en 1600x900 para probar modo 2 columnas en 135%)
      await tester.tap(find.text('Bolsa de Premios'));
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(1600, 900);
      await tester.pumpAndSettle();

      // 4. Navegar a Respaldos y Excel (en 1600x900 y 1024x768)
      await tester.tap(find.text('Respaldos y Excel'));
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpAndSettle();

      // 5. Navegar a Tutorial y Guía
      await tester.tap(find.text('Tutorial y Guía'));
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();

      // 6. Probar PremiarPiezaDialog y EditarInscripcionDialog en zoom 135%
      final navContext = tester.element(find.byType(AppShell));
      showDialog(
        context: navContext,
        builder: (_) => PremiarPiezaDialog(
          registro: registro,
          concurso: concurso,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sin Premio (Ninguno / Quitar premio)'), findsOneWidget);
      Navigator.of(navContext).pop();
      await tester.pumpAndSettle();

      showDialog(
        context: navContext,
        builder: (_) => EditarInscripcionDialog(
          registro: registro,
          concurso: concurso,
        ),
      );
      await tester.pumpAndSettle();
      Navigator.of(navContext).pop();
      await tester.pumpAndSettle();
    },
  );
}
