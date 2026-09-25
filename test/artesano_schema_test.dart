import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:casart_concursos_desktop/core/database/app_database.dart';
import 'package:casart_concursos_desktop/models/artesano.dart';
import 'package:casart_concursos_desktop/repositories/artesano_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Verificación de Esquema de Artesano, InfoContacto y Residencia', () {
    late Database db;
    late AppDatabase dbHelper;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 7,
          onCreate: AppDatabase().onCreate,
          onUpgrade: AppDatabase().onUpgrade,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );
      dbHelper = AppDatabase.withDatabase(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('1. La tabla info_contacto tiene las columnas requeridas y en orden', () async {
      final columns = await db.rawQuery('PRAGMA table_info(info_contacto)');
      final columnNames = columns.map((c) => c['name'] as String).toList();

      expect(columnNames, equals([
        'id',
        'correo',
        'telefono',
        'telefono_emergencia',
        'facebook',
        'instagram',
        'tiktok',
        'youtube',
        'x',
        'created_at',
        'updated_at',
      ]));
    });

    test('2. La tabla residencia tiene las columnas requeridas y en orden', () async {
      final columns = await db.rawQuery('PRAGMA table_info(residencia)');
      final columnNames = columns.map((c) => c['name'] as String).toList();

      expect(columnNames, equals([
        'id',
        'municipio',
        'localidad',
        'colonia',
        'calle',
        'numero_exterior',
        'cp',
        'created_at',
        'updated_at',
      ]));
    });

    test('3. La tabla artesano tiene las 30 columnas requeridas en el orden exacto solicitado', () async {
      final columns = await db.rawQuery('PRAGMA table_info(artesano)');
      final columnNames = columns.map((c) => c['name'] as String).toList();

      final expectedOrder = [
        'id',
        'nombre',
        'ap_paterno',
        'ap_materno',
        'curp',
        'rfc',
        'fecha_nacimiento',
        'genero',
        'finado',
        'max_nivel_academico',
        'id_imagen',
        'id_etnia',
        'id_info_contacto',
        'id_info_socioeconomica',
        'id_info_espacio_produccion',
        'id_info_artesanal',
        'id_materias_primas',
        'id_productos_principales',
        'id_canales_venta',
        'id_residencia',
        'id_problemas_salud',
        'id_estado_civil',
        'created_at',
        'updated_at',
        'deleted_at',
        'created_by',
        'id_firma',
        'numero_ine',
        'area',
        'verificado',
      ];

      expect(columnNames, equals(expectedOrder));

      // Validar que las columnas que se movieron a info_contacto y residencia YA NO están directamente en artesano
      expect(columnNames.contains('telefono'), isFalse);
      expect(columnNames.contains('correo_electronico'), isFalse);
      expect(columnNames.contains('municipio'), isFalse);
      expect(columnNames.contains('localidad'), isFalse);
      expect(columnNames.contains('colonia'), isFalse);
      expect(columnNames.contains('calle'), isFalse);
      expect(columnNames.contains('numero_exterior'), isFalse);
      expect(columnNames.contains('codigo_postal'), isFalse);
      expect(columnNames.contains('nivel_educativo'), isFalse); // Renombrado a max_nivel_academico
    });

    test('4. Inserción y consulta relacional completa a través de ArtesanoRepository', () async {
      final repo = ArtesanoRepository(dbHelper: dbHelper);

      final artesano = Artesano(
        nombre: 'María',
        apPaterno: 'Tzintzun',
        apMaterno: 'Pedro',
        curp: 'TZPM900101MMNRRL01',
        rfc: 'TZPM900101XYZ',
        fechaNacimiento: '1990-01-01',
        genero: 'F',
        finado: false,
        maxNivelAcademico: '5',
        correo: 'maria@ejemplo.com',
        telefono: '4439876543',
        telefonoEmergencia: '4431112233',
        facebook: 'facebook.com/mariatz',
        municipio: 'Tzintzuntzan',
        localidad: 'Tzintzuntzan',
        colonia: 'Barrio Yahuiche',
        calle: 'Av. Las Yácatas',
        numeroExterior: '12',
        cp: '58440',
        idEtnia: 5, // Purépecha
        idEstadoCivil: 1, // Casado
      );

      final id = await repo.createArtesano(artesano);
      expect(id, isPositive);

      // Verificar registro en tabla info_contacto
      final artRow = (await db.query('artesano', where: 'id = ?', whereArgs: [id])).first;
      expect(artRow['finado'], equals(0));
      expect(artRow['max_nivel_academico'], equals('5'));
      expect(artRow['area'], equals('concursos'));
      expect(artRow['verificado'], equals(0));

      final idInfoContacto = artRow['id_info_contacto'] as int;
      final contactRow = (await db.query('info_contacto', where: 'id = ?', whereArgs: [idInfoContacto])).first;
      expect(contactRow['telefono'], equals('4439876543'));
      expect(contactRow['correo'], equals('maria@ejemplo.com'));
      expect(contactRow['telefono_emergencia'], equals('4431112233'));
      expect(contactRow['facebook'], equals('facebook.com/mariatz'));

      final idResidencia = artRow['id_residencia'] as int;
      final resRow = (await db.query('residencia', where: 'id = ?', whereArgs: [idResidencia])).first;
      expect(resRow['municipio'], equals('Tzintzuntzan'));
      expect(resRow['localidad'], equals('Tzintzuntzan'));
      expect(resRow['colonia'], equals('Barrio Yahuiche'));
      expect(resRow['calle'], equals('Av. Las Yácatas'));
      expect(resRow['numero_exterior'], equals('12'));
      expect(resRow['cp'], equals('58440'));

      // Consulta del artesano recupera todos los datos relacionales
      final artConsultado = await repo.getArtesanoById(id);
      expect(artConsultado, isNotNull);
      expect(artConsultado!.nombreCompleto, equals('María Tzintzun Pedro'));
      expect(artConsultado.telefono, equals('4439876543'));
      expect(artConsultado.municipio, equals('Tzintzuntzan'));
      expect(artConsultado.localidad, equals('Tzintzuntzan'));
      expect(artConsultado.etniaNombre, equals('Purépecha'));
      expect(artConsultado.estadoCivilNombre, equals('Casado'));
      expect(artConsultado.maxNivelAcademico, equals('5'));
      expect(artConsultado.nivelEducativo, equals('5')); // Alias retrocompatible
      expect(artConsultado.finado, isFalse);
    });

    test('5. Migración de base de datos previa (Legacy Schema) preserva datos en las nuevas tablas', () async {
      // Simular base de datos legacy versión 5 con artesano plano
      final legacyDb = await databaseFactoryFfi.openDatabase(
        'legacy_migration_test.db',
        options: OpenDatabaseOptions(
          version: 5,
          singleInstance: false,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE etnia (id INTEGER PRIMARY KEY, nombre TEXT);
            ''');
            await db.execute('''
              CREATE TABLE estado_civil (id INTEGER PRIMARY KEY, nombre TEXT);
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
                id_etnia INTEGER,
                id_estado_civil INTEGER,
                nivel_educativo TEXT,
                telefono TEXT,
                correo_electronico TEXT,
                municipio TEXT NOT NULL,
                localidad TEXT NOT NULL,
                colonia TEXT,
                calle TEXT,
                numero_exterior TEXT,
                codigo_postal TEXT,
                verificado INTEGER DEFAULT 0,
                created_at TEXT DEFAULT (datetime('now', 'localtime'))
              )
            ''');

            await db.insert('artesano', {
              'id': 100,
              'nombre': 'Tata',
              'ap_paterno': 'Vasco',
              'ap_materno': 'Quiroga',
              'curp': 'VASQ700101HMCNRL01',
              'rfc': 'VASQ700101XYZ',
              'fecha_nacimiento': '1970-01-01',
              'genero': 'M',
              'nivel_educativo': '9',
              'telefono': '4430009988',
              'correo_electronico': 'tata@michoacan.gob.mx',
              'municipio': 'Pátzcuaro',
              'localidad': 'Santa Clara del Cobre',
              'colonia': 'Centro',
              'calle': 'Pino Suárez',
              'numero_exterior': '10',
              'codigo_postal': '61800',
              'verificado': 1,
            });
          },
        ),
      );

      // Ejecutar la migración a versión 7
      final appDb = AppDatabase();
      await appDb.onUpgrade(legacyDb, 5, 7);

      // Validar esquema de la tabla artesano migrada
      final cols = (await legacyDb.rawQuery('PRAGMA table_info(artesano)')).map((c) => c['name'] as String).toList();
      expect(cols.contains('finado'), isTrue);
      expect(cols.contains('max_nivel_academico'), isTrue);
      expect(cols.contains('id_info_contacto'), isTrue);
      expect(cols.contains('id_residencia'), isTrue);
      expect(cols.contains('area'), isTrue);
      expect(cols.contains('telefono'), isFalse);
      expect(cols.contains('municipio'), isFalse);

      // Validar que los datos del artesano migraron correctamente
      final migArt = (await legacyDb.query('artesano', where: 'id = 100')).first;
      expect(migArt['nombre'], equals('Tata'));
      expect(migArt['curp'], equals('VASQ700101HMCNRL01'));
      expect(migArt['max_nivel_academico'], equals('9'));
      expect(migArt['area'], equals('concursos'));
      expect(migArt['verificado'], equals(1));
      expect(migArt['finado'], equals(0));

      // Validar que se crearon los registros en info_contacto y residencia
      final idContact = migArt['id_info_contacto'] as int;
      final contactRow = (await legacyDb.query('info_contacto', where: 'id = ?', whereArgs: [idContact])).first;
      expect(contactRow['telefono'], equals('4430009988'));
      expect(contactRow['correo'], equals('tata@michoacan.gob.mx'));

      final idRes = migArt['id_residencia'] as int;
      final resRow = (await legacyDb.query('residencia', where: 'id = ?', whereArgs: [idRes])).first;
      expect(resRow['municipio'], equals('Pátzcuaro'));
      expect(resRow['localidad'], equals('Santa Clara del Cobre'));
      expect(resRow['colonia'], equals('Centro'));
      expect(resRow['calle'], equals('Pino Suárez'));
      expect(resRow['numero_exterior'], equals('10'));
      expect(resRow['cp'], equals('61800'));

      await legacyDb.close();
    });

    test('6. Búsqueda de artesanos busca estrictamente por ID o por CURP, no por nombre ni ubicación', () async {
      final repo = ArtesanoRepository(dbHelper: dbHelper);

      final id1 = await repo.createArtesano(Artesano(
        nombre: 'Pedro',
        apPaterno: 'Infante',
        apMaterno: 'Cruz',
        curp: 'INCP300101HMCNRL01',
        genero: 'H',
        municipio: 'Morelia',
        localidad: 'Morelia',
      ));

      final id2 = await repo.createArtesano(Artesano(
        nombre: 'María',
        apPaterno: 'Félix',
        apMaterno: 'Güereña',
        curp: 'FELM400202MMCNRL02',
        genero: 'M',
        municipio: 'Pátzcuaro',
        localidad: 'Pátzcuaro',
      ));

      // 1. Búsqueda por ID numérico exacto
      final resId1 = await repo.searchArtesanos(query: id1.toString());
      expect(resId1.isNotEmpty, isTrue);
      expect(resId1.first.id, equals(id1));
      expect(resId1.first.nombre, equals('Pedro'));

      final resId2 = await repo.searchArtesanos(query: id2.toString());
      expect(resId2.isNotEmpty, isTrue);
      expect(resId2.first.id, equals(id2));
      expect(resId2.first.nombre, equals('María'));

      // 2. Búsqueda por CURP (exacta y parcial)
      final resCurpExact = await repo.searchArtesanos(query: 'INCP300101HMCNRL01');
      expect(resCurpExact.isNotEmpty, isTrue);
      expect(resCurpExact.first.id, equals(id1));

      final resCurpParcial = await repo.searchArtesanos(query: 'FELM400');
      expect(resCurpParcial.isNotEmpty, isTrue);
      expect(resCurpParcial.first.id, equals(id2));

      // 3. Búsqueda por nombre o apellido debe retornar vacío (no debe buscar por nombre)
      final resNombre = await repo.searchArtesanos(query: 'Pedro');
      expect(resNombre.isEmpty, isTrue);

      final resApellido = await repo.searchArtesanos(query: 'Félix');
      expect(resApellido.isEmpty, isTrue);

      final resMunicipio = await repo.searchArtesanos(query: 'Morelia');
      expect(resMunicipio.isEmpty, isTrue);
    });
  });
}
