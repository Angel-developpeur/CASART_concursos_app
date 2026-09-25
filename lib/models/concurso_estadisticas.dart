import 'concurso.dart';
import 'categoria.dart';
import 'registro_concurso.dart';
import 'artesano.dart';
import 'premio.dart';

class ConcursoEstadisticas {
  final Concurso concurso;
  final int totalArtesanos;
  final int totalMunicipios;
  final int totalPiezas;
  final int totalCategorias;
  final int totalSubcategorias;
  final int totalPremios;
  final double bolsaPremios;
  final int totalHombres;
  final int totalMujeres;
  final Map<String, int> etniasConteo;
  final Map<String, int> ramasConteo;
  final Map<String, int> municipiosConteo;
  final List<Categoria> categoriasConcurso;

  const ConcursoEstadisticas({
    required this.concurso,
    required this.totalArtesanos,
    required this.totalMunicipios,
    required this.totalPiezas,
    required this.totalCategorias,
    required this.totalSubcategorias,
    required this.totalPremios,
    required this.bolsaPremios,
    required this.totalHombres,
    required this.totalMujeres,
    required this.etniasConteo,
    required this.ramasConteo,
    required this.municipiosConteo,
    required this.categoriasConcurso,
  });

  /// Realiza los cálculos y agregaciones estadísticas exactamente igual que la
  /// versión web en `routes/web.php` y `estadisticasConcurso.blade.php`.
  factory ConcursoEstadisticas.calcular({
    required Concurso concurso,
    required List<RegistroConcurso> registros,
    required List<Premio> premios,
  }) {
    // 1. Artesanos únicos participantes
    final Map<int, Artesano> artesanosMap = {};
    for (final reg in registros) {
      final art = reg.artesano;
      if (art != null) {
        final id = art.id ?? reg.idArtesano;
        artesanosMap[id] = art;
      }
    }
    final int totalArtesanos = artesanosMap.length;

    // 2. Género
    int totalHombres = 0;
    int totalMujeres = 0;
    for (final art in artesanosMap.values) {
      final g = (art.genero ?? '').trim().toUpperCase();
      if (g == 'M' || g == 'H' || g == 'MASCULINO') {
        totalHombres++;
      } else if (g == 'F' || g == 'FEMENINO') {
        totalMujeres++;
      }
    }

    // 3. Total piezas y conteo por rama artesanal
    int totalPiezas = 0;
    final Map<String, int> rawRamasConteo = {};
    for (final reg in registros) {
      for (final pieza in [reg.artesania1, reg.artesania2]) {
        if (pieza != null && pieza.nombre.trim().isNotEmpty) {
          totalPiezas++;
          String rama = (pieza.ramaNombre ?? '').trim();
          if (rama.isEmpty) {
            rama = (pieza.categoriaNombre ?? '').trim();
          }
          if (rama.isEmpty) {
            rama = 'OTRO';
          }
          rawRamasConteo[rama] = (rawRamasConteo[rama] ?? 0) + 1;
        }
      }
    }
    final ramasConteo = _sortDescending(rawRamasConteo);

    // 4. Premios configurados y bolsa de premiación
    final int totalPremios = premios.length;
    final double bolsaPremios = premios.fold(0.0, (sum, p) => sum + p.monto);

    // 5. Municipios participantes de los artesanos
    final Map<String, int> rawMunicipiosConteo = {};
    for (final art in artesanosMap.values) {
      final muni = art.municipio.trim();
      if (muni.isNotEmpty) {
        final muniNorm = _toTitleCase(muni);
        rawMunicipiosConteo[muniNorm] = (rawMunicipiosConteo[muniNorm] ?? 0) + 1;
      } else {
        rawMunicipiosConteo['Sin especificar'] =
            (rawMunicipiosConteo['Sin especificar'] ?? 0) + 1;
      }
    }
    final municipiosConteo = _sortDescending(rawMunicipiosConteo);
    final validMunicipios =
        municipiosConteo.keys.where((m) => m != 'Sin especificar').toList();
    int totalMunicipios = validMunicipios.length;
    if (totalMunicipios == 0 && municipiosConteo.isNotEmpty) {
      totalMunicipios = municipiosConteo.length;
    }

    // 6. Categorías y Subcategorías
    final categoriasConcurso = concurso.categorias;
    final int totalCategorias = categoriasConcurso.length;
    final int totalSubcategorias =
        categoriasConcurso.fold(0, (sum, c) => sum + c.subcategorias.length);

    // 7. Desglose por etnia de los artesanos
    final Map<String, int> rawEtniasConteo = {};
    for (final art in artesanosMap.values) {
      final etnia = (art.etniaNombre ?? '').trim();
      String etniaNorm;
      if (etnia.isEmpty ||
          etnia.toLowerCase() == 'ninguna' ||
          etnia.toLowerCase() == 'no aplica') {
        etniaNorm = 'Mestizo / Sin etnia';
      } else {
        etniaNorm = _toTitleCase(etnia);
      }
      rawEtniasConteo[etniaNorm] = (rawEtniasConteo[etniaNorm] ?? 0) + 1;
    }
    final etniasConteo = _sortDescending(rawEtniasConteo);

    return ConcursoEstadisticas(
      concurso: concurso,
      totalArtesanos: totalArtesanos,
      totalMunicipios: totalMunicipios,
      totalPiezas: totalPiezas,
      totalCategorias: totalCategorias,
      totalSubcategorias: totalSubcategorias,
      totalPremios: totalPremios,
      bolsaPremios: bolsaPremios,
      totalHombres: totalHombres,
      totalMujeres: totalMujeres,
      etniasConteo: etniasConteo,
      ramasConteo: ramasConteo,
      municipiosConteo: municipiosConteo,
      categoriasConcurso: categoriasConcurso,
    );
  }

  static Map<String, int> _sortDescending(Map<String, int> map) {
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries);
  }

  static String _toTitleCase(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      final lower = word.toLowerCase();
      return lower[0].toUpperCase() + lower.substring(1);
    }).join(' ');
  }
}
