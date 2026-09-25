class TipoConcurso {
  final int? id;
  final String nombre;
  final String? createdAt;
  final String? updatedAt;

  TipoConcurso({
    this.id,
    required this.nombre,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  Map<String, dynamic> toDbMap() => toMap();

  factory TipoConcurso.fromMap(Map<String, dynamic> map) {
    return TipoConcurso(
      id: map['id'] as int?,
      nombre: map['nombre'] as String? ?? '',
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  TipoConcurso copyWith({
    int? id,
    String? nombre,
    String? createdAt,
    String? updatedAt,
  }) {
    return TipoConcurso(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TipoConcurso &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nombre == other.nombre;

  @override
  int get hashCode => id.hashCode ^ nombre.hashCode;
}
