class Artesano {
  final int? id;
  final String nombre;
  final String apPaterno;
  final String? apMaterno;
  final String curp;
  final String? rfc;
  final String? fechaNacimiento;
  final String? genero;
  final bool finado;
  final String? maxNivelAcademico;
  final int? idImagen;
  final int? idEtnia;
  final int? idInfoContacto;
  final int? idInfoSocioeconomica;
  final int? idInfoEspacioProduccion;
  final int? idInfoArtesanal;
  final int? idMateriasPrimas;
  final int? idProductosPrincipales;
  final int? idCanalesVenta;
  final int? idResidencia;
  final int? idProblemasSalud;
  final int? idEstadoCivil;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;
  final int? createdBy;
  final int? idFirma;
  final String? numeroIne;
  final String area;
  final bool verificado;

  // Atributos de info_contacto
  final String? correo;
  final String? telefono;
  final String? telefonoEmergencia;
  final String? facebook;
  final String? instagram;
  final String? tiktok;
  final String? youtube;
  final String? x;

  // Atributos de residencia
  final String municipio;
  final String localidad;
  final String? colonia;
  final String? calle;
  final String? numeroExterior;
  final String? cp;

  // Catálogos vinculados
  final String? etniaNombre;
  final String? estadoCivilNombre;

  Artesano({
    this.id,
    required this.nombre,
    required this.apPaterno,
    this.apMaterno,
    required this.curp,
    this.rfc,
    this.fechaNacimiento,
    this.genero,
    this.finado = false,
    String? maxNivelAcademico,
    String? nivelEducativo,
    this.idImagen,
    this.idEtnia,
    this.idInfoContacto,
    this.idInfoSocioeconomica,
    this.idInfoEspacioProduccion,
    this.idInfoArtesanal,
    this.idMateriasPrimas,
    this.idProductosPrincipales,
    this.idCanalesVenta,
    this.idResidencia,
    this.idProblemasSalud,
    this.idEstadoCivil,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.createdBy,
    this.idFirma,
    this.numeroIne,
    this.area = 'concursos',
    this.verificado = false,
    String? correo,
    String? correoElectronico,
    this.telefono,
    this.telefonoEmergencia,
    this.facebook,
    this.instagram,
    this.tiktok,
    this.youtube,
    this.x,
    required this.municipio,
    required this.localidad,
    this.colonia,
    this.calle,
    this.numeroExterior,
    String? cp,
    String? codigoPostal,
    this.etniaNombre,
    this.estadoCivilNombre,
  })  : maxNivelAcademico = maxNivelAcademico ?? nivelEducativo,
        correo = correo ?? correoElectronico,
        cp = cp ?? codigoPostal;

  // Getters de retrocompatibilidad
  String? get nivelEducativo => maxNivelAcademico;
  String? get correoElectronico => correo;
  String? get codigoPostal => cp;

  String get nombreCompleto {
    final apM = (apMaterno != null && apMaterno!.trim().isNotEmpty) ? ' $apMaterno' : '';
    return '$nombre $apPaterno$apM'.trim();
  }

  String get direccionCompleta {
    final partes = [
      if (calle != null && calle!.isNotEmpty) 'Calle $calle',
      if (numeroExterior != null && numeroExterior!.isNotEmpty) '#$numeroExterior',
      if (colonia != null && colonia!.isNotEmpty) 'Col. $colonia',
      if (cp != null && cp!.isNotEmpty) 'C.P. $cp',
      '$localidad, $municipio, Michoacán',
    ];
    return partes.join(', ');
  }

  String? get generoDescripcion {
    switch (genero?.toUpperCase()) {
      case 'M':
        return 'Hombre (M)';
      case 'F':
        return 'Mujer (F)';
      case 'O':
        return 'Otro (O)';
      default:
        return genero;
    }
  }

