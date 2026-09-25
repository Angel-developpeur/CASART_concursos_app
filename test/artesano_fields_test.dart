import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:casart_concursos_desktop/core/database/app_database.dart';
import 'package:casart_concursos_desktop/models/concurso.dart';
import 'package:casart_concursos_desktop/models/categoria.dart';
import 'package:casart_concursos_desktop/models/artesano.dart';
import 'package:casart_concursos_desktop/models/artesania.dart';
import 'package:casart_concursos_desktop/repositories/concurso_repository.dart';
import 'package:casart_concursos_desktop/repositories/artesano_repository.dart';
import 'package:casart_concursos_desktop/repositories/registro_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Validación y persistencia de fecha_nacimiento, genero y sección domicilio completa en artesano', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: AppDatabase().onCreate,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );

    final dbHelper = AppDatabase.withDatabase(db);
    final concursoRepo = ConcursoRepository(dbHelper: dbHelper);
    final artesanoRepo = ArtesanoRepository(dbHelper: dbHelper);
    final registroRepo = RegistroRepository(dbHelper: dbHelper);

    // 1. Crear Concurso
    final concursoId = await concursoRepo.saveConcurso(
      Concurso(
        nombre: 'Concurso Estatal Artesanal 2026',
        idTipoConcurso: 1,
        ejercicio: '2026',
        categorias: [Categoria(nombre: 'Alfarería y Cerámica')],
      ),
    );
    final concurso = await concursoRepo.getConcursoById(concursoId);
    final catId = concurso!.categorias.first.id!;

    // 2. Registrar inscripción con artesano con todos los nuevos campos
    final nuevoArtesano = Artesano(
      nombre: 'Guadalupe',
      apPaterno: 'Hernández',
      apMaterno: 'Solís',
      curp: 'HESG850515MMNRRL01',
      rfc: 'HESG850515ABC',
      fechaNacimiento: '1985-05-15',
      genero: 'F',
      telefono: '4431234567',
      municipio: 'Pátzcuaro',
      localidad: 'Pátzcuaro',
      colonia: 'Centro Histórico',
      calle: 'Vasco de Quiroga',
      numeroExterior: '45',
      codigoPostal: '61600',
    );

    final registro = await registroRepo.registrarInscripcion(
      idConcurso: concursoId,
      artesano: nuevoArtesano,
      esNuevoArtesano: true,
      pieza1: Artesania(
        nombre: 'Olla de Barro Brunido',
        costoProduccion: 750.0,
        costoVenta: 900.0,
        tiempoElaboracion: 6.0,
        plazoElaboracion: 'dias',
        materialElaboracion: 'Barro rojo',
        descripcion: 'Olla bruñida con grecas tradicionales',
        idRamaArtesanal: 1,
        idCategoriaConcurso: catId,
      ),
    );

    expect(registro.id, isNotNull);
    expect(registro.folio, equals(1));
    expect(registro.artesano, isNotNull);

    final artGuardado = registro.artesano!;
    expect(artGuardado.nombre, equals('Guadalupe'));
    expect(artGuardado.apPaterno, equals('Hernández'));
    expect(artGuardado.fechaNacimiento, equals('1985-05-15'));
    expect(artGuardado.genero, equals('F'));
    expect(artGuardado.generoDescripcion, equals('Mujer (F)'));
    expect(artGuardado.municipio, equals('Pátzcuaro'));
    expect(artGuardado.localidad, equals('Pátzcuaro'));
    expect(artGuardado.colonia, equals('Centro Histórico'));
    expect(artGuardado.calle, equals('Vasco de Quiroga'));
    expect(artGuardado.numeroExterior, equals('45'));
    expect(artGuardado.codigoPostal, equals('61600'));

    expect(
      artGuardado.direccionCompleta,
      equals('Calle Vasco de Quiroga, #45, Col. Centro Histórico, C.P. 61600, Pátzcuaro, Pátzcuaro, Michoacán'),
    );

    // 3. Modificar inscripción con nuevos datos de domicilio y verificar persistencia
    final artesanoModificado = artGuardado.copyWith(
      genero: 'M',
      colonia: 'Revolución',
      calle: 'Benito Juárez',
      numeroExterior: '102-B',
      codigoPostal: '61605',
    );

    final registroActualizado = await registroRepo.actualizarInscripcion(
      idRegistro: registro.id!,
      idConcurso: concursoId,
      artesano: artesanoModificado,
      pieza1: registro.artesania1!,
    );

    final artActualizado = registroActualizado.artesano!;
    expect(artActualizado.genero, equals('M'));
    expect(artActualizado.generoDescripcion, equals('Hombre (M)'));
    expect(artActualizado.colonia, equals('Revolución'));
    expect(artActualizado.calle, equals('Benito Juárez'));
    expect(artActualizado.numeroExterior, equals('102-B'));
    expect(artActualizado.codigoPostal, equals('61605'));
    expect(
      artActualizado.direccionCompleta,
      equals('Calle Benito Juárez, #102-B, Col. Revolución, C.P. 61605, Pátzcuaro, Pátzcuaro, Michoacán'),
    );

    // 4. Consultar artesano desde repositorio por ID y CURP
    final artesanoPorCurp = await artesanoRepo.getArtesanoByCurp('HESG850515MMNRRL01');
    expect(artesanoPorCurp, isNotNull);
    expect(artesanoPorCurp!.fechaNacimiento, equals('1985-05-15'));
    expect(artesanoPorCurp.genero, equals('M'));
    expect(artesanoPorCurp.codigoPostal, equals('61605'));

    await db.close();
  });
}
