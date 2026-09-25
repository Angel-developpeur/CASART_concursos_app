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
      SELECT pr.*, 
             p.nombre as premio_nombre, p.monto as premio_monto,
             a.nombre as artesania_nombre, a.costo_venta as artesania_costo,
             r.folio as folio_concurso,
             art.nombre as artesano_nombre, art.ap_paterno as artesano_paterno, art.curp as artesano_curp,
             c.nombre as categoria_nombre
          FROM premiacion pr
      JOIN premio p ON pr.id_premio = p.id
      JOIN artesania_concurso a ON pr.id_artesania = a.id
      JOIN registro_concurso r ON (r.id_artesania_1 = a.id OR r.id_artesania_2 = a.id)
      JOIN artesano art ON r.id_artesano = art.id
      LEFT JOIN categoria_concurso c ON a.id_categoria_concurso = c.id
      WHERE pr.id_concurso = ?
      ORDER BY p.monto DESC, pr.lugar ASC
    ''';

    return await db.rawQuery(query, [idConcurso]);
  }
}
