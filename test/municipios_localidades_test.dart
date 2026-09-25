import 'package:flutter_test/flutter_test.dart';
import 'package:casart_concursos_desktop/core/data/municipios_data.dart';
import 'package:casart_concursos_desktop/repositories/artesano_repository.dart';

void main() {
  group('MunicipiosData y Selectores Dependientes de Localidad', () {
    test('Contiene los 113 municipios oficiales de Michoacán', () {
      expect(MunicipiosData.municipios.length, equals(113));
      expect(MunicipiosData.municipios, contains('Morelia zona (I)'));
      expect(MunicipiosData.municipios, contains('Patzcuaro zona (I)'));
      expect(MunicipiosData.municipios, contains('Uruapan zona (II)'));
      expect(MunicipiosData.municipios, contains('Tepalcatepec'));
      expect(MunicipiosData.municipios, contains('Ziracuaretiro zona (I)'));
    });

    test('ArtesanoRepository expone getMunicipios y getLocalidades', () {
      final repo = ArtesanoRepository();
      final municipios = repo.getMunicipios();
      expect(municipios.length, equals(113));

      final locsMorelia = repo.getLocalidades('Morelia zona (I)');
      expect(locsMorelia, isNotEmpty);
      expect(locsMorelia, contains('Capula'));
    });

    test('obtenerLocalidades devuelve localidades correctas y sin duplicados por municipio', () {
      final locsMorelia = MunicipiosData.obtenerLocalidades('Morelia zona (I)');
      expect(locsMorelia.length, greaterThan(300));
      expect(locsMorelia.toSet().length, equals(locsMorelia.length)); // Sin duplicados
      expect(locsMorelia, contains('Capula'));
      expect(locsMorelia, contains('San Nicolás Obispo'));
      expect(locsMorelia, contains('Tiripetío'));

      final locsPatzcuaro = MunicipiosData.obtenerLocalidades('Patzcuaro zona (I)');
      expect(locsPatzcuaro.length, greaterThan(50));
      expect(locsPatzcuaro.toSet().length, equals(locsPatzcuaro.length)); // Sin duplicados
      expect(locsPatzcuaro, contains('Cuanajo'));
      expect(locsPatzcuaro, contains('Ajuno'));

      final locsTepalcatepec = MunicipiosData.obtenerLocalidades('Tepalcatepec');
      expect(locsTepalcatepec, isNotEmpty);

      final locsZiracuaretiro = MunicipiosData.obtenerLocalidades('Ziracuaretiro zona (I)');
      expect(locsZiracuaretiro, isNotEmpty);
    });

    test('obtenerLocalidades resuelve búsquedas parciales o nombres cortos de municipio', () {
      final locsShort = MunicipiosData.obtenerLocalidades('Morelia');
      expect(locsShort, isNotEmpty);
      expect(locsShort, contains('Capula'));

      final locsVacio = MunicipiosData.obtenerLocalidades('');
      expect(locsVacio, isEmpty);

      final locsNull = MunicipiosData.obtenerLocalidades(null);
      expect(locsNull, isEmpty);

      final locsInexistente = MunicipiosData.obtenerLocalidades('MunicipioInexistente123');
      expect(locsInexistente, isEmpty);
    });
  });
}
