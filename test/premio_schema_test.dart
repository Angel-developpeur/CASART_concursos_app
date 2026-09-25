import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:casart_concursos_desktop/core/database/app_database.dart';
import 'package:casart_concursos_desktop/models/premio.dart';
import 'package:casart_concursos_desktop/repositories/premio_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Verificación de Esquema de la Tabla Premio (Paridad con Laravel)', () {
    test('La tabla premio tiene las 12 columnas en el orden y tipo exacto de Laravel', () async {
      final db = await databaseFactoryFfi.openDatabase(
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

      final List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info(premio)');

      final expectedColumns = [
        'id',
        'id_categoria',
        'id_concurso',
        'id_tipo_premio',
        'id_sub_categoria',
        'nombre',
        'monto',
        'lugar',
        'limite_otorgacion',
        'activo',
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

      expect(colMap['id_categoria']!['type'], equals('INTEGER'));
      expect(colMap['id_categoria']!['notnull'], equals(0)); // nullable

      expect(colMap['id_concurso']!['type'], equals('INTEGER'));
      expect(colMap['id_concurso']!['notnull'], equals(1));

      expect(colMap['id_tipo_premio']!['type'], equals('INTEGER'));
      expect(colMap['id_tipo_premio']!['notnull'], equals(1));

      expect(colMap['id_sub_categoria']!['type'], equals('INTEGER'));
      expect(colMap['id_sub_categoria']!['notnull'], equals(0)); // nullable

      expect(colMap['nombre']!['type'], equals('TEXT'));
      expect(colMap['nombre']!['notnull'], equals(1));

      expect(colMap['monto']!['type'], equals('INTEGER'));
      expect(colMap['monto']!['notnull'], equals(1));

      expect(colMap['lugar']!['type'], equals('INTEGER'));
      expect(colMap['limite_otorgacion']!['type'], equals('INTEGER'));
      expect(colMap['activo']!['type'], equals('INTEGER'));

      expect(colMap['created_at']!['type'], equals('TEXT'));
      expect(colMap['updated_at']!['type'], equals('TEXT'));
    });

    test('Premio.toDbMap() serializa los campos en el orden exacto de Laravel', () {
      final p = Premio(
        id: 1,
        idCategoria: 2,
        idConcurso: 10,
        idTipoPremio: 1,
        idSubCategoria: 3,
        nombre: 'Primer Lugar Alfarería',
        monto: 15000.0,
        lugar: 1,
        limiteOtorgacion: 1,
        activo: true,
        createdAt: '2026-09-23 10:00:00',
        updatedAt: '2026-09-23 10:00:00',
      );

      final dbMap = p.toDbMap();
      final keys = dbMap.keys.toList();

      final expectedKeys = [
        'id',
        'id_categoria',
        'id_concurso',
        'id_tipo_premio',
        'id_sub_categoria',
        'nombre',
        'monto',
        'lugar',
        'limite_otorgacion',
        'activo',
        'created_at',
        'updated_at',
      ];

      expect(keys, equals(expectedKeys));
      expect(dbMap['monto'], isA<int>());
      expect(dbMap['monto'], equals(15000));
      expect(dbMap['activo'], equals(1));
    });

    test('CRUD y timestamps mediante PremioRepository', () async {
      final db = await databaseFactoryFfi.openDatabase(
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

      // tipo_concurso y tipo_premio ya son sembrados por onCreate (SeedData)
      await db.execute('''
        INSERT INTO concurso (
          id, nombre, fecha_inicio_registro, fecha_limite_registro,
          finalizado, ejercicio, lugar, fecha_dictamen, fecha_premiacion,
          id_tipo_concurso, iva, utilidad
        ) VALUES (
          1, 'Concurso Textil', '2026-01-01', '2026-01-10',
          0, '2026', 'Pátzcuaro', '2026-01-15', '2026-01-20', 1, 16, 0.0
        );
      ''');

      final dbHelper = AppDatabase.withDatabase(db);
      final repo = PremioRepository(dbHelper: dbHelper);

      // 1. Crear Premio
      final id = await repo.createPremio(
        Premio(
          idConcurso: 1,
          idTipoPremio: 1,
          nombre: 'Galardón Textil',
          monto: 20000.0,
          lugar: 1,
        ),
      );

      final premios = await repo.getPremiosByConcurso(1);
      expect(premios.length, equals(1));
      final p = premios.first;
      expect(p.id, equals(id));
      expect(p.nombre, equals('Galardón Textil'));
      expect(p.monto, equals(20000.0));
      expect(p.createdAt, isNotNull);
      expect(p.updatedAt, isNotNull);

      // 2. Modificar Premio
      await repo.updatePremio(p.copyWith(monto: 25000.0));
      final updatedPremios = await repo.getPremiosByConcurso(1);
      expect(updatedPremios.first.monto, equals(25000.0));
      expect(updatedPremios.first.updatedAt, isNotNull);

      // 3. Eliminar Premio
      await repo.deletePremio(id);
      final emptyPremios = await repo.getPremiosByConcurso(1);
      expect(emptyPremios, isEmpty);
    });

    test('Migración onUpgrade de v4 a v5 reordena columnas de premio sin perder datos', () async {
      final db = await databaseFactoryFfi.openDatabase(
        'file:db_premio_upgrade_test?mode=memory&cache=private',
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: (db, version) async {
            await db.execute('CREATE TABLE tipo_concurso (id INTEGER PRIMARY KEY, nombre TEXT)');
            await db.execute("INSERT INTO tipo_concurso VALUES (1, 'Regional')");
            await db.execute('''
              CREATE TABLE concurso (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nombre TEXT NOT NULL,
                fecha_inicio_registro TEXT,
                fecha_limite_registro TEXT,
                finalizado INTEGER DEFAULT 0,
                ejercicio TEXT,
                lugar TEXT,
                fecha_dictamen TEXT,
                fecha_premiacion TEXT,
                id_tipo_concurso INTEGER NOT NULL,
                iva INTEGER DEFAULT 16,
                utilidad REAL DEFAULT 0.0,
                created_at TEXT,
                updated_at TEXT
              )
            ''');
            await db.execute("INSERT INTO concurso (id, nombre, id_tipo_concurso) VALUES (1, 'Concurso 1', 1)");

            await db.execute('CREATE TABLE tipo_premio (id INTEGER PRIMARY KEY, nombre TEXT)');
            await db.execute("INSERT INTO tipo_premio VALUES (1, 'Galardón')");

            // Tabla premio v4 con orden antiguo
            await db.execute('''
              CREATE TABLE premio (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                id_concurso INTEGER NOT NULL,
                id_categoria INTEGER,
                id_sub_categoria INTEGER,
                id_tipo_premio INTEGER,
                nombre TEXT NOT NULL,
                monto REAL NOT NULL,
                lugar INTEGER,
                limite_otorgacion INTEGER DEFAULT 1,
                activo INTEGER DEFAULT 1,
                FOREIGN KEY (id_concurso) REFERENCES concurso(id) ON DELETE CASCADE
              )
            ''');

            await db.execute('''
              INSERT INTO premio (
                id, id_concurso, id_categoria, id_sub_categoria, id_tipo_premio,
                nombre, monto, lugar, limite_otorgacion, activo
              ) VALUES (
                10, 1, NULL, NULL, 1,
                'Premio Especial de Barro', 12500.0, 1, 1, 1
              )
            ''');
          },
        ),
      );

      // Ejecutar upgrade a versión 5
      await AppDatabase().onUpgrade(db, 4, 5);

      // Verificar que las columnas ahora tienen el orden exacto de Laravel
      final List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info(premio)');
      final expectedColumns = [
        'id',
        'id_categoria',
        'id_concurso',
        'id_tipo_premio',
        'id_sub_categoria',
        'nombre',
        'monto',
        'lugar',
        'limite_otorgacion',
        'activo',
        'created_at',
        'updated_at',
      ];

      for (int i = 0; i < expectedColumns.length; i++) {
        expect(columns[i]['name'], equals(expectedColumns[i]));
      }

      // Verificar que los datos anteriores se conservaron intactos
      final rows = await db.query('premio');
      expect(rows.length, equals(1));
      final row = rows.first;
      expect(row['id'], equals(10));
      expect(row['nombre'], equals('Premio Especial de Barro'));
      expect(row['monto'], equals(12500));
      expect(row['id_concurso'], equals(1));
      expect(row['id_tipo_premio'], equals(1));
      expect(row['created_at'], isNotNull);
      expect(row['updated_at'], isNotNull);
    });
  });
}
