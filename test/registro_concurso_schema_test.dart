import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:casart_concursos_desktop/core/database/app_database.dart';
import 'package:casart_concursos_desktop/models/registro_concurso.dart';
import 'package:casart_concursos_desktop/models/concurso.dart';
import 'package:casart_concursos_desktop/models/artesano.dart';
import 'package:casart_concursos_desktop/models/artesania.dart';
import 'package:casart_concursos_desktop/models/categoria.dart';
import 'package:casart_concursos_desktop/repositories/registro_repository.dart';
import 'package:casart_concursos_desktop/repositories/concurso_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Verificación de Esquema de la Tabla RegistroConcurso', () {
    test('La tabla registro_concurso tiene las 8 columnas en el orden y tipo exacto solicitado', () async {
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

      final List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info(registro_concurso)');

      final expectedColumns = [
        'id',
        'folio',
        'id_artesano',
        'id_concurso',
        'id_artesania_1',
        'id_artesania_2',
        'created_at',
        'updated_at',
      ];

      expect(columns.length, equals(expectedColumns.length),
          reason: 'Debe contener exactamente ${expectedColumns.length} columnas');

      for (int i = 0; i < expectedColumns.length; i++) {
        final col = columns[i];
        expect(col['name'], equals(expectedColumns[i]),
            reason: 'La columna en la posición $i debe ser ${expectedColumns[i]}');
      }

      final colMap = {for (var c in columns) c['name'] as String: c};
      expect(colMap['id']!['type'], equals('INTEGER'));
      expect(colMap['id']!['pk'], equals(1));

      expect(colMap['folio']!['type'], equals('INTEGER'));
      expect(colMap['folio']!['notnull'], equals(1));

      expect(colMap['id_artesano']!['type'], equals('INTEGER'));
      expect(colMap['id_artesano']!['notnull'], equals(1));

      expect(colMap['id_concurso']!['type'], equals('INTEGER'));
      expect(colMap['id_concurso']!['notnull'], equals(1));

      expect(colMap['id_artesania_1']!['type'], equals('INTEGER'));
      expect(colMap['id_artesania_1']!['notnull'], equals(1));

      expect(colMap['id_artesania_2']!['type'], equals('INTEGER'));
      expect(colMap['id_artesania_2']!['notnull'], equals(0)); // nullable

      expect(colMap['created_at']!['type'], equals('TEXT'));
      expect(colMap['updated_at']!['type'], equals('TEXT'));
    });

    test('RegistroConcurso.toDbMap() serializa los campos en el orden exacto solicitado', () {
      final reg = RegistroConcurso(
        id: 1,
        folio: 101,
        idArtesano: 5,
        idConcurso: 2,
        idArtesania1: 20,
        idArtesania2: 21,
        createdAt: '2026-09-24 10:00:00',
        updatedAt: '2026-09-24 10:30:00',
      );

      final dbMap = reg.toDbMap();
      final keys = dbMap.keys.toList();

      final expectedKeys = [
        'id',
        'folio',
        'id_artesano',
        'id_concurso',
        'id_artesania_1',
        'id_artesania_2',
        'created_at',
        'updated_at',
      ];

      expect(keys, equals(expectedKeys));
      expect(dbMap['folio'], equals(101));
      expect(dbMap['id_artesano'], equals(5));
      expect(dbMap['id_concurso'], equals(2));
      expect(dbMap['id_artesania_1'], equals(20));
      expect(dbMap['id_artesania_2'], equals(21));
      expect(dbMap['created_at'], equals('2026-09-24 10:00:00'));
      expect(dbMap['updated_at'], equals('2026-09-24 10:30:00'));
    });

    test('RegistroRepository inserta y actualiza registro_concurso con timestamps en el nuevo esquema', () async {
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
      final registroRepo = RegistroRepository(dbHelper: dbHelper);

      final concursoId = await concursoRepo.saveConcurso(
        Concurso(
          nombre: 'Concurso Michoacán 2026',
          idTipoConcurso: 1,
          ejercicio: '2026',
          categorias: [Categoria(nombre: 'Textiles')],
        ),
      );

      final concurso = await concursoRepo.getConcursoById(concursoId);
      final catId = concurso!.categorias.first.id!;

      final artesano = Artesano(
        nombre: 'Rosa',
        apPaterno: 'Morales',
        curp: 'MORR900101MMNRRL01',
        municipio: 'Morelia',
        localidad: 'Morelia',
      );

      final pieza1 = Artesania(
        nombre: 'Rebozo de Lana',
        descripcion: 'Rebozo tradicional elaborado a mano',
        costoProduccion: 500.0,
        costoVenta: 1200.0,
        tiempoElaboracion: 10.0,
        plazoElaboracion: 'dias',
        materialElaboracion: 'Lana de borrego',
        idRamaArtesanal: 2,
        idCategoriaConcurso: catId,
      );

      // Inscribir
      final reg = await registroRepo.registrarInscripcion(
        idConcurso: concursoId,
        artesano: artesano,
        esNuevoArtesano: true,
        pieza1: pieza1,
      );

      expect(reg.id, isNotNull);
      expect(reg.folio, equals(1));
      expect(reg.idConcurso, equals(concursoId));
      expect(reg.createdAt, isNotNull);
      expect(reg.updatedAt, isNotNull);

      // Consultar directo en base de datos para validar columnas
      final rows = await db.query('registro_concurso', where: 'id = ?', whereArgs: [reg.id]);
      expect(rows.length, equals(1));
      final row = rows.first;
      expect(row['folio'], equals(1));
      expect(row['id_artesano'], equals(reg.idArtesano));
      expect(row['id_concurso'], equals(concursoId));
      expect(row['id_artesania_1'], equals(reg.idArtesania1));
      expect(row['created_at'], isNotNull);
      expect(row['updated_at'], isNotNull);

      // Actualizar inscripción
      await registroRepo.actualizarInscripcion(
        idRegistro: reg.id!,
        idConcurso: concursoId,
        artesano: artesano.copyWith(nombre: 'Rosa Elena'),
        pieza1: pieza1.copyWith(costoVenta: 1500.0),
      );

      final updatedReg = await registroRepo.getRegistroById(reg.id!);
      expect(updatedReg, isNotNull);
      expect(updatedReg!.updatedAt, isNotNull);
    });

    test('Migración onUpgrade de v8 a v9 reorganiza registro_concurso sin perder registros', () async {
      final db = await databaseFactoryFfi.openDatabase(
        'file:db_reg_upgrade_test?mode=memory&cache=private',
        options: OpenDatabaseOptions(
          version: 8,
          onCreate: (db, version) async {
            // Esquema antiguo v8: folio en 4to lugar, id_concurso en 2do, sin updated_at
            await db.execute('CREATE TABLE concurso (id INTEGER PRIMARY KEY, nombre TEXT)');
            await db.execute("INSERT INTO concurso VALUES (10, 'Concurso Alfarería')");

            await db.execute('CREATE TABLE artesano (id INTEGER PRIMARY KEY, nombre TEXT)');
            await db.execute("INSERT INTO artesano VALUES (50, 'Pedro Infante')");

            await db.execute('CREATE TABLE artesania_concurso (id INTEGER PRIMARY KEY, nombre TEXT)');
            await db.execute("INSERT INTO artesania_concurso VALUES (100, 'Jarrón de Barro')");
            await db.execute("INSERT INTO artesania_concurso VALUES (101, 'Plato Decorativo')");

            await db.execute('''
              CREATE TABLE registro_concurso (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                id_concurso INTEGER NOT NULL,
                id_artesano INTEGER NOT NULL,
                folio INTEGER NOT NULL,
                id_artesania_1 INTEGER NOT NULL,
                id_artesania_2 INTEGER,
                created_at TEXT DEFAULT (datetime('now', 'localtime')),
                FOREIGN KEY (id_concurso) REFERENCES concurso(id) ON DELETE CASCADE,
                FOREIGN KEY (id_artesano) REFERENCES artesano(id),
                FOREIGN KEY (id_artesania_1) REFERENCES artesania_concurso(id),
                FOREIGN KEY (id_artesania_2) REFERENCES artesania_concurso(id),
                UNIQUE (id_concurso, folio)
              )
            ''');

            await db.execute('''
              INSERT INTO registro_concurso (
                id, id_concurso, id_artesano, folio, id_artesania_1, id_artesania_2, created_at
              ) VALUES (
                1, 10, 50, 42, 100, 101, '2026-09-20 12:00:00'
              )
            ''');
          },
        ),
      );

      // Ejecutar upgrade a versión 9
      await AppDatabase().onUpgrade(db, 8, 9);

      // Validar orden de columnas post-migración
      final List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info(registro_concurso)');
      final expectedColumns = [
        'id',
        'folio',
        'id_artesano',
        'id_concurso',
        'id_artesania_1',
        'id_artesania_2',
        'created_at',
        'updated_at',
      ];

      for (int i = 0; i < expectedColumns.length; i++) {
        expect(columns[i]['name'], equals(expectedColumns[i]),
            reason: 'La columna en la posición $i debe ser ${expectedColumns[i]}');
      }

      // Validar que los datos existentes se migraron intactos
      final rows = await db.query('registro_concurso');
      expect(rows.length, equals(1));
      final row = rows.first;
      expect(row['id'], equals(1));
      expect(row['folio'], equals(42));
      expect(row['id_artesano'], equals(50));
      expect(row['id_concurso'], equals(10));
      expect(row['id_artesania_1'], equals(100));
      expect(row['id_artesania_2'], equals(101));
      expect(row['created_at'], equals('2026-09-20 12:00:00'));
      expect(row['updated_at'], isNotNull);
    });
  });
}
