import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:casart_concursos_desktop/core/database/app_database.dart';
import 'package:casart_concursos_desktop/models/categoria.dart';
import 'package:casart_concursos_desktop/models/subcategoria.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Verificación de tabla categoria_concurso (Compatibilidad 100% Laravel)', () {
    test('La tabla categoria_concurso tiene las mismas columnas y en el mismo orden que Laravel', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: AppDatabase().onCreate,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );

      final tableInfo = await db.rawQuery('PRAGMA table_info(categoria_concurso)');
      final columnNames = tableInfo.map((row) => row['name'] as String).toList();

      // Columnas esperadas en el orden idéntico a la migración de Laravel:
      // $table->id();
      // $table->string('nombre')->nullable(false);
      // $table->foreignId('id_concurso')->constrained('concurso');
      // $table->boolean('activo')->default(true);
      // $table->timestamps(); -> created_at, updated_at
      final expectedColumns = [
        'id',
        'nombre',
        'id_concurso',
        'activo',
        'created_at',
        'updated_at',
      ];

      expect(columnNames, expectedColumns);

      // Validar nulabilidad y tipos
      final nombreCol = tableInfo.firstWhere((r) => r['name'] == 'nombre');
      expect(nombreCol['notnull'], 1);

      final idConcursoCol = tableInfo.firstWhere((r) => r['name'] == 'id_concurso');
      expect(idConcursoCol['notnull'], 1);

      final activoCol = tableInfo.firstWhere((r) => r['name'] == 'activo');
      expect(activoCol['dflt_value'], '1');

      await db.close();
    });

    test('La tabla sub_categoria_concurso tiene las mismas columnas y en el mismo orden que Laravel', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: AppDatabase().onCreate,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );

      final tableInfo = await db.rawQuery('PRAGMA table_info(sub_categoria_concurso)');
      final columnNames = tableInfo.map((row) => row['name'] as String).toList();

      // Columnas esperadas en el orden idéntico a la migración de Laravel:
      // $table->id();
      // $table->string('nombre');
      // $table->foreignId('id_categoria')->constrained('categoria_concurso');
      // $table->boolean('activo')->default(true);
      // $table->timestamps(); -> created_at, updated_at
      final expectedColumns = [
        'id',
        'nombre',
        'id_categoria',
        'activo',
        'created_at',
        'updated_at',
      ];

      expect(columnNames, expectedColumns);

      final nombreCol = tableInfo.firstWhere((r) => r['name'] == 'nombre');
      expect(nombreCol['notnull'], 1);

      final idCategoriaCol = tableInfo.firstWhere((r) => r['name'] == 'id_categoria');
      expect(idCategoriaCol['notnull'], 1);

      await db.close();
    });

    test('Modelos Categoria y Subcategoria serializan llaves en el orden exacto de Laravel', () {
      final cat = Categoria(
        id: 5,
        nombre: 'Textiles',
        idConcurso: 1,
        activo: true,
        createdAt: '2026-09-23 15:00:00',
        updatedAt: '2026-09-23 15:00:00',
      );

      final catMap = cat.toDbMap();
      expect(catMap.keys.toList(), [
        'id',
        'nombre',
        'id_concurso',
        'activo',
        'created_at',
        'updated_at',
      ]);

      final sub = Subcategoria(
        id: 10,
        nombre: 'Bordado tradicional',
        idCategoria: 5,
        activo: true,
        createdAt: '2026-09-23 15:00:00',
        updatedAt: '2026-09-23 15:00:00',
      );

      final subMap = sub.toMap();
      expect(subMap.keys.toList(), [
        'id',
        'nombre',
        'id_categoria',
        'activo',
        'created_at',
        'updated_at',
      ]);
    });

    test('Migración onUpgrade de v3 a v4 reordena columnas sin perder datos', () async {
      final db = await databaseFactory.openDatabase(
        'file:test_v3_to_v4?mode=memory&cache=private',
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, version) async {
            await db.execute('CREATE TABLE tipo_concurso (id INTEGER PRIMARY KEY, nombre TEXT)');
            await db.execute("INSERT INTO tipo_concurso VALUES (1, 'Estatal')");

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
            await db.execute("INSERT INTO concurso (id, nombre, id_tipo_concurso) VALUES (1, 'Concurso Michoacán', 1)");

            // Esquema v3 antiguo (id_concurso antes que nombre, sin created_at/updated_at)
            await db.execute('''
              CREATE TABLE categoria_concurso (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                id_concurso INTEGER NOT NULL,
                nombre TEXT NOT NULL,
                activo INTEGER DEFAULT 1
              )
            ''');
            await db.execute("INSERT INTO categoria_concurso (id, id_concurso, nombre, activo) VALUES (1, 1, 'Alfarería', 1)");

            await db.execute('''
              CREATE TABLE sub_categoria_concurso (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                id_categoria INTEGER NOT NULL,
                nombre TEXT NOT NULL,
                activo INTEGER DEFAULT 1
              )
            ''');
            await db.execute("INSERT INTO sub_categoria_concurso (id, id_categoria, nombre, activo) VALUES (1, 1, 'Bruñido', 1)");
          },
        ),
      );

      // Ejecutar upgrade a versión 4
      await AppDatabase().onUpgrade(db, 3, 4);

      // Validar esquema de categoria_concurso
      final catCols = (await db.rawQuery('PRAGMA table_info(categoria_concurso)')).map((r) => r['name'] as String).toList();
      expect(catCols, ['id', 'nombre', 'id_concurso', 'activo', 'created_at', 'updated_at']);

      // Validar esquema de sub_categoria_concurso
      final subCols = (await db.rawQuery('PRAGMA table_info(sub_categoria_concurso)')).map((r) => r['name'] as String).toList();
      expect(subCols, ['id', 'nombre', 'id_categoria', 'activo', 'created_at', 'updated_at']);

      // Validar preservación de datos
      final catRows = await db.query('categoria_concurso');
      expect(catRows.length, 1);
      expect(catRows.first['nombre'], 'Alfarería');
      expect(catRows.first['id_concurso'], 1);
      expect(catRows.first['created_at'], isNotNull);

      final subRows = await db.query('sub_categoria_concurso');
      expect(subRows.length, 1);
      expect(subRows.first['nombre'], 'Bruñido');
      expect(subRows.first['id_categoria'], 1);
      expect(subRows.first['created_at'], isNotNull);

      await db.close();
    });
  });
}
