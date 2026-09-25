class InfoContacto {
  final int? id;
  final String? correo;
  final String? telefono;
  final String? telefonoEmergencia;
  final String? facebook;
  final String? instagram;
  final String? tiktok;
  final String? youtube;
  final String? x;
  final String? createdAt;
  final String? updatedAt;

  InfoContacto({
    this.id,
    this.correo,
    this.telefono,
    this.telefonoEmergencia,
    this.facebook,
    this.instagram,
    this.tiktok,
    this.youtube,
    this.x,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'correo': correo,
      'telefono': telefono,
      'telefono_emergencia': telefonoEmergencia,
      'facebook': facebook,
      'instagram': instagram,
      'tiktok': tiktok,
      'youtube': youtube,
      'x': x,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  factory InfoContacto.fromMap(Map<String, dynamic> map) {
    return InfoContacto(
      id: map['id'] as int?,
      correo: (map['correo'] ?? map['correo_electronico']) as String?,
      telefono: map['telefono'] as String?,
      telefonoEmergencia: map['telefono_emergencia'] as String?,
      facebook: map['facebook'] as String?,
      instagram: map['instagram'] as String?,
      tiktok: map['tiktok'] as String?,
      youtube: map['youtube'] as String?,
      x: map['x'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  InfoContacto copyWith({
    int? id,
    String? correo,
    String? telefono,
    String? telefonoEmergencia,
    String? facebook,
    String? instagram,
    String? tiktok,
    String? youtube,
    String? x,
    String? createdAt,
    String? updatedAt,
  }) {
    return InfoContacto(
      id: id ?? this.id,
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
      telefonoEmergencia: telefonoEmergencia ?? this.telefonoEmergencia,
      facebook: facebook ?? this.facebook,
      instagram: instagram ?? this.instagram,
      tiktok: tiktok ?? this.tiktok,
      youtube: youtube ?? this.youtube,
      x: x ?? this.x,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
