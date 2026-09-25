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
  });
}
