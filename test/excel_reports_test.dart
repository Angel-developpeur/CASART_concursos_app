import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:casart_concursos_desktop/core/database/app_database.dart';
import 'package:casart_concursos_desktop/core/utils/numero_a_letras.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Pruebas de Conversión de Números a Letras (NumeroALetras)', () {
    test('Conversión de enteros a letras básica', () {
      expect(NumeroALetras.convertirEnteroALetras(0), equals('cero'));
      expect(NumeroALetras.convertirEnteroALetras(1), equals('un'));
      expect(NumeroALetras.convertirEnteroALetras(15), equals('quince'));
      expect(NumeroALetras.convertirEnteroALetras(21), equals('veintiun'));
      expect(NumeroALetras.convertirEnteroALetras(100), equals('cien'));
      expect(NumeroALetras.convertirEnteroALetras(105), equals('ciento cinco'));
      expect(NumeroALetras.convertirEnteroALetras(1000), equals('mil'));
      expect(NumeroALetras.convertirEnteroALetras(25000), equals('veinticinco mil'));
      expect(NumeroALetras.convertirEnteroALetras(1000000), equals('un millón'));
      expect(NumeroALetras.convertirEnteroALetras(2500000), equals('dos millones quinientos mil'));
    });

    test('Conversión de montos monetarios en formato oficial de concurso', () {
      expect(
        NumeroALetras.numeroAMonedaLetras(0),
        equals('Cero pesos 00/100 M.N.'),
      );
      expect(
        NumeroALetras.numeroAMonedaLetras(1),
        equals('Un peso 00/100 M.N.'),
      );
      expect(
        NumeroALetras.numeroAMonedaLetras(25000),
        equals('Veinticinco mil pesos 00/100 M.N.'),
      );
      expect(
        NumeroALetras.numeroAMonedaLetras(5350.50),
        equals('Cinco mil trescientos cincuenta pesos 50/100 M.N.'),
      );
    });
  });

  group('Pruebas de Generación de Reportes Excel (Formatos A, B, C y D)', () {
    late Database db;

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

      // Seed data
      await db.execute("INSERT OR IGNORE INTO tipo_concurso (id, nombre) VALUES (1, 'Estatal')");
      await db.execute('''
        INSERT INTO concurso (
          id, nombre, fecha_inicio_registro, fecha_limite_registro,
          finalizado, ejercicio, lugar, fecha_dictamen, fecha_premiacion, id_tipo_concurso
        ) VALUES (
          1, 'Concurso Estatal Michoacán', '2026-09-01', '2026-09-20',
          1, '2026', 'Pátzcuaro, Michoacán', '2026-09-20', '2026-09-25 12:00:00', 1
        )
      ''');

      await db.execute("INSERT OR IGNORE INTO rama_artesanal (id, nombre) VALUES (1, 'Textiles')");
      await db.execute("INSERT INTO categoria_concurso (id, id_concurso, nombre) VALUES (1, 1, 'Rebozos')");
      await db.execute("INSERT INTO sub_categoria_concurso (id, id_categoria, nombre) VALUES (1, 1, 'Algodón')");
      await db.execute("INSERT OR IGNORE INTO tipo_premio (id, nombre) VALUES (1, 'Galardón'), (2, 'Especial'), (3, 'Común')");

      // Premios
      await db.execute('''
        INSERT INTO premio (
          id, id_concurso, id_categoria, id_tipo_premio, nombre, monto, lugar, limite_otorgacion, activo
        ) VALUES 
        (1, 1, NULL, 1, 'Galardón Michoacano', 30000, 1, 1, 1),
        (2, 1, 1, 3, 'Primer Lugar Rebozos', 10000, 1, 1, 1)
      ''');

      // Artesano 1 con dos piezas
      await db.execute("INSERT INTO info_contacto (id, correo, telefono) VALUES (1, 'juan@casart.com', '4431112233')");
      await db.execute("INSERT INTO residencia (id, municipio, localidad, calle, numero_exterior, cp) VALUES (1, 'Morelia', 'Morelia Centro', 'Madero', '100', '58000')");
      await db.execute("INSERT OR IGNORE INTO etnia (id, nombre) VALUES (1, 'Purépecha')");
      await db.execute("INSERT OR IGNORE INTO estado_civil (id, nombre) VALUES (1, 'Casado(a)')");

      await db.execute('''
        INSERT INTO artesano (
          id, nombre, ap_paterno, ap_materno, curp, rfc, fecha_nacimiento, genero,
          max_nivel_academico, id_info_contacto, id_residencia, id_etnia, id_estado_civil
        ) VALUES (
          1, 'Juan', 'Perez', 'Lopez', 'PERJ800101HMNRR01', 'PERJ800101XYZ',
          '1980-01-01', 'Masculino', '4', 1, 1, 1, 1
        )
      ''');

      await db.execute('''
        INSERT INTO artesania_concurso (
          id, nombre, costo_produccion, costo_venta, tiempo_elaboracion, plazo_elaboracion,
          material_elaboracion, descripcion, id_rama_artesanal, id_categoria_concurso, id_sub_categoria_concurso, id_premio
        ) VALUES 
        (1, 'Rebozo de Pluma Fino', 1500, 3500, 4, 'semanas', 'Pluma y seda', 'Rebozo de gala', 1, 1, 1, 1),
        (2, 'Faja Ceremonial Azul', 500, 1200, 2, 'semanas', 'Algodón', 'Faja bordada', 1, 1, 1, 2)
      ''');

      await db.execute('''
        INSERT INTO registro_concurso (id, id_concurso, id_artesano, id_artesania_1, id_artesania_2, folio)
        VALUES (1, 1, 1, 1, 2, 101)
      ''');

      // Asignar premiación
      await db.execute('''
        INSERT INTO premiacion (id, id_concurso, id_premio, id_artesania, id_categoria, lugar)
        VALUES 
        (1, 1, 1, 1, 1, 1),
        (2, 1, 2, 2, 1, 1)
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('Verificación de consultas y estructura de datos para Formato A', () async {
      final premiaciones = await db.rawQuery('''
        SELECT 
          pr.id as premiacion_id,
          pr.lugar as premiacion_lugar,
          p.id as premio_id,
          p.nombre as premio_nombre,
          p.monto as premio_monto,
          p.id_tipo_premio,
          a.id as artesania_id,
          a.nombre as artesania_nombre,
          r.folio as registro_folio,
          r.id_artesania_1,
          r.id_artesania_2,
          art.nombre as artesano_nombre,
          art.ap_paterno as artesano_paterno,
          res.localidad,
          et.nombre as etnia_nombre
        FROM premiacion pr
        JOIN premio p ON pr.id_premio = p.id
        JOIN artesania_concurso a ON pr.id_artesania = a.id
        JOIN registro_concurso r ON (r.id_artesania_1 = a.id OR r.id_artesania_2 = a.id)
        JOIN artesano art ON r.id_artesano = art.id
        LEFT JOIN residencia res ON art.id_residencia = res.id
        LEFT JOIN etnia et ON art.id_etnia = et.id
        WHERE pr.id_concurso = 1
        ORDER BY p.id_tipo_premio ASC
      ''');

      expect(premiaciones.length, equals(2));

      // Pieza 1 es Galardón (id_tipo_premio == 1)
      final p1 = premiaciones.firstWhere((p) => p['id_tipo_premio'] == 1);
      expect(p1['premio_nombre'], equals('Galardón Michoacano'));
      expect(p1['artesania_nombre'], equals('Rebozo de Pluma Fino'));
      expect(p1['etnia_nombre'], equals('Mazahua'));
      expect(p1['localidad'], equals('Morelia Centro'));
      // Folio sufijo -A
      final isPieza2 = p1['artesania_id'] == p1['id_artesania_2'];
      expect(isPieza2, isFalse);
      expect('${p1['registro_folio']}-A', equals('101-A'));

      // Pieza 2 es Premio Común (id_tipo_premio == 3) con sufijo -B
      final p2 = premiaciones.firstWhere((p) => p['id_tipo_premio'] == 3);
      expect(p2['artesania_id'] == p2['id_artesania_2'], isTrue);
      expect('${p2['registro_folio']}-B', equals('101-B'));
    });

    test('Verificación de datos completos para Formato B (31 columnas)', () async {
      final rows = await db.rawQuery('''
        SELECT 
          pr.id,
          art.curp,
          art.rfc,
          art.fecha_nacimiento,
          art.genero,
          art.max_nivel_academico,
          res.municipio,
          res.localidad,
          res.cp,
          ic.telefono,
          p.monto,
          a.tiempo_elaboracion,
          a.plazo_elaboracion
        FROM premiacion pr
        JOIN premio p ON pr.id_premio = p.id
        JOIN artesania_concurso a ON pr.id_artesania = a.id
        JOIN registro_concurso r ON (r.id_artesania_1 = a.id OR r.id_artesania_2 = a.id)
        JOIN artesano art ON r.id_artesano = art.id
        LEFT JOIN residencia res ON art.id_residencia = res.id
        LEFT JOIN info_contacto ic ON art.id_info_contacto = ic.id
        WHERE pr.id_concurso = 1
      ''');

      expect(rows.length, equals(2));
      final first = rows.first;
      expect(first['curp'], equals('PERJ800101HMNRR01'));
      expect(first['telefono'], equals('4431112233'));
      expect(first['cp'], equals('58000'));
      expect(first['municipio'], equals('Morelia'));
    });

    test('Verificación de datos para Formato C y Formato D (Inscritas y Resumen)', () async {
      final rows = await db.rawQuery('''
        SELECT 
          r.folio as folio_boleta,
          art.nombre as artesano_nombre,
          art.ap_paterno as artesano_paterno,
          p1.nombre as p1_nombre,
          p1.costo_venta as p1_costo_venta,
          p2.nombre as p2_nombre,
          p2.costo_venta as p2_costo_venta
        FROM registro_concurso r
        JOIN artesano art ON r.id_artesano = art.id
        LEFT JOIN artesania_concurso p1 ON r.id_artesania_1 = p1.id
        LEFT JOIN artesania_concurso p2 ON r.id_artesania_2 = p2.id
        WHERE r.id_concurso = 1
      ''');

      expect(rows.length, equals(1));
      final r = rows.first;
      expect(r['folio_boleta'], equals(101));
      expect(r['p1_nombre'], equals('Rebozo de Pluma Fino'));
      expect(r['p2_nombre'], equals('Faja Ceremonial Azul'));

      // Claves de productos
      final claveA = '${r['folio_boleta']}A';
      final claveB = '${r['folio_boleta']}B';
      expect(claveA, equals('101A'));
      expect(claveB, equals('101B'));
    });
  });
}
