import 'categoria.dart';
import 'aportacion.dart';

class Concurso {
  final int? id;
  final String nombre;
  final String? fechaInicioRegistro;
  final String? fechaLimiteRegistro;
  final bool finalizado;
  final String ejercicio;
  final String? lugar;
  final String? fechaDictamen;
  final String? fechaPremiacion;
  final int idTipoConcurso;
  final String? tipoConcursoNombre;
  final int iva;
  final double utilidad;
  final String? createdAt;
  final String? updatedAt;
  final List<Categoria> categorias;
  final List<Aportacion> aportaciones;

  Concurso({
    this.id,
    required this.nombre,
    this.fechaInicioRegistro,
    this.fechaLimiteRegistro,
    this.finalizado = false,
    String? ejercicio,
    this.lugar,
    this.fechaDictamen,
    this.fechaPremiacion,
    required this.idTipoConcurso,
    this.tipoConcursoNombre,
    num iva = 16,
    this.utilidad = 0.0,
    this.createdAt,
    this.updatedAt,
    this.categorias = const [],
    this.aportaciones = const [],
  })  : ejercicio = ejercicio ?? DateTime.now().year.toString(),
        iva = iva.toInt();

  double get totalAportaciones =>
      aportaciones.fold(0.0, (sum, a) => sum + a.cantidad);

  /// Genera un Map para base de datos con las mismas columnas, tipos y orden
  /// de la migración oficial de Laravel en tabla 'concurso'.
  Map<String, dynamic> toDbMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'fecha_inicio_registro': fechaInicioRegistro,
      'fecha_limite_registro': fechaLimiteRegistro,
      'finalizado': finalizado ? 1 : 0,
      'ejercicio': ejercicio,
      'lugar': lugar,
      'fecha_dictamen': fechaDictamen,
      'fecha_premiacion': fechaPremiacion,
      'id_tipo_concurso': idTipoConcurso,
      'iva': iva,
      'utilidad': utilidad,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  Map<String, dynamic> toMap({bool includeRelations = true}) {
    final map = toDbMap();
    if (includeRelations) {
      map['categorias'] = categorias.map((c) => c.toMap(includeRelations: true)).toList();
      map['aportaciones'] = aportaciones.map((a) => a.toMap()).toList();
      if (tipoConcursoNombre != null) map['tipo_concurso_nombre'] = tipoConcursoNombre;
    }
    return map;
  }

  factory Concurso.fromMap(Map<String, dynamic> map, {
    List<Categoria>? categorias,
    List<Aportacion>? aportaciones,
    String? tipoConcursoNombre,
  }) {
    List<Categoria> resolvedCategorias = categorias ?? [];
    if (resolvedCategorias.isEmpty && map['categorias'] is List) {
      resolvedCategorias = (map['categorias'] as List)
          .map((m) => Categoria.fromMap(m as Map<String, dynamic>))
          .toList();
    }

    List<Aportacion> resolvedAportaciones = aportaciones ?? [];
    if (resolvedAportaciones.isEmpty && map['aportaciones'] is List) {
      resolvedAportaciones = (map['aportaciones'] as List)
          .map((m) => Aportacion.fromMap(m as Map<String, dynamic>))
          .toList();
    }

    return Concurso(
      id: map['id'] as int?,
      nombre: map['nombre'] as String? ?? '',
      fechaInicioRegistro: map['fecha_inicio_registro'] as String?,
      fechaLimiteRegistro: map['fecha_limite_registro'] as String?,
      finalizado: map['finalizado'] == 1 || map['finalizado'] == true || map['finalizado'] == '1',
      ejercicio: map['ejercicio']?.toString() ?? DateTime.now().year.toString(),
      lugar: map['lugar'] as String?,
      fechaDictamen: map['fecha_dictamen'] as String?,
      fechaPremiacion: map['fecha_premiacion'] as String?,
      idTipoConcurso: map['id_tipo_concurso'] as int? ?? 1,
      tipoConcursoNombre: tipoConcursoNombre ?? map['tipo_concurso_nombre'] as String?,
      iva: (map['iva'] as num?)?.toInt() ?? 16,
      utilidad: (map['utilidad'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      categorias: resolvedCategorias,
      aportaciones: resolvedAportaciones,
    );
  }

  Concurso copyWith({
    int? id,
    String? nombre,
    String? fechaInicioRegistro,
    String? fechaLimiteRegistro,
    bool? finalizado,
    String? ejercicio,
    String? lugar,
    String? fechaDictamen,
    String? fechaPremiacion,
    int? idTipoConcurso,
    String? tipoConcursoNombre,
    num? iva,
    double? utilidad,
    String? createdAt,
    String? updatedAt,
    List<Categoria>? categorias,
    List<Aportacion>? aportaciones,
  }) {
    return Concurso(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      fechaInicioRegistro: fechaInicioRegistro ?? this.fechaInicioRegistro,
      fechaLimiteRegistro: fechaLimiteRegistro ?? this.fechaLimiteRegistro,
      finalizado: finalizado ?? this.finalizado,
      ejercicio: ejercicio ?? this.ejercicio,
      lugar: lugar ?? this.lugar,
      fechaDictamen: fechaDictamen ?? this.fechaDictamen,
      fechaPremiacion: fechaPremiacion ?? this.fechaPremiacion,
      idTipoConcurso: idTipoConcurso ?? this.idTipoConcurso,
      tipoConcursoNombre: tipoConcursoNombre ?? this.tipoConcursoNombre,
      iva: iva ?? this.iva,
      utilidad: utilidad ?? this.utilidad,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categorias: categorias ?? this.categorias,
      aportaciones: aportaciones ?? this.aportaciones,
    );
  }
}
