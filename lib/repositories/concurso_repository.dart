import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/database/app_database.dart';
import '../core/logging/app_logger.dart';
import '../core/network/api_client.dart';
import '../models/concurso.dart';
import '../models/categoria.dart';
import '../models/subcategoria.dart';
import '../models/aportacion.dart';

class ConcursoRepository {
  final AppDatabase _dbHelper;
  final ApiClient? apiClient;

  ConcursoRepository({AppDatabase? dbHelper, this.apiClient})
      : _dbHelper = dbHelper ?? AppDatabase();

  Future<List<Map<String, dynamic>>> getTiposConcurso() async {
    if (apiClient != null) {
      final data = await apiClient!.getCatalogos();
      return (data['tipos_concurso'] as List? ?? [
        {'id': 1, 'nombre': 'Regional'},
        {'id': 2, 'nombre': 'Estatal'},
        {'id': 3, 'nombre': 'Nacional'},
      ]).cast<Map<String, dynamic>>();
    }
    final db = await _dbHelper.database;
    return await db.query('tipo_concurso', orderBy: 'id ASC');
  }

  Future<List<Concurso>> getConcursos({
    String? search,
    String? ejercicio,
    bool? finalizado,
  }) async {
    if (apiClient != null) {
      return await apiClient!.getConcursos(
        search: search,
        ejercicio: ejercicio,
        finalizado: finalizado,
      );
    }

    final db = await _dbHelper.database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (search != null && search.trim().isNotEmpty) {
      whereClause += ' AND (c.nombre LIKE ? OR c.lugar LIKE ?)';
      final queryPattern = '%${search.trim()}%';
      whereArgs.addAll([queryPattern, queryPattern]);
    }

    if (ejercicio != null && ejercicio.isNotEmpty) {
      whereClause += ' AND c.ejercicio = ?';
      whereArgs.add(ejercicio);
    }

    if (finalizado != null) {
      whereClause += ' AND c.finalizado = ?';
      whereArgs.add(finalizado ? 1 : 0);
    }

    final query = '''
      SELECT c.*, tc.nombre as tipo_concurso_nombre
      FROM concurso c
      JOIN tipo_concurso tc ON c.id_tipo_concurso = tc.id
      WHERE $whereClause
      ORDER BY c.id DESC
    ''';

    final results = await db.rawQuery(query, whereArgs);

    List<Concurso> list = [];
    for (final row in results) {
      final id = row['id'] as int;

      // Obtener aportaciones
      final aportacionesRows = await db.query(
        'aportacion_concurso',
        where: 'id_concurso = ?',
        whereArgs: [id],
      );
      final aportaciones = aportacionesRows.map(Aportacion.fromMap).toList();

      // Obtener categorías y subcategorías
      final categorias = await _getCategoriasByConcurso(db, id);

      list.add(Concurso.fromMap(
        row,
        categorias: categorias,
        aportaciones: aportaciones,
      ));
    }

    return list;
  }

  Future<Concurso?> getConcursoById(int id) async {
    if (apiClient != null) {
      return await apiClient!.getConcursoById(id);
    }

    final db = await _dbHelper.database;

    final query = '''
      SELECT c.*, tc.nombre as tipo_concurso_nombre
      FROM concurso c
      JOIN tipo_concurso tc ON c.id_tipo_concurso = tc.id
      WHERE c.id = ?
    ''';

    final results = await db.rawQuery(query, [id]);
    if (results.isEmpty) return null;

    final row = results.first;

    final aportacionesRows = await db.query(
      'aportacion_concurso',
      where: 'id_concurso = ?',
      whereArgs: [id],
    );
    final aportaciones = aportacionesRows.map(Aportacion.fromMap).toList();

    final categorias = await _getCategoriasByConcurso(db, id);

    return Concurso.fromMap(
      row,
      categorias: categorias,
      aportaciones: aportaciones,
    );
  }

  Future<List<Categoria>> _getCategoriasByConcurso(DatabaseExecutor db, int idConcurso) async {
    final catRows = await db.query(
      'categoria_concurso',
      where: 'id_concurso = ?',
      whereArgs: [idConcurso],
      orderBy: 'id ASC',
    );

    List<Categoria> categorias = [];
    for (final catRow in catRows) {
      final catId = catRow['id'] as int;
      final subRows = await db.query(
        'sub_categoria_concurso',
        where: 'id_categoria = ?',
        whereArgs: [catId],
        orderBy: 'id ASC',
      );
      final subcategorias = subRows.map(Subcategoria.fromMap).toList();

      categorias.add(Categoria.fromMap(
        catRow,
        subcategorias: subcategorias,
      ));
    }
    return categorias;
  }

