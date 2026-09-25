import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:casart_concursos_desktop/core/database/app_database.dart';
import 'package:casart_concursos_desktop/models/artesania.dart';
import 'package:casart_concursos_desktop/repositories/registro_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Verificación de Esquema de la Tabla ArtesaniaConcurso', () {
    test('La tabla artesania_concurso tiene las 16 columnas en el orden y tipo exacto solicitado', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 10,
          onCreate: AppDatabase().onCreate,
          onUpgrade: AppDatabase().onUpgrade,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );

      final List<Map<String, dynamic>> columns =
          await db.rawQuery('PRAGMA table_info(artesania_concurso)');

      final expectedColumns = [
        'id',
        'nombre',
        'costo_produccion',
        'costo_venta',
        'estado',
        'tiempo_elaboracion',
        'plazo_elaboracion',
        'material_elaboracion',
        'descripcion',
        'id_rama_artesanal',
        'id_imagen',
        'id_premio',
        'id_categoria_concurso',
        'id_sub_categoria_concurso',
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

      // 1. id
      expect(colMap['id']!['type'], equals('INTEGER'));
      expect(colMap['id']!['pk'], equals(1));

      // 2. nombre
      expect(colMap['nombre']!['type'], equals('TEXT'));
      expect(colMap['nombre']!['notnull'], equals(1));

      // 3. costo_produccion
      expect(colMap['costo_produccion']!['type'], equals('REAL'));
      expect(colMap['costo_produccion']!['notnull'], equals(1));

      // 4. costo_venta
      expect(colMap['costo_venta']!['type'], equals('REAL'));
      expect(colMap['costo_venta']!['notnull'], equals(1));

      // 5. estado (nullable)
      expect(colMap['estado']!['type'], equals('TEXT'));
      expect(colMap['estado']!['notnull'], equals(0));

      // 6. tiempo_elaboracion
      expect(colMap['tiempo_elaboracion']!['type'], equals('REAL'));
      expect(colMap['tiempo_elaboracion']!['notnull'], equals(1));

      // 7. plazo_elaboracion
      expect(colMap['plazo_elaboracion']!['type'], equals('TEXT'));
      expect(colMap['plazo_elaboracion']!['notnull'], equals(1));

      // 8. material_elaboracion
      expect(colMap['material_elaboracion']!['type'], equals('TEXT'));
      expect(colMap['material_elaboracion']!['notnull'], equals(1));

      // 9. descripcion (nullable)
      expect(colMap['descripcion']!['type'], equals('TEXT'));
      expect(colMap['descripcion']!['notnull'], equals(0));

      // 10. id_rama_artesanal
      expect(colMap['id_rama_artesanal']!['type'], equals('INTEGER'));
      expect(colMap['id_rama_artesanal']!['notnull'], equals(1));

      // 11. id_imagen (nullable)
      expect(colMap['id_imagen']!['type'], equals('INTEGER'));
      expect(colMap['id_imagen']!['notnull'], equals(0));

      // 12. id_premio (nullable)
      expect(colMap['id_premio']!['type'], equals('INTEGER'));
      expect(colMap['id_premio']!['notnull'], equals(0));

      // 13. id_categoria_concurso
      expect(colMap['id_categoria_concurso']!['type'], equals('INTEGER'));
      expect(colMap['id_categoria_concurso']!['notnull'], equals(1));

      // 14. id_sub_categoria_concurso (nullable)
      expect(colMap['id_sub_categoria_concurso']!['type'], equals('INTEGER'));
      expect(colMap['id_sub_categoria_concurso']!['notnull'], equals(0));

      // 15. created_at
      expect(colMap['created_at']!['type'], equals('TEXT'));

      // 16. updated_at (nullable)
      expect(colMap['updated_at']!['type'], equals('TEXT'));
      expect(colMap['updated_at']!['notnull'], equals(0));

      // Foreign Keys
      final fks = await db.rawQuery('PRAGMA foreign_key_list(artesania_concurso)');
      final fkTables = fks.map((f) => f['table'] as String).toSet();
      expect(fkTables.contains('rama_artesanal'), isTrue);
      expect(fkTables.contains('premio'), isTrue);
      expect(fkTables.contains('categoria_concurso'), isTrue);
      expect(fkTables.contains('sub_categoria_concurso'), isTrue);

      await db.close();
    });

    test('Artesania toMap() y fromMap() soportan todos los campos en el orden correcto', () {
      final artesania = Artesania(
        id: 1,
        nombre: 'Rebozo de Seda',
        costoProduccion: 1200.0,
        costoVenta: 1800.0,
        estado: 'inscrito',
        tiempoElaboracion: 3.5,
        plazoElaboracion: 'semanas',
        materialElaboracion: 'Seda natural e hilos finos',
        descripcion: 'Rebozo fino con diseño tradicional',
        idRamaArtesanal: 2,
        ramaNombre: 'Textiles',
        idImagen: 42,
        idPremio: 5,
        premioNombre: 'Primer Lugar',
        idCategoriaConcurso: 1,
        categoriaNombre: 'Textiles y Rebozos',
        idSubCategoriaConcurso: 3,
        subcategoriaNombre: 'Seda Fina',
        createdAt: '2026-09-24 10:00:00',
        updatedAt: '2026-09-24 12:00:00',
      );

      final map = artesania.toMap();

      expect(map['id'], equals(1));
      expect(map['nombre'], equals('Rebozo de Seda'));
      expect(map['costo_produccion'], equals(1200.0));
      expect(map['costo_venta'], equals(1800.0));
      expect(map['estado'], equals('inscrito'));
      expect(map['tiempo_elaboracion'], equals(3.5));
      expect(map['plazo_elaboracion'], equals('semanas'));
      expect(map['material_elaboracion'], equals('Seda natural e hilos finos'));
      expect(map['descripcion'], equals('Rebozo fino con diseño tradicional'));
      expect(map['id_rama_artesanal'], equals(2));
      expect(map['id_imagen'], equals(42));
      expect(map['id_premio'], equals(5));
      expect(map['id_categoria_concurso'], equals(1));
      expect(map['id_sub_categoria_concurso'], equals(3));
      expect(map['created_at'], equals('2026-09-24 10:00:00'));
      expect(map['updated_at'], equals('2026-09-24 12:00:00'));

      final reconstituida = Artesania.fromMap(map,
          ramaNombre: 'Textiles',
          categoriaNombre: 'Textiles y Rebozos',
          subcategoriaNombre: 'Seda Fina',
          premioNombre: 'Primer Lugar');

      expect(reconstituida.id, equals(1));
      expect(reconstituida.nombre, equals('Rebozo de Seda'));
      expect(reconstituida.costoProduccion, equals(1200.0));
      expect(reconstituida.costoVenta, equals(1800.0));
      expect(reconstituida.estado, equals('inscrito'));
      expect(reconstituida.tiempoElaboracion, equals(3.5));
      expect(reconstituida.plazoElaboracion, equals('semanas'));
      expect(reconstituida.materialElaboracion, equals('Seda natural e hilos finos'));
      expect(reconstituida.descripcion, equals('Rebozo fino con diseño tradicional'));
      expect(reconstituida.idRamaArtesanal, equals(2));
      expect(reconstituida.ramaNombre, equals('Textiles'));
      expect(reconstituida.idImagen, equals(42));
      expect(reconstituida.idPremio, equals(5));
      expect(reconstituida.premioNombre, equals('Primer Lugar'));
      expect(reconstituida.idCategoriaConcurso, equals(1));
      expect(reconstituida.idSubCategoriaConcurso, equals(3));
      expect(reconstituida.createdAt, equals('2026-09-24 10:00:00'));
      expect(reconstituida.updatedAt, equals('2026-09-24 12:00:00'));
    });

    test('Migración reorganiza artesania_concurso antigua preservando datos y foreign keys', () async {
      // 1. Crear una base de datos con esquema v7 antiguo
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 7,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE rama_artesanal (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nombre TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE concurso (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nombre TEXT NOT NULL,
                id_tipo_concurso INTEGER NOT NULL DEFAULT 1
              )
            ''');
            await db.execute('''
              CREATE TABLE categoria_concurso (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nombre TEXT NOT NULL,
                id_concurso INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE sub_categoria_concurso (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nombre TEXT NOT NULL,
                id_categoria INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE premio (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                id_concurso INTEGER NOT NULL,
                id_tipo_premio INTEGER NOT NULL DEFAULT 1,
                nombre TEXT NOT NULL,
                monto INTEGER NOT NULL
              )
            ''');
            // Antigua artesania_concurso sin estado, sin id_premio, sin id_imagen, sin updated_at
            // y con id_rama_artesanal en 3er lugar
            await db.execute('''
              CREATE TABLE artesania_concurso (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nombre TEXT NOT NULL,
                id_rama_artesanal INTEGER NOT NULL,
                costo_produccion REAL NOT NULL,
                costo_venta REAL NOT NULL,
                tiempo_elaboracion REAL NOT NULL,
                plazo_elaboracion TEXT NOT NULL,
                material_elaboracion TEXT NOT NULL,
                descripcion TEXT,
                id_categoria_concurso INTEGER NOT NULL,
                id_sub_categoria_concurso INTEGER,
                created_at TEXT DEFAULT (datetime('now', 'localtime'))
              )
            ''');
            await db.execute('''
              CREATE TABLE premiacion (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                id_concurso INTEGER NOT NULL,
                id_premio INTEGER NOT NULL,
                id_artesania INTEGER NOT NULL
              )
            ''');
          },
        ),
      );

      // Insertar datos de prueba
      await db.insert('rama_artesanal', {'id': 1, 'nombre': 'Alfarería'});
      await db.insert('concurso', {'id': 1, 'nombre': 'Concurso Estatal'});
      await db.insert('categoria_concurso', {'id': 1, 'nombre': 'Barro Negro', 'id_concurso': 1});
      await db.insert('sub_categoria_concurso', {'id': 1, 'nombre': 'Ollas', 'id_categoria': 1});
      await db.insert('premio', {'id': 10, 'id_concurso': 1, 'nombre': 'Primer Lugar', 'monto': 10000});

      await db.insert('artesania_concurso', {
        'id': 100,
        'nombre': 'Jarrón de Barro',
        'id_rama_artesanal': 1,
        'costo_produccion': 500.0,
        'costo_venta': 800.0,
        'tiempo_elaboracion': 2.0,
        'plazo_elaboracion': 'semanas',
        'material_elaboracion': 'Barro rojo',
        'descripcion': 'Jarrón pulido a mano',
        'id_categoria_concurso': 1,
        'id_sub_categoria_concurso': 1,
        'created_at': '2026-09-20 10:00:00',
      });

      // Vincular en premiacion
      await db.insert('premiacion', {
        'id_concurso': 1,
        'id_premio': 10,
        'id_artesania': 100,
      });

      // 2. Ejecutar la migración a v10
      await AppDatabase().onUpgrade(db, 7, 10);

      // 3. Verificar que las columnas ahora tengan el orden y estructura correcta
      final cols = await db.rawQuery('PRAGMA table_info(artesania_concurso)');
      final expectedCols = [
        'id',
        'nombre',
        'costo_produccion',
        'costo_venta',
        'estado',
        'tiempo_elaboracion',
        'plazo_elaboracion',
        'material_elaboracion',
        'descripcion',
        'id_rama_artesanal',
        'id_imagen',
        'id_premio',
        'id_categoria_concurso',
        'id_sub_categoria_concurso',
        'created_at',
        'updated_at',
      ];

      expect(cols.length, equals(expectedCols.length));
      for (int i = 0; i < expectedCols.length; i++) {
        expect(cols[i]['name'], equals(expectedCols[i]));
      }

      // 4. Verificar que los datos históricos se conservaron intactos y se pobló id_premio
      final rows = await db.query('artesania_concurso', where: 'id = ?', whereArgs: [100]);
      expect(rows.length, equals(1));
      final r = rows.first;
      expect(r['nombre'], equals('Jarrón de Barro'));
      expect(r['costo_produccion'], equals(500.0));
      expect(r['costo_venta'], equals(800.0));
      expect(r['estado'], isNull);
      expect(r['tiempo_elaboracion'], equals(2.0));
      expect(r['plazo_elaboracion'], equals('semanas'));
      expect(r['material_elaboracion'], equals('Barro rojo'));
      expect(r['descripcion'], equals('Jarrón pulido a mano'));
      expect(r['id_rama_artesanal'], equals(1));
      expect(r['id_imagen'], isNull);
      expect(r['id_premio'], equals(10)); // Poblado desde premiación
      expect(r['id_categoria_concurso'], equals(1));
      expect(r['id_sub_categoria_concurso'], equals(1));
      expect(r['created_at'], equals('2026-09-20 10:00:00'));
      expect(r['updated_at'], equals('2026-09-20 10:00:00'));

      await db.close();
    });

    test('getRegistrosByConcurso devuelve los registros ordenados por folio de forma descendente (DESC)', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 10,
          onCreate: AppDatabase().onCreate,
          onUpgrade: AppDatabase().onUpgrade,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );

      final repo = RegistroRepository(dbHelper: AppDatabase.withDatabase(db));

      // 1. Crear Concurso y Categoría
      await db.insert('concurso', {
        'id': 1,
        'nombre': 'Concurso de Alfarería',
        'id_tipo_concurso': 1,
      });
      await db.insert('categoria_concurso', {
        'id': 1,
        'nombre': 'Barro Negro',
        'id_concurso': 1,
      });

      // 2. Insertar 3 inscripciones con folios consecutivos 1, 2, 3
      for (int i = 1; i <= 3; i++) {
        final pieza = Artesania(
          nombre: 'Pieza $i',
          costoProduccion: 100.0 * i,
          costoVenta: 200.0 * i,
          tiempoElaboracion: 1.0,
          plazoElaboracion: 'dias',
          materialElaboracion: 'Barro',
          descripcion: 'Descripción $i',
          idRamaArtesanal: 1,
          idCategoriaConcurso: 1,
        );

        final artesanoMap = {
          'nombre': 'Artesano',
          'ap_paterno': '$i',
          'curp': 'CURP00000000$i',
        };
        final artId = await db.insert('artesano', artesanoMap);
        final pId = await db.insert('artesania_concurso', pieza.toMap());

        await db.insert('registro_concurso', {
          'id': i,
          'folio': i,
          'id_artesano': artId,
          'id_concurso': 1,
          'id_artesania_1': pId,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // 3. Consultar a través del repositorio
      final registros = await repo.getRegistrosByConcurso(1);

      expect(registros.length, equals(3));
      expect(registros[0].folio, equals(3));
      expect(registros[1].folio, equals(2));
      expect(registros[2].folio, equals(1));

      await db.close();
    });
  });
}
