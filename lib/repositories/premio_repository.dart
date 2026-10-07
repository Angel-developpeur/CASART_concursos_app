import '../core/database/app_database.dart';
import '../core/logging/app_logger.dart';
import '../core/network/api_client.dart';
import '../models/premio.dart';

class PremioRepository {
  final AppDatabase _dbHelper;
  final ApiClient? apiClient;

  PremioRepository({AppDatabase? dbHelper, this.apiClient})
    : _dbHelper = dbHelper ?? AppDatabase();

  Future<List<Map<String, dynamic>>> getTiposPremio() async {
    if (apiClient != null) {
      final data = await apiClient!.getCatalogos();
      return (data['tipos_premio'] as List? ??
              [
                {'id': 1, 'nombre': 'Galardón'},
                {'id': 2, 'nombre': 'Especial'},
                {'id': 3, 'nombre': 'Común'},
              ])
          .cast<Map<String, dynamic>>();
    }
    final db = await _dbHelper.database;
    return await db.query('tipo_premio', orderBy: 'id ASC');
  }

  Future<List<Premio>> getPremiosByConcurso(int idConcurso) async {
    if (apiClient != null) {
      return await apiClient!.getPremios(idConcurso);
    }

    final db = await _dbHelper.database;

    final query = '''
      SELECT p.*, c.nombre as categoria_nombre, s.nombre as subcategoria_nombre, tp.nombre as tipo_premio_nombre
      FROM premio p
      LEFT JOIN categoria_concurso c ON p.id_categoria = c.id
      LEFT JOIN sub_categoria_concurso s ON p.id_sub_categoria = s.id
      LEFT JOIN tipo_premio tp ON p.id_tipo_premio = tp.id
      WHERE p.id_concurso = ?
      ORDER BY p.id ASC
    ''';

    final rows = await db.rawQuery(query, [idConcurso]);
    return rows.map(Premio.fromMap).toList();
  }

  Future<int> savePremio(Premio premio) async {
    if (apiClient != null) {
      return await apiClient!.savePremio(premio);
    }
    if (premio.id == null) {
      return await createPremio(premio);
    } else {
      await updatePremio(premio);
      return premio.id!;
    }
  }

