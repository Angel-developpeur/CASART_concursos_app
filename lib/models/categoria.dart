import 'subcategoria.dart';

class Categoria {
  final int? id;
  final String nombre;
  final int? idConcurso;
  final bool activo;
  final String? createdAt;
  final String? updatedAt;
  final List<Subcategoria> subcategorias;

  Categoria({
    this.id,
    required this.nombre,
    this.idConcurso,
    this.activo = true,
    this.createdAt,
    this.updatedAt,
    this.subcategorias = const [],
  });

  Map<String, dynamic> toDbMap({int? overrideIdConcurso}) {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'id_concurso': overrideIdConcurso ?? idConcurso,
      'activo': activo ? 1 : 0,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  Map<String, dynamic> toMap({int? overrideIdConcurso, bool includeRelations = true}) {
    final map = toDbMap(overrideIdConcurso: overrideIdConcurso);
    if (includeRelations) {
      map['subcategorias'] = subcategorias.map((s) => s.toMap()).toList();
    }
    return map;
  }

  factory Categoria.fromMap(Map<String, dynamic> map, {List<Subcategoria>? subcategorias}) {
    List<Subcategoria> resolvedSub = subcategorias ?? [];
    if (resolvedSub.isEmpty && map['subcategorias'] is List) {
      resolvedSub = (map['subcategorias'] as List)
          .map((s) => Subcategoria.fromMap(s as Map<String, dynamic>))
          .toList();
    }
    return Categoria(
      id: map['id'] as int?,
      nombre: map['nombre'] as String? ?? '',
      idConcurso: map['id_concurso'] as int?,
      activo: (map['activo'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      subcategorias: resolvedSub,
    );
  }

  Categoria copyWith({
    int? id,
    String? nombre,
    int? idConcurso,
    bool? activo,
    String? createdAt,
    String? updatedAt,
    List<Subcategoria>? subcategorias,
  }) {
    return Categoria(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      idConcurso: idConcurso ?? this.idConcurso,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subcategorias: subcategorias ?? this.subcategorias,
    );
  }
}
