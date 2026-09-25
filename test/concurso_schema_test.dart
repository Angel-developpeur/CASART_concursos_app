import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:casart_concursos_desktop/core/database/app_database.dart';
import 'package:casart_concursos_desktop/models/concurso.dart';
import 'package:casart_concursos_desktop/repositories/concurso_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Verificación de Esquema de la Tabla Concurso (Paridad con Laravel)', () {
    test('La tabla concurso tiene las 14 columnas en el orden y tipo exacto de Laravel', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: AppDatabase().onCreate,
          onUpgrade: AppDatabase().onUpgrade,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );

      // Obtener información de columnas de la tabla 'concurso' en SQLite usando PRAGMA table_info
      final List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info(concurso)');

      final expectedColumns = [
        'id',
        'nombre',
        'fecha_inicio_registro',
        'fecha_limite_registro',
        'finalizado',
        'ejercicio',
        'lugar',
        'fecha_dictamen',
        'fecha_premiacion',
        'id_tipo_concurso',
        'iva',
        'utilidad',
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

      // Validar tipos específicos
      final colMap = {for (var c in columns) c['name'] as String: c};
      expect(colMap['id']!['type'], equals('INTEGER'));
      expect(colMap['id']!['pk'], equals(1));

      expect(colMap['nombre']!['type'], equals('TEXT'));
      expect(colMap['nombre']!['notnull'], equals(1));

      expect(colMap['finalizado']!['type'], equals('INTEGER'));
      expect(colMap['id_tipo_concurso']!['type'], equals('INTEGER'));
      expect(colMap['id_tipo_concurso']!['notnull'], equals(1));

      expect(colMap['iva']!['type'], equals('INTEGER'));
      expect(colMap['utilidad']!['type'], equals('REAL'));

      expect(colMap['created_at']!['type'], equals('TEXT'));
      expect(colMap['updated_at']!['type'], equals('TEXT'));
    });

    test('Concurso.toDbMap() serializa los campos en el orden exacto de Laravel', () {
      final c = Concurso(
        id: 1,
        nombre: 'Concurso Estatal 2026',
        fechaInicioRegistro: '2026-10-01',
        fechaLimiteRegistro: '2026-10-15',
        finalizado: false,
        ejercicio: '2026',
        lugar: 'Pátzcuaro',
        fechaDictamen: '2026-10-20',
        fechaPremiacion: '2026-10-25 12:00:00',
        idTipoConcurso: 2,
        iva: 16,
        utilidad: 10.0,
        createdAt: '2026-09-23 10:00:00',
        updatedAt: '2026-09-23 10:00:00',
      );

      final dbMap = c.toDbMap();
      final keys = dbMap.keys.toList();

      final expectedKeys = [
        'id',
        'nombre',
        'fecha_inicio_registro',
        'fecha_limite_registro',
        'finalizado',
        'ejercicio',
        'lugar',
        'fecha_dictamen',
        'fecha_premiacion',
        'id_tipo_concurso',
        'iva',
        'utilidad',
        'created_at',
        'updated_at',
      ];

      expect(keys, equals(expectedKeys));
      expect(dbMap['iva'], isA<int>());
      expect(dbMap['iva'], equals(16));
      expect(dbMap['utilidad'], isA<double>());
      expect(dbMap['finalizado'], equals(0));
    });

    test('CRUD y actualización de updated_at mediante ConcursoRepository', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: AppDatabase().onCreate,
          onUpgrade: AppDatabase().onUpgrade,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );

      final dbHelper = AppDatabase.withDatabase(db);
      final repo = ConcursoRepository(dbHelper: dbHelper);

      // Crear concurso
      final id = await repo.createConcurso(
        Concurso(
          nombre: 'Concurso de Alfarería',
          idTipoConcurso: 1,
          ejercicio: '2026',
          lugar: 'Capula',
          iva: 16,
          utilidad: 5.0,
        ),
      );

      final saved = await repo.getConcursoById(id);
      expect(saved, isNotNull);
      expect(saved!.iva, equals(16));
      expect(saved.utilidad, equals(5.0));
      expect(saved.finalizado, isFalse);
      expect(saved.createdAt, isNotNull);
      expect(saved.updatedAt, isNotNull);

      // Modificar concurso
      await repo.updateConcurso(saved.copyWith(
        nombre: 'Concurso de Alfarería y Catrinas',
        iva: 16,
      ));

      final updated = await repo.getConcursoById(id);
      expect(updated!.nombre, equals('Concurso de Alfarería y Catrinas'));
      expect(updated.updatedAt, isNotNull);
    });

    test('Migración onUpgrade de v1 a v2 reordena las columnas sin perder datos', () async {
      // 1. Simular base de datos en versión 1 con nombre único en memoria
      final db = await databaseFactoryFfi.openDatabase(
        'file:db_upgrade_test?mode=memory&cache=private',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('CREATE TABLE tipo_concurso (id INTEGER PRIMARY KEY, nombre TEXT)');
            await db.execute("INSERT INTO tipo_concurso VALUES (1, 'Regional')");

            // Tabla v1 con el orden anterior
            await db.execute('''
              CREATE TABLE concurso (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nombre TEXT NOT NULL,
                id_tipo_concurso INTEGER NOT NULL,
                fecha_inicio_registro TEXT,
                fecha_limite_registro TEXT,
                ejercicio TEXT DEFAULT (strftime('%Y', 'now')),
                lugar TEXT,
                fecha_dictamen TEXT,
                fecha_premiacion TEXT,
                iva REAL DEFAULT 16.0,
                utilidad REAL DEFAULT 0.0,
                finalizado INTEGER DEFAULT 0,
                created_at TEXT DEFAULT (datetime('now', 'localtime')),
                FOREIGN KEY (id_tipo_concurso) REFERENCES tipo_concurso(id)
              )
            ''');

            await db.execute('''
              INSERT INTO concurso (
                nombre, id_tipo_concurso, fecha_inicio_registro, fecha_limite_registro,
                ejercicio, lugar, fecha_dictamen, fecha_premiacion, iva, utilidad, finalizado
              ) VALUES (
                'Concurso Antiguo v1', 1, '2026-01-01', '2026-01-10',
                '2026', 'Morelia', '2026-01-15', '2026-01-20 18:00:00', 16.0, 8.5, 1
              )
            ''');
          },
        ),
      );

      // 2. Ejecutar upgrade a versión 2
      await AppDatabase().onUpgrade(db, 1, 2);

      // 3. Verificar que las columnas ahora tienen el orden exacto de Laravel
      final List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info(concurso)');
      final expectedColumns = [
        'id',
        'nombre',
        'fecha_inicio_registro',
        'fecha_limite_registro',
        'finalizado',
        'ejercicio',
        'lugar',
        'fecha_dictamen',
        'fecha_premiacion',
        'id_tipo_concurso',
        'iva',
        'utilidad',
        'created_at',
        'updated_at',
      ];

      for (int i = 0; i < expectedColumns.length; i++) {
        expect(columns[i]['name'], equals(expectedColumns[i]));
      }

      // 4. Verificar que los datos anteriores se conservaron intactos
      final rows = await db.query('concurso');
      expect(rows.length, equals(1));
      final row = rows.first;
      expect(row['nombre'], equals('Concurso Antiguo v1'));
      expect(row['finalizado'], equals(1));
      expect(row['id_tipo_concurso'], equals(1));
      expect(row['iva'], equals(16));
      expect(row['utilidad'], equals(8.5));
      expect(row['lugar'], equals('Morelia'));
      expect(row['updated_at'], isNotNull);
    });
  });
}
