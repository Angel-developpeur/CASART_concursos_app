import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:casart_concursos_desktop/core/database/app_database.dart';
import 'package:casart_concursos_desktop/models/concurso.dart';
import 'package:casart_concursos_desktop/models/categoria.dart';
import 'package:casart_concursos_desktop/models/subcategoria.dart';
import 'package:casart_concursos_desktop/models/premio.dart';
import 'package:casart_concursos_desktop/repositories/concurso_repository.dart';
import 'package:casart_concursos_desktop/repositories/premio_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('updateConcurso preserves category and subcategory IDs and prevents breaking foreign keys', () async {
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
    final premioRepo = PremioRepository(dbHelper: dbHelper);

    // 1. Create initial contest with categories
    final concursoId = await concursoRepo.createConcurso(
      Concurso(
        nombre: 'Concurso Inicial',
        idTipoConcurso: 1,
        categorias: [
          Categoria(
            nombre: 'Textiles',
            subcategorias: [
              Subcategoria(nombre: 'Bordado Tradicional'),
            ],
          ),
          Categoria(
            nombre: 'Alfarería',
            subcategorias: [],
          ),
        ],
      ),
    );

    final createdConcurso = await concursoRepo.getConcursoById(concursoId);
    expect(createdConcurso, isNotNull);
    final originalCatId = createdConcurso!.categorias.first.id!;
    final originalSubId = createdConcurso.categorias.first.subcategorias.first.id!;

    // 2. Add prize linked to this category
    final premio = Premio(
      idConcurso: concursoId,
      nombre: '1er Lugar Textiles',
      monto: 5000.0,
      idTipoPremio: 3, // COMUN
      idCategoria: originalCatId,
      idSubCategoria: originalSubId,
      lugar: 1,
    );
    final premioId = await premioRepo.savePremio(premio);
    expect(premioId, isPositive);

    // 3. Update the contest (simulating editing contest in ConcursoFormDialog)
    // The category ID must be preserved so the foreign key in 'premio' does not fail
    final updatedConcurso = Concurso(
      id: concursoId,
      nombre: 'Concurso Inicial Renombrado',
      idTipoConcurso: 1,
      categorias: [
        Categoria(
          id: originalCatId,
          nombre: 'Textiles y Rebozos', // edited name
          subcategorias: [
            Subcategoria(id: originalSubId, nombre: 'Bordado Fino'), // edited name
            Subcategoria(nombre: 'Deshilado'), // newly added subcategory
          ],
        ),
        Categoria(
          nombre: 'Madera Tallada', // newly added category
          subcategorias: [],
        ),
      ],
    );

    await concursoRepo.updateConcurso(updatedConcurso);

    // 4. Verify category ID was preserved
    final reloaded = await concursoRepo.getConcursoById(concursoId);
    expect(reloaded, isNotNull);
    final reloadedCat = reloaded!.categorias.firstWhere((c) => c.nombre == 'Textiles y Rebozos');
    expect(reloadedCat.id, equals(originalCatId));
    final reloadedSub = reloadedCat.subcategorias.firstWhere((s) => s.nombre == 'Bordado Fino');
    expect(reloadedSub.id, equals(originalSubId));

    // 5. Verify the existing prize is still valid and linked to the category
    final premios = await premioRepo.getPremiosByConcurso(concursoId);
    expect(premios.length, 1);
    expect(premios.first.idCategoria, equals(originalCatId));
    expect(premios.first.categoriaNombre, 'Textiles y Rebozos');
    expect(premios.first.subcategoriaNombre, 'Bordado Fino');

    // 6. Register another prize for the newly added category
    final newCat = reloaded.categorias.firstWhere((c) => c.nombre == 'Madera Tallada');
    expect(newCat.id, isNotNull);
    final nuevoPremio = Premio(
      idConcurso: concursoId,
      nombre: '1er Lugar Madera',
      monto: 3000.0,
      idTipoPremio: 3,
      idCategoria: newCat.id,
      lugar: 1,
    );
    final nuevoPremioId = await premioRepo.savePremio(nuevoPremio);
    expect(nuevoPremioId, isPositive);

    final allPremios = await premioRepo.getPremiosByConcurso(concursoId);
    expect(allPremios.length, 2);

    await db.close();
  });
}
