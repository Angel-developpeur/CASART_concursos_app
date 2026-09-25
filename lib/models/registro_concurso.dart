import 'artesano.dart';
import 'artesania.dart';
import 'concurso.dart';

class RegistroConcurso {
  final int? id;
  final int folio;
  final int idArtesano;
  final int idConcurso;
  final int idArtesania1;
  final int? idArtesania2;
  final String? createdAt;
  final String? updatedAt;

  final Artesano? artesano;
  final Artesania? artesania1;
  final Artesania? artesania2;
  final Concurso? concurso;

  RegistroConcurso({
    this.id,
    required this.folio,
    required this.idArtesano,
    required this.idConcurso,
    required this.idArtesania1,
    this.idArtesania2,
    this.createdAt,
    this.updatedAt,
    this.artesano,
    this.artesania1,
    this.artesania2,
    this.concurso,
  });

  Map<String, dynamic> toDbMap() {
    return {
      if (id != null) 'id': id,
      'folio': folio,
      'id_artesano': idArtesano,
      'id_concurso': idConcurso,
      'id_artesania_1': idArtesania1,
      'id_artesania_2': idArtesania2,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  Map<String, dynamic> toMap() => toDbMap();

  factory RegistroConcurso.fromMap(Map<String, dynamic> map, {
    Artesano? artesano,
    Artesania? artesania1,
    Artesania? artesania2,
    Concurso? concurso,
  }) {
    return RegistroConcurso(
      id: map['id'] as int?,
      folio: map['folio'] as int? ?? 1,
      idArtesano: map['id_artesano'] as int? ?? 0,
      idConcurso: map['id_concurso'] as int? ?? 0,
      idArtesania1: map['id_artesania_1'] as int? ?? 0,
      idArtesania2: map['id_artesania_2'] as int?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      artesano: artesano,
      artesania1: artesania1,
      artesania2: artesania2,
      concurso: concurso,
    );
  }

  RegistroConcurso copyWith({
    int? id,
    int? folio,
    int? idArtesano,
    int? idConcurso,
    int? idArtesania1,
    int? idArtesania2,
    String? createdAt,
    String? updatedAt,
    Artesano? artesano,
    Artesania? artesania1,
    Artesania? artesania2,
    Concurso? concurso,
  }) {
    return RegistroConcurso(
      id: id ?? this.id,
      folio: folio ?? this.folio,
      idArtesano: idArtesano ?? this.idArtesano,
      idConcurso: idConcurso ?? this.idConcurso,
      idArtesania1: idArtesania1 ?? this.idArtesania1,
      idArtesania2: idArtesania2 ?? this.idArtesania2,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      artesano: artesano ?? this.artesano,
      artesania1: artesania1 ?? this.artesania1,
      artesania2: artesania2 ?? this.artesania2,
      concurso: concurso ?? this.concurso,
    );
  }
}
