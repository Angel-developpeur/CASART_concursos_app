import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:casart_concursos_desktop/core/database/app_database.dart';
import 'package:casart_concursos_desktop/models/aportacion.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Verificación de tabla aportacion_concurso (Compatibilidad 100% Laravel)', () {
    test('La tabla aportacion_concurso tiene las mismas columnas y en el mismo orden que Laravel', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: AppDatabase().onCreate,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );

      final tableInfo = await db.rawQuery('PRAGMA table_info(aportacion_concurso)');

      final columnNames = tableInfo.map((row) => row['name'] as String).toList();

      // Columnas esperadas en el orden idéntico a la migración de Laravel:
      // $table->id();
      // $table->string('nombre')->nullable(false);
      // $table->decimal('cantidad', 12, 2)->nullable(false);
      // $table->foreignId('id_concurso')->constrained('concurso')->onDelete('cascade');
      // $table->timestamps(); -> created_at, updated_at
      final expectedColumns = [
        'id',
        'nombre',
        'cantidad',
        'id_concurso',
        'created_at',
        'updated_at',
      ];

      expect(columnNames, expectedColumns);

      // Verificar tipos y nulabilidad
      final nombreCol = tableInfo.firstWhere((r) => r['name'] == 'nombre');
      expect(nombreCol['notnull'], 1);

      final cantidadCol = tableInfo.firstWhere((r) => r['name'] == 'cantidad');
      expect(cantidadCol['notnull'], 1);

      final idConcursoCol = tableInfo.firstWhere((r) => r['name'] == 'id_concurso');
      expect(idConcursoCol['notnull'], 1);

      await db.close();
    });

    test('Modelo Aportacion soporta updated_at y preserva el orden de claves para Laravel', () {
      final aport = Aportacion(
        id: 5,
        nombre: 'FONART',
        cantidad: 50000.0,
        idConcurso: 1,
        createdAt: '2026-09-23 10:00:00',
        updatedAt: '2026-09-23 12:00:00',
      );

      final map = aport.toMap();
      expect(map.keys.toList(), ['id', 'nombre', 'cantidad', 'id_concurso', 'created_at', 'updated_at']);

      final deserialized = Aportacion.fromMap(map);
      expect(deserialized.id, 5);
      expect(deserialized.nombre, 'FONART');
      expect(deserialized.cantidad, 50000.0);
      expect(deserialized.idConcurso, 1);
      expect(deserialized.createdAt, '2026-09-23 10:00:00');
      expect(deserialized.updatedAt, '2026-09-23 12:00:00');
    });

    test('Migración onUpgrade de versión anterior a v3 reorganiza las columnas sin perder datos', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, v) async {
            await db.execute('''
              CREATE TABLE concurso (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nombre TEXT NOT NULL
              )
            ''');
            // Estructura vieja de aportacion_concurso (con id_concurso antes de nombre y sin updated_at)
            await db.execute('''
              CREATE TABLE aportacion_concurso (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                id_concurso INTEGER NOT NULL,
                nombre TEXT NOT NULL,
                cantidad REAL NOT NULL,
                created_at TEXT DEFAULT (datetime('now', 'localtime'))
              )
            ''');

            await db.insert('concurso', {'id': 1, 'nombre': 'Concurso Estatal'});
            await db.insert('aportacion_concurso', {
              'id': 10,
              'id_concurso': 1,
              'nombre': 'Secretaría de Cultura',
              'cantidad': 120000.0,
              'created_at': '2026-09-20 09:00:00',
            });
          },
        ),
      );

      // Ejecutar actualización a v3
      await AppDatabase().onUpgrade(db, 2, 3);

      final info = await db.rawQuery('PRAGMA table_info(aportacion_concurso)');
      final columnNames = info.map((r) => r['name'] as String).toList();
      expect(columnNames, ['id', 'nombre', 'cantidad', 'id_concurso', 'created_at', 'updated_at']);

      final rows = await db.query('aportacion_concurso');
      expect(rows.length, 1);
      expect(rows.first['id'], 10);
      expect(rows.first['nombre'], 'Secretaría de Cultura');
      expect(rows.first['cantidad'], 120000.0);
      expect(rows.first['id_concurso'], 1);
      expect(rows.first['created_at'], '2026-09-20 09:00:00');
      expect(rows.first['updated_at'], '2026-09-20 09:00:00');

      await db.close();
    });
  });
}
