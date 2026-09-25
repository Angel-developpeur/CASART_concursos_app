import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:casart_concursos_desktop/core/database/app_database.dart';
import 'package:casart_concursos_desktop/core/network/embedded_server.dart';
import 'package:casart_concursos_desktop/core/network/api_client.dart';
import 'package:casart_concursos_desktop/models/concurso.dart';
import 'package:casart_concursos_desktop/models/categoria.dart';
import 'package:casart_concursos_desktop/models/artesano.dart';
import 'package:casart_concursos_desktop/models/artesania.dart';
import 'package:casart_concursos_desktop/repositories/concurso_repository.dart';
import 'package:casart_concursos_desktop/repositories/artesano_repository.dart';
import 'package:casart_concursos_desktop/repositories/registro_repository.dart';
import 'package:casart_concursos_desktop/repositories/premio_repository.dart';
import 'package:casart_concursos_desktop/models/premio.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'Medida de seguridad: Si concurso está finalizado no se permite registrar, modificar ni eliminar piezas (Modo Solo Lectura)',
    () async {
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
      final premioRepo = PremioRepository(dbHelper: dbHelper);

      // 1. Crear concurso en proceso
      final concursoId = await concursoRepo.saveConcurso(
        Concurso(
          nombre: 'Concurso Estatal Michoacán 2026',
          idTipoConcurso: 1,
          ejercicio: '2026',
          categorias: [Categoria(nombre: 'Alfarería')],
          finalizado: false,
        ),
      );

      final concurso = await concursoRepo.getConcursoById(concursoId);
      expect(concurso, isNotNull);
      final catId = concurso!.categorias.first.id!;

      // 2. Registrar inscripción mientras está EN PROCESO (debe funcionar correctamente)
      final reg1 = await registroRepo.registrarInscripcion(
        idConcurso: concursoId,
        artesano: Artesano(
          nombre: 'Teresa',
          apPaterno: 'Mendoza',
          curp: 'MENT800101MMNRR01',
          municipio: 'Pátzcuaro',
          localidad: 'Pátzcuaro',
        ),
        esNuevoArtesano: true,
        pieza1: Artesania(
          nombre: 'Olla de Barro Vidriado',
          costoProduccion: 500.0,
          costoVenta: 600.0,
          tiempoElaboracion: 5.0,
          plazoElaboracion: 'dias',
          materialElaboracion: 'Barro',
          descripcion: 'Olla vidriada tradicional',
          idRamaArtesanal: 1,
          idCategoriaConcurso: catId,
        ),
      );

      expect(reg1.folio, equals(1));
      expect(reg1.id, isNotNull);

      // 3. Finalizar el concurso
      await concursoRepo.setFinalizado(concursoId, true);
      final concursoFinalizado = await concursoRepo.getConcursoById(concursoId);
      expect(concursoFinalizado!.finalizado, isTrue);

      // 4. Intentar inscribir nueva pieza en concurso finalizado (DEBE FALLAR con StateError)
      await expectLater(
        () => registroRepo.registrarInscripcion(
          idConcurso: concursoId,
          artesano: Artesano(
            nombre: 'Carlos',
            apPaterno: 'Ruiz',
            curp: 'RUIC900202HMNRR02',
            municipio: 'Uruapan',
            localidad: 'Uruapan',
          ),
          esNuevoArtesano: true,
          pieza1: Artesania(
            nombre: 'Batea Maqueada',
            costoProduccion: 800.0,
            costoVenta: 1000.0,
            tiempoElaboracion: 10.0,
            plazoElaboracion: 'dias',
            materialElaboracion: 'Madera de cedro',
            descripcion: 'Batea artesanal',
            idRamaArtesanal: 1,
            idCategoriaConcurso: catId,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('está finalizado'),
          ),
        ),
      );

      // 5. Intentar modificar una inscripción existente en concurso finalizado (DEBE FALLAR)
      await expectLater(
        () => registroRepo.actualizarInscripcion(
          idRegistro: reg1.id!,
          idConcurso: concursoId,
          artesano: reg1.artesano!,
          pieza1: reg1.artesania1!.copyWith(
            nombre: 'Olla con intento de modificación',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('está finalizado'),
          ),
        ),
      );

      // 6. Intentar eliminar una inscripción en concurso finalizado (DEBE FALLAR)
      await expectLater(
        () => registroRepo.deleteRegistro(reg1.id!),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('está finalizado'),
          ),
        ),
      );

      // 6.1 Intentar agregar un premio a la bolsa en concurso finalizado (DEBE FALLAR)
      await expectLater(
        () => premioRepo.createPremio(
          Premio(
            idConcurso: concursoId,
            nombre: 'Premio Especial Bloqueado',
            monto: 5000.0,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('está finalizado'),
          ),
        ),
      );

      // 7. La inscripción debe seguir intacta en modo solo lectura
      final registrosConsultados = await registroRepo.getRegistrosByConcurso(
        concursoId,
      );
      expect(registrosConsultados.length, equals(1));
      expect(
        registrosConsultados.first.artesania1!.nombre,
        equals('Olla de Barro Vidriado'),
      );

      // 8. Iniciar EmbeddedServer y validar API REST en modo solo lectura
      const testPort = 8099;
      final server = EmbeddedServer(
        concursoRepo: concursoRepo,
        artesanoRepo: artesanoRepo,
        registroRepo: registroRepo,
        premioRepo: premioRepo,
      );
      await server.start(port: testPort);
      expect(server.isRunning, isTrue);

      final client = ApiClient(baseUrl: 'http://127.0.0.1:$testPort/api');
      final healthy = await client.checkHealth();
      expect(healthy, isTrue);

      // Intentar registrar vía API en concurso finalizado (debe ser rechazado con 403 Forbidden)
      await expectLater(
        () => client.registrarInscripcion(
          idConcurso: concursoId,
          artesano: Artesano(
            nombre: 'Arturo',
            apPaterno: 'Luna',
            curp: 'LUNA910303HMNRR03',
            municipio: 'Morelia',
            localidad: 'Morelia',
          ),
          esNuevoArtesano: true,
          pieza1: Artesania(
            nombre: 'Rebozo de Lana',
            costoProduccion: 900.0,
            costoVenta: 1200.0,
            tiempoElaboracion: 7.0,
            plazoElaboracion: 'dias',
            materialElaboracion: 'Lana de borrego',
            descripcion: 'Rebozo tradicional',
            idRamaArtesanal: 1,
            idCategoriaConcurso: catId,
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'error',
            contains('finalizado'),
          ),
        ),
      );

      // Intentar actualizar vía API en concurso finalizado (debe ser rechazado)
      await expectLater(
        () => client.actualizarInscripcion(
          idRegistro: reg1.id!,
          idConcurso: concursoId,
          artesano: reg1.artesano!,
          pieza1: reg1.artesania1!,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'error',
            contains('finalizado'),
          ),
        ),
      );

      // Intentar eliminar vía API en concurso finalizado (debe ser rechazado)
      await expectLater(
        () => client.deleteRegistro(reg1.id!),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'error',
            contains('finalizado'),
          ),
        ),
      );

      // Intentar agregar premio vía API en concurso finalizado (debe ser rechazado con 403 Forbidden)
      await expectLater(
        () => client.savePremio(
          Premio(
            idConcurso: concursoId,
            nombre: 'Premio Especial API Bloqueado',
            monto: 7000.0,
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'error',
            contains('finalizado'),
          ),
        ),
      );

      await server.stop();

      // 9. Reabrir concurso (cambiar a finalizado: false) y verificar que se rehabilitan las operaciones
      await concursoRepo.setFinalizado(concursoId, false);
      final concursoReabierto = await concursoRepo.getConcursoById(concursoId);
      expect(concursoReabierto!.finalizado, isFalse);

      // Ahora sí se debe permitir una nueva inscripción
      final reg2 = await registroRepo.registrarInscripcion(
        idConcurso: concursoId,
        artesano: Artesano(
          nombre: 'Carlos',
          apPaterno: 'Ruiz',
          curp: 'RUIC900202HMNRR02',
          municipio: 'Uruapan',
          localidad: 'Uruapan',
        ),
        esNuevoArtesano: true,
        pieza1: Artesania(
          nombre: 'Batea Maqueada',
          costoProduccion: 800.0,
          costoVenta: 1000.0,
          tiempoElaboracion: 10.0,
          plazoElaboracion: 'dias',
          materialElaboracion: 'Madera de cedro',
          descripcion: 'Batea artesanal',
          idRamaArtesanal: 1,
          idCategoriaConcurso: catId,
        ),
      );

      expect(reg2.folio, equals(2));
      final totalRegistros = await registroRepo.getRegistrosByConcurso(
        concursoId,
      );
      expect(totalRegistros.length, equals(2));

      // Ahora sí se debe permitir agregar un premio a la bolsa
      final nuevoPremioId = await premioRepo.savePremio(
        Premio(
          idConcurso: concursoId,
          nombre: 'Premio Especial Post Reapertura',
          monto: 7000.0,
        ),
      );
      expect(nuevoPremioId, isPositive);
      final premios = await premioRepo.getPremiosByConcurso(concursoId);
      expect(
        premios.any((p) => p.nombre == 'Premio Especial Post Reapertura'),
        isTrue,
      );

      await db.close();
    },
  );
}
