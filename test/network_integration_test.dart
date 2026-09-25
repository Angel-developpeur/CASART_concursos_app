import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:casart_concursos_desktop/core/database/app_database.dart';
import 'package:casart_concursos_desktop/core/network/embedded_server.dart';
import 'package:casart_concursos_desktop/core/network/api_client.dart';
import 'package:casart_concursos_desktop/models/concurso.dart';
import 'package:casart_concursos_desktop/models/categoria.dart';
import 'package:casart_concursos_desktop/models/subcategoria.dart';
import 'package:casart_concursos_desktop/models/aportacion.dart';
import 'package:casart_concursos_desktop/models/artesano.dart';
import 'package:casart_concursos_desktop/models/artesania.dart';
import 'package:casart_concursos_desktop/repositories/concurso_repository.dart';
import 'package:casart_concursos_desktop/repositories/artesano_repository.dart';
import 'package:casart_concursos_desktop/repositories/registro_repository.dart';
import 'package:casart_concursos_desktop/repositories/premio_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Host Server and Terminal Client end-to-end communication with consecutive folios', () async {
    // 1. Initialize an in-memory database with CASART schema and seed data
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

    // 2. Start Embedded Server on test port 8098
    final server = EmbeddedServer(
      concursoRepo: concursoRepo,
      artesanoRepo: artesanoRepo,
      registroRepo: registroRepo,
      premioRepo: premioRepo,
    );

    const testPort = 8098;
    await server.start(port: testPort);
    expect(server.isRunning, isTrue);

    // 3. Connect Terminal Client
    final client = ApiClient(baseUrl: 'http://localhost:$testPort/api');

    // Health check
    final isHealthy = await client.checkHealth();
    expect(isHealthy, isTrue);

    // 4. Catalog query
    final catalogos = await client.getCatalogos();
    expect(catalogos['ramas'], isNotEmpty);
    expect(catalogos['etnias'], isNotEmpty);
    expect(catalogos['tipos_concurso'], isNotEmpty);

    // 5. Create Contest with Categories, Subcategories & Aportaciones
    final nuevoConcurso = Concurso(
      nombre: 'Gran Premio de Arte Popular 2026',
      idTipoConcurso: 1,
      lugar: 'Toluca, Estado de México',
      ejercicio: '2026',
      iva: 16.0,
      utilidad: 10.0,
      categorias: [
        Categoria(
          nombre: 'Alfarería y Cerámica',
          subcategorias: [
            Subcategoria(nombre: 'Barro Policromado'),
            Subcategoria(nombre: 'Barro Bruñido'),
          ],
        ),
        Categoria(
          nombre: 'Textiles',
          subcategorias: [
            Subcategoria(nombre: 'Rebozo'),
          ],
        ),
      ],
      aportaciones: [
        Aportacion(nombre: 'FONART', cantidad: 150000.0),
        Aportacion(nombre: 'Gobierno del Estado', cantidad: 200000.0),
      ],
    );

    final concursoId = await client.saveConcurso(nuevoConcurso);
    expect(concursoId, isPositive);

    // Verify contest created with aportaciones and categories
    final savedConcurso = await client.getConcursoById(concursoId);
    expect(savedConcurso, isNotNull);
    expect(savedConcurso!.nombre, 'Gran Premio de Arte Popular 2026');
    expect(savedConcurso.categorias.length, 2);
    expect(savedConcurso.aportaciones.length, 2);
    expect(savedConcurso.aportaciones.first.nombre, 'FONART');
    expect(savedConcurso.aportaciones.first.cantidad, 150000.0);

    final cat1 = savedConcurso.categorias.first;

    // 6. Simulate 2 concurrent Terminals registering 2 artisans concurrently
    // Terminal A: Artisan Juan Perez
    final artesanoA = Artesano(
      nombre: 'Juan',
      apPaterno: 'Perez',
      curp: 'PEPJ800101MEX01',
      municipio: 'Metepec',
      localidad: 'Centro',
    );
    final piezaA = Artesania(
      nombre: 'Árbol de la Vida Miniatura',
      idRamaArtesanal: 1,
      idCategoriaConcurso: cat1.id!,
      costoProduccion: 500.0,
      costoVenta: 1200.0,
      tiempoElaboracion: 15.0,
      plazoElaboracion: 'dias',
      materialElaboracion: 'Barro modelado',
      descripcion: 'Pieza de concurso tradicional',
    );

    // Terminal B: Artisan Maria Lopez
    final artesanoB = Artesano(
      nombre: 'Maria',
      apPaterno: 'Lopez',
      curp: 'LOPM850202MEX02',
      municipio: 'Toluca',
      localidad: 'San Mateo Oxtotitlán',
    );
    final piezaB = Artesania(
      nombre: 'Cántaro Tradicional',
      idRamaArtesanal: 1,
      idCategoriaConcurso: cat1.id!,
      costoProduccion: 300.0,
      costoVenta: 800.0,
      tiempoElaboracion: 8.0,
      plazoElaboracion: 'dias',
      materialElaboracion: 'Barro rojo',
      descripcion: 'Cántaro cocido en leña',
    );

    // Concurrently register both artisans
    final results = await Future.wait([
      client.registrarInscripcion(
        idConcurso: concursoId,
        artesano: artesanoA,
        esNuevoArtesano: true,
        pieza1: piezaA,
      ),
      client.registrarInscripcion(
        idConcurso: concursoId,
        artesano: artesanoB,
        esNuevoArtesano: true,
        pieza1: piezaB,
      ),
    ]);

    final registro1 = results[0];
    final registro2 = results[1];

    // Folios must be 1 and 2, never duplicate
    final folios = [registro1.folio, registro2.folio]..sort();
    expect(folios, [1, 2]);

    // Check next folio is 3
    final nextFolio = await client.getNextFolio(concursoId);
    expect(nextFolio, 3);

    // Verify search artesanos via client
    final searchResults = await client.searchArtesanos(query: 'PEPJ');
    expect(searchResults.length, 1);
    expect(searchResults.first.nombre, 'Juan');

    // 7. Test actualizarInscripcion via network client
    final artesanoActualizado = registro1.artesano!.copyWith(nombre: 'Juan Carlos', telefono: '4431234567');
    final pieza1Actualizada = registro1.artesania1!.copyWith(nombre: 'Árbol de la Vida Monumental', costoProduccion: 750.0);

    final regActualizado = await client.actualizarInscripcion(
      idRegistro: registro1.id!,
      idConcurso: concursoId,
      artesano: artesanoActualizado,
      pieza1: pieza1Actualizada,
    );

    expect(regActualizado.artesano!.nombre, 'Juan Carlos');
    expect(regActualizado.artesano!.telefono, '4431234567');
    expect(regActualizado.artesania1!.nombre, 'Árbol de la Vida Monumental');
    expect(regActualizado.artesania1!.costoProduccion, 750.0);

    // Verify list of registros on server
    final registrosServidor = await client.getRegistros(concursoId);
    expect(registrosServidor.length, 2);
    expect(registrosServidor.any((r) => r.artesano?.nombre == 'Juan Carlos'), isTrue);

    // Clean up
    await server.stop();
    await db.close();
  });
}
