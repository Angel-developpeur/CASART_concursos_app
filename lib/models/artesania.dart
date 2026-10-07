class Artesania {
  final int? id;
  final String nombre;
  final double costoProduccion;
  final double costoVenta;
  final String? estado;
  final double tiempoElaboracion;
  final String plazoElaboracion; // 'dias', 'semanas', 'meses', 'anos'
  final String materialElaboracion;
  final String descripcion;
  final int idRamaArtesanal;
  final String? ramaNombre;
  final int? idImagen;
  final int? idPremio;
  final String? premioNombre;
  final int idCategoriaConcurso;
  final String? categoriaNombre;
  final int? idSubCategoriaConcurso;
  final String? subcategoriaNombre;
  final String? createdAt;
  final String? updatedAt;

  Artesania({
    this.id,
    required this.nombre,
    required this.costoProduccion,
    required this.costoVenta,
    this.estado,
    required this.tiempoElaboracion,
    required this.plazoElaboracion,
    required this.materialElaboracion,
    required this.descripcion,
    required this.idRamaArtesanal,
    this.ramaNombre,
    this.idImagen,
    this.idPremio,
    this.premioNombre,
    required this.idCategoriaConcurso,
    this.categoriaNombre,
    this.idSubCategoriaConcurso,
    this.subcategoriaNombre,
    this.createdAt,
    this.updatedAt,
  });

  /// Mapa para persistencia en tabla SQLite 'artesania_concurso'
  Map<String, dynamic> toTableMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'costo_produccion': costoProduccion,
      'costo_venta': costoVenta,
      'estado': estado,
      'tiempo_elaboracion': tiempoElaboracion,
      'plazo_elaboracion': plazoElaboracion,
      'material_elaboracion': materialElaboracion,
      'descripcion': descripcion,
      'id_rama_artesanal': idRamaArtesanal,
      'id_imagen': idImagen,
      'id_premio': idPremio,
      'id_categoria_concurso': idCategoriaConcurso,
      'id_sub_categoria_concurso': idSubCategoriaConcurso,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  /// Mapa serializado completo (para JSON de API, respaldos y clientes en red)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'costo_produccion': costoProduccion,
      'costo_venta': costoVenta,
      'estado': estado,
      'tiempo_elaboracion': tiempoElaboracion,
      'plazo_elaboracion': plazoElaboracion,
      'material_elaboracion': materialElaboracion,
      'descripcion': descripcion,
      'id_rama_artesanal': idRamaArtesanal,
      'id_imagen': idImagen,
      'id_premio': idPremio,
      'id_categoria_concurso': idCategoriaConcurso,
      'id_sub_categoria_concurso': idSubCategoriaConcurso,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      // Nombres enriquecidos para que los clientes en red conozcan el premio y catálogos
      if (ramaNombre != null) 'rama_nombre': ramaNombre,
      if (categoriaNombre != null) 'categoria_nombre': categoriaNombre,
      if (subcategoriaNombre != null) 'subcategoria_nombre': subcategoriaNombre,
      if (premioNombre != null) 'premio_nombre': premioNombre,
    };
  }


  factory Artesania.fromMap(Map<String, dynamic> map, {
    String? ramaNombre,
    String? categoriaNombre,
    String? subcategoriaNombre,
    String? premioNombre,
  }) {
    return Artesania(
      id: map['id'] as int?,
      nombre: map['nombre'] as String? ?? '',
      costoProduccion: (map['costo_produccion'] as num?)?.toDouble() ?? 0.0,
      costoVenta: (map['costo_venta'] as num?)?.toDouble() ?? 0.0,
      estado: map['estado'] as String?,
      tiempoElaboracion: (map['tiempo_elaboracion'] as num?)?.toDouble() ?? 1.0,
      plazoElaboracion: map['plazo_elaboracion'] as String? ?? 'semanas',
      materialElaboracion: map['material_elaboracion'] as String? ?? 'Varios',
      descripcion: map['descripcion'] as String? ?? '',
      idRamaArtesanal: map['id_rama_artesanal'] as int? ?? 1,
      ramaNombre: ramaNombre ?? map['rama_nombre'] as String?,
      idImagen: map['id_imagen'] is int
          ? map['id_imagen'] as int
          : int.tryParse(map['id_imagen']?.toString() ?? ''),
      idPremio: map['id_premio'] as int?,
      premioNombre: premioNombre ?? map['premio_nombre'] as String?,
      idCategoriaConcurso: map['id_categoria_concurso'] as int? ?? 1,
      categoriaNombre: categoriaNombre ?? map['categoria_nombre'] as String?,
      idSubCategoriaConcurso: map['id_sub_categoria_concurso'] as int?,
      subcategoriaNombre: subcategoriaNombre ?? map['subcategoria_nombre'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Artesania copyWith({
    int? id,
    String? nombre,
    double? costoProduccion,
    double? costoVenta,
    String? estado,
    double? tiempoElaboracion,
    String? plazoElaboracion,
    String? materialElaboracion,
    String? descripcion,
    int? idRamaArtesanal,
    String? ramaNombre,
    int? idImagen,
    int? idPremio,
    String? premioNombre,
    int? idCategoriaConcurso,
    String? categoriaNombre,
    int? idSubCategoriaConcurso,
    String? subcategoriaNombre,
    String? createdAt,
    String? updatedAt,
  }) {
    return Artesania(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      costoProduccion: costoProduccion ?? this.costoProduccion,
      costoVenta: costoVenta ?? this.costoVenta,
      estado: estado ?? this.estado,
      tiempoElaboracion: tiempoElaboracion ?? this.tiempoElaboracion,
      plazoElaboracion: plazoElaboracion ?? this.plazoElaboracion,
      materialElaboracion: materialElaboracion ?? this.materialElaboracion,
      descripcion: descripcion ?? this.descripcion,
      idRamaArtesanal: idRamaArtesanal ?? this.idRamaArtesanal,
      ramaNombre: ramaNombre ?? this.ramaNombre,
      idImagen: idImagen ?? this.idImagen,
      idPremio: idPremio ?? this.idPremio,
      premioNombre: premioNombre ?? this.premioNombre,
      idCategoriaConcurso: idCategoriaConcurso ?? this.idCategoriaConcurso,
      categoriaNombre: categoriaNombre ?? this.categoriaNombre,
      idSubCategoriaConcurso: idSubCategoriaConcurso ?? this.idSubCategoriaConcurso,
      subcategoriaNombre: subcategoriaNombre ?? this.subcategoriaNombre,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
