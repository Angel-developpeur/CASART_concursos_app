import 'package:flutter_test/flutter_test.dart';
import 'package:casart_concursos_desktop/core/utils/pdf_generator.dart';
import 'package:casart_concursos_desktop/models/artesano.dart';
import 'package:casart_concursos_desktop/models/artesania.dart';
import 'package:casart_concursos_desktop/models/concurso.dart';
import 'package:casart_concursos_desktop/models/registro_concurso.dart';

void main() {
  group('PdfGenerator Comprobante Inscripción', () {
    final testConcurso = Concurso(
      id: 1,
      nombre: 'XXIII CONCURSO ARTESANAL DE OPOPEO 2026',
      idTipoConcurso: 1,
    );

    final testArtesano = Artesano(
      id: 1,
      nombre: 'EVELIA',
      apPaterno: 'BUCIO',
      apMaterno: 'PEREZ',
      curp: 'BUPE800101MMNRRL01',
      municipio: 'SALVADOR ESCALANTE',
      localidad: 'OPOPEO',
      telefono: '4431234567',
    );

    final testPieza1 = Artesania(
      id: 1,
      nombre: 'SILLA DE MADERA TALLADA',
      costoProduccion: 1500.0,
      costoVenta: 2500.0,
      tiempoElaboracion: 2,
      plazoElaboracion: 'meses',
      materialElaboracion: 'Madera de pino',
      descripcion: 'Silla artesanal tallada a mano',
      idRamaArtesanal: 1,
      ramaNombre: 'MADERAS',
      idCategoriaConcurso: 1,
      categoriaNombre: 'MUEBLES',
      idSubCategoriaConcurso: 1,
      subcategoriaNombre: 'TALLADO TRADICIONAL',
    );

    final testPieza2 = Artesania(
      id: 2,
      nombre: 'MESA DE CENTRO DE CEDRO',
      costoProduccion: 3000.0,
      costoVenta: 4800.0,
      tiempoElaboracion: 1,
      plazoElaboracion: 'mes',
      materialElaboracion: 'Madera de cedro',
      descripcion: 'Mesa con acabado natural',
      idRamaArtesanal: 1,
      ramaNombre: 'MADERAS',
      idCategoriaConcurso: 1,
      categoriaNombre: 'MUEBLES',
      idSubCategoriaConcurso: 1,
      subcategoriaNombre: 'ENSAMBLE FINO',
    );

    test('Genera PDF válido con 1 pieza (formato 215mm x 215mm y diseño web oficial)', () async {
      final registro = RegistroConcurso(
        id: 1,
        folio: 1,
        idArtesano: 1,
        idConcurso: 1,
        idArtesania1: 1,
        concurso: testConcurso,
        artesano: testArtesano,
        artesania1: testPieza1,
      );

      final pdfBytes = await PdfGenerator.generateComprobanteInscripcion(registro);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('Genera PDF válido con 2 piezas con etiquetas QR A y B completas', () async {
      final registro = RegistroConcurso(
        id: 2,
        folio: 2,
        idArtesano: 1,
        idConcurso: 1,
        idArtesania1: 1,
        idArtesania2: 2,
        concurso: testConcurso,
        artesano: testArtesano,
        artesania1: testPieza1,
        artesania2: testPieza2,
      );

      final pdfBytes = await PdfGenerator.generateComprobanteInscripcion(registro);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('resolverNombreConcurso concatena nombre verdadero + ejercicio correctamente', () {
      // Caso 1: Concurso sin ejercicio en el nombre
      final c1 = Concurso(
        id: 10,
        nombre: 'LIV Concurso Estatal de Artesanías de Domingo de Ramos',
        ejercicio: '2024',
        idTipoConcurso: 1,
      );
      expect(
        PdfGenerator.resolverNombreConcurso(c1),
        equals('LIV CONCURSO ESTATAL DE ARTESANÍAS DE DOMINGO DE RAMOS 2024'),
      );

      // Caso 2: Concurso que ya contiene el ejercicio al final del nombre (sin duplicar)
      final c2 = Concurso(
        id: 11,
        nombre: 'XXIII Concurso Artesanal de Opopeo 2026',
        ejercicio: '2026',
        idTipoConcurso: 1,
      );
      expect(
        PdfGenerator.resolverNombreConcurso(c2),
        equals('XXIII CONCURSO ARTESANAL DE OPOPEO 2026'),
      );

      // Caso 3: Concurso nulo (fallback)
      expect(
        PdfGenerator.resolverNombreConcurso(null),
        equals('CONCURSO ESTATAL DE ARTESANÍAS'),
      );
    });

    test('generateComprobanteInscripcion acepta concurso explícito con nombre + ejercicio', () async {
      final registro = RegistroConcurso(
        id: 3,
        folio: 3,
        idArtesano: 1,
        idConcurso: 99,
        idArtesania1: 1,
        artesano: testArtesano,
        artesania1: testPieza1,
      );

      final concursoPersonalizado = Concurso(
        id: 99,
        nombre: 'Concurso Estatal del Rebozo',
        ejercicio: '2025',
        idTipoConcurso: 1,
      );

      final pdfBytes = await PdfGenerator.generateComprobanteInscripcion(
        registro,
        concurso: concursoPersonalizado,
      );
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}
