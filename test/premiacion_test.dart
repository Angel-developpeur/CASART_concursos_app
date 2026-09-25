import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:casart_concursos_desktop/core/database/app_database.dart';
import 'package:casart_concursos_desktop/repositories/premio_repository.dart';
import 'package:casart_concursos_desktop/repositories/registro_repository.dart';

class _FakeDbHelper implements AppDatabase {
  final Database db;
  _FakeDbHelper(this.db);

  @override
  Future<Database> get database async => db;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Pruebas de Premiación de Piezas y Límite de Otorgación', () {
    late Database db;
    late PremioRepository premioRepo;
    late RegistroRepository registroRepo;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: AppDatabase().onCreate,
          onUpgrade: AppDatabase().onUpgrade,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );

      final fakeHelper = _FakeDbHelper(db);
      premioRepo = PremioRepository(dbHelper: fakeHelper);
      registroRepo = RegistroRepository(dbHelper: fakeHelper);

      // Seed data básica
      await db.execute("INSERT OR IGNORE INTO tipo_concurso (id, nombre) VALUES (1, 'Estatal')");
      await db.execute('''
        INSERT INTO concurso (
          id, nombre, fecha_inicio_registro, fecha_limite_registro,
          finalizado, ejercicio, id_tipo_concurso
        ) VALUES (
          1, 'Concurso Estatal Michoacán 2026', '2026-09-01', '2026-09-20',
          1, '2026', 1
        )
      ''');

      await db.execute("INSERT OR IGNORE INTO rama_artesanal (id, nombre) VALUES (1, 'Textiles')");
      await db.execute("INSERT INTO categoria_concurso (id, id_concurso, nombre) VALUES (1, 1, 'Rebozos')");
      await db.execute("INSERT OR IGNORE INTO tipo_premio (id, nombre) VALUES (1, 'Galardón'), (2, 'Primer Lugar')");

      // Insertar Premios:
      // Premio 1: Galardón (limite_otorgacion = 1)
      // Premio 2: Mención Honorífica (limite_otorgacion = 2)
      await db.execute('''
        INSERT INTO premio (
          id, id_concurso, id_categoria, id_tipo_premio, nombre, monto, lugar, limite_otorgacion, activo
        ) VALUES 
        (1, 1, 1, 1, 'Galardón Textil Michoacano', 25000, 1, 1, 1),
        (2, 1, 1, 2, 'Mención Honorífica Especial', 5000, 2, 2, 1)
      ''');

      // Seed Artesano 1
      await db.execute('''
        INSERT INTO info_contacto (id, correo, telefono) VALUES (1, 'artesano1@casart.com', '4431112233')
      ''');
      await db.execute('''
        INSERT INTO residencia (id, municipio, localidad) VALUES (1, 'Morelia', 'Morelia Centro')
      ''');
      await db.execute('''
        INSERT INTO artesano (id, nombre, ap_paterno, curp, id_info_contacto, id_residencia)
        VALUES (1, 'Juan', 'Perez', 'PERJ800101HMNRR01', 1, 1)
      ''');

      // Seed Artesano 2
      await db.execute('''
        INSERT INTO info_contacto (id, correo, telefono) VALUES (2, 'artesano2@casart.com', '4434445566')
      ''');
      await db.execute('''
        INSERT INTO residencia (id, municipio, localidad) VALUES (2, 'Pátzcuaro', 'Pátzcuaro')
      ''');
      await db.execute('''
        INSERT INTO artesano (id, nombre, ap_paterno, curp, id_info_contacto, id_residencia)
        VALUES (2, 'María', 'Gómez', 'GOMM850505MMNRR02', 2, 2)
      ''');

      // Piezas del Artesano 1 (Registro con Pieza A y Pieza B)
      await db.execute('''
        INSERT INTO artesania_concurso (
          id, nombre, costo_produccion, costo_venta, tiempo_elaboracion, plazo_elaboracion,
          material_elaboracion, descripcion, id_rama_artesanal, id_categoria_concurso
        ) VALUES 
        (1, 'Rebozo de Seda Azul', 1200, 2500, 3, 'semanas', 'Seda natural', 'Rebozo fino', 1, 1),
        (2, 'Camisa Bordada Tradicional', 800, 1600, 2, 'semanas', 'Algodón', 'Bordado punto de cruz', 1, 1)
      ''');
      await db.execute('''
        INSERT INTO registro_concurso (id, id_concurso, id_artesano, id_artesania_1, id_artesania_2, folio)
        VALUES (1, 1, 1, 1, 2, 101)
      ''');

      // Pieza del Artesano 2 (Registro con sólo Pieza A)
      await db.execute('''
        INSERT INTO artesania_concurso (
          id, nombre, costo_produccion, costo_venta, tiempo_elaboracion, plazo_elaboracion,
          material_elaboracion, descripcion, id_rama_artesanal, id_categoria_concurso
        ) VALUES 
        (3, 'Faja Telar de Cintura', 600, 1200, 1, 'semanas', 'Lana', 'Faja ceremonial', 1, 1)
      ''');
      await db.execute('''
        INSERT INTO registro_concurso (id, id_concurso, id_artesano, id_artesania_1, id_artesania_2, folio)
        VALUES (2, 1, 2, 3, NULL, 102)
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('PremioRepository.asignarPremiacion premia individualmente a Pieza A (id 1)', () async {
      final inicialConteos = await premioRepo.getConteoPremiosOtorgados(1);
      expect(inicialConteos[1] ?? 0, equals(0));

      await premioRepo.asignarPremiacion(
        idConcurso: 1,
        idPremio: 1,
        idArtesania: 1, // Pieza A
        idCategoria: 1,
        lugar: 1,
      );

      // Verificar artesania_concurso actualizada
      final piezaRow = await db.query('artesania_concurso', where: 'id = ?', whereArgs: [1]);
      expect(piezaRow.first['id_premio'], equals(1));

      // Verificar tabla premiacion
      final premiacionRow = await db.query('premiacion', where: 'id_artesania = ?', whereArgs: [1]);
      expect(premiacionRow, isNotEmpty);
      expect(premiacionRow.first['id_premio'], equals(1));
      expect(premiacionRow.first['id_concurso'], equals(1));

      // Verificar conteo de otorgados
      final conteos = await premioRepo.getConteoPremiosOtorgados(1);
      expect(conteos[1], equals(1));

      // Pieza B no fue premiada
      final piezaBRow = await db.query('artesania_concurso', where: 'id = ?', whereArgs: [2]);
      expect(piezaBRow.first['id_premio'], isNull);
    });

    test('Límite de otorgación: Premio con limite_otorgacion = 1 se agota tras ser otorgado una vez', () async {
      final premios = await premioRepo.getPremiosByConcurso(1);
      final galardon = premios.firstWhere((p) => p.id == 1);
      expect(galardon.limiteOtorgacion, equals(1));

      // Asignar a Pieza A (id 1)
      await premioRepo.asignarPremiacion(
        idConcurso: 1,
        idPremio: galardon.id!,
        idArtesania: 1,
        idCategoria: 1,
        lugar: 1,
      );

      final conteos = await premioRepo.getConteoPremiosOtorgados(1);
      final int otorgados = conteos[galardon.id!] ?? 0;
      final int cuposRestantes = galardon.limiteOtorgacion - otorgados;

      expect(otorgados, equals(1));
      expect(cuposRestantes, equals(0), reason: 'El cupo debe ser 0 al haber alcanzado su límite de 1');
    });

    test('Premio con limite_otorgacion = 2 puede ser otorgado a dos piezas distintas (ej. Pieza B y Pieza 3)', () async {
      final premios = await premioRepo.getPremiosByConcurso(1);
      final mencion = premios.firstWhere((p) => p.id == 2);
      expect(mencion.limiteOtorgacion, equals(2));

      // 1. Asignar primera vez a Pieza B (id 2) del registro 1
      await premioRepo.asignarPremiacion(
        idConcurso: 1,
        idPremio: mencion.id!,
        idArtesania: 2,
        idCategoria: 1,
        lugar: 2,
      );

      var conteos = await premioRepo.getConteoPremiosOtorgados(1);
      expect(conteos[mencion.id!], equals(1));
      expect(mencion.limiteOtorgacion - conteos[mencion.id!]!, equals(1), reason: 'Aún queda 1 cupo disponible');

      // 2. Asignar segunda vez a Pieza 3 (id 3) del registro 2
      await premioRepo.asignarPremiacion(
        idConcurso: 1,
        idPremio: mencion.id!,
        idArtesania: 3,
        idCategoria: 1,
        lugar: 2,
      );

      conteos = await premioRepo.getConteoPremiosOtorgados(1);
      expect(conteos[mencion.id!], equals(2));
      expect(mencion.limiteOtorgacion - conteos[mencion.id!]!, equals(0), reason: 'Los 2 cupos fueron consumidos');
    });

    test('PremioRepository.removerPremiacion libera el cupo y limpia id_premio en artesania', () async {
      // Asignar premio
      await premioRepo.asignarPremiacion(
        idConcurso: 1,
        idPremio: 1,
        idArtesania: 1,
        idCategoria: 1,
        lugar: 1,
      );

      var conteos = await premioRepo.getConteoPremiosOtorgados(1);
      expect(conteos[1], equals(1));

      // Remover premio
      await premioRepo.removerPremiacion(
        idConcurso: 1,
        idArtesania: 1,
      );

      // Verificar que id_premio quedó NULL en artesania_concurso
      final piezaRow = await db.query('artesania_concurso', where: 'id = ?', whereArgs: [1]);
      expect(piezaRow.first['id_premio'], isNull);

      // Verificar que se eliminó el registro de premiacion
      final premiacionRow = await db.query('premiacion', where: 'id_artesania = ?', whereArgs: [1]);
      expect(premiacionRow, isEmpty);

      // Verificar que el cupo volvió a estar libre
      conteos = await premioRepo.getConteoPremiosOtorgados(1);
      expect(conteos[1] ?? 0, equals(0));
    });

    test('RegistroRepository carga premio_nombre correctamente tras la premiación', () async {
      await premioRepo.asignarPremiacion(
        idConcurso: 1,
        idPremio: 1,
        idArtesania: 1, // Pieza 1
        idCategoria: 1,
        lugar: 1,
      );

      final registros = await registroRepo.getRegistrosByConcurso(1);
      final r1 = registros.firstWhere((r) => r.id == 1);

      expect(r1.artesania1?.idPremio, equals(1));
      expect(r1.artesania1?.premioNombre, equals('Galardón Textil Michoacano'));
      expect(r1.artesania2?.idPremio, isNull);
      expect(r1.artesania2?.premioNombre, isNull);
    });
  });
}
