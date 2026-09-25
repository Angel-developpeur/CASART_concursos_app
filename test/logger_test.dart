import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:casart_concursos_desktop/core/database/app_database.dart';
import 'package:casart_concursos_desktop/core/logging/app_logger.dart';
import 'package:casart_concursos_desktop/models/concurso.dart';
import 'package:casart_concursos_desktop/models/categoria.dart';
import 'package:casart_concursos_desktop/models/artesano.dart';
import 'package:casart_concursos_desktop/models/artesania.dart';
import 'package:casart_concursos_desktop/models/premio.dart';
import 'package:casart_concursos_desktop/repositories/concurso_repository.dart';
import 'package:casart_concursos_desktop/repositories/artesano_repository.dart';
import 'package:casart_concursos_desktop/repositories/registro_repository.dart';
import 'package:casart_concursos_desktop/repositories/premio_repository.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppLogger.init();
  });

  group('AppLogger Core Functionality', () {
    test('AppLogger initializes and creates log file in test directory', () async {
      expect(AppLogger.logFilePath, isNotNull);
      final file = File(AppLogger.logFilePath!);
      expect(await file.exists(), isTrue);
    });

    test('AppLogger writes CREATE, UPDATE, DELETE, ERROR, and INFO entries', () async {
      AppLogger.create('Creación de prueba única', category: 'TEST_CREATE', data: {'id': 100});
      AppLogger.update('Modificación de prueba única', category: 'TEST_UPDATE', data: {'id': 100});
      AppLogger.delete('Eliminación de prueba única', category: 'TEST_DELETE', data: {'id': 100});
      AppLogger.error('Error de prueba única', category: 'TEST_ERROR', error: Exception('Fallo simulado'));
      AppLogger.info('Mensaje informativo único', category: 'TEST_INFO');

      final createEntry = AppLogger.recentEntries.firstWhere((e) => e.message == 'Creación de prueba única');
      expect(createEntry.level, LogLevel.create);
      expect(createEntry.category, 'TEST_CREATE');

      final updateEntry = AppLogger.recentEntries.firstWhere((e) => e.message == 'Modificación de prueba única');
      expect(updateEntry.level, LogLevel.update);
      expect(updateEntry.category, 'TEST_UPDATE');

      final deleteEntry = AppLogger.recentEntries.firstWhere((e) => e.message == 'Eliminación de prueba única');
      expect(deleteEntry.level, LogLevel.delete);
      expect(deleteEntry.category, 'TEST_DELETE');

      final errorEntry = AppLogger.recentEntries.firstWhere((e) => e.message == 'Error de prueba única');
      expect(errorEntry.level, LogLevel.error);
      expect(errorEntry.category, 'TEST_ERROR');

      final infoEntry = AppLogger.recentEntries.firstWhere((e) => e.message == 'Mensaje informativo único');
      expect(infoEntry.level, LogLevel.info);
      expect(infoEntry.category, 'TEST_INFO');

      await AppLogger.flush();
      final logContent = await File(AppLogger.logFilePath!).readAsString();
      expect(logContent, contains('[CREATE] [TEST_CREATE] Creación de prueba única'));
      expect(logContent, contains('[UPDATE] [TEST_UPDATE] Modificación de prueba única'));
      expect(logContent, contains('[DELETE] [TEST_DELETE] Eliminación de prueba única'));
      expect(logContent, contains('[ERROR] [TEST_ERROR] Error de prueba única'));
      expect(logContent, contains('[INFO] [TEST_INFO] Mensaje informativo único'));
    });
  });

  group('Repositories Automated Activity Logging', () {
    late Database db;
    late AppDatabase appDb;
    late ConcursoRepository concursoRepo;
    late ArtesanoRepository artesanoRepo;
    late RegistroRepository registroRepo;
    late PremioRepository premioRepo;

    setUp(() async {
      db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: AppDatabase().onCreate,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );
      appDb = AppDatabase.withDatabase(db);
      concursoRepo = ConcursoRepository(dbHelper: appDb);
      artesanoRepo = ArtesanoRepository(dbHelper: appDb);
      registroRepo = RegistroRepository(dbHelper: appDb);
      premioRepo = PremioRepository(dbHelper: appDb);
    });

    tearDown(() async {
      await db.close();
    });

    test('Creación y modificación de concurso se registran en los logs', () async {
      final initialLogs = AppLogger.recentEntries.length;

      // 1. Crear Concurso
      final concurso = Concurso(
        nombre: 'Concurso Estatal Michoacán 2026',
        idTipoConcurso: 1,
        ejercicio: '2026',
        lugar: 'Pátzcuaro',
        categorias: [
          Categoria(nombre: 'Alfarería y Cerámica'),
          Categoria(nombre: 'Textiles'),
        ],
      );

      final concursoId = await concursoRepo.createConcurso(concurso);
      expect(concursoId, greaterThan(0));

      // Verificar log de creación
      final createEntry = AppLogger.recentEntries.last;
      expect(createEntry.level, LogLevel.create);
      expect(createEntry.category, 'CONCURSO');
      expect(createEntry.message, contains('Concurso Estatal Michoacán 2026'));

      // 2. Modificar Concurso
      final concursoModificado = concurso.copyWith(
        id: concursoId,
        nombre: 'Concurso Estatal Michoacán 2026 Modificado',
      );
      await concursoRepo.updateConcurso(concursoModificado);

      final updateEntry = AppLogger.recentEntries.last;
      expect(updateEntry.level, LogLevel.update);
      expect(updateEntry.category, 'CONCURSO');
      expect(updateEntry.message, contains('Concurso actualizado'));

      // 3. Finalizar concurso
      await concursoRepo.setFinalizado(concursoId, true);
      final finalizeEntry = AppLogger.recentEntries.last;
      expect(finalizeEntry.level, LogLevel.update);
      expect(finalizeEntry.category, 'CONCURSO');
      expect(finalizeEntry.message, contains('FINALIZADO'));

      expect(AppLogger.recentEntries.length, initialLogs + 3);
    });

    test('Creación y modificación de artesano se registran en los logs', () async {
      final artesano = Artesano(
        nombre: 'María',
        apPaterno: 'Gómez',
        apMaterno: 'Hernández',
        curp: 'GOHM850512MNRR02',
        municipio: 'Uruapan',
        localidad: 'Capacuaro',
      );

      final artesanoId = await artesanoRepo.createArtesano(artesano);
      expect(artesanoId, greaterThan(0));

      final createEntry = AppLogger.recentEntries.last;
      expect(createEntry.level, LogLevel.create);
      expect(createEntry.category, 'ARTESANO');
      expect(createEntry.message, contains('María Gómez Hernández'));
      expect(createEntry.message, contains('GOHM850512MNRR02'));

      // Modificar artesano
      final artesanoActualizado = artesano.copyWith(id: artesanoId, telefono: '4431234567');
      await artesanoRepo.updateArtesano(artesanoActualizado);

      final updateEntry = AppLogger.recentEntries.last;
      expect(updateEntry.level, LogLevel.update);
      expect(updateEntry.category, 'ARTESANO');
      expect(updateEntry.message, contains('Artesano actualizado'));
    });

    test('Creación, modificación y eliminación de inscripción se registran en los logs', () async {
      // Registrar concurso base
      final concursoId = await concursoRepo.createConcurso(
        Concurso(
          nombre: 'Concurso Prueba Inscripción',
          idTipoConcurso: 1,
          ejercicio: '2026',
          categorias: [Categoria(nombre: 'Madera')],
        ),
      );

      final cats = await db.query('categoria_concurso', where: 'id_concurso = ?', whereArgs: [concursoId]);
      final catId = cats.first['id'] as int;

      // 1. Registrar Inscripción
      final artesano = Artesano(
        nombre: 'Pedro',
        apPaterno: 'Juárez',
        curp: 'JUPP900101MNRR01',
        municipio: 'Quiroga',
        localidad: 'Quiroga Centro',
      );

      final pieza1 = Artesania(
        nombre: 'Batea Tallada a Mano',
        idRamaArtesanal: 1,
        costoProduccion: 500,
        costoVenta: 650,
        tiempoElaboracion: 5,
        plazoElaboracion: 'Días',
        materialElaboracion: 'Madera de pino',
        descripcion: 'Batea decorativa tallada a mano',
        idCategoriaConcurso: catId,
      );

      final reg = await registroRepo.registrarInscripcion(
        idConcurso: concursoId,
        artesano: artesano,
        esNuevoArtesano: true,
        pieza1: pieza1,
      );

      expect(reg.folio, 1);
      final createEntry = AppLogger.recentEntries.last;
      expect(createEntry.level, LogLevel.create);
      expect(createEntry.category, 'INSCRIPCION');
      expect(createEntry.message, contains('Folio #1'));
      expect(createEntry.message, contains('Pedro Juárez'));

      // 2. Modificar Inscripción
      final regActualizado = await registroRepo.actualizarInscripcion(
        idRegistro: reg.id!,
        idConcurso: concursoId,
        artesano: artesano.copyWith(id: reg.idArtesano, telefono: '4439998877'),
        pieza1: pieza1.copyWith(id: reg.idArtesania1, costoVenta: 800),
      );

      expect(regActualizado.id, reg.id);
      final updateEntry = AppLogger.recentEntries.last;
      expect(updateEntry.level, LogLevel.update);
      expect(updateEntry.category, 'INSCRIPCION');
      expect(updateEntry.message, contains('Inscripción Folio #1 (ID: ${reg.id}) actualizada'));

      // 3. Eliminar Inscripción
      await registroRepo.deleteRegistro(reg.id!);
      final deleteEntry = AppLogger.recentEntries.last;
      expect(deleteEntry.level, LogLevel.delete);
      expect(deleteEntry.category, 'INSCRIPCION');
      expect(deleteEntry.message, contains('Inscripción eliminada (ID: ${reg.id}, Folio: #1)'));
    });

    test('Creación, eliminación de premios y asignación de ganadores se registran en los logs', () async {
      final concursoId = await concursoRepo.createConcurso(
        Concurso(
          nombre: 'Concurso Premios',
          idTipoConcurso: 1,
          ejercicio: '2026',
          categorias: [Categoria(nombre: 'Cestería')],
        ),
      );

      // 1. Crear Premio
      final premioId = await premioRepo.createPremio(
        Premio(
          idConcurso: concursoId,
          nombre: 'Primer Lugar Cestería',
          monto: 15000,
          lugar: 1,
        ),
      );

      final createEntry = AppLogger.recentEntries.last;
      expect(createEntry.level, LogLevel.create);
      expect(createEntry.category, 'PREMIO');
      expect(createEntry.message, contains('Primer Lugar Cestería'));

      // 2. Eliminar Premio
      await premioRepo.deletePremio(premioId);
      final deleteEntry = AppLogger.recentEntries.last;
      expect(deleteEntry.level, LogLevel.delete);
      expect(deleteEntry.category, 'PREMIO');
      expect(deleteEntry.message, contains('Premio #$premioId eliminado'));
    });
  });
}
