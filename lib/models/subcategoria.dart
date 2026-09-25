class Subcategoria {
  final int? id;
  final String nombre;
  final int? idCategoria;
  final bool activo;
  final String? createdAt;
  final String? updatedAt;

  Subcategoria({
    this.id,
    required this.nombre,
    this.idCategoria,
    this.activo = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap({int? overrideIdCategoria}) {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'id_categoria': overrideIdCategoria ?? idCategoria,
      'activo': activo ? 1 : 0,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  Map<String, dynamic> toDbMap({int? overrideIdCategoria}) => toMap(overrideIdCategoria: overrideIdCategoria);

  factory Subcategoria.fromMap(Map<String, dynamic> map) {
    return Subcategoria(
      id: map['id'] as int?,
      nombre: map['nombre'] as String? ?? '',
      idCategoria: map['id_categoria'] as int?,
      activo: (map['activo'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Subcategoria copyWith({
    int? id,
    String? nombre,
    int? idCategoria,
    bool? activo,
    String? createdAt,
    String? updatedAt,
  }) {
    return Subcategoria(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      idCategoria: idCategoria ?? this.idCategoria,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
