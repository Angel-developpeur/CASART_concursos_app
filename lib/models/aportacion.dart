class Aportacion {
  final int? id;
  final String nombre;
  final double cantidad;
  final int? idConcurso;
  final String? createdAt;
  final String? updatedAt;

  Aportacion({
    this.id,
    required this.nombre,
    required this.cantidad,
    this.idConcurso,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap({int? overrideIdConcurso}) {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'cantidad': cantidad,
      'id_concurso': overrideIdConcurso ?? idConcurso,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  factory Aportacion.fromMap(Map<String, dynamic> map) {
    return Aportacion(
      id: map['id'] as int?,
      nombre: map['nombre'] as String? ?? '',
      cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0.0,
      idConcurso: map['id_concurso'] as int?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Aportacion copyWith({
    int? id,
    String? nombre,
    double? cantidad,
    int? idConcurso,
    String? createdAt,
    String? updatedAt,
  }) {
    return Aportacion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      cantidad: cantidad ?? this.cantidad,
      idConcurso: idConcurso ?? this.idConcurso,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

