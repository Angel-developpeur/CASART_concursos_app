import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import '../logging/app_logger.dart';
import '../../models/concurso.dart';
import '../../models/artesano.dart';
import '../../models/artesania.dart';
import '../../models/premio.dart';
import '../../repositories/concurso_repository.dart';
import '../../repositories/artesano_repository.dart';
import '../../repositories/registro_repository.dart';
import '../../repositories/premio_repository.dart';

class EmbeddedServer {
  final ConcursoRepository concursoRepo;
  final ArtesanoRepository artesanoRepo;
  final RegistroRepository registroRepo;
  final PremioRepository premioRepo;

  HttpServer? _server;
  int _port = 8080;

  EmbeddedServer({
    required this.concursoRepo,
    required this.artesanoRepo,
    required this.registroRepo,
    required this.premioRepo,
  });

  bool get isRunning => _server != null;
  int get port => _port;

  Future<void> start({int port = 8080}) async {
    if (_server != null) return;
    _port = port;

    final router = Router();

    // ==========================================
    // 1. HEALTH CHECK
    // ==========================================
    router.get('/api/health', (Request req) {
      return Response.ok(
        jsonEncode({
          'status': 'ok',
          'app': 'casart_concursos',
          'server': Platform.localHostname,
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // ==========================================
    // 2. CATÁLOGOS BASE
    // ==========================================
    router.get('/api/catalogos', (Request req) async {
      final ramas = await artesanoRepo.getRamasArtesanales();
      final etnias = await artesanoRepo.getEtnias();
      final estadosCiviles = await artesanoRepo.getEstadosCiviles();
      final tiposPremio = await premioRepo.getTiposPremio();
      final tiposConcurso = await concursoRepo.getTiposConcurso();

      return Response.ok(
        jsonEncode({
          'ramas': ramas,
          'etnias': etnias,
          'estados_civiles': estadosCiviles,
          'tipos_premio': tiposPremio,
          'tipos_concurso': tiposConcurso,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // ==========================================
    // 3. CONCURSOS
    // ==========================================
    router.get('/api/concursos', (Request req) async {
      final search = req.url.queryParameters['search'];
      final ejercicio = req.url.queryParameters['ejercicio'];
      final finalizadoStr = req.url.queryParameters['finalizado'];
      bool? finalizado;
      if (finalizadoStr != null) finalizado = finalizadoStr == '1';

      final list = await concursoRepo.getConcursos(
        search: search,
        ejercicio: ejercicio,
        finalizado: finalizado,
      );

      final jsonList = list.map((c) => c.toMap()).toList();
      return Response.ok(
        jsonEncode(jsonList),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.get('/api/concursos/<id>', (Request req, String id) async {
      final intId = int.tryParse(id);
      if (intId == null) return Response.badRequest(body: 'ID inválido');

      final c = await concursoRepo.getConcursoById(intId);
      if (c == null) return Response.notFound('Concurso no encontrado');

      return Response.ok(
        jsonEncode(c.toMap()),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.post('/api/concursos', (Request req) async {
      final body = await req.readAsString();
      final map = jsonDecode(body) as Map<String, dynamic>;
      final concurso = Concurso.fromMap(map);
      final id = await concursoRepo.saveConcurso(concurso);

      return Response.ok(
        jsonEncode({'id': id}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.put('/api/concursos/<id>/finalizado', (
      Request req,
      String id,
    ) async {
      final intId = int.tryParse(id);
      if (intId == null) return Response.badRequest(body: 'ID inválido');

      final body = await req.readAsString();
      final map = jsonDecode(body) as Map<String, dynamic>;
      final finalizado = map['finalizado'] == true || map['finalizado'] == 1;

      await concursoRepo.setFinalizado(intId, finalizado);
      return Response.ok(
        jsonEncode({'success': true, 'finalizado': finalizado}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.delete('/api/concursos/<id>', (Request req, String id) async {
      return Response.forbidden(
        jsonEncode({
          'error':
              'No se permite eliminar concursos por integridad institucional e histórica.',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // ==========================================
    // 4. ARTESANOS
    // ==========================================
    router.get('/api/artesanos/search', (Request req) async {
      final q = req.url.queryParameters['q'] ?? '';
      final limit =
          int.tryParse(req.url.queryParameters['limit'] ?? '10') ?? 10;

      final artesanos = await artesanoRepo.searchArtesanos(
        query: q,
        limit: limit,
      );
      final jsonList = artesanos.map((a) => a.toMap()).toList();

      return Response.ok(
        jsonEncode(jsonList),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // ==========================================
    // 5. REGISTROS / INSCRIPCIONES (ATÓMICO)
    // ==========================================
    router.get('/api/concursos/<id>/next-folio', (
      Request req,
      String id,
    ) async {
      final intId = int.tryParse(id);
      if (intId == null) return Response.badRequest(body: 'ID inválido');

      final nextFolio = await registroRepo.getNextFolio(intId);
      return Response.ok(
        jsonEncode({'next_folio': nextFolio}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.get('/api/concursos/<id>/registros', (Request req, String id) async {
      final intId = int.tryParse(id);
      if (intId == null) return Response.badRequest(body: 'ID inválido');

      final search = req.url.queryParameters['search'];
      final registros = await registroRepo.getRegistrosByConcurso(
        intId,
        search: search,
      );

      final jsonList = registros.map((r) {
        final map = r.toMap();
        if (r.artesano != null) map['artesano'] = r.artesano!.toMap();
        if (r.artesania1 != null) map['artesania1'] = r.artesania1!.toMap();
        if (r.artesania2 != null) map['artesania2'] = r.artesania2!.toMap();
        if (r.concurso != null) map['concurso'] = r.concurso!.toMap();
        return map;
      }).toList();

      return Response.ok(
        jsonEncode(jsonList),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.post('/api/concursos/<id>/inscripcion', (
      Request req,
      String id,
    ) async {
      final intId = int.tryParse(id);
      if (intId == null) return Response.badRequest(body: 'ID inválido');

      final body = await req.readAsString();

      final c = await concursoRepo.getConcursoById(intId);
      if (c == null) return Response.notFound('Concurso no encontrado');
      if (c.finalizado) {
        return Response.forbidden(
          jsonEncode({
            'error':
                'El concurso "${c.nombre}" está finalizado. No se permiten nuevas inscripciones (modo solo lectura).',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final map = jsonDecode(body) as Map<String, dynamic>;

      final artesano = Artesano.fromMap(
        map['artesano'] as Map<String, dynamic>,
      );
      final esNuevoArtesano = map['es_nuevo_artesano'] as bool? ?? false;
      final pieza1 = Artesania.fromMap(map['pieza1'] as Map<String, dynamic>);
      final pieza2 = map['pieza2'] != null
          ? Artesania.fromMap(map['pieza2'] as Map<String, dynamic>)
          : null;

      try {
        // REGISTRO ATÓMICO CONCURRENTE CON LOCK EN BASE DE DATOS
        final regGuardado = await registroRepo.registrarInscripcion(
          idConcurso: intId,
          artesano: artesano,
          esNuevoArtesano: esNuevoArtesano,
          pieza1: pieza1,
          pieza2: pieza2,
        );

        final resMap = regGuardado.toMap();
        if (regGuardado.artesano != null)
          resMap['artesano'] = regGuardado.artesano!.toMap();
        if (regGuardado.artesania1 != null)
          resMap['artesania1'] = regGuardado.artesania1!.toMap();
        if (regGuardado.artesania2 != null)
          resMap['artesania2'] = regGuardado.artesania2!.toMap();
        if (regGuardado.concurso != null)
          resMap['concurso'] = regGuardado.concurso!.toMap();

        return Response.ok(
          jsonEncode(resMap),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'error': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    router.put('/api/concursos/<idConcurso>/inscripcion/<idRegistro>', (
      Request req,
      String idConcurso,
      String idRegistro,
    ) async {
      final intConcursoId = int.tryParse(idConcurso);
      final intRegistroId = int.tryParse(idRegistro);
      if (intConcursoId == null || intRegistroId == null)
        return Response.badRequest(body: 'ID inválido');

      final body = await req.readAsString();

      final c = await concursoRepo.getConcursoById(intConcursoId);
      if (c == null) return Response.notFound('Concurso no encontrado');
      if (c.finalizado) {
        return Response.forbidden(
          jsonEncode({
            'error':
                'El concurso "${c.nombre}" está finalizado. No se permite modificar inscripciones (modo solo lectura).',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final map = jsonDecode(body) as Map<String, dynamic>;

      final artesano = Artesano.fromMap(
        map['artesano'] as Map<String, dynamic>,
      );
      final pieza1 = Artesania.fromMap(map['pieza1'] as Map<String, dynamic>);
      final pieza2 = map['pieza2'] != null
          ? Artesania.fromMap(map['pieza2'] as Map<String, dynamic>)
          : null;

      try {
        final regActualizado = await registroRepo.actualizarInscripcion(
          idRegistro: intRegistroId,
          idConcurso: intConcursoId,
          artesano: artesano,
          pieza1: pieza1,
          pieza2: pieza2,
        );

        final resMap = regActualizado.toMap();
        if (regActualizado.artesano != null)
          resMap['artesano'] = regActualizado.artesano!.toMap();
        if (regActualizado.artesania1 != null)
          resMap['artesania1'] = regActualizado.artesania1!.toMap();
        if (regActualizado.artesania2 != null)
          resMap['artesania2'] = regActualizado.artesania2!.toMap();
        if (regActualizado.concurso != null)
          resMap['concurso'] = regActualizado.concurso!.toMap();

        return Response.ok(
          jsonEncode(resMap),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'error': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    router.delete('/api/registros/<id>', (Request req, String id) async {
      final intId = int.tryParse(id);
      if (intId == null) return Response.badRequest(body: 'ID inválido');

      final reg = await registroRepo.getRegistroById(intId);
      if (reg != null && reg.concurso != null && reg.concurso!.finalizado) {
        return Response.forbidden(
          jsonEncode({
            'error':
                'El concurso "${reg.concurso!.nombre}" está finalizado. No se permite eliminar inscripciones (modo solo lectura).',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      try {
        await registroRepo.deleteRegistro(intId);
        return Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'error': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // ==========================================
    // 6. PREMIOS Y PREMIACIÓN
    // ==========================================
    router.get('/api/concursos/<id>/premios', (Request req, String id) async {
      final intId = int.tryParse(id);
      if (intId == null) return Response.badRequest(body: 'ID inválido');

      final premios = await premioRepo.getPremiosByConcurso(intId);
      final jsonList = premios.map((p) => p.toMap()).toList();

      return Response.ok(
        jsonEncode(jsonList),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.post('/api/concursos/<id>/premios', (Request req, String id) async {
      final intId = int.tryParse(id) ?? 0;
      final c = await concursoRepo.getConcursoById(intId);
      if (c != null && c.finalizado) {
        return Response(
          403,
          body: jsonEncode({
            'error':
                'El concurso "${c.nombre}" está finalizado. No se permite agregar premios (modo solo lectura).',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
      final body = await req.readAsString();
      final map = jsonDecode(body) as Map<String, dynamic>;
      final premio = Premio.fromMap(map);
      final premioId = await premioRepo.savePremio(premio);

      return Response.ok(
        jsonEncode({'id': premioId}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.delete('/api/premios/<id>', (Request req, String id) async {
      final intId = int.tryParse(id);
      if (intId == null) return Response.badRequest(body: 'ID inválido');

      await premioRepo.deletePremio(intId);
      return Response.ok(
        jsonEncode({'success': true}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.get('/api/concursos/<id>/ganadores', (Request req, String id) async {
      final intId = int.tryParse(id);
      if (intId == null) return Response.badRequest(body: 'ID inválido');

      final ganadores = await premioRepo.getGanadoresByConcurso(intId);
      return Response.ok(
        jsonEncode(ganadores),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.post('/api/concursos/<id>/premiacion', (
      Request req,
      String id,
    ) async {
      final intId = int.tryParse(id);
      if (intId == null) return Response.badRequest(body: 'ID inválido');

      final body = await req.readAsString();
      final map = jsonDecode(body) as Map<String, dynamic>;

      await premioRepo.asignarPremio(
        idConcurso: intId,
        idPremio: map['id_premio'] as int,
        idArtesania: map['id_artesania'] as int,
        idCategoria: map['id_categoria'] as int?,
        lugar: map['lugar'] as int?,
      );

      return Response.ok(
        jsonEncode({'success': true}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.delete('/api/concursos/<id>/premiacion/<idArtesania>', (
      Request req,
      String id,
      String idArtesania,
    ) async {
      final intId = int.tryParse(id);
      final intArtId = int.tryParse(idArtesania);
      if (intId == null || intArtId == null) {
        return Response.badRequest(body: 'ID inválido');
      }

      await premioRepo.removerPremiacion(
        idConcurso: intId,
        idArtesania: intArtId,
      );

      return Response.ok(
        jsonEncode({'success': true}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.get('/api/concursos/<id>/premios-conteo', (
      Request req,
      String id,
    ) async {
      final intId = int.tryParse(id);
      if (intId == null) return Response.badRequest(body: 'ID inválido');

      final conteo = await premioRepo.getConteoPremiosOtorgados(intId);
      final stringKeyMap = conteo.map((k, v) => MapEntry(k.toString(), v));
      return Response.ok(
        jsonEncode(stringKeyMap),
        headers: {'Content-Type': 'application/json'},
      );
    });


    // MIDDLEWARE: CORS y Log
    final handler = const Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(logRequests())
        .addHandler(router.call);

    _server = await io.serve(handler, InternetAddress.anyIPv4, _port);
    AppLogger.info(
      'Servidor Local CASART iniciado en http://0.0.0.0:$_port (Listo para recibir terminales)',
      category: 'RED_SERVIDOR',
    );
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      AppLogger.info(
        'Servidor Local CASART detenido.',
        category: 'RED_SERVIDOR',
      );
    }
  }

  Middleware _corsMiddleware() {
    return (innerHandler) {
      return (request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok(
            '',
            headers: {
              'Access-Control-Allow-Origin': '*',
              'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
              'Access-Control-Allow-Headers':
                  'Origin, Content-Type, Accept, Authorization',
            },
          );
        }
        final response = await innerHandler(request);
        return response.change(
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers':
                'Origin, Content-Type, Accept, Authorization',
          },
        );
      };
    };
  }
}