  Future<int> createPremio(Premio premio) async {
    try {
      final db = await _dbHelper.database;
      final cRows = await db.query(
        'concurso',
        columns: ['finalizado', 'nombre'],
        where: 'id = ?',
        whereArgs: [premio.idConcurso],
      );
      if (cRows.isNotEmpty) {
        final isFinalizado =
            cRows.first['finalizado'] == 1 || cRows.first['finalizado'] == true;
        if (isFinalizado) {
          throw StateError(
            'El concurso "${cRows.first['nombre']}" está finalizado. No se permite agregar nuevos premios (modo solo lectura).',
          );
        }
      }
      final insertMap = premio.toMap();
      final now = DateTime.now().toIso8601String();
      insertMap['created_at'] ??= now;
      insertMap['updated_at'] ??= now;
      final id = await db.insert('premio', insertMap);
      AppLogger.create(
        'Premio registrado en bolsa: "${premio.nombre}" (\$${premio.monto.toStringAsFixed(2)}) en Concurso #${premio.idConcurso}',
        category: 'PREMIO',
        data: {
          'id': id,
          'nombre': premio.nombre,
          'monto': premio.monto,
          'idConcurso': premio.idConcurso,
        },
      );
      return id;
    } catch (e, stack) {
      AppLogger.error(
        'Error al crear premio "${premio.nombre}": $e',
        category: 'PREMIO',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> updatePremio(Premio premio) async {
    if (premio.id == null) return;
    try {
      final db = await _dbHelper.database;
      final updateMap = premio.toMap();
      updateMap['updated_at'] = DateTime.now().toIso8601String();
      await db.update(
        'premio',
        updateMap,
        where: 'id = ?',
        whereArgs: [premio.id],
      );
      AppLogger.update(
        'Premio actualizado: "${premio.nombre}" (ID: ${premio.id}, Monto: \$${premio.monto.toStringAsFixed(2)})',
        category: 'PREMIO',
        data: {'id': premio.id, 'nombre': premio.nombre, 'monto': premio.monto},
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error al actualizar premio #${premio.id}: $e',
        category: 'PREMIO',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> deletePremio(int id) async {
    try {
      if (apiClient != null) {
        await apiClient!.deletePremio(id);
        AppLogger.delete(
          'Premio #$id eliminado vía API',
          category: 'PREMIO',
          data: {'id': id},
        );
        return;
      }
      final db = await _dbHelper.database;
      await db.update(
        'artesania_concurso',
        {
          'id_premio': null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id_premio = ?',
        whereArgs: [id],
      );
      await db.delete('premio', where: 'id = ?', whereArgs: [id]);
      AppLogger.delete(
        'Premio #$id eliminado de la bolsa del concurso',
        category: 'PREMIO',
        data: {'id': id},
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error al eliminar premio #$id: $e',
        category: 'PREMIO',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> asignarPremio({
    required int idConcurso,
    required int idPremio,
    required int idArtesania,
    int? idCategoria,
    int? lugar,
  }) async {
    await asignarPremiacion(
      idConcurso: idConcurso,
      idPremio: idPremio,
      idArtesania: idArtesania,
      idCategoria: idCategoria,
      lugar: lugar,
    );
  }

  Future<void> asignarPremiacion({
    required int idConcurso,
    required int idPremio,
    required int idArtesania,
    int? idCategoria,
    int? lugar,
  }) async {
    try {
      if (apiClient != null) {
        await apiClient!.asignarGanador(
          idConcurso: idConcurso,
          idPremio: idPremio,
          idArtesania: idArtesania,
          idCategoria: idCategoria,
          lugar: lugar,
        );
        AppLogger.create(
          'Ganador asignado vía API: Concurso #$idConcurso, Premio #$idPremio, Pieza #$idArtesania, Lugar: $lugar',
          category: 'PREMIACION',
          data: {
            'idConcurso': idConcurso,
            'idPremio': idPremio,
            'idArtesania': idArtesania,
            'lugar': lugar,
          },
        );
        return;
      }

      final db = await _dbHelper.database;
      // Eliminar asignación previa de esta pieza en premiacion si existía
      await db.delete('premiacion', where: 'id_artesania = ?', whereArgs: [idArtesania]);

      await db.insert('premiacion', {
        'id_concurso': idConcurso,
        'id_premio': idPremio,
        'id_artesania': idArtesania,
        'id_categoria': idCategoria,
        'lugar': lugar,
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.update(
        'artesania_concurso',
        {
          'id_premio': idPremio,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [idArtesania],
      );

      AppLogger.create(
        'Ganador asignado en Concurso #$idConcurso: Premio #$idPremio otorgado a Pieza #$idArtesania (Lugar: ${lugar ?? 'N/A'})',
        category: 'PREMIACION',
        data: {
          'idConcurso': idConcurso,
          'idPremio': idPremio,
          'idArtesania': idArtesania,
          'lugar': lugar,
        },
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error al asignar ganador en Concurso #$idConcurso (Premio #$idPremio, Pieza #$idArtesania): $e',
        category: 'PREMIACION',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> removerPremiacion({
    required int idConcurso,
    required int idArtesania,
  }) async {
    try {
      if (apiClient != null) {
        await apiClient!.removerGanador(
          idConcurso: idConcurso,
          idArtesania: idArtesania,
        );
        return;
      }

      final db = await _dbHelper.database;
      await db.delete('premiacion', where: 'id_artesania = ?', whereArgs: [idArtesania]);
      await db.update(
        'artesania_concurso',
        {
          'id_premio': null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [idArtesania],
      );

      AppLogger.update(
        'Premio retirado de Pieza #$idArtesania en Concurso #$idConcurso',
        category: 'PREMIACION',
        data: {'idConcurso': idConcurso, 'idArtesania': idArtesania},
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error al retirar premio de Pieza #$idArtesania: $e',
        category: 'PREMIACION',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<Map<int, int>> getConteoPremiosOtorgados(int idConcurso) async {
    if (apiClient != null) {
      final ganadores = await apiClient!.getGanadores(idConcurso);
      final Map<int, int> resultado = {};
      for (final row in ganadores) {
        final idPremio = row['id_premio'] as int?;
        if (idPremio != null) {
          resultado[idPremio] = (resultado[idPremio] ?? 0) + 1;
        }
      }
      return resultado;
    }

    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT a.id_premio, COUNT(DISTINCT a.id) as conteo
      FROM artesania_concurso a
      JOIN registro_concurso r ON (r.id_artesania_1 = a.id OR r.id_artesania_2 = a.id)
      WHERE r.id_concurso = ? AND a.id_premio IS NOT NULL
      GROUP BY a.id_premio
    ''', [idConcurso]);

    final Map<int, int> resultado = {};
    for (final row in rows) {
      final idPremio = row['id_premio'] as int?;
      final conteo = (row['conteo'] as num?)?.toInt() ?? 0;
      if (idPremio != null) {
        resultado[idPremio] = conteo;
      }
    }
    return resultado;
  }

  Future<List<Map<String, dynamic>>> getGanadoresByConcurso(
    int idConcurso,
  ) async {
    if (apiClient != null) {
      return await apiClient!.getGanadores(idConcurso);
    }

    final db = await _dbHelper.database;

    final query = '''
      SELECT 
        pr.*,
        pr.id as premiacion_id,
        pr.lugar as premiacion_lugar,
        p.id as premio_id,
        p.nombre as premio_nombre,
        p.monto as premio_monto,
        p.lugar as premio_lugar,
        p.id_tipo_premio,
        p.id_categoria as premio_id_categoria,
        p.id_sub_categoria as premio_id_sub_categoria,
        tp.nombre as tipo_premio_nombre,
        a.id as artesania_id,
        a.nombre as artesania_nombre,
        a.costo_venta as artesania_costo,
        a.costo_produccion as artesania_costo_produccion,
        a.descripcion as artesania_descripcion,
        a.material_elaboracion,
        a.tiempo_elaboracion,
        a.plazo_elaboracion,
        a.id_categoria_concurso,
        a.id_sub_categoria_concurso,
        r.folio as folio_concurso,
        r.folio as registro_folio,
        r.id as registro_id,
        r.id_artesania_1,
        r.id_artesania_2,
        art.id as artesano_id,
        art.nombre as artesano_nombre,
        art.ap_paterno as artesano_paterno,
        art.ap_materno as artesano_materno,
        art.genero as artesano_genero,
        art.curp as artesano_curp,
        art.fecha_nacimiento as artesano_fecha_nacimiento,
        art.max_nivel_academico as artesano_escolaridad,
        res.municipio,
        res.localidad,
        res.colonia,
        res.calle,
        res.numero_exterior,
        res.cp,
        et.nombre as etnia_nombre,
        ec.nombre as estado_civil_nombre,
        ic.telefono,
        cat.nombre as categoria_nombre,
        sub.nombre as subcategoria_nombre,
        rama.nombre as rama_nombre
      FROM premiacion pr
      JOIN premio p ON pr.id_premio = p.id
      LEFT JOIN tipo_premio tp ON p.id_tipo_premio = tp.id
      JOIN artesania_concurso a ON pr.id_artesania = a.id
      JOIN registro_concurso r ON (r.id_artesania_1 = a.id OR r.id_artesania_2 = a.id)
      JOIN artesano art ON r.id_artesano = art.id
      LEFT JOIN residencia res ON art.id_residencia = res.id
      LEFT JOIN etnia et ON art.id_etnia = et.id
      LEFT JOIN estado_civil ec ON art.id_estado_civil = ec.id
      LEFT JOIN info_contacto ic ON art.id_info_contacto = ic.id
      LEFT JOIN categoria_concurso cat ON a.id_categoria_concurso = cat.id
      LEFT JOIN sub_categoria_concurso sub ON a.id_sub_categoria_concurso = sub.id
      LEFT JOIN rama_artesanal rama ON a.id_rama_artesanal = rama.id
      WHERE pr.id_concurso = ?
      ORDER BY p.id_tipo_premio ASC, p.monto DESC, pr.lugar ASC, p.lugar ASC
    ''';

    return await db.rawQuery(query, [idConcurso]);
  }
}
