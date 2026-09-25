class Residencia {
  final int? id;
  final String municipio;
  final String localidad;
  final String? colonia;
  final String? calle;
  final String? numeroExterior;
  final String? cp;
  final String? createdAt;
  final String? updatedAt;

  Residencia({
    this.id,
    required this.municipio,
    required this.localidad,
    this.colonia,
    this.calle,
    this.numeroExterior,
    this.cp,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'municipio': municipio,
      'localidad': localidad,
      'colonia': colonia,
      'calle': calle,
      'numero_exterior': numeroExterior,
      'cp': cp,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  factory Residencia.fromMap(Map<String, dynamic> map) {
    return Residencia(
      id: map['id'] as int?,
      municipio: (map['municipio'] as String?) ?? '',
      localidad: (map['localidad'] as String?) ?? '',
      colonia: map['colonia'] as String?,
      calle: map['calle'] as String?,
      numeroExterior: map['numero_exterior'] as String?,
      cp: (map['cp'] ?? map['codigo_postal']) as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Residencia copyWith({
    int? id,
    String? municipio,
    String? localidad,
    String? colonia,
    String? calle,
    String? numeroExterior,
    String? cp,
    String? createdAt,
    String? updatedAt,
  }) {
    return Residencia(
      id: id ?? this.id,
      municipio: municipio ?? this.municipio,
      localidad: localidad ?? this.localidad,
      colonia: colonia ?? this.colonia,
      calle: calle ?? this.calle,
      numeroExterior: numeroExterior ?? this.numeroExterior,
      cp: cp ?? this.cp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
