import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../logging/app_logger.dart';
import 'seed_data.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();
  AppDatabase.withDatabase(Database db) : _database = db;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Inicializar FFI para Windows Desktop
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 10,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          onOpen: (db) async {
            await _checkAportacionSchema(db);
            await _checkCategoriaSchema(db);
            await _checkPremioSchema(db);
            await _checkTipoConcursoSchema(db);
            await _checkArtesanoSchema(db);
            await _checkArtesaniaSchema(db);
            await _checkRegistroConcursoSchema(db);
          },
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final casartDir = Directory(p.join(documentsDirectory.path, 'CASART_Concursos'));
    if (!await casartDir.exists()) {
      await casartDir.create(recursive: true);
    }

    final path = p.join(casartDir.path, 'concursos_offline.db');
    AppLogger.info('Abriendo base de datos SQLite en: $path', category: 'DATABASE');

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 10,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          await _checkAportacionSchema(db);
          await _checkCategoriaSchema(db);
          await _checkPremioSchema(db);
          await _checkTipoConcursoSchema(db);
          await _checkArtesanoSchema(db);
          await _checkArtesaniaSchema(db);
          await _checkRegistroConcursoSchema(db);
        },
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
  }

  Future<void> onCreate(Database db, int version) => _onCreate(db, version);
  Future<void> onUpgrade(Database db, int oldVersion, int newVersion) => _onUpgrade(db, oldVersion, newVersion);

  Future<void> _checkAportacionSchema(Database db) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info(aportacion_concurso)');
      if (info.isEmpty) return;
      final colNames = info.map((r) => r['name'] as String).toList();
      if (!colNames.contains('updated_at') || (colNames.length >= 2 && colNames[1] == 'id_concurso')) {
        await _onUpgrade(db, 2, 3);
      }
    } catch (_) {}
  }

  Future<void> _checkCategoriaSchema(Database db) async {
    try {
      final catInfo = await db.rawQuery('PRAGMA table_info(categoria_concurso)');
      final subInfo = await db.rawQuery('PRAGMA table_info(sub_categoria_concurso)');
      final catCols = catInfo.map((r) => r['name'] as String).toList();
      final subCols = subInfo.map((r) => r['name'] as String).toList();

      final catNeedsUpgrade = catInfo.isNotEmpty &&
          (!catCols.contains('updated_at') || (catCols.length >= 2 && catCols[1] == 'id_concurso'));
      final subNeedsUpgrade = subInfo.isNotEmpty &&
          (!subCols.contains('updated_at') || (subCols.length >= 2 && subCols[1] == 'id_categoria'));

      if (catNeedsUpgrade || subNeedsUpgrade) {
        await _onUpgrade(db, 3, 4);
      }
    } catch (_) {}
  }

  Future<void> _checkPremioSchema(Database db) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info(premio)');
      if (info.isEmpty) return;
      final colNames = info.map((r) => r['name'] as String).toList();
      if (!colNames.contains('updated_at') || (colNames.length >= 2 && colNames[1] != 'id_categoria')) {
        await _onUpgrade(db, 4, 5);
      }
    } catch (_) {}
  }

  Future<void> _checkTipoConcursoSchema(Database db) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info(tipo_concurso)');
      if (info.isEmpty) return;
      final colNames = info.map((r) => r['name'] as String).toList();
      if (!colNames.contains('updated_at')) {
        await _onUpgrade(db, 5, 6);
      }
    } catch (_) {}
  }

  Future<void> _checkArtesanoSchema(Database db) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info(artesano)');
      if (info.isEmpty) return;
      final colNames = info.map((r) => r['name'] as String).toList();
      final contactTable = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='info_contacto'");
      final resTable = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='residencia'");
      final needsMigration = contactTable.isEmpty ||
          resTable.isEmpty ||
          colNames.contains('telefono') ||
          colNames.contains('municipio') ||
          !colNames.contains('max_nivel_academico') ||
          !colNames.contains('id_info_contacto') ||
          !colNames.contains('id_residencia') ||
          !colNames.contains('id_info_espacio_produccion');
      if (needsMigration) {
        await _migrateArtesanoSchema(db);
      }
    } catch (_) {}
  }

  Future<void> _checkArtesaniaSchema(Database db) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info(artesania_concurso)');
      if (info.isEmpty) return;
      final colNames = info.map((r) => r['name'] as String).toList();
      final needsMigration = !colNames.contains('updated_at') ||
          !colNames.contains('estado') ||
          !colNames.contains('id_premio') ||
          !colNames.contains('id_imagen') ||
          (colNames.length >= 3 && colNames[2] != 'costo_produccion');
      if (needsMigration) {
        await _migrateArtesaniaSchema(db);
      }
    } catch (_) {}
  }

  Future<void> _checkRegistroConcursoSchema(Database db) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info(registro_concurso)');
      if (info.isEmpty) return;
      final colNames = info.map((r) => r['name'] as String).toList();
      final needsMigration = !colNames.contains('updated_at') ||
          (colNames.length >= 2 && colNames[1] != 'folio') ||
          (colNames.length >= 4 && colNames[3] != 'id_concurso') ||
          (colNames.length >= 5 && colNames[4] != 'id_artesania_1');
      if (needsMigration) {
        await _migrateRegistroConcursoSchema(db);
      }
    } catch (_) {}
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2 && newVersion >= 2) {
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='concurso'");
      if (tables.isNotEmpty) {
        // Reorganizar tabla concurso para que coincida exactamente con la migración de Laravel
        await db.execute('PRAGMA foreign_keys = OFF');
        await db.execute('''
          CREATE TABLE concurso_tmp (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            fecha_inicio_registro TEXT,
            fecha_limite_registro TEXT,
            finalizado INTEGER DEFAULT 0,
            ejercicio TEXT DEFAULT (strftime('%Y', 'now')),
            lugar TEXT,
            fecha_dictamen TEXT,
            fecha_premiacion TEXT,
            id_tipo_concurso INTEGER NOT NULL,
            iva INTEGER DEFAULT 16,
            utilidad REAL DEFAULT 0.0,
            created_at TEXT DEFAULT (datetime('now', 'localtime')),
            updated_at TEXT,
            FOREIGN KEY (id_tipo_concurso) REFERENCES tipo_concurso(id)
          )
        ''');

        await db.execute('''
          INSERT INTO concurso_tmp (
            id, nombre, fecha_inicio_registro, fecha_limite_registro,
            finalizado, ejercicio, lugar, fecha_dictamen, fecha_premiacion,
            id_tipo_concurso, iva, utilidad, created_at, updated_at
          )
          SELECT
            id, nombre, fecha_inicio_registro, fecha_limite_registro,
            finalizado, ejercicio, lugar, fecha_dictamen, fecha_premiacion,
            id_tipo_concurso, CAST(iva AS INTEGER), utilidad, created_at, created_at
          FROM concurso
        ''');

        await db.execute('DROP TABLE concurso');
        await db.execute('ALTER TABLE concurso_tmp RENAME TO concurso');
        await db.execute('PRAGMA foreign_keys = ON');
      }
    }

    if (oldVersion < 3 && newVersion >= 3) {
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='aportacion_concurso'");
      if (tables.isNotEmpty) {
        // Reorganizar tabla aportacion_concurso para que coincida exactamente con la migración de Laravel
        await db.execute('PRAGMA foreign_keys = OFF');
        await db.execute('''
          CREATE TABLE aportacion_concurso_tmp (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            cantidad DECIMAL(12, 2) NOT NULL,
            id_concurso INTEGER NOT NULL,
            created_at TEXT DEFAULT (datetime('now', 'localtime')),
            updated_at TEXT,
            FOREIGN KEY (id_concurso) REFERENCES concurso(id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          INSERT INTO aportacion_concurso_tmp (
            id, nombre, cantidad, id_concurso, created_at, updated_at
          )
          SELECT
            id, nombre, cantidad, id_concurso, created_at, created_at
          FROM aportacion_concurso
        ''');

        await db.execute('DROP TABLE aportacion_concurso');
        await db.execute('ALTER TABLE aportacion_concurso_tmp RENAME TO aportacion_concurso');
        await db.execute('PRAGMA foreign_keys = ON');
      }
    }

    if (oldVersion < 4 && newVersion >= 4) {
      // Reorganizar tablas categoria_concurso y sub_categoria_concurso para que coincidan 100% con Laravel:
      // categoria_concurso: id, nombre, id_concurso, activo, created_at, updated_at
      // sub_categoria_concurso: id, nombre, id_categoria, activo, created_at, updated_at
      await db.execute('PRAGMA foreign_keys = OFF');

      final catTables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='categoria_concurso'");
      if (catTables.isNotEmpty) {
        final catInfo = await db.rawQuery('PRAGMA table_info(categoria_concurso)');
        final catCols = catInfo.map((r) => r['name'] as String).toList();
        if (!catCols.contains('updated_at') || (catCols.length >= 2 && catCols[1] == 'id_concurso')) {
          await db.execute('''
            CREATE TABLE categoria_concurso_tmp (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nombre TEXT NOT NULL,
              id_concurso INTEGER NOT NULL,
              activo INTEGER DEFAULT 1,
              created_at TEXT DEFAULT (datetime('now', 'localtime')),
              updated_at TEXT,
              FOREIGN KEY (id_concurso) REFERENCES concurso(id) ON DELETE CASCADE
            )
          ''');

          await db.execute('''
            INSERT INTO categoria_concurso_tmp (
              id, nombre, id_concurso, activo, created_at, updated_at
            )
            SELECT
              id, nombre, id_concurso, activo,
              datetime('now', 'localtime'), datetime('now', 'localtime')
            FROM categoria_concurso
          ''');

          await db.execute('DROP TABLE categoria_concurso');
          await db.execute('ALTER TABLE categoria_concurso_tmp RENAME TO categoria_concurso');
        }
      }

      final subTables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='sub_categoria_concurso'");
      if (subTables.isNotEmpty) {
        final subInfo = await db.rawQuery('PRAGMA table_info(sub_categoria_concurso)');
        final subCols = subInfo.map((r) => r['name'] as String).toList();
        if (!subCols.contains('updated_at') || (subCols.length >= 2 && subCols[1] == 'id_categoria')) {
          await db.execute('''
            CREATE TABLE sub_categoria_concurso_tmp (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nombre TEXT NOT NULL,
              id_categoria INTEGER NOT NULL,
              activo INTEGER DEFAULT 1,
              created_at TEXT DEFAULT (datetime('now', 'localtime')),
              updated_at TEXT,
              FOREIGN KEY (id_categoria) REFERENCES categoria_concurso(id) ON DELETE CASCADE
            )
          ''');

          await db.execute('''
            INSERT INTO sub_categoria_concurso_tmp (
              id, nombre, id_categoria, activo, created_at, updated_at
            )
            SELECT
              id, nombre, id_categoria, activo,
              datetime('now', 'localtime'), datetime('now', 'localtime')
            FROM sub_categoria_concurso
          ''');

          await db.execute('DROP TABLE sub_categoria_concurso');
          await db.execute('ALTER TABLE sub_categoria_concurso_tmp RENAME TO sub_categoria_concurso');
        }
      }

      await db.execute('PRAGMA foreign_keys = ON');
    }

    if (oldVersion < 5 && newVersion >= 5) {
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='premio'");
      if (tables.isNotEmpty) {
        // Reorganizar tabla premio para que coincida exactamente con la migración de Laravel:
        // id, id_categoria, id_concurso, id_tipo_premio, id_sub_categoria, nombre, monto, lugar, limite_otorgacion, activo, created_at, updated_at
        await db.execute('PRAGMA foreign_keys = OFF');
        await db.execute('''
          CREATE TABLE premio_tmp (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            id_categoria INTEGER,
            id_concurso INTEGER NOT NULL,
            id_tipo_premio INTEGER NOT NULL,
            id_sub_categoria INTEGER,
            nombre TEXT NOT NULL,
            monto INTEGER NOT NULL,
            lugar INTEGER,
            limite_otorgacion INTEGER DEFAULT 1,
            activo INTEGER DEFAULT 1,
            created_at TEXT DEFAULT (datetime('now', 'localtime')),
            updated_at TEXT,
            FOREIGN KEY (id_concurso) REFERENCES concurso(id) ON DELETE CASCADE,
            FOREIGN KEY (id_categoria) REFERENCES categoria_concurso(id),
            FOREIGN KEY (id_sub_categoria) REFERENCES sub_categoria_concurso(id),
            FOREIGN KEY (id_tipo_premio) REFERENCES tipo_premio(id)
          )
        ''');

        await db.execute('''
          INSERT INTO premio_tmp (
            id, id_categoria, id_concurso, id_tipo_premio, id_sub_categoria,
            nombre, monto, lugar, limite_otorgacion, activo, created_at, updated_at
          )
          SELECT
            id, id_categoria, id_concurso, id_tipo_premio, id_sub_categoria,
            nombre, CAST(monto AS INTEGER), lugar, limite_otorgacion, activo,
            datetime('now', 'localtime'), datetime('now', 'localtime')
          FROM premio
        ''');

        await db.execute('DROP TABLE premio');
        await db.execute('ALTER TABLE premio_tmp RENAME TO premio');
        await db.execute('PRAGMA foreign_keys = ON');
      }
    }

    if (oldVersion < 6 && newVersion >= 6) {
      // Reorganizar tabla tipo_concurso para que coincida exactamente con la migración de Laravel:
      // id, nombre, created_at, updated_at
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='tipo_concurso'");
      if (tables.isNotEmpty) {
        final info = await db.rawQuery('PRAGMA table_info(tipo_concurso)');
        final colNames = info.map((r) => r['name'] as String).toList();
        if (!colNames.contains('updated_at')) {
          await db.execute('PRAGMA foreign_keys = OFF');
          await db.execute('''
            CREATE TABLE tipo_concurso_tmp (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nombre TEXT NOT NULL UNIQUE,
              created_at TEXT DEFAULT (datetime('now', 'localtime')),
              updated_at TEXT
            )
          ''');

          await db.execute('''
            INSERT INTO tipo_concurso_tmp (id, nombre, created_at, updated_at)
            SELECT id, nombre, datetime('now', 'localtime'), datetime('now', 'localtime')
            FROM tipo_concurso
          ''');

          await db.execute('DROP TABLE tipo_concurso');
          await db.execute('ALTER TABLE tipo_concurso_tmp RENAME TO tipo_concurso');
          await db.execute('PRAGMA foreign_keys = ON');
        }
      }
    }

    if (oldVersion < 7 && newVersion >= 7) {
      await _migrateArtesanoSchema(db);
    }

    if (oldVersion < 8 && newVersion >= 8) {
      await _migrateArtesaniaSchema(db);
    }

    if (oldVersion < 9 && newVersion >= 9) {
      await _migrateRegistroConcursoSchema(db);
    }

    if (oldVersion < 10 && newVersion >= 10) {
      await _migrateArtesaniaSchema(db);
    }
  }

  Future<void> _migrateArtesanoSchema(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF');

    // 1. Crear tablas info_contacto y residencia si no existen
    await db.execute('''
      CREATE TABLE IF NOT EXISTS info_contacto (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        correo TEXT,
        telefono TEXT,
        telefono_emergencia TEXT,
        facebook TEXT,
        instagram TEXT,
        tiktok TEXT,
        youtube TEXT,
        x TEXT,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS residencia (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        municipio TEXT NOT NULL,
        localidad TEXT NOT NULL,
        colonia TEXT,
        calle TEXT,
        numero_exterior TEXT,
        cp TEXT,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT
      )
    ''');

    // 2. Crear tabla temporal artesano_tmp con el nuevo esquema
    await db.execute('''
      CREATE TABLE IF NOT EXISTS artesano_tmp (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        ap_paterno TEXT NOT NULL,
        ap_materno TEXT,
        curp TEXT NOT NULL UNIQUE,
        rfc TEXT,
        fecha_nacimiento TEXT,
        genero TEXT,
        finado INTEGER DEFAULT 0,
        max_nivel_academico TEXT DEFAULT '0',
        id_imagen INTEGER DEFAULT NULL,
        id_etnia INTEGER,
        id_info_contacto INTEGER,
        id_info_socioeconomica INTEGER,
        id_info_espacio_produccion INTEGER,
        id_info_artesanal INTEGER,
        id_materias_primas INTEGER,
        id_productos_principales INTEGER,
        id_canales_venta INTEGER,
        id_residencia INTEGER,
        id_problemas_salud INTEGER,
        id_estado_civil INTEGER,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT,
        deleted_at TEXT,
        created_by INTEGER,
        id_firma INTEGER,
        numero_ine TEXT,
        area TEXT DEFAULT 'concursos',
        verificado INTEGER DEFAULT 0,
        FOREIGN KEY (id_etnia) REFERENCES etnia(id),
        FOREIGN KEY (id_info_contacto) REFERENCES info_contacto(id),
        FOREIGN KEY (id_residencia) REFERENCES residencia(id),
        FOREIGN KEY (id_estado_civil) REFERENCES estado_civil(id)
      )
    ''');

    // 3. Migrar registros de la tabla previa si existe
    final artesanoInfo = await db.rawQuery('PRAGMA table_info(artesano)');
    if (artesanoInfo.isNotEmpty) {
      final cols = artesanoInfo.map((r) => r['name'] as String).toSet();
      final oldRows = await db.rawQuery('SELECT * FROM artesano');
      for (final row in oldRows) {
        int? idInfoContacto = cols.contains('id_info_contacto') ? (row['id_info_contacto'] as int?) : null;
        int? idResidencia = cols.contains('id_residencia') ? (row['id_residencia'] as int?) : null;

        if (idInfoContacto == null && (cols.contains('telefono') || cols.contains('correo_electronico'))) {
          final correo = (row['correo_electronico'] ?? row['correo']) as String?;
          final tel = row['telefono'] as String?;
          final createdAt = (row['created_at'] ?? DateTime.now().toIso8601String()) as String;
          idInfoContacto = await db.insert('info_contacto', {
            'correo': correo,
            'telefono': tel,
            'created_at': createdAt,
            'updated_at': createdAt,
          });
        }

        if (idResidencia == null && cols.contains('municipio')) {
          final mun = (row['municipio'] as String?) ?? 'Desconocido';
          final loc = (row['localidad'] as String?) ?? 'Desconocida';
          final col = row['colonia'] as String?;
          final calle = row['calle'] as String?;
          final numExt = row['numero_exterior'] as String?;
          final cp = (row['codigo_postal'] ?? row['cp']) as String?;
          final createdAt = (row['created_at'] ?? DateTime.now().toIso8601String()) as String;
          idResidencia = await db.insert('residencia', {
            'municipio': mun,
            'localidad': loc,
            'colonia': col,
            'calle': calle,
            'numero_exterior': numExt,
            'cp': cp,
            'created_at': createdAt,
            'updated_at': createdAt,
          });
        }

        final nivel = (row['max_nivel_academico'] ?? row['nivel_educativo'] ?? '0').toString();
        final createdAt = (row['created_at'] ?? DateTime.now().toIso8601String()) as String;

        await db.insert('artesano_tmp', {
          'id': row['id'],
          'nombre': row['nombre'],
          'ap_paterno': row['ap_paterno'],
          'ap_materno': row['ap_materno'],
          'curp': row['curp'],
          'rfc': row['rfc'],
          'fecha_nacimiento': row['fecha_nacimiento'],
          'genero': row['genero'],
          'finado': (row['finado'] == 1 || row['finado'] == true) ? 1 : 0,
          'max_nivel_academico': nivel,
          'id_imagen': cols.contains('id_imagen') ? row['id_imagen'] : null,
          'id_etnia': row['id_etnia'],
          'id_info_contacto': idInfoContacto,
          'id_info_socioeconomica': cols.contains('id_info_socioeconomica') ? row['id_info_socioeconomica'] : null,
          'id_info_espacio_produccion': cols.contains('id_info_espacio_produccion') ? row['id_info_espacio_produccion'] : null,
          'id_info_artesanal': cols.contains('id_info_artesanal') ? row['id_info_artesanal'] : null,
          'id_materias_primas': cols.contains('id_materias_primas') ? row['id_materias_primas'] : null,
          'id_productos_principales': cols.contains('id_productos_principales') ? row['id_productos_principales'] : null,
          'id_canales_venta': cols.contains('id_canales_venta') ? row['id_canales_venta'] : null,
          'id_residencia': idResidencia,
          'id_problemas_salud': cols.contains('id_problemas_salud') ? row['id_problemas_salud'] : null,
          'id_estado_civil': row['id_estado_civil'],
          'created_at': createdAt,
          'updated_at': cols.contains('updated_at') ? row['updated_at'] : createdAt,
          'deleted_at': cols.contains('deleted_at') ? row['deleted_at'] : null,
          'created_by': cols.contains('created_by') ? row['created_by'] : null,
          'id_firma': cols.contains('id_firma') ? row['id_firma'] : null,
          'numero_ine': cols.contains('numero_ine') ? row['numero_ine'] : null,
          'area': cols.contains('area') ? (row['area'] ?? 'concursos') : 'concursos',
          'verificado': (row['verificado'] == 1 || row['verificado'] == true) ? 1 : 0,
        });
      }

      await db.execute('DROP TABLE artesano');
      await db.execute('ALTER TABLE artesano_tmp RENAME TO artesano');
    }

    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _migrateArtesaniaSchema(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF');

    final info = await db.rawQuery('PRAGMA table_info(artesania_concurso)');
    if (info.isNotEmpty) {
      final colNames = info.map((r) => r['name'] as String).toSet();

      await db.execute('''
        CREATE TABLE IF NOT EXISTS artesania_concurso_tmp (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL,
          costo_produccion REAL NOT NULL,
          costo_venta REAL NOT NULL,
          estado TEXT,
          tiempo_elaboracion REAL NOT NULL,
          plazo_elaboracion TEXT NOT NULL,
          material_elaboracion TEXT NOT NULL,
          descripcion TEXT,
          id_rama_artesanal INTEGER NOT NULL,
          id_imagen INTEGER,
          id_premio INTEGER,
          id_categoria_concurso INTEGER NOT NULL,
          id_sub_categoria_concurso INTEGER,
          created_at TEXT DEFAULT (datetime('now', 'localtime')),
          updated_at TEXT,
          FOREIGN KEY (id_rama_artesanal) REFERENCES rama_artesanal(id),
          FOREIGN KEY (id_premio) REFERENCES premio(id),
          FOREIGN KEY (id_categoria_concurso) REFERENCES categoria_concurso(id),
          FOREIGN KEY (id_sub_categoria_concurso) REFERENCES sub_categoria_concurso(id)
        )
      ''');

      final hasEstado = colNames.contains('estado');
      final hasIdImagen = colNames.contains('id_imagen');
      final hasIdPremio = colNames.contains('id_premio');
      final hasUpdatedAt = colNames.contains('updated_at');

      final estadoExpr = hasEstado ? 'estado' : 'NULL';
      final imagenExpr = hasIdImagen ? 'id_imagen' : 'NULL';
      final premioExpr = hasIdPremio
          ? 'id_premio'
          : '(SELECT pr.id_premio FROM premiacion pr WHERE pr.id_artesania = artesania_concurso.id LIMIT 1)';
      final updatedExpr = hasUpdatedAt ? 'updated_at' : 'created_at';

      await db.execute('''
        INSERT INTO artesania_concurso_tmp (
          id, nombre, costo_produccion, costo_venta, estado,
          tiempo_elaboracion, plazo_elaboracion, material_elaboracion, descripcion,
          id_rama_artesanal, id_imagen, id_premio,
          id_categoria_concurso, id_sub_categoria_concurso,
          created_at, updated_at
        )
        SELECT
          id,
          nombre,
          costo_produccion,
          costo_venta,
          $estadoExpr,
          tiempo_elaboracion,
          plazo_elaboracion,
          material_elaboracion,
          descripcion,
          id_rama_artesanal,
          $imagenExpr,
          $premioExpr,
          id_categoria_concurso,
          id_sub_categoria_concurso,
          created_at,
          $updatedExpr
        FROM artesania_concurso
      ''');

      await db.execute('DROP TABLE artesania_concurso');
      await db.execute('ALTER TABLE artesania_concurso_tmp RENAME TO artesania_concurso');
    }

    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _migrateRegistroConcursoSchema(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF');

    final info = await db.rawQuery('PRAGMA table_info(registro_concurso)');
    if (info.isNotEmpty) {
      final colNames = info.map((r) => r['name'] as String).toSet();

      await db.execute('''
        CREATE TABLE IF NOT EXISTS registro_concurso_tmp (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          folio INTEGER NOT NULL,
          id_artesano INTEGER NOT NULL,
          id_concurso INTEGER NOT NULL,
          id_artesania_1 INTEGER NOT NULL,
          id_artesania_2 INTEGER,
          created_at TEXT DEFAULT (datetime('now', 'localtime')),
          updated_at TEXT,
          FOREIGN KEY (id_concurso) REFERENCES concurso(id) ON DELETE CASCADE,
          FOREIGN KEY (id_artesano) REFERENCES artesano(id),
          FOREIGN KEY (id_artesania_1) REFERENCES artesania_concurso(id),
          FOREIGN KEY (id_artesania_2) REFERENCES artesania_concurso(id),
          UNIQUE (id_concurso, folio)
        )
      ''');

      final hasUpdatedAt = colNames.contains('updated_at');
      final updatedExpr = hasUpdatedAt ? 'updated_at' : 'created_at';

      await db.execute('''
        INSERT INTO registro_concurso_tmp (
          id, folio, id_artesano, id_concurso, id_artesania_1, id_artesania_2, created_at, updated_at
        )
        SELECT
          id, folio, id_artesano, id_concurso, id_artesania_1, id_artesania_2, created_at, $updatedExpr
        FROM registro_concurso
      ''');

      await db.execute('DROP TABLE registro_concurso');
      await db.execute('ALTER TABLE registro_concurso_tmp RENAME TO registro_concurso');
    }

    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Catálogos base
    await db.execute('''
      CREATE TABLE tipo_concurso (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE etnia (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE estado_civil (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE rama_artesanal (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tipo_premio (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL
      )
    ''');

    // 2. Tablas del Concurso (mismas columnas, tipo y orden que migración Laravel)
    await db.execute('''
      CREATE TABLE concurso (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        fecha_inicio_registro TEXT,
        fecha_limite_registro TEXT,
        finalizado INTEGER DEFAULT 0,
        ejercicio TEXT DEFAULT (strftime('%Y', 'now')),
        lugar TEXT,
        fecha_dictamen TEXT,
        fecha_premiacion TEXT,
        id_tipo_concurso INTEGER NOT NULL,
        iva INTEGER DEFAULT 16,
        utilidad REAL DEFAULT 0.0,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT,
        FOREIGN KEY (id_tipo_concurso) REFERENCES tipo_concurso(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE categoria_concurso (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        id_concurso INTEGER NOT NULL,
        activo INTEGER DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT,
        FOREIGN KEY (id_concurso) REFERENCES concurso(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sub_categoria_concurso (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        id_categoria INTEGER NOT NULL,
        activo INTEGER DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT,
        FOREIGN KEY (id_categoria) REFERENCES categoria_concurso(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE aportacion_concurso (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        cantidad DECIMAL(12, 2) NOT NULL,
        id_concurso INTEGER NOT NULL,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT,
        FOREIGN KEY (id_concurso) REFERENCES concurso(id) ON DELETE CASCADE
      )
    ''');

    // 3. Tablas de Artesano (mismas columnas, tipo y orden que migración Laravel)
    await db.execute('''
      CREATE TABLE info_contacto (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        correo TEXT,
        telefono TEXT,
        telefono_emergencia TEXT,
        facebook TEXT,
        instagram TEXT,
        tiktok TEXT,
        youtube TEXT,
        x TEXT,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE residencia (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        municipio TEXT NOT NULL,
        localidad TEXT NOT NULL,
        colonia TEXT,
        calle TEXT,
        numero_exterior TEXT,
        cp TEXT,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE artesano (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        ap_paterno TEXT NOT NULL,
        ap_materno TEXT,
        curp TEXT NOT NULL UNIQUE,
        rfc TEXT,
        fecha_nacimiento TEXT,
        genero TEXT,
        finado INTEGER DEFAULT 0,
        max_nivel_academico TEXT DEFAULT '0',
        id_imagen INTEGER DEFAULT NULL,
        id_etnia INTEGER,
        id_info_contacto INTEGER,
        id_info_socioeconomica INTEGER,
        id_info_espacio_produccion INTEGER,
        id_info_artesanal INTEGER,
        id_materias_primas INTEGER,
        id_productos_principales INTEGER,
        id_canales_venta INTEGER,
        id_residencia INTEGER,
        id_problemas_salud INTEGER,
        id_estado_civil INTEGER,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT,
        deleted_at TEXT,
        created_by INTEGER,
        id_firma INTEGER,
        numero_ine TEXT,
        area TEXT DEFAULT 'concursos',
        verificado INTEGER DEFAULT 0,
        FOREIGN KEY (id_etnia) REFERENCES etnia(id),
        FOREIGN KEY (id_info_contacto) REFERENCES info_contacto(id),
        FOREIGN KEY (id_residencia) REFERENCES residencia(id),
        FOREIGN KEY (id_estado_civil) REFERENCES estado_civil(id)
      )
    ''');

    // 4. Piezas registradas al concurso
    await db.execute('''
      CREATE TABLE artesania_concurso (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        costo_produccion REAL NOT NULL,
        costo_venta REAL NOT NULL,
        estado TEXT,
        tiempo_elaboracion REAL NOT NULL,
        plazo_elaboracion TEXT NOT NULL,
        material_elaboracion TEXT NOT NULL,
        descripcion TEXT,
        id_rama_artesanal INTEGER NOT NULL,
        id_imagen INTEGER,
        id_premio INTEGER,
        id_categoria_concurso INTEGER NOT NULL,
        id_sub_categoria_concurso INTEGER,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT,
        FOREIGN KEY (id_rama_artesanal) REFERENCES rama_artesanal(id),
        FOREIGN KEY (id_premio) REFERENCES premio(id),
        FOREIGN KEY (id_categoria_concurso) REFERENCES categoria_concurso(id),
        FOREIGN KEY (id_sub_categoria_concurso) REFERENCES sub_categoria_concurso(id)
      )
    ''');

    // 5. Cédula o Registro de Concurso
    await db.execute('''
      CREATE TABLE registro_concurso (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folio INTEGER NOT NULL,
        id_artesano INTEGER NOT NULL,
        id_concurso INTEGER NOT NULL,
        id_artesania_1 INTEGER NOT NULL,
        id_artesania_2 INTEGER,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT,
        FOREIGN KEY (id_concurso) REFERENCES concurso(id) ON DELETE CASCADE,
        FOREIGN KEY (id_artesano) REFERENCES artesano(id),
        FOREIGN KEY (id_artesania_1) REFERENCES artesania_concurso(id),
        FOREIGN KEY (id_artesania_2) REFERENCES artesania_concurso(id),
        UNIQUE (id_concurso, folio)
      )
    ''');

    // 6. Premios y Premiación (mismas columnas, tipo y orden que migración Laravel)
    await db.execute('''
      CREATE TABLE premio (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_categoria INTEGER,
        id_concurso INTEGER NOT NULL,
        id_tipo_premio INTEGER NOT NULL,
        id_sub_categoria INTEGER,
        nombre TEXT NOT NULL,
        monto INTEGER NOT NULL,
        lugar INTEGER,
        limite_otorgacion INTEGER DEFAULT 1,
        activo INTEGER DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT,
        FOREIGN KEY (id_concurso) REFERENCES concurso(id) ON DELETE CASCADE,
        FOREIGN KEY (id_categoria) REFERENCES categoria_concurso(id),
        FOREIGN KEY (id_sub_categoria) REFERENCES sub_categoria_concurso(id),
        FOREIGN KEY (id_tipo_premio) REFERENCES tipo_premio(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE premiacion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_concurso INTEGER NOT NULL,
        id_premio INTEGER NOT NULL,
        id_categoria INTEGER,
        id_artesania INTEGER NOT NULL,
        lugar INTEGER,
        created_at TEXT DEFAULT (datetime('now', 'localtime')),
        FOREIGN KEY (id_concurso) REFERENCES concurso(id) ON DELETE CASCADE,
        FOREIGN KEY (id_premio) REFERENCES premio(id),
        FOREIGN KEY (id_artesania) REFERENCES artesania_concurso(id)
      )
    ''');

    // Poblado de catálogos base (Seeders)
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    for (final tipo in SeedData.tiposConcurso) {
      batch.insert('tipo_concurso', {
        'nombre': tipo,
        'created_at': now,
        'updated_at': now,
      });
    }

    for (final etnia in SeedData.etnias) {
      batch.insert('etnia', {'nombre': etnia});
    }

    for (final ec in SeedData.estadosCiviles) {
      batch.insert('estado_civil', {'nombre': ec});
    }

    for (final rama in SeedData.ramasArtesanales) {
      batch.insert('rama_artesanal', {'nombre': rama});
    }

    for (final tp in SeedData.tiposPremio) {
      batch.insert('tipo_premio', {'nombre': tp});
    }

    await batch.commit(noResult: true);
  }

  /// Permite respaldar el archivo SQLite actual a la ruta destino proporcionada
  Future<void> backupDatabase(String destinationPath) async {
    final db = await database;
    await db.close();
    _database = null;

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final sourcePath = p.join(documentsDirectory.path, 'CASART_Concursos', 'concursos_offline.db');
    final sourceFile = File(sourcePath);
    if (await sourceFile.exists()) {
      await sourceFile.copy(destinationPath);
      AppLogger.create(
        'Copia de seguridad de base de datos realizada con éxito en: $destinationPath',
        category: 'RESPALDO',
        data: {'origen': sourcePath, 'destino': destinationPath},
      );
    }

    // Reabrir la base de datos
    _database = await _initDatabase();
  }

  /// Retorna la ruta física del archivo de la base de datos
  Future<String> getDatabasePath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return p.join(documentsDirectory.path, 'CASART_Concursos', 'concursos_offline.db');
  }
}
