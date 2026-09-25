import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:casart_concursos_desktop/models/concurso.dart';
import 'package:casart_concursos_desktop/models/categoria.dart';
import 'package:casart_concursos_desktop/models/subcategoria.dart';
import 'package:casart_concursos_desktop/models/registro_concurso.dart';
import 'package:casart_concursos_desktop/models/artesano.dart';
import 'package:casart_concursos_desktop/models/artesania.dart';
import 'package:casart_concursos_desktop/models/premio.dart';
import 'package:casart_concursos_desktop/models/concurso_estadisticas.dart';
import 'package:casart_concursos_desktop/providers/estadisticas_provider.dart';
import 'package:casart_concursos_desktop/views/concursos/estadisticas_concurso_view.dart';

void main() {
  group('Cálculo de Métricas Estadísticas de Concurso (ConcursoEstadisticas)', () {
    test('Calcula métricas correctamente para concurso vacío', () {
      final concurso = Concurso(
        id: 1,
        nombre: 'Concurso Sin Registros',
        ejercicio: '2026',
        lugar: 'Morelia',
        idTipoConcurso: 1,
        categorias: [
          Categoria(id: 1, nombre: 'Textiles', subcategorias: [
            Subcategoria(id: 1, idCategoria: 1, nombre: 'Lana'),
            Subcategoria(id: 2, idCategoria: 1, nombre: 'Algodón'),
          ]),
        ],
      );

      final stats = ConcursoEstadisticas.calcular(
        concurso: concurso,
        registros: [],
        premios: [
          Premio(id: 1, idConcurso: 1, nombre: 'Galardón 1', monto: 20000),
          Premio(id: 2, idConcurso: 1, nombre: 'Especial 1', monto: 10000),
        ],
      );

      expect(stats.totalArtesanos, equals(0));
      expect(stats.totalMunicipios, equals(0));
      expect(stats.totalPiezas, equals(0));
      expect(stats.totalHombres, equals(0));
      expect(stats.totalMujeres, equals(0));
      expect(stats.totalCategorias, equals(1));
      expect(stats.totalSubcategorias, equals(2));
      expect(stats.totalPremios, equals(2));
      expect(stats.bolsaPremios, equals(30000.0));
      expect(stats.etniasConteo, isEmpty);
      expect(stats.ramasConteo, isEmpty);
      expect(stats.municipiosConteo, isEmpty);
    });

    test('Calcula agregaciones con múltiples artesanos, piezas, géneros, etnias y municipios', () {
      final concurso = Concurso(
        id: 10,
        nombre: 'Concurso Estatal Michoacán 2026',
        ejercicio: '2026',
        lugar: 'Pátzcuaro',
        idTipoConcurso: 2,
        categorias: [
          Categoria(id: 1, nombre: 'Textiles', subcategorias: [
            Subcategoria(id: 1, idCategoria: 1, nombre: 'Bordados'),
          ]),
          Categoria(id: 2, nombre: 'Alfarería', subcategorias: []),
          Categoria(id: 3, nombre: 'Madera', subcategorias: [
            Subcategoria(id: 2, idCategoria: 3, nombre: 'Talla'),
            Subcategoria(id: 3, idCategoria: 3, nombre: 'Muebles'),
          ]),
        ],
      );

      final artesano1 = Artesano(
        id: 1,
        nombre: 'Pedro',
        apPaterno: 'Juarez',
        curp: 'JUAP800101HMN01',
        genero: 'MASCULINO',
        municipio: 'MORELIA',
        localidad: 'Morelia',
        etniaNombre: 'purépecha',
      );

      final artesano2 = Artesano(
        id: 2,
        nombre: 'María',
        apPaterno: 'Gomez',
        curp: 'GOMM850101MMN01',
        genero: 'F',
        municipio: 'pátzcuaro',
        localidad: 'Pátzcuaro',
        etniaNombre: 'Ninguna', // Debe normalizarse a 'Mestizo / Sin etnia'
      );

      final artesano3 = Artesano(
        id: 3,
        nombre: 'Elena',
        apPaterno: 'Lopez',
        curp: 'LOPE900101MMN01',
        genero: 'FEMENINO',
        municipio: 'Pátzcuaro',
        localidad: 'Pátzcuaro',
        etniaNombre: 'Otomí',
      );

      final pTextil1 = Artesania(
        id: 1,
        nombre: 'Rebozo Azul',
        costoProduccion: 500,
        costoVenta: 1200,
        tiempoElaboracion: 2,
        plazoElaboracion: 'semanas',
        materialElaboracion: 'Algodón',
        descripcion: 'Rebozo',
        idRamaArtesanal: 1,
        ramaNombre: 'Textiles',
        idCategoriaConcurso: 1,
      );

      final pAlfareria = Artesania(
        id: 2,
        nombre: 'Olla de Barro',
        costoProduccion: 300,
        costoVenta: 800,
        tiempoElaboracion: 1,
        plazoElaboracion: 'semanas',
        materialElaboracion: 'Barro',
        descripcion: 'Olla',
        idRamaArtesanal: 2,
        ramaNombre: 'Alfarería',
        idCategoriaConcurso: 2,
      );

      final pTextil2 = Artesania(
        id: 3,
        nombre: 'Camisa Bordada',
        costoProduccion: 400,
        costoVenta: 1000,
        tiempoElaboracion: 3,
        plazoElaboracion: 'semanas',
        materialElaboracion: 'Lino',
        descripcion: 'Camisa',
        idRamaArtesanal: 1,
        ramaNombre: 'Textiles',
        idCategoriaConcurso: 1,
      );

      final pMadera1 = Artesania(
        id: 4,
        nombre: 'Máscara Tallada',
        costoProduccion: 600,
        costoVenta: 1500,
        tiempoElaboracion: 4,
        plazoElaboracion: 'semanas',
        materialElaboracion: 'Madera',
        descripcion: 'Máscara',
        idRamaArtesanal: 3,
        ramaNombre: 'Madera',
        idCategoriaConcurso: 3,
      );

      final pMadera2 = Artesania(
        id: 5,
        nombre: 'Batea Decorada',
        costoProduccion: 450,
        costoVenta: 1100,
        tiempoElaboracion: 2,
        plazoElaboracion: 'semanas',
        materialElaboracion: 'Madera',
        descripcion: 'Batea',
        idRamaArtesanal: 3,
        ramaNombre: 'Madera',
        idCategoriaConcurso: 3,
      );

      final registros = [
        RegistroConcurso(
          id: 1,
          folio: 101,
          idArtesano: 1,
          idConcurso: 10,
          idArtesania1: 1,
          idArtesania2: 2,
          artesano: artesano1,
          artesania1: pTextil1,
          artesania2: pAlfareria,
        ),
        RegistroConcurso(
          id: 2,
          folio: 102,
          idArtesano: 2,
          idConcurso: 10,
          idArtesania1: 3,
          artesano: artesano2,
          artesania1: pTextil2,
        ),
        RegistroConcurso(
          id: 3,
          folio: 103,
          idArtesano: 3,
          idConcurso: 10,
          idArtesania1: 4,
          idArtesania2: 5,
          artesano: artesano3,
          artesania1: pMadera1,
          artesania2: pMadera2,
        ),
      ];

      final premios = [
        Premio(id: 1, idConcurso: 10, nombre: 'Galardón Michoacano', monto: 35000),
        Premio(id: 2, idConcurso: 10, nombre: 'Primer Lugar Textiles', monto: 12000),
        Premio(id: 3, idConcurso: 10, nombre: 'Primer Lugar Madera', monto: 12000),
      ];

      final stats = ConcursoEstadisticas.calcular(
        concurso: concurso,
        registros: registros,
        premios: premios,
      );

      // Verificaciones clave
      expect(stats.totalArtesanos, equals(3));
      expect(stats.totalPiezas, equals(5));
      expect(stats.totalHombres, equals(1));
      expect(stats.totalMujeres, equals(2));
      expect(stats.totalMunicipios, equals(2)); // Morelia y Pátzcuaro normalizados
      expect(stats.municipiosConteo['Pátzcuaro'], equals(2));
      expect(stats.municipiosConteo['Morelia'], equals(1));

      expect(stats.etniasConteo['Purépecha'], equals(1));
      expect(stats.etniasConteo['Mestizo / Sin etnia'], equals(1));
      expect(stats.etniasConteo['Otomí'], equals(1));

      expect(stats.ramasConteo['Textiles'], equals(2));
      expect(stats.ramasConteo['Madera'], equals(2));
      expect(stats.ramasConteo['Alfarería'], equals(1));

      expect(stats.totalCategorias, equals(3));
      expect(stats.totalSubcategorias, equals(3));
      expect(stats.totalPremios, equals(3));
      expect(stats.bolsaPremios, equals(59000.0));
    });
  });

  group('Widget Tests: EstadisticasConcursoView', () {
    testWidgets('Muestra la vista con banner, KPIs y desgloses', (tester) async {
      final testConcurso = Concurso(
        id: 99,
        nombre: 'Gran Concurso Michoacano',
        ejercicio: '2026',
        lugar: 'Pátzcuaro, Michoacán',
        idTipoConcurso: 1,
        finalizado: false,
        categorias: [
          Categoria(id: 1, nombre: 'Textiles Tradicionales', subcategorias: [
            Subcategoria(id: 1, idCategoria: 1, nombre: 'Algodón Hilado'),
          ]),
        ],
      );

      final dummyStats = ConcursoEstadisticas(
        concurso: testConcurso,
        totalArtesanos: 25,
        totalMunicipios: 8,
        totalPiezas: 42,
        totalCategorias: 4,
        totalSubcategorias: 7,
        totalPremios: 12,
        bolsaPremios: 150000.0,
        totalHombres: 10,
        totalMujeres: 15,
        etniasConteo: {
          'Purépecha': 15,
          'Mestizo / Sin etnia': 7,
          'Mazahua': 3,
        },
        ramasConteo: {
          'Textiles': 20,
          'Madera': 12,
          'Alfarería': 10,
        },
        municipiosConteo: {
          'Pátzcuaro': 12,
          'Morelia': 8,
          'Uruapan': 5,
        },
        categoriasConcurso: testConcurso.categorias,
      );

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            concursoEstadisticasProvider(99).overrideWith((ref) => dummyStats),
          ],
          child: MaterialApp(
            home: EstadisticasConcursoView(concurso: testConcurso),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar Título y Banner
      expect(find.text('Estadísticas del Concurso'), findsOneWidget);
      expect(find.text('Gran Concurso Michoacano'), findsWidgets);
      expect(find.text('Ejercicio Fiscal: 2026'), findsOneWidget);
      expect(find.text('EN PROCESO'), findsOneWidget);
      expect(find.text('Estadísticas Generales'), findsOneWidget);

      // Verificar KPIs
      expect(find.text('ARTESANOS PARTICIPANTES'), findsOneWidget);
      expect(find.text('25'), findsWidgets);
      expect(find.text('MUNICIPIOS PARTICIPANTES'), findsOneWidget);
      expect(find.text('8'), findsWidgets);
      expect(find.text('PIEZAS INSCRITAS'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('CATEGORÍAS / SUBCATEGORÍAS'), findsOneWidget);
      expect(find.text('4 cat. / 7 subcat.'), findsOneWidget);
      expect(find.text('PREMIOS CONFIGURADOS'), findsOneWidget);
      expect(find.text('12'), findsWidgets);
      expect(find.text('BOLSA DE PREMIACIÓN'), findsOneWidget);
      expect(find.text('\$150,000.00'), findsOneWidget);

      // Verificar Desgloses
      expect(find.text('Artesanos por Pueblo Indígena / Etnia'), findsOneWidget);
      expect(find.text('3 grupos'), findsOneWidget);
      expect(find.text('Purépecha'), findsOneWidget);

      expect(find.text('Distribución por Género'), findsOneWidget);
      expect(find.text('HOMBRES'), findsOneWidget);
      expect(find.text('10'), findsWidgets);
      expect(find.text('MUJERES'), findsOneWidget);
      expect(find.text('15'), findsWidgets);

      expect(find.text('Piezas por Rama Artesanal'), findsOneWidget);
      expect(find.text('Textiles'), findsOneWidget);

      expect(find.text('Municipios de Origen'), findsOneWidget);
      expect(find.text('8 municipios'), findsOneWidget);
      expect(find.text('Pátzcuaro'), findsWidgets);

      expect(find.text('Categorías y Subcategorías'), findsOneWidget);
      expect(find.text('Textiles Tradicionales'), findsOneWidget);
      expect(find.text('Algodón Hilado'), findsOneWidget);

      // Verificar botón de exportación Excel
      expect(find.text('Exportar Excel'), findsOneWidget);
    });
  });
}
