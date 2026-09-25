import 'dart:convert';
import 'package:http/http.dart' as http;
import '../logging/app_logger.dart';
import '../../models/concurso.dart';
import '../../models/artesano.dart';
import '../../models/artesania.dart';
import '../../models/registro_concurso.dart';
import '../../models/premio.dart';

class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<bool> checkHealth() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['status'] == 'ok';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // CONCURSOS
  // ==========================================
  Future<List<Concurso>> getConcursos({
    String? search,
    String? ejercicio,
    bool? finalizado,
  }) async {
    final uri = Uri.parse('$baseUrl/concursos').replace(
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (ejercicio != null && ejercicio.isNotEmpty) 'ejercicio': ejercicio,
        if (finalizado != null) 'finalizado': finalizado ? '1' : '0',
      },
    );

    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200)
      throw Exception('Error al obtener concursos: ${res.body}');

    final List<dynamic> list = jsonDecode(utf8.decode(res.bodyBytes));
    return list
        .map((m) => Concurso.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<Concurso?> getConcursoById(int id) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/concursos/$id'),
      headers: _headers,
    );
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200)
      throw Exception('Error al obtener concurso: ${res.body}');

    return Concurso.fromMap(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<int> saveConcurso(Concurso concurso) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/concursos'),
        headers: _headers,
        body: jsonEncode(concurso.toMap()),
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        throw Exception('Error al guardar concurso: ${res.body}');
      }
      final data = jsonDecode(res.body);
      final id = data['id'] as int;
      AppLogger.create(
        'Concurso "${concurso.nombre}" guardado exitosamente en Servidor (ID: $id)',
        category: 'RED_CLIENTE',
        data: {'id': id, 'nombre': concurso.nombre},
      );
      return id;
    } catch (e, stack) {
      AppLogger.error(
        'Error al guardar concurso vía API: $e',
        category: 'RED_CLIENTE',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> setFinalizado(int id, bool finalizado) async {
    try {
      final res = await _client.put(
        Uri.parse('$baseUrl/concursos/$id/finalizado'),
        headers: _headers,
        body: jsonEncode({'finalizado': finalizado}),
      );
      if (res.statusCode != 200) {
        throw Exception(
          'Error al actualizar estatus de finalización: ${res.body}',
        );
      }
      AppLogger.update(
        'Estatus de concurso #$id actualizado en servidor: ${finalizado ? "FINALIZADO" : "EN PROCESO"}',
        category: 'RED_CLIENTE',
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error al actualizar estatus de finalización vía API: $e',
        category: 'RED_CLIENTE',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> deleteConcurso(int id) async {
    try {
      final res = await _client.delete(
        Uri.parse('$baseUrl/concursos/$id'),
        headers: _headers,
      );
      if (res.statusCode != 200)
        throw Exception('Error al eliminar concurso: ${res.body}');
    } catch (e, stack) {
      AppLogger.error(
        'Error al eliminar concurso vía API: $e',
        category: 'RED_CLIENTE',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  // ==========================================
  // CATÁLOGOS Y ARTESANOS
  // ==========================================
  Future<Map<String, dynamic>> getCatalogos() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/catalogos'),
      headers: _headers,
    );
    if (res.statusCode != 200)
      throw Exception('Error al obtener catálogos: ${res.body}');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<List<Artesano>> searchArtesanos({
    required String query,
    int limit = 10,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/artesanos/search',
    ).replace(queryParameters: {'q': query, 'limit': limit.toString()});

    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200)
      throw Exception('Error al buscar artesanos: ${res.body}');

    final List<dynamic> list = jsonDecode(utf8.decode(res.bodyBytes));
    return list
        .map((m) => Artesano.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  // ==========================================
  // INSCRIPCIONES (FOLIO ATÓMICO EN SERVIDOR)
  // ==========================================
  Future<int> getNextFolio(int idConcurso) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/concursos/$idConcurso/next-folio'),
      headers: _headers,
    );
    if (res.statusCode != 200)
      throw Exception('Error al obtener folio: ${res.body}');
    final data = jsonDecode(res.body);
    return data['next_folio'] as int;
  }

  Future<List<RegistroConcurso>> getRegistros(
    int idConcurso, {
    String? search,
  }) async {
    final uri = Uri.parse('$baseUrl/concursos/$idConcurso/registros').replace(
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200)
      throw Exception('Error al obtener registros: ${res.body}');

    final List<dynamic> list = jsonDecode(utf8.decode(res.bodyBytes));
    return list.map((m) {
      final map = m as Map<String, dynamic>;
      return RegistroConcurso.fromMap(
        map,
        artesano: map['artesano'] != null
            ? Artesano.fromMap(map['artesano'])
            : null,
        artesania1: map['artesania1'] != null
            ? Artesania.fromMap(map['artesania1'])
            : null,
        artesania2: map['artesania2'] != null
            ? Artesania.fromMap(map['artesania2'])
            : null,
        concurso: map['concurso'] != null
            ? Concurso.fromMap(map['concurso'])
            : null,
      );
    }).toList();
  }

  Future<RegistroConcurso> registrarInscripcion({
    required int idConcurso,
    required Artesano artesano,
    required bool esNuevoArtesano,
    required Artesania pieza1,
    Artesania? pieza2,
  }) async {
    final payload = {
      'id_concurso': idConcurso,
      'artesano': artesano.toMap(),
      'es_nuevo_artesano': esNuevoArtesano,
      'pieza1': pieza1.toMap(),
      if (pieza2 != null) 'pieza2': pieza2.toMap(),
    };

    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/concursos/$idConcurso/inscripcion'),
        headers: _headers,
        body: jsonEncode(payload),
      );

      if (res.statusCode != 200 && res.statusCode != 201) {
        String msg = res.body;
        try {
          final errMap = jsonDecode(utf8.decode(res.bodyBytes));
          if (errMap is Map && errMap.containsKey('error')) {
            msg = errMap['error'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }

      final map =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final reg = RegistroConcurso.fromMap(
        map,
        artesano: map['artesano'] != null
            ? Artesano.fromMap(map['artesano'])
            : null,
        artesania1: map['artesania1'] != null
            ? Artesania.fromMap(map['artesania1'])
            : null,
        artesania2: map['artesania2'] != null
            ? Artesania.fromMap(map['artesania2'])
            : null,
        concurso: map['concurso'] != null
            ? Concurso.fromMap(map['concurso'])
            : null,
      );

      AppLogger.create(
        'Inscripción Folio #${reg.folio} enviada y confirmada en Servidor (Concurso #$idConcurso). Artesano: "${artesano.nombreCompleto}"',
        category: 'RED_CLIENTE',
        data: {
          'folio': reg.folio,
          'idConcurso': idConcurso,
          'idRegistro': reg.id,
        },
      );

      return reg;
    } catch (e, stack) {
      AppLogger.error(
        'Error al registrar inscripción vía API en Concurso #$idConcurso: $e',
        category: 'RED_CLIENTE',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<RegistroConcurso> actualizarInscripcion({
    required int idRegistro,
    required int idConcurso,
    required Artesano artesano,
    required Artesania pieza1,
    Artesania? pieza2,
  }) async {
    final payload = {
      'id_registro': idRegistro,
      'id_concurso': idConcurso,
      'artesano': artesano.toMap(),
      'pieza1': pieza1.toMap(),
      if (pieza2 != null) 'pieza2': pieza2.toMap(),
    };

    try {
      final res = await _client.put(
        Uri.parse('$baseUrl/concursos/$idConcurso/inscripcion/$idRegistro'),
        headers: _headers,
        body: jsonEncode(payload),
      );

      if (res.statusCode != 200) {
        String msg = res.body;
        try {
          final errMap = jsonDecode(utf8.decode(res.bodyBytes));
          if (errMap is Map && errMap.containsKey('error')) {
            msg = errMap['error'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }

      final map =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final reg = RegistroConcurso.fromMap(
        map,
        artesano: map['artesano'] != null
            ? Artesano.fromMap(map['artesano'])
            : null,
        artesania1: map['artesania1'] != null
            ? Artesania.fromMap(map['artesania1'])
            : null,
        artesania2: map['artesania2'] != null
            ? Artesania.fromMap(map['artesania2'])
            : null,
        concurso: map['concurso'] != null
            ? Concurso.fromMap(map['concurso'])
            : null,
      );

      AppLogger.update(
        'Inscripción Folio #${reg.folio} (ID: $idRegistro) actualizada con éxito en el Servidor',
        category: 'RED_CLIENTE',
        data: {
          'folio': reg.folio,
          'idRegistro': idRegistro,
          'idConcurso': idConcurso,
        },
      );

      return reg;
    } catch (e, stack) {
      AppLogger.error(
        'Error al actualizar inscripción #$idRegistro vía API: $e',
        category: 'RED_CLIENTE',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> deleteRegistro(int id) async {
    try {
      final res = await _client.delete(
        Uri.parse('$baseUrl/registros/$id'),
        headers: _headers,
      );
      if (res.statusCode != 200) {
        String msg = res.body;
        try {
          final errMap = jsonDecode(utf8.decode(res.bodyBytes));
          if (errMap is Map && errMap.containsKey('error')) {
            msg = errMap['error'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
      AppLogger.delete(
        'Inscripción #$id eliminada exitosamente en el Servidor',
        category: 'RED_CLIENTE',
        data: {'id': id},
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error al eliminar registro #$id vía API: $e',
        category: 'RED_CLIENTE',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  // ==========================================
  // PREMIOS Y PREMIACIÓN
  // ==========================================
  Future<List<Premio>> getPremios(int idConcurso) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/concursos/$idConcurso/premios'),
      headers: _headers,
    );
    if (res.statusCode != 200)
      throw Exception('Error al obtener premios: ${res.body}');

    final List<dynamic> list = jsonDecode(utf8.decode(res.bodyBytes));
    return list.map((m) => Premio.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<int> savePremio(Premio premio) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/concursos/${premio.idConcurso}/premios'),
        headers: _headers,
        body: jsonEncode(premio.toMap()),
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        String msg = res.body;
        try {
          final errMap = jsonDecode(utf8.decode(res.bodyBytes));
          if (errMap is Map && errMap.containsKey('error')) {
            msg = errMap['error'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
      final data = jsonDecode(res.body);
      final id = data['id'] as int;
      AppLogger.create(
        'Premio "${premio.nombre}" (\$${premio.monto}) guardado vía API en Concurso #${premio.idConcurso}',
        category: 'RED_CLIENTE',
        data: {'id': id},
      );
      return id;
    } catch (e, stack) {
      AppLogger.error(
        'Error al guardar premio vía API: $e',
        category: 'RED_CLIENTE',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> deletePremio(int id) async {
    try {
      final res = await _client.delete(
        Uri.parse('$baseUrl/premios/$id'),
        headers: _headers,
      );
      if (res.statusCode != 200)
        throw Exception('Error al eliminar premio: ${res.body}');
      AppLogger.delete(
        'Premio #$id eliminado vía API',
        category: 'RED_CLIENTE',
        data: {'id': id},
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error al eliminar premio #$id vía API: $e',
        category: 'RED_CLIENTE',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getGanadores(int idConcurso) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/concursos/$idConcurso/ganadores'),
      headers: _headers,
    );
    if (res.statusCode != 200)
      throw Exception('Error al obtener ganadores: ${res.body}');

    final List<dynamic> list = jsonDecode(utf8.decode(res.bodyBytes));
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> asignarGanador({
    required int idConcurso,
    required int idPremio,
    required int idArtesania,
    int? idCategoria,
    int? lugar,
  }) async {
    final payload = {
      'id_concurso': idConcurso,
      'id_premio': idPremio,
      'id_artesania': idArtesania,
      'id_categoria': idCategoria,
      'lugar': lugar,
    };

    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/concursos/$idConcurso/premiacion'),
        headers: _headers,
        body: jsonEncode(payload),
      );

      if (res.statusCode != 200 && res.statusCode != 201) {
        throw Exception('Error al asignar ganador: ${res.body}');
      }
      AppLogger.create(
        'Ganador asignado vía API: Concurso #$idConcurso, Premio #$idPremio, Pieza #$idArtesania',
        category: 'RED_CLIENTE',
        data: {
          'idConcurso': idConcurso,
          'idPremio': idPremio,
          'idArtesania': idArtesania,
          'lugar': lugar,
        },
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error al asignar ganador vía API: $e',
        category: 'RED_CLIENTE',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }
}