  Future<int> saveConcurso(Concurso concurso) async {
    if (apiClient != null) {
      return await apiClient!.saveConcurso(concurso);
    }
    if (concurso.id == null) {
      return await createConcurso(concurso);
    } else {
      await updateConcurso(concurso);
      return concurso.id!;
    }
  }

  Future<int> createConcurso(Concurso concurso) async {
    try {
      final db = await _dbHelper.database;

      final concursoId = await db.transaction<int>((txn) async {
        // 1. Insertar el concurso
        final insertMap = concurso.toDbMap();
        final now = DateTime.now().toIso8601String();
        insertMap['created_at'] ??= now;
        insertMap['updated_at'] ??= now;
        final id = await txn.insert('concurso', insertMap);

        // 2. Insertar categorías y subcategorías
        for (final cat in concurso.categorias) {
          if (cat.nombre.trim().isEmpty) continue;
          final catMap = cat.toDbMap(overrideIdConcurso: id);
          catMap['created_at'] ??= now;
          catMap['updated_at'] ??= now;
          final catId = await txn.insert(
            'categoria_concurso',
            catMap,
          );

          for (final sub in cat.subcategorias) {
            if (sub.nombre.trim().isEmpty) continue;
            final subMap = sub.toMap(overrideIdCategoria: catId);
            subMap['created_at'] ??= now;
            subMap['updated_at'] ??= now;
            await txn.insert(
              'sub_categoria_concurso',
              subMap,
            );
          }
        }

        // 3. Insertar aportaciones multi-fila
        for (final aportacion in concurso.aportaciones) {
          if (aportacion.nombre.trim().isEmpty) continue;
          await txn.insert(
            'aportacion_concurso',
            aportacion.toMap(overrideIdConcurso: id),
          );
        }

        return id;
      });

      AppLogger.create(
        'Concurso registrado exitosamente: "${concurso.nombre}" (ID: $concursoId, Ejercicio: ${concurso.ejercicio}, Categorías: ${concurso.categorias.length}, Aportaciones: ${concurso.aportaciones.length})',
        category: 'CONCURSO',
        data: {'id': concursoId, 'nombre': concurso.nombre, 'ejercicio': concurso.ejercicio},
      );

      return concursoId;
    } catch (e, stack) {
      AppLogger.error(
        'Error al crear concurso "${concurso.nombre}": $e',
        category: 'CONCURSO',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> updateConcurso(Concurso concurso) async {
    final db = await _dbHelper.database;
    if (concurso.id == null) return;

    try {
      await db.transaction((txn) async {
        final now = DateTime.now().toIso8601String();
        final updateMap = concurso.toDbMap();
        updateMap['updated_at'] = now;
        await txn.update(
          'concurso',
          updateMap,
          where: 'id = ?',
          whereArgs: [concurso.id],
        );

        // 1. Manejo de categorías y subcategorías preservando IDs existentes
        final currentCats = await txn.query(
          'categoria_concurso',
          where: 'id_concurso = ?',
          whereArgs: [concurso.id],
        );
        final currentCatIds = currentCats.map((r) => r['id'] as int).toSet();
        final keptCatIds = <int>{};

        for (final cat in concurso.categorias) {
          if (cat.nombre.trim().isEmpty) continue;
          int catId;
          if (cat.id != null && currentCatIds.contains(cat.id)) {
            catId = cat.id!;
            keptCatIds.add(catId);
            final catMap = cat.toDbMap(overrideIdConcurso: concurso.id);
            catMap['updated_at'] = now;
            await txn.update(
              'categoria_concurso',
              catMap,
              where: 'id = ?',
              whereArgs: [catId],
            );
          } else {
            final catMap = cat.toDbMap(overrideIdConcurso: concurso.id);
            catMap['created_at'] ??= now;
            catMap['updated_at'] ??= now;
            catId = await txn.insert(
              'categoria_concurso',
              catMap,
            );
            keptCatIds.add(catId);
          }

          // Subcategorías de esta categoría
          final currentSubs = await txn.query(
            'sub_categoria_concurso',
            where: 'id_categoria = ?',
            whereArgs: [catId],
          );
          final currentSubIds = currentSubs.map((r) => r['id'] as int).toSet();
          final keptSubIds = <int>{};

          for (final sub in cat.subcategorias) {
            if (sub.nombre.trim().isEmpty) continue;
            if (sub.id != null && currentSubIds.contains(sub.id)) {
              keptSubIds.add(sub.id!);
              final subMap = sub.toMap(overrideIdCategoria: catId);
              subMap['updated_at'] = now;
              await txn.update(
                'sub_categoria_concurso',
                subMap,
                where: 'id = ?',
                whereArgs: [sub.id],
              );
            } else {
              final subMap = sub.toMap(overrideIdCategoria: catId);
              subMap['created_at'] ??= now;
              subMap['updated_at'] ??= now;
              final newSubId = await txn.insert(
                'sub_categoria_concurso',
                subMap,
              );
              keptSubIds.add(newSubId);
            }
          }

          // Eliminar subcategorías retiradas de esta categoría
          for (final oldSubId in currentSubIds) {
            if (!keptSubIds.contains(oldSubId)) {
              await txn.delete(
                'sub_categoria_concurso',
                where: 'id = ?',
                whereArgs: [oldSubId],
              );
            }
          }
        }

        // Eliminar categorías retiradas
        for (final oldCatId in currentCatIds) {
          if (!keptCatIds.contains(oldCatId)) {
            await txn.delete(
              'categoria_concurso',
              where: 'id = ?',
              whereArgs: [oldCatId],
            );
          }
        }

        // 2. Manejo de aportaciones
        final currentAports = await txn.query(
          'aportacion_concurso',
          where: 'id_concurso = ?',
          whereArgs: [concurso.id],
        );
        final currentAportIds = currentAports.map((r) => r['id'] as int).toSet();
        final keptAportIds = <int>{};

        for (final aportacion in concurso.aportaciones) {
          if (aportacion.nombre.trim().isEmpty) continue;
          if (aportacion.id != null && currentAportIds.contains(aportacion.id)) {
            keptAportIds.add(aportacion.id!);
            await txn.update(
              'aportacion_concurso',
              aportacion.toMap(overrideIdConcurso: concurso.id),
              where: 'id = ?',
              whereArgs: [aportacion.id],
            );
          } else {
            final newAportId = await txn.insert(
              'aportacion_concurso',
              aportacion.toMap(overrideIdConcurso: concurso.id),
            );
            keptAportIds.add(newAportId);
          }
        }

        for (final oldAportId in currentAportIds) {
          if (!keptAportIds.contains(oldAportId)) {
            await txn.delete(
              'aportacion_concurso',
              where: 'id = ?',
              whereArgs: [oldAportId],
            );
          }
        }
      });

      AppLogger.update(
        'Concurso actualizado: "${concurso.nombre}" (ID: ${concurso.id})',
        category: 'CONCURSO',
        data: {'id': concurso.id, 'nombre': concurso.nombre},
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error al actualizar concurso #${concurso.id}: $e',
        category: 'CONCURSO',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> setFinalizado(int id, bool finalizado) async {
    try {
      if (apiClient != null) {
        await apiClient!.setFinalizado(id, finalizado);
        AppLogger.update(
          'Estatus de concurso #$id actualizado vía API a: ${finalizado ? "FINALIZADO" : "EN PROCESO"}',
          category: 'CONCURSO',
          data: {'id': id, 'finalizado': finalizado},
        );
        return;
      }
      final db = await _dbHelper.database;
      await db.update(
        'concurso',
        {
          'finalizado': finalizado ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      AppLogger.update(
        'Concurso #$id marcado como: ${finalizado ? "FINALIZADO" : "EN PROCESO"}',
        category: 'CONCURSO',
        data: {'id': id, 'finalizado': finalizado},
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error al cambiar estado finalizado del concurso #$id: $e',
        category: 'CONCURSO',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> deleteConcurso(int id) async {
    AppLogger.warn(
      'Intento de eliminar Concurso #$id rechazado por política de integridad institucional.',
      category: 'CONCURSO',
    );
    throw UnsupportedError('No se permite eliminar concursos por integridad institucional e histórica.');
  }
}
