import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/database/app_database.dart';
import '../core/logging/app_logger.dart';
import '../core/network/api_client.dart';
import '../models/registro_concurso.dart';
import '../models/artesano.dart';
import '../models/artesania.dart';
import '../models/concurso.dart';

class RegistroRepository {
  final AppDatabase _dbHelper;
  final ApiClient? apiClient;

  RegistroRepository({AppDatabase? dbHelper, this.apiClient})
      : _dbHelper = dbHelper ?? AppDatabase();

  Future<int> getNextFolio(int idConcurso) async {
    if (apiClient != null) {
      return await apiClient!.getNextFolio(idConcurso);
    }
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      'SELECT COALESCE(MAX(folio), 0) + 1 as next_folio FROM registro_concurso WHERE id_concurso = ?',
      [idConcurso],
    );
    return res.first['next_folio'] as int? ?? 1;
  }

  Future<RegistroConcurso> registrarInscripcion({
    required int idConcurso,
    required Artesano artesano,
    required bool esNuevoArtesano,
    required Artesania pieza1,
    Artesania? pieza2,
  }) async {
    if (apiClient != null) {
      return await apiClient!.registrarInscripcion(
        idConcurso: idConcurso,
        artesano: artesano,
        esNuevoArtesano: esNuevoArtesano,
        pieza1: pieza1,
        pieza2: pieza2,
      );
    }

    try {
      final db = await _dbHelper.database;
      final registro = await db.transaction<RegistroConcurso>((txn) async {
        // 0. Validar estatus del concurso (Medida de seguridad: modo solo lectura si está finalizado)
        final concursoRows = await txn.query('concurso', where: 'id = ?', whereArgs: [idConcurso]);
        if (concursoRows.isEmpty) throw StateError('Concurso #$idConcurso no encontrado');
        final concursoData = Concurso.fromMap(concursoRows.first);
        if (concursoData.finalizado) {
          throw StateError(
            'El concurso "${concursoData.nombre}" está finalizado. No se permite inscribir nuevas piezas (modo solo lectura).',
          );
        }

        // 1. Resolver el ID del artesano
        int artesanoId;
        if (esNuevoArtesano || artesano.id == null) {
          // Verificar si existe la CURP
          final existing = await txn.query(
            'artesano',
            where: 'UPPER(curp) = ?',
            whereArgs: [artesano.curp.trim().toUpperCase()],
          );
          if (existing.isNotEmpty) {
            artesanoId = existing.first['id'] as int;
            int? contactId = existing.first['id_info_contacto'] as int? ?? artesano.idInfoContacto;
            int? resId = existing.first['id_residencia'] as int? ?? artesano.idResidencia;

            if (contactId != null) {
              await txn.update('info_contacto', artesano.toInfoContactoMap(), where: 'id = ?', whereArgs: [contactId]);
            } else {
              contactId = await txn.insert('info_contacto', artesano.toInfoContactoMap());
            }

            if (resId != null) {
              await txn.update('residencia', artesano.toResidenciaMap(), where: 'id = ?', whereArgs: [resId]);
            } else {
              resId = await txn.insert('residencia', artesano.toResidenciaMap());
            }

            final artMap = artesano.toTableMap(
              idInfoContacto: contactId,
              idResidencia: resId,
            );
            artMap.remove('id');
            await txn.update('artesano', artMap, where: 'id = ?', whereArgs: [artesanoId]);
          } else {
            final contactId = await txn.insert('info_contacto', artesano.toInfoContactoMap());
            final resId = await txn.insert('residencia', artesano.toResidenciaMap());
            final artMap = artesano.toTableMap(
              idInfoContacto: contactId,
              idResidencia: resId,
            );
            artesanoId = await txn.insert('artesano', artMap);
          }
        } else {
          artesanoId = artesano.id!;
        }

        // 2. Insertar Pieza 1
        final now = DateTime.now().toIso8601String();
        final p1Map = pieza1.toMap();
        p1Map['created_at'] ??= now;
        p1Map['updated_at'] = now;
        final pieza1Id = await txn.insert('artesania_concurso', p1Map);

        // 3. Insertar Pieza 2 (si existe)
        int? pieza2Id;
        if (pieza2 != null && pieza2.nombre.trim().isNotEmpty) {
          final p2Map = pieza2.toMap();
          p2Map['created_at'] ??= now;
          p2Map['updated_at'] = now;
          pieza2Id = await txn.insert('artesania_concurso', p2Map);
        }

        // 4. Calcular el Folio Atómico dentro de la transacción
        final folioResult = await txn.rawQuery(
          'SELECT COALESCE(MAX(folio), 0) + 1 as next_folio FROM registro_concurso WHERE id_concurso = ?',
          [idConcurso],
        );
        final nuevoFolio = folioResult.first['next_folio'] as int? ?? 1;
        final nowStr = DateTime.now().toIso8601String();

        // 5. Crear el registro del concurso
        final registroMap = {
          'folio': nuevoFolio,
          'id_artesano': artesanoId,
          'id_concurso': idConcurso,
          'id_artesania_1': pieza1Id,
          'id_artesania_2': pieza2Id,
          'created_at': nowStr,
          'updated_at': nowStr,
        };

        final registroId = await txn.insert('registro_concurso', registroMap);

        // 6. Consultar y construir el objeto completo
        final artesanoGuardado = await _getArtesano(txn, artesanoId);
        final pieza1Guardada = await _getArtesania(txn, pieza1Id);
        final pieza2Guardada = pieza2Id != null ? await _getArtesania(txn, pieza2Id) : null;
        final concursoRow = await txn.query('concurso', where: 'id = ?', whereArgs: [idConcurso]);

        return RegistroConcurso(
          id: registroId,
          folio: nuevoFolio,
          idArtesano: artesanoId,
          idConcurso: idConcurso,
          idArtesania1: pieza1Id,
          idArtesania2: pieza2Id,
          createdAt: registroMap['created_at'] as String?,
          updatedAt: registroMap['updated_at'] as String?,
          artesano: artesanoGuardado,
          artesania1: pieza1Guardada,
          artesania2: pieza2Guardada,
          concurso: concursoRow.isNotEmpty ? Concurso.fromMap(concursoRow.first) : null,
        );
      });

      AppLogger.create(
        'Inscripción registrada Folio #${registro.folio} en Concurso #$idConcurso. Artesano: "${registro.artesano?.nombreCompleto}" (CURP: ${artesano.curp}). Pieza 1: "${pieza1.nombre}" (\$${pieza1.costoVenta.toStringAsFixed(2)}). ${pieza2 != null ? 'Pieza 2: "${pieza2.nombre}" (\$${pieza2.costoVenta.toStringAsFixed(2)})' : 'Sin Pieza 2'}',
        category: 'INSCRIPCION',
        data: {
          'folio': registro.folio,
          'id_concurso': idConcurso,
          'id_registro': registro.id,
          'curp': artesano.curp,
        },
      );

      return registro;
    } catch (e, stack) {
      AppLogger.error(
        'Error al registrar inscripción en Concurso #$idConcurso: $e',
        category: 'INSCRIPCION',
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
    if (apiClient != null) {
      return await apiClient!.actualizarInscripcion(
        idRegistro: idRegistro,
        idConcurso: idConcurso,
        artesano: artesano,
        pieza1: pieza1,
        pieza2: pieza2,
      );
    }

    final db = await _dbHelper.database;

    try {
      final registro = await db.transaction<RegistroConcurso>((txn) async {
        // 0. Validar estatus del concurso (Medida de seguridad: modo solo lectura si está finalizado)
        final concursoRows = await txn.query('concurso', where: 'id = ?', whereArgs: [idConcurso]);
        if (concursoRows.isEmpty) throw StateError('Concurso #$idConcurso no encontrado');
        final concursoData = Concurso.fromMap(concursoRows.first);
        if (concursoData.finalizado) {
          throw StateError(
            'El concurso "${concursoData.nombre}" está finalizado. No se permite modificar inscripciones (modo solo lectura).',
          );
        }

        // 1. Obtener registro existente
        final regRows = await txn.query('registro_concurso', where: 'id = ?', whereArgs: [idRegistro]);
        if (regRows.isEmpty) throw Exception('Inscripción con ID #$idRegistro no encontrada');

        final regRow = regRows.first;
        final artesanoId = regRow['id_artesano'] as int;
        final p1Id = regRow['id_artesania_1'] as int;
        int? p2Id = regRow['id_artesania_2'] as int?;

        // 2. Actualizar artesano
        final existingArts = await txn.query('artesano', where: 'id = ?', whereArgs: [artesanoId]);
        int? contactId;
        int? resId;
        if (existingArts.isNotEmpty) {
          contactId = existingArts.first['id_info_contacto'] as int? ?? artesano.idInfoContacto;
          resId = existingArts.first['id_residencia'] as int? ?? artesano.idResidencia;
        }

        if (contactId != null) {
          await txn.update('info_contacto', artesano.toInfoContactoMap(), where: 'id = ?', whereArgs: [contactId]);
        } else {
          contactId = await txn.insert('info_contacto', artesano.toInfoContactoMap());
        }

        if (resId != null) {
          await txn.update('residencia', artesano.toResidenciaMap(), where: 'id = ?', whereArgs: [resId]);
        } else {
          resId = await txn.insert('residencia', artesano.toResidenciaMap());
        }

        final artMap = artesano.toTableMap(
          idInfoContacto: contactId,
          idResidencia: resId,
        );
        artMap.remove('id');
        await txn.update('artesano', artMap, where: 'id = ?', whereArgs: [artesanoId]);

        // 3. Actualizar Pieza 1
        final now = DateTime.now().toIso8601String();
        final p1Map = pieza1.toMap();
        p1Map.remove('id');
        p1Map['updated_at'] = now;
        await txn.update('artesania_concurso', p1Map, where: 'id = ?', whereArgs: [p1Id]);

        // 4. Actualizar o insertar Pieza 2
        if (pieza2 != null && pieza2.nombre.trim().isNotEmpty) {
          final p2Map = pieza2.toMap();
          p2Map.remove('id');
          p2Map['updated_at'] = now;
          if (p2Id != null) {
            await txn.update('artesania_concurso', p2Map, where: 'id = ?', whereArgs: [p2Id]);
          } else {
            p2Map['created_at'] ??= now;
            p2Id = await txn.insert('artesania_concurso', p2Map);
            await txn.update('registro_concurso', {'id_artesania_2': p2Id, 'updated_at': now}, where: 'id = ?', whereArgs: [idRegistro]);
          }
        } else if (p2Id != null && (pieza2 == null || pieza2.nombre.trim().isEmpty)) {
          await txn.update('registro_concurso', {'id_artesania_2': null, 'updated_at': now}, where: 'id = ?', whereArgs: [idRegistro]);
          await txn.delete('artesania_concurso', where: 'id = ?', whereArgs: [p2Id]);
          p2Id = null;
        }

        await txn.update('registro_concurso', {'updated_at': now}, where: 'id = ?', whereArgs: [idRegistro]);

        // 5. Retornar registro completo actualizado
        final artesanoGuardado = await _getArtesano(txn, artesanoId);
        final pieza1Guardada = await _getArtesania(txn, p1Id);
        final pieza2Guardada = p2Id != null ? await _getArtesania(txn, p2Id) : null;
        final concursoRow = await txn.query('concurso', where: 'id = ?', whereArgs: [idConcurso]);

        return RegistroConcurso(
          id: idRegistro,
          folio: regRow['folio'] as int,
          idArtesano: artesanoId,
          idConcurso: idConcurso,
          idArtesania1: p1Id,
          idArtesania2: p2Id,
          createdAt: regRow['created_at'] as String?,
          updatedAt: now,
          artesano: artesanoGuardado,
          artesania1: pieza1Guardada,
          artesania2: pieza2Guardada,
          concurso: concursoRow.isNotEmpty ? Concurso.fromMap(concursoRow.first) : null,
        );
      });

      AppLogger.update(
        'Inscripción Folio #${registro.folio} (ID: $idRegistro) actualizada en Concurso #$idConcurso. Artesano: "${registro.artesano?.nombreCompleto}". Modificaciones guardadas.',
        category: 'INSCRIPCION',
        data: {'idRegistro': idRegistro, 'folio': registro.folio, 'idConcurso': idConcurso},
      );

      return registro;
    } catch (e, stack) {
      AppLogger.error(
        'Error al actualizar inscripción #$idRegistro: $e',
        category: 'INSCRIPCION',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<List<RegistroConcurso>> getRegistrosByConcurso(int idConcurso, {String? search}) async {
    if (apiClient != null) {
      return await apiClient!.getRegistros(idConcurso, search: search);
    }

    final db = await _dbHelper.database;

    String where = 'r.id_concurso = ?';
    List<dynamic> args = [idConcurso];

    if (search != null && search.trim().isNotEmpty) {
      final pattern = '%${search.trim()}%';
      where += ''' AND (
        a.nombre LIKE ? OR 
        a.ap_paterno LIKE ? OR 
        a.curp LIKE ? OR 
        p1.nombre LIKE ? OR 
        CAST(r.folio AS TEXT) = ?
      )''';
      args.addAll([pattern, pattern, pattern, pattern, search.trim()]);
    }

    final query = '''
      SELECT r.* 
      FROM registro_concurso r
      JOIN artesano a ON r.id_artesano = a.id
      JOIN artesania_concurso p1 ON r.id_artesania_1 = p1.id
      WHERE $where
      ORDER BY r.folio DESC
    ''';

    final rows = await db.rawQuery(query, args);

    final concursoRows = await db.query('concurso', where: 'id = ?', whereArgs: [idConcurso]);
    final concurso = concursoRows.isNotEmpty ? Concurso.fromMap(concursoRows.first) : null;

    List<RegistroConcurso> registros = [];
    for (final row in rows) {
      final artesanoId = row['id_artesano'] as int;
      final pieza1Id = row['id_artesania_1'] as int;
      final pieza2Id = row['id_artesania_2'] as int?;

      final artesano = await _getArtesano(db, artesanoId);
      final pieza1 = await _getArtesania(db, pieza1Id);
      final pieza2 = pieza2Id != null ? await _getArtesania(db, pieza2Id) : null;

      registros.add(RegistroConcurso.fromMap(
        row,
        artesano: artesano,
        artesania1: pieza1,
        artesania2: pieza2,
        concurso: concurso,
      ));
    }

    return registros;
  }

  Future<RegistroConcurso?> getRegistroById(int id) async {
    final db = await _dbHelper.database;

    final rows = await db.query('registro_concurso', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;

    final row = rows.first;
    final idConcurso = row['id_concurso'] as int;
    final artesanoId = row['id_artesano'] as int;
    final pieza1Id = row['id_artesania_1'] as int;
    final pieza2Id = row['id_artesania_2'] as int?;

    final artesano = await _getArtesano(db, artesanoId);
    final pieza1 = await _getArtesania(db, pieza1Id);
    final pieza2 = pieza2Id != null ? await _getArtesania(db, pieza2Id) : null;
    final concursoRows = await db.query('concurso', where: 'id = ?', whereArgs: [idConcurso]);

    return RegistroConcurso.fromMap(
      row,
      artesano: artesano,
      artesania1: pieza1,
      artesania2: pieza2,
      concurso: concursoRows.isNotEmpty ? Concurso.fromMap(concursoRows.first) : null,
    );
  }

  Future<void> deleteRegistro(int id) async {
    try {
      if (apiClient != null) {
        await apiClient!.deleteRegistro(id);
        AppLogger.delete('Inscripción #$id eliminada vía API', category: 'INSCRIPCION', data: {'id': id});
        return;
      }

      final db = await _dbHelper.database;
      final rows = await db.query('registro_concurso', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return;

      final r = rows.first;
      final p1Id = r['id_artesania_1'] as int;
      final p2Id = r['id_artesania_2'] as int?;
      final folio = r['folio'] as int?;
      final idConcurso = r['id_concurso'] as int?;

      await db.transaction((txn) async {
        // Validar estatus del concurso antes de eliminar (Medida de seguridad)
        if (idConcurso != null) {
          final cRows = await txn.query('concurso', where: 'id = ?', whereArgs: [idConcurso]);
          if (cRows.isNotEmpty) {
            final c = Concurso.fromMap(cRows.first);
            if (c.finalizado) {
              throw StateError(
                'El concurso "${c.nombre}" está finalizado. No se permite eliminar inscripciones (modo solo lectura).',
              );
            }
          }
        }

        await txn.delete('registro_concurso', where: 'id = ?', whereArgs: [id]);
        await txn.delete('artesania_concurso', where: 'id = ?', whereArgs: [p1Id]);
        if (p2Id != null) {
          await txn.delete('artesania_concurso', where: 'id = ?', whereArgs: [p2Id]);
        }
      });

      AppLogger.delete(
        'Inscripción eliminada (ID: $id, Folio: #$folio) en Concurso #$idConcurso. Piezas eliminadas: [P1: $p1Id${p2Id != null ? ', P2: $p2Id' : ''}]',
        category: 'INSCRIPCION',
        data: {'id': id, 'folio': folio, 'idConcurso': idConcurso},
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error al eliminar inscripción #$id: $e',
        category: 'INSCRIPCION',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<Artesano?> _getArtesano(DatabaseExecutor db, int id) async {
    final rows = await db.rawQuery('''
      SELECT a.*,
             ic.correo, ic.telefono, ic.telefono_emergencia, ic.facebook, ic.instagram, ic.tiktok, ic.youtube, ic.x,
             r.municipio, r.localidad, r.colonia, r.calle, r.numero_exterior, r.cp,
             e.nombre as etnia_nombre, ec.nombre as estado_civil_nombre
      FROM artesano a
      LEFT JOIN info_contacto ic ON a.id_info_contacto = ic.id
      LEFT JOIN residencia r ON a.id_residencia = r.id
      LEFT JOIN etnia e ON a.id_etnia = e.id
      LEFT JOIN estado_civil ec ON a.id_estado_civil = ec.id
      WHERE a.id = ?
    ''', [id]);
    return rows.isNotEmpty ? Artesano.fromMap(rows.first) : null;
  }

  Future<Artesania?> _getArtesania(DatabaseExecutor db, int id) async {
    final rows = await db.rawQuery('''
      SELECT p.*, r.nombre as rama_nombre, c.nombre as categoria_nombre, s.nombre as subcategoria_nombre, pr.nombre as premio_nombre
      FROM artesania_concurso p
      LEFT JOIN rama_artesanal r ON p.id_rama_artesanal = r.id
      LEFT JOIN categoria_concurso c ON p.id_categoria_concurso = c.id
      LEFT JOIN sub_categoria_concurso s ON p.id_sub_categoria_concurso = s.id
      LEFT JOIN premio pr ON p.id_premio = pr.id
      WHERE p.id = ?
    ''', [id]);
    return rows.isNotEmpty ? Artesania.fromMap(rows.first) : null;
  }
}