  /// Retorna un mapa exclusivo con las columnas de la tabla SQLite `artesano`
  Map<String, dynamic> toTableMap({
    int? idInfoContacto,
    int? idResidencia,
  }) {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'ap_paterno': apPaterno,
      'ap_materno': apMaterno,
      'curp': curp.toUpperCase(),
      'rfc': rfc?.toUpperCase(),
      'fecha_nacimiento': fechaNacimiento,
      'genero': genero,
      'finado': finado ? 1 : 0,
      'max_nivel_academico': maxNivelAcademico ?? '0',
      'id_imagen': idImagen,
      'id_etnia': idEtnia,
      'id_info_contacto': idInfoContacto ?? this.idInfoContacto,
      'id_info_socioeconomica': idInfoSocioeconomica,
      'id_info_espacio_produccion': idInfoEspacioProduccion,
      'id_info_artesanal': idInfoArtesanal,
      'id_materias_primas': idMateriasPrimas,
      'id_productos_principales': idProductosPrincipales,
      'id_canales_venta': idCanalesVenta,
      'id_residencia': idResidencia ?? this.idResidencia,
      'id_problemas_salud': idProblemasSalud,
      'id_estado_civil': idEstadoCivil,
      if (createdAt != null) 'created_at': createdAt,
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
      'deleted_at': deletedAt,
      'created_by': createdBy,
      'id_firma': idFirma,
      'numero_ine': numeroIne,
      'area': area,
      'verificado': verificado ? 1 : 0,
    };
  }

  /// Retorna mapa para la tabla SQLite `info_contacto`
  Map<String, dynamic> toInfoContactoMap() {
    return {
      'correo': correo,
      'telefono': telefono,
      'telefono_emergencia': telefonoEmergencia,
      'facebook': facebook,
      'instagram': instagram,
      'tiktok': tiktok,
      'youtube': youtube,
      'x': x,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  /// Retorna mapa para la tabla SQLite `residencia`
  Map<String, dynamic> toResidenciaMap() {
    return {
      'municipio': municipio,
      'localidad': localidad,
      'colonia': colonia,
      'calle': calle,
      'numero_exterior': numeroExterior,
      'cp': cp,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  /// Mapa serializado completo (para JSON API y respaldos)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'ap_paterno': apPaterno,
      'ap_materno': apMaterno,
      'curp': curp.toUpperCase(),
      'rfc': rfc?.toUpperCase(),
      'fecha_nacimiento': fechaNacimiento,
      'genero': genero,
      'finado': finado ? 1 : 0,
      'max_nivel_academico': maxNivelAcademico,
      'nivel_educativo': maxNivelAcademico,
      'id_imagen': idImagen,
      'id_etnia': idEtnia,
      'id_info_contacto': idInfoContacto,
      'id_info_socioeconomica': idInfoSocioeconomica,
      'id_info_espacio_produccion': idInfoEspacioProduccion,
      'id_info_artesanal': idInfoArtesanal,
      'id_materias_primas': idMateriasPrimas,
      'id_productos_principales': idProductosPrincipales,
      'id_canales_venta': idCanalesVenta,
      'id_residencia': idResidencia,
      'id_problemas_salud': idProblemasSalud,
      'id_estado_civil': idEstadoCivil,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
      'created_by': createdBy,
      'id_firma': idFirma,
      'numero_ine': numeroIne,
      'area': area,
      'verificado': verificado ? 1 : 0,

      // Datos de contacto
      'correo': correo,
      'correo_electronico': correo,
      'telefono': telefono,
      'telefono_emergencia': telefonoEmergencia,
      'facebook': facebook,
      'instagram': instagram,
      'tiktok': tiktok,
      'youtube': youtube,
      'x': x,

      // Datos de residencia
      'municipio': municipio,
      'localidad': localidad,
      'colonia': colonia,
      'calle': calle,
      'numero_exterior': numeroExterior,
      'cp': cp,
      'codigo_postal': cp,

      // Catálogos
      if (etniaNombre != null) 'etnia_nombre': etniaNombre,
      if (estadoCivilNombre != null) 'estado_civil_nombre': estadoCivilNombre,
    };
  }

  factory Artesano.fromMap(
    Map<String, dynamic> map, {
    String? etniaNombre,
    String? estadoCivilNombre,
  }) {
    // Soportar tanto mapas planos con joins como objetos anidados
    final infoContactoMap = map['info_contacto'] is Map<String, dynamic>
        ? map['info_contacto'] as Map<String, dynamic>
        : null;
    final residenciaMap = map['residencia'] is Map<String, dynamic>
        ? map['residencia'] as Map<String, dynamic>
        : null;

    final finadoVal = map['finado'];
    final esFinado = finadoVal == 1 || finadoVal == true || finadoVal == '1';

    final verificadoVal = map['verificado'];
    final esVerificado = verificadoVal == 1 || verificadoVal == true || verificadoVal == '1';

    return Artesano(
      id: map['id'] as int?,
      nombre: (map['nombre'] as String?) ?? '',
      apPaterno: (map['ap_paterno'] as String?) ?? '',
      apMaterno: map['ap_materno'] as String?,
      curp: (map['curp'] as String?) ?? '',
      rfc: map['rfc'] as String?,
      fechaNacimiento: map['fecha_nacimiento'] as String?,
      genero: map['genero'] as String?,
      finado: esFinado,
      maxNivelAcademico: (map['max_nivel_academico'] ?? map['nivel_educativo'])?.toString(),
      idImagen: map['id_imagen'] as int?,
      idEtnia: map['id_etnia'] as int?,
      idInfoContacto: map['id_info_contacto'] as int?,
      idInfoSocioeconomica: map['id_info_socioeconomica'] as int?,
      idInfoEspacioProduccion: map['id_info_espacio_produccion'] as int?,
      idInfoArtesanal: map['id_info_artesanal'] as int?,
      idMateriasPrimas: map['id_materias_primas'] as int?,
      idProductosPrincipales: map['id_productos_principales'] as int?,
      idCanalesVenta: map['id_canales_venta'] as int?,
      idResidencia: map['id_residencia'] as int?,
      idProblemasSalud: map['id_problemas_salud'] as int?,
      idEstadoCivil: map['id_estado_civil'] as int?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      deletedAt: map['deleted_at'] as String?,
      createdBy: map['created_by'] as int?,
      idFirma: map['id_firma'] as int?,
      numeroIne: map['numero_ine'] as String?,
      area: (map['area'] as String?) ?? 'concursos',
      verificado: esVerificado,

      // Contacto
      correo: (infoContactoMap?['correo'] ?? map['correo'] ?? map['correo_electronico']) as String?,
      telefono: (infoContactoMap?['telefono'] ?? map['telefono']) as String?,
      telefonoEmergencia: (infoContactoMap?['telefono_emergencia'] ?? map['telefono_emergencia']) as String?,
      facebook: (infoContactoMap?['facebook'] ?? map['facebook']) as String?,
      instagram: (infoContactoMap?['instagram'] ?? map['instagram']) as String?,
      tiktok: (infoContactoMap?['tiktok'] ?? map['tiktok']) as String?,
      youtube: (infoContactoMap?['youtube'] ?? map['youtube']) as String?,
      x: (infoContactoMap?['x'] ?? map['x']) as String?,

      // Residencia
      municipio: (residenciaMap?['municipio'] ?? map['municipio'] as String?) ?? '',
      localidad: (residenciaMap?['localidad'] ?? map['localidad'] as String?) ?? '',
      colonia: (residenciaMap?['colonia'] ?? map['colonia']) as String?,
      calle: (residenciaMap?['calle'] ?? map['calle']) as String?,
      numeroExterior: (residenciaMap?['numero_exterior'] ?? map['numero_exterior']) as String?,
      cp: (residenciaMap?['cp'] ?? map['cp'] ?? map['codigo_postal']) as String?,

      // Etiquetas de catálogos
      etniaNombre: etniaNombre ?? map['etnia_nombre'] as String?,
      estadoCivilNombre: estadoCivilNombre ?? map['estado_civil_nombre'] as String?,
    );
  }

  Artesano copyWith({
    int? id,
    String? nombre,
    String? apPaterno,
    String? apMaterno,
    String? curp,
    String? rfc,
    String? fechaNacimiento,
    String? genero,
    bool? finado,
    String? maxNivelAcademico,
    String? nivelEducativo,
    int? idImagen,
    int? idEtnia,
    int? idInfoContacto,
    int? idInfoSocioeconomica,
    int? idInfoEspacioProduccion,
    int? idInfoArtesanal,
    int? idMateriasPrimas,
    int? idProductosPrincipales,
    int? idCanalesVenta,
    int? idResidencia,
    int? idProblemasSalud,
    int? idEstadoCivil,
    String? createdAt,
    String? updatedAt,
    String? deletedAt,
    int? createdBy,
    int? idFirma,
    String? numeroIne,
    String? area,
    bool? verificado,
    String? correo,
    String? correoElectronico,
    String? telefono,
    String? telefonoEmergencia,
    String? facebook,
    String? instagram,
    String? tiktok,
    String? youtube,
    String? x,
    String? municipio,
    String? localidad,
    String? colonia,
    String? calle,
    String? numeroExterior,
    String? cp,
    String? codigoPostal,
    String? etniaNombre,
    String? estadoCivilNombre,
  }) {
    return Artesano(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      apPaterno: apPaterno ?? this.apPaterno,
      apMaterno: apMaterno ?? this.apMaterno,
      curp: curp ?? this.curp,
      rfc: rfc ?? this.rfc,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      genero: genero ?? this.genero,
      finado: finado ?? this.finado,
      maxNivelAcademico: maxNivelAcademico ?? nivelEducativo ?? this.maxNivelAcademico,
      idImagen: idImagen ?? this.idImagen,
      idEtnia: idEtnia ?? this.idEtnia,
      idInfoContacto: idInfoContacto ?? this.idInfoContacto,
      idInfoSocioeconomica: idInfoSocioeconomica ?? this.idInfoSocioeconomica,
      idInfoEspacioProduccion: idInfoEspacioProduccion ?? this.idInfoEspacioProduccion,
      idInfoArtesanal: idInfoArtesanal ?? this.idInfoArtesanal,
      idMateriasPrimas: idMateriasPrimas ?? this.idMateriasPrimas,
      idProductosPrincipales: idProductosPrincipales ?? this.idProductosPrincipales,
      idCanalesVenta: idCanalesVenta ?? this.idCanalesVenta,
      idResidencia: idResidencia ?? this.idResidencia,
      idProblemasSalud: idProblemasSalud ?? this.idProblemasSalud,
      idEstadoCivil: idEstadoCivil ?? this.idEstadoCivil,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      createdBy: createdBy ?? this.createdBy,
      idFirma: idFirma ?? this.idFirma,
      numeroIne: numeroIne ?? this.numeroIne,
      area: area ?? this.area,
      verificado: verificado ?? this.verificado,
      correo: correo ?? correoElectronico ?? this.correo,
      telefono: telefono ?? this.telefono,
      telefonoEmergencia: telefonoEmergencia ?? this.telefonoEmergencia,
      facebook: facebook ?? this.facebook,
      instagram: instagram ?? this.instagram,
      tiktok: tiktok ?? this.tiktok,
      youtube: youtube ?? this.youtube,
      x: x ?? this.x,
      municipio: municipio ?? this.municipio,
      localidad: localidad ?? this.localidad,
      colonia: colonia ?? this.colonia,
      calle: calle ?? this.calle,
      numeroExterior: numeroExterior ?? this.numeroExterior,
      cp: cp ?? codigoPostal ?? this.cp,
      etniaNombre: etniaNombre ?? this.etniaNombre,
      estadoCivilNombre: estadoCivilNombre ?? this.estadoCivilNombre,
    );
  }
}
