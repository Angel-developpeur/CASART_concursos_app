import '../core/data/municipios_data.dart';
import '../core/database/app_database.dart';
import '../core/logging/app_logger.dart';
import '../core/network/api_client.dart';
import '../models/artesano.dart';

class ArtesanoRepository {
  final AppDatabase _dbHelper;
  final ApiClient? apiClient;

  ArtesanoRepository({AppDatabase? dbHelper, this.apiClient})
      : _dbHelper = dbHelper ?? AppDatabase();

  Future<List<Map<String, dynamic>>> getEtnias() async {
    if (apiClient != null) {
      final data = await apiClient!.getCatalogos();
      return (data['etnias'] as List).cast<Map<String, dynamic>>();
    }
    final db = await _dbHelper.database;
    return await db.query('etnia', orderBy: 'id ASC');
  }

  Future<List<Map<String, dynamic>>> getEstadosCiviles() async {
    if (apiClient != null) {
      final data = await apiClient!.getCatalogos();
      return (data['estados_civiles'] as List).cast<Map<String, dynamic>>();
    }
    final db = await _dbHelper.database;
    return await db.query('estado_civil', orderBy: 'id ASC');
  }

  Future<List<Map<String, dynamic>>> getRamasArtesanales() async {
    if (apiClient != null) {
      final data = await apiClient!.getCatalogos();
      return (data['ramas'] as List).cast<Map<String, dynamic>>();
    }
    final db = await _dbHelper.database;
    return await db.query('rama_artesanal', orderBy: 'id ASC');
  }

  List<String> getMunicipios() {
    return MunicipiosData.municipios;
  }

  List<String> getLocalidades(String? municipio) {
    return MunicipiosData.obtenerLocalidades(municipio);
  }

  Future<List<Artesano>> searchArtesanos({String? query, int limit = 50}) async {
    if (apiClient != null) {
      return await apiClient!.searchArtesanos(query: query ?? '', limit: limit);
    }

    final db = await _dbHelper.database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    String orderBy = 'a.id DESC';

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim();
      final idNum = int.tryParse(q);
      final pattern = '%${q.toUpperCase()}%';

      if (idNum != null) {
        whereClause += ' AND (a.id = ? OR UPPER(a.curp) LIKE ?)';
        whereArgs.addAll([idNum, pattern]);
        orderBy = '''
          CASE 
            WHEN a.id = ? THEN 0
            WHEN UPPER(a.curp) = ? THEN 1
            ELSE 2 
          END, a.id DESC
        ''';
        whereArgs.addAll([idNum, q.toUpperCase()]);
      } else {
        whereClause += ' AND UPPER(a.curp) LIKE ?';
        whereArgs.add(pattern);
        orderBy = '''
          CASE 
            WHEN UPPER(a.curp) = ? THEN 0
            ELSE 1 
          END, a.id DESC
        ''';
        whereArgs.add(q.toUpperCase());
      }
    }

    final sql = '''
      SELECT a.*,
             ic.correo, ic.telefono, ic.telefono_emergencia, ic.facebook, ic.instagram, ic.tiktok, ic.youtube, ic.x,
             r.municipio, r.localidad, r.colonia, r.calle, r.numero_exterior, r.cp,
             e.nombre as etnia_nombre, ec.nombre as estado_civil_nombre
      FROM artesano a
      LEFT JOIN info_contacto ic ON a.id_info_contacto = ic.id
      LEFT JOIN residencia r ON a.id_residencia = r.id
      LEFT JOIN etnia e ON a.id_etnia = e.id
      LEFT JOIN estado_civil ec ON a.id_estado_civil = ec.id
      WHERE $whereClause
      ORDER BY $orderBy
      LIMIT $limit
    ''';

    final results = await db.rawQuery(sql, whereArgs);
    return results.map(Artesano.fromMap).toList();
  }

  Future<Artesano?> getArtesanoByCurp(String curp) async {
    if (apiClient != null) {
      final list = await apiClient!.searchArtesanos(query: curp, limit: 1);
      return list.isNotEmpty ? list.first : null;
    }

    final db = await _dbHelper.database;

    final sql = '''
      SELECT a.*,
             ic.correo, ic.telefono, ic.telefono_emergencia, ic.facebook, ic.instagram, ic.tiktok, ic.youtube, ic.x,
             r.municipio, r.localidad, r.colonia, r.calle, r.numero_exterior, r.cp,
             e.nombre as etnia_nombre, ec.nombre as estado_civil_nombre
      FROM artesano a
      LEFT JOIN info_contacto ic ON a.id_info_contacto = ic.id
      LEFT JOIN residencia r ON a.id_residencia = r.id
      LEFT JOIN etnia e ON a.id_etnia = e.id
      LEFT JOIN estado_civil ec ON a.id_estado_civil = ec.id
      WHERE UPPER(a.curp) = ?
      LIMIT 1
    ''';

    final results = await db.rawQuery(sql, [curp.trim().toUpperCase()]);
    if (results.isEmpty) return null;
    return Artesano.fromMap(results.first);
  }

  Future<Artesano?> getArtesanoById(int id) async {
    if (apiClient != null) {
      final list = await apiClient!.searchArtesanos(query: id.toString(), limit: 1);
      return list.isNotEmpty ? list.first : null;
    }

    final db = await _dbHelper.database;

    final sql = '''
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
      LIMIT 1
    ''';

    final results = await db.rawQuery(sql, [id]);
    if (results.isEmpty) return null;
    return Artesano.fromMap(results.first);
  }

  Future<int> createArtesano(Artesano artesano) async {
    try {
      final db = await _dbHelper.database;
      return await db.transaction<int>((txn) async {
        final contactId = await txn.insert('info_contacto', artesano.toInfoContactoMap());
        final resId = await txn.insert('residencia', artesano.toResidenciaMap());

        final artMap = artesano.toTableMap(
          idInfoContacto: contactId,
          idResidencia: resId,
        );
        final id = await txn.insert('artesano', artMap);

        AppLogger.create(
          'Artesano registrado exitosamente: "${artesano.nombreCompleto}" (ID: $id, CURP: ${artesano.curp}, Municipio: ${artesano.municipio})',
          category: 'ARTESANO',
          data: {'id': id, 'curp': artesano.curp, 'nombre': artesano.nombreCompleto},
        );
        return id;
      });
    } catch (e, stack) {
      AppLogger.error(
        'Error al crear artesano "${artesano.nombreCompleto}": $e',
        category: 'ARTESANO',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> updateArtesano(Artesano artesano) async {
    if (artesano.id == null) return;
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        final existingRows = await txn.query('artesano', where: 'id = ?', whereArgs: [artesano.id]);
        if (existingRows.isEmpty) return;

        final existing = existingRows.first;
        int? contactId = existing['id_info_contacto'] as int? ?? artesano.idInfoContacto;
        int? resId = existing['id_residencia'] as int? ?? artesano.idResidencia;

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
        await txn.update('artesano', artMap, where: 'id = ?', whereArgs: [artesano.id]);
      });

      AppLogger.update(
        'Artesano actualizado: "${artesano.nombreCompleto}" (ID: ${artesano.id}, CURP: ${artesano.curp})',
        category: 'ARTESANO',
        data: {'id': artesano.id, 'curp': artesano.curp},
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error al actualizar artesano #${artesano.id}: $e',
        category: 'ARTESANO',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }
}
