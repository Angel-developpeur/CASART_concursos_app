class Premio {
  final int? id;
  final int? idCategoria;
  final int idConcurso;
  final int? idTipoPremio;
  final int? idSubCategoria;
  final String nombre;
  final double monto;
  final int? lugar;
  final int limiteOtorgacion;
  final bool activo;
  final String? createdAt;
  final String? updatedAt;
  final String? categoriaNombre;
  final String? subcategoriaNombre;
  final String? tipoPremioNombre;

  Premio({
    this.id,
    this.idCategoria,
    required this.idConcurso,
    this.idTipoPremio = 1,
    this.idSubCategoria,
    required this.nombre,
    required this.monto,
    this.lugar,
    this.limiteOtorgacion = 1,
    this.activo = true,
    this.createdAt,
    this.updatedAt,
    this.categoriaNombre,
    this.subcategoriaNombre,
    this.tipoPremioNombre,
  });

  /// Genera un Map para base de datos con las mismas columnas, tipos y orden
  /// de la migración oficial de Laravel en tabla 'premio'.
  Map<String, dynamic> toDbMap() {
    return {
      if (id != null) 'id': id,
      'id_categoria': idCategoria,
      'id_concurso': idConcurso,
      'id_tipo_premio': idTipoPremio ?? 1,
      'id_sub_categoria': idSubCategoria,
      'nombre': nombre,
      'monto': monto.round(),
      'lugar': lugar,
      'limite_otorgacion': limiteOtorgacion,
      'activo': activo ? 1 : 0,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  Map<String, dynamic> toMap() => toDbMap();

  factory Premio.fromMap(Map<String, dynamic> map, {
    String? categoriaNombre,
    String? subcategoriaNombre,
    String? tipoPremioNombre,
  }) {
    return Premio(
      id: map['id'] as int?,
      idCategoria: map['id_categoria'] as int?,
      idConcurso: map['id_concurso'] as int? ?? 0,
      idTipoPremio: map['id_tipo_premio'] as int?,
      idSubCategoria: map['id_sub_categoria'] as int?,
      nombre: map['nombre'] as String? ?? '',
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      lugar: map['lugar'] as int?,
      limiteOtorgacion: map['limite_otorgacion'] as int? ?? 1,
      activo: map['activo'] == 1 || map['activo'] == true || map['activo'] == '1',
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      categoriaNombre: categoriaNombre ?? map['categoria_nombre'] as String?,
      subcategoriaNombre: subcategoriaNombre ?? map['subcategoria_nombre'] as String?,
      tipoPremioNombre: tipoPremioNombre ?? map['tipo_premio_nombre'] as String?,
    );
  }

  Premio copyWith({
    int? id,
    int? idCategoria,
    int? idConcurso,
    int? idTipoPremio,
    int? idSubCategoria,
    String? nombre,
    double? monto,
    int? lugar,
    int? limiteOtorgacion,
    bool? activo,
    String? createdAt,
    String? updatedAt,
    String? categoriaNombre,
    String? subcategoriaNombre,
    String? tipoPremioNombre,
  }) {
    return Premio(
      id: id ?? this.id,
      idCategoria: idCategoria ?? this.idCategoria,
      idConcurso: idConcurso ?? this.idConcurso,
      idTipoPremio: idTipoPremio ?? this.idTipoPremio,
      idSubCategoria: idSubCategoria ?? this.idSubCategoria,
      nombre: nombre ?? this.nombre,
      monto: monto ?? this.monto,
      lugar: lugar ?? this.lugar,
      limiteOtorgacion: limiteOtorgacion ?? this.limiteOtorgacion,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categoriaNombre: categoriaNombre ?? this.categoriaNombre,
      subcategoriaNombre: subcategoriaNombre ?? this.subcategoriaNombre,
      tipoPremioNombre: tipoPremioNombre ?? this.tipoPremioNombre,
    );
  }
}
