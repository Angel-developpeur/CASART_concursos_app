import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:casart_concursos_desktop/core/database/app_database.dart';
import 'package:casart_concursos_desktop/models/tipo_concurso.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Verificación de tabla tipo_concurso (Compatibilidad 100% Laravel)', () {
    test('La tabla tipo_concurso tiene las mismas columnas y en el mismo orden que Laravel', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: AppDatabase().onCreate,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );

      final tableInfo = await db.rawQuery('PRAGMA table_info(tipo_concurso)');
      final columnNames = tableInfo.map((row) => row['name'] as String).toList();

      // Columnas esperadas en el orden idéntico a la migración de Laravel:
      // $table->id();
      // $table->string('nombre')->unique();
      // $table->timestamps(); -> created_at, updated_at
      final expectedColumns = [
        'id',
        'nombre',
        'created_at',
        'updated_at',
      ];

      expect(columnNames, expectedColumns);

      final nombreCol = tableInfo.firstWhere((r) => r['name'] == 'nombre');
      expect(nombreCol['notnull'], 1);

      await db.close();
    });

    test('Modelo TipoConcurso serializa llaves en el orden exacto de Laravel', () {
      final tc = TipoConcurso(
        id: 1,
        nombre: 'Estatal',
        createdAt: '2026-09-23 15:00:00',
        updatedAt: '2026-09-23 15:00:00',
      );

      final map = tc.toDbMap();
      expect(map.keys.toList(), [
        'id',
        'nombre',
        'created_at',
        'updated_at',
      ]);

      final fromMap = TipoConcurso.fromMap(map);
      expect(fromMap.id, 1);
      expect(fromMap.nombre, 'Estatal');
      expect(fromMap.createdAt, '2026-09-23 15:00:00');
      expect(fromMap.updatedAt, '2026-09-23 15:00:00');
    });

    test('Migración onUpgrade de v5 a v6 reordena columnas y añade timestamps sin perder datos', () async {
      final db = await databaseFactory.openDatabase(
        'file:test_v5_to_v6_tipo_concurso?mode=memory&cache=private',
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (db, version) async {
            // Esquema v5 antiguo (sin created_at/updated_at)
            await db.execute('''
              CREATE TABLE tipo_concurso (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nombre TEXT NOT NULL
              )
            ''');
            await db.execute("INSERT INTO tipo_concurso (id, nombre) VALUES (1, 'Regional'), (2, 'Estatal')");
          },
        ),
      );

      // Ejecutar upgrade a versión 6
      await AppDatabase().onUpgrade(db, 5, 6);

      // Validar esquema
      final cols = (await db.rawQuery('PRAGMA table_info(tipo_concurso)')).map((r) => r['name'] as String).toList();
      expect(cols, ['id', 'nombre', 'created_at', 'updated_at']);

      // Validar preservación de datos
      final rows = await db.query('tipo_concurso', orderBy: 'id ASC');
      expect(rows.length, 2);
      expect(rows[0]['id'], 1);
      expect(rows[0]['nombre'], 'Regional');
      expect(rows[0]['created_at'], isNotNull);
      expect(rows[1]['id'], 2);
      expect(rows[1]['nombre'], 'Estatal');
      expect(rows[1]['created_at'], isNotNull);

      await db.close();
    });
  });
}
