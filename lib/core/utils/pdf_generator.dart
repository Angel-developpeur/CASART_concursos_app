import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/registro_concurso.dart';
import '../../models/concurso.dart';
import '../database/app_database.dart';

class PdfGenerator {
  static const double mm = PdfPageFormat.mm;

  // Colores oficiales del diseño web
  static final PdfColor _colorCardBg = PdfColor.fromHex('#D8D8D8');
  static final PdfColor _colorFolioRed = PdfColor.fromHex('#D00000');
  static final PdfColor _colorMutedGrey = PdfColor.fromHex('#666666');
  static final PdfColor _colorBlack = PdfColors.black;

  // Caché de recursos gráficos
  static Uint8List? _cachedFonartBytes;
  static String? _cachedCasartSvg;

  /// Carga de bytes de assets con fallback a File para pruebas offline / tests
  static Future<Uint8List?> _loadAssetBytes(String path) async {
    if (_cachedFonartBytes != null) return _cachedFonartBytes;
    try {
      final byteData = await rootBundle.load(path);
      _cachedFonartBytes = byteData.buffer.asUint8List();
      return _cachedFonartBytes;
    } catch (_) {
      try {
        final file = File(path);
        if (await file.exists()) {
          _cachedFonartBytes = await file.readAsBytes();
          return _cachedFonartBytes;
        }
      } catch (_) {}
      return null;
    }
  }

  /// Carga de SVG de assets con fallback a File
  static Future<String?> _loadAssetString(String path) async {
    if (_cachedCasartSvg != null) return _cachedCasartSvg;
    try {
      _cachedCasartSvg = await rootBundle.loadString(path);
      return _cachedCasartSvg;
    } catch (_) {
      try {
        final file = File(path);
        if (await file.exists()) {
          _cachedCasartSvg = await file.readAsString();
          return _cachedCasartSvg;
        }
      } catch (_) {}
      return null;
    }
  }

  /// Normaliza texto a mayúsculas sin acentos (compatibilidad iOS/Android vCard)
  static String _normalizeText(String? str) {
    if (str == null || str.isEmpty) return '';
    final upper = str.toUpperCase();
    const accents = {
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'Ü': 'U',
      'Ñ': 'N',
    };
    var result = upper;
    accents.forEach((k, v) {
      result = result.replaceAll(k, v);
    });
    return result.replaceAll(RegExp(r'[^A-Z0-9\s\$\.\,\:\/\-\#]'), '').trim();
  }

  /// Formatea tiempo de elaboración idéntico a la versión web Laravel
  static String _formatearTiempo(num? tiempo, String? plazo) {
    if (tiempo == null && (plazo == null || plazo.isEmpty)) return 'N/A';
    final num val = tiempo ?? 0;
    var plazoClean = (plazo ?? '').trim().toUpperCase();
    if (val == 1) {
      const singulares = {
        'DÍAS': 'DÍA',
        'DIAS': 'DÍA',
        'SEMANAS': 'SEMANA',
        'MESES': 'MES',
        'AÑOS': 'AÑO',
        'ANIOS': 'AÑO',
      };
      plazoClean = singulares[plazoClean] ?? plazoClean;
    } else {
      const plurales = {
        'DIA': 'DÍAS',
        'DÍA': 'DÍAS',
        'SEMANA': 'SEMANAS',
        'MES': 'MESES',
        'AÑO': 'AÑOS',
        'ANIO': 'AÑOS',
      };
      plazoClean = plurales[plazoClean] ?? plazoClean;
    }
    final numText = (val == val.toInt())
        ? val.toInt().toString()
        : val.toString();
    final res = '$numText $plazoClean'.trim();
    return res.isEmpty ? 'N/A' : res;
  }

  /// Construye la vCard 3.0 para el código QR de cada pieza
  static String _buildVCard({
    required String clave,
    required double costoVenta,
    required String artesaniaNombre,
    required String categoria,
    required String artesanoNombre,
    required String telefono,
    required String localidad,
  }) {
    final claveClean = _normalizeText(clave);
    final costoVentaClean =
        '\$${NumberFormat('#,##0.00', 'en_US').format(costoVenta)}';
    final artesaniaClean = _normalizeText(artesaniaNombre);
    final ramaClean = _normalizeText(categoria);
    final artesanoClean = _normalizeText(artesanoNombre);
    final telClean = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final telFinal = telClean.isEmpty ? 'N/A' : telClean;
    final locClean = _normalizeText(localidad);

    final noteLines = [
      'CLAVE: $claveClean',
      'COSTO VENTA: $costoVentaClean',
      'ARTESANIA: $artesaniaClean',
      'RAMA: $ramaClean',
      'ARTESANO: $artesanoClean',
      'TELEFONO: $telFinal',
      'LOCALIDAD: $locClean',
    ];
    final noteEscaped = noteLines.join(r'\n');

    return 'BEGIN:VCARD\n'
        'VERSION:3.0\n'
        'FN:$claveClean - $artesanoClean\n'
        'TEL;TYPE=CELL:$telFinal\n'
        'ADR;TYPE=HOME:;;$locClean;;;;\n'
        'NOTE:$noteEscaped\n'
        'END:VCARD';
  }

  /// Obtiene el nombre oficial del concurso concatenado con su ejercicio
  static String resolverNombreConcurso(Concurso? concurso) {
    if (concurso == null) {
      return 'CONCURSO ESTATAL DE ARTESANÍAS';
    }
    final nombre = concurso.nombre.trim();
    final ejercicio = concurso.ejercicio.trim();
    if (ejercicio.isNotEmpty &&
        !nombre.toUpperCase().endsWith(ejercicio.toUpperCase())) {
      return '$nombre $ejercicio'.toUpperCase();
    }
    return nombre.toUpperCase();
  }

  /// Genera el documento PDF de inscripción oficial con el diseño exacto de inscripcion_concurso.blade.php
  static Future<Uint8List> generateComprobanteInscripcion(
    RegistroConcurso registro, {
    Concurso? concurso,
  }) async {
    final pdf = pw.Document();

    // Tamaño oficial: 215mm x 215mm
    final pageFormat = const PdfPageFormat(215 * mm, 215 * mm, marginAll: 0);

    // Cargar logos
    final fonartBytes = await _loadAssetBytes('assets/images/logo_fonart.png');
    final fonartImage = fonartBytes != null
        ? pw.MemoryImage(fonartBytes)
        : null;
    final casartSvg = await _loadAssetString(
      'assets/images/casa_artesanias.svg',
    );

    // Datos del concurso, artesano y piezas
    Concurso? concursoFinal = concurso ?? registro.concurso;
    if (concursoFinal == null && registro.idConcurso > 0) {
      try {
        final db = await AppDatabase().database;
        final cRows = await db.query(
          'concurso',
          where: 'id = ?',
          whereArgs: [registro.idConcurso],
        );
        if (cRows.isNotEmpty) {
          concursoFinal = Concurso.fromMap(cRows.first);
        }
      } catch (_) {}
    }

    final artesano = registro.artesano;
    final p1 = registro.artesania1;
    final p2 = registro.artesania2;

    final String folio = registro.folio.toString().padLeft(4, '0');
    final String nombreDelConcurso = resolverNombreConcurso(concursoFinal);
    final String artesanoNombre = (artesano?.nombreCompleto ?? 'N/A')
        .toUpperCase();
    final String artesanoLocalidad =
        ((artesano?.localidad != null && artesano!.localidad.isNotEmpty)
                ? artesano.localidad
                : ((artesano?.municipio != null &&
                          artesano!.municipio.isNotEmpty)
                      ? artesano.municipio
                      : 'N/A'))
            .toUpperCase();
    final String artesanoTelefono =
        (artesano?.telefono != null && artesano!.telefono!.isNotEmpty)
        ? artesano.telefono!
        : 'N/A';

    // Pieza A
    final String piezaANombre = (p1?.nombre ?? 'N/A').toUpperCase();
    final double piezaAValor = p1?.costoProduccion ?? 0.0;
    final double piezaAVenta = p1?.costoVenta ?? 0.0;
    final String piezaACategoria =
        (p1?.categoriaNombre ?? p1?.ramaNombre ?? 'N/A').toUpperCase();
    final String piezaATecnica = (p1?.subcategoriaNombre ?? 'N/A')
        .toUpperCase();
    final String piezaATiempo = _formatearTiempo(
      p1?.tiempoElaboracion,
      p1?.plazoElaboracion,
    );

    // Pieza B
    final bool hasPiezaB =
        p2 != null &&
        p2.nombre.trim().isNotEmpty &&
        p2.nombre.trim().toUpperCase() != 'N/A';
    final String piezaBNombre = hasPiezaB ? p2.nombre.toUpperCase() : 'N/A';
    final double piezaBValor = hasPiezaB ? p2.costoProduccion : 0.0;
    final double piezaBVenta = hasPiezaB ? p2.costoVenta : 0.0;
    final String piezaBCategoria = hasPiezaB
        ? (p2.categoriaNombre ?? p2.ramaNombre ?? 'N/A').toUpperCase()
        : 'N/A';
    final String piezaBTecnica = hasPiezaB
        ? (p2.subcategoriaNombre ?? 'N/A').toUpperCase()
        : 'N/A';
    final String piezaBTiempo = hasPiezaB
        ? _formatearTiempo(p2.tiempoElaboracion, p2.plazoElaboracion)
        : 'N/A';

    // QR Codes
    final String vCardA = _buildVCard(
      clave: '${folio}A',
      costoVenta: piezaAVenta,
      artesaniaNombre: piezaANombre,
      categoria: piezaACategoria,
      artesanoNombre: artesanoNombre,
      telefono: artesanoTelefono,
      localidad: artesanoLocalidad,
    );

    final String vCardB = hasPiezaB
        ? _buildVCard(
            clave: '${folio}B',
            costoVenta: piezaBVenta,
            artesaniaNombre: piezaBNombre,
            categoria: piezaBCategoria,
            artesanoNombre: artesanoNombre,
            telefono: artesanoTelefono,
            localidad: artesanoLocalidad,
          )
        : '';

    final numberFormat = NumberFormat('#,##0.00', 'en_US');

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Container(
            width: 215 * mm,
            height: 215 * mm,
            color: PdfColors.white,
            child: pw.Stack(
              children: [
                // ===== LOGOS SUPERIORES =====
                // Logo FONART izquierdo
                if (fonartImage != null)
                  pw.Positioned(
                    left: 5 * mm,
                    top: 5 * mm,
                    child: pw.Image(fonartImage, height: 10 * mm),
                  ),

                // Logo Casa de las Artesanías izquierdo
                if (casartSvg != null)
                  pw.Positioned(
                    left: 65 * mm,
                    top: 5 * mm,
                    child: pw.SvgImage(svg: casartSvg, height: 10 * mm),
                  ),

                // Logo FONART derecho
                if (fonartImage != null)
                  pw.Positioned(
                    right: 80 * mm,
                    top: 5 * mm,
                    child: pw.Image(fonartImage, height: 10 * mm),
                  ),

                // Logo Casa de las Artesanías derecho
                if (casartSvg != null)
                  pw.Positioned(
                    right: 23 * mm,
                    top: 5 * mm,
                    child: pw.SvgImage(svg: casartSvg, height: 10 * mm),
                  ),

                // ===== COLUMNA IZQUIERDA =====

                // Certificado Principal (sec-main-cert)
                pw.Positioned(
                  top: 18 * mm,
                  left: 5 * mm,
                  child: pw.Container(
                    width: 88 * mm,
                    height: 50 * mm,
                    decoration: pw.BoxDecoration(
                      color: _colorCardBg,
                      borderRadius: pw.BorderRadius.circular(4 * mm),
                    ),
                    padding: const pw.EdgeInsets.all(3 * mm),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          'Gobierno del Estado de Michoacán de Ocampo',
                          style: pw.TextStyle(
                            fontSize: 3.3 * mm,
                            fontWeight: pw.FontWeight.bold,
                            color: _colorBlack,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 2 * mm),
                        pw.RichText(
                          textAlign: pw.TextAlign.center,
                          text: pw.TextSpan(
                            style: pw.TextStyle(
                              fontSize: 2.7 * mm,
                              color: _colorBlack,
                              lineSpacing: 1.2,
                            ),
                            children: [
                              const pw.TextSpan(
                                text:
                                    'Casa de las Artesanías de Michoacán de Ocampo\n',
                              ),
                              pw.TextSpan(
                                text: nombreDelConcurso,
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 3 * mm),
                        pw.Text(
                          'Certificado de Participación a nombre de:',
                          style: pw.TextStyle(
                            fontSize: 3.0 * mm,
                            fontWeight: pw.FontWeight.bold,
                            color: _colorBlack,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 3 * mm),
                        pw.Table(
                          columnWidths: const {
                            0: pw.FixedColumnWidth(25 * mm),
                            1: pw.FlexColumnWidth(),
                          },
                          children: [
                            pw.TableRow(
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.only(
                                    right: 3 * mm,
                                  ),
                                  child: pw.Text(
                                    'Artesano:',
                                    style: pw.TextStyle(
                                      fontSize: 2.7 * mm,
                                      color: _colorBlack,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                                pw.Text(
                                  artesanoNombre,
                                  style: pw.TextStyle(
                                    fontSize: 2.7 * mm,
                                    fontWeight: pw.FontWeight.bold,
                                    color: _colorBlack,
                                  ),
                                  textAlign: pw.TextAlign.left,
                                ),
                              ],
                            ),
                            pw.TableRow(
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.only(
                                    right: 3 * mm,
                                  ),
                                  child: pw.Text(
                                    'de la localidad:',
                                    style: pw.TextStyle(
                                      fontSize: 2.7 * mm,
                                      color: _colorBlack,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                                pw.Text(
                                  artesanoLocalidad,
                                  style: pw.TextStyle(
                                    fontSize: 2.7 * mm,
                                    fontWeight: pw.FontWeight.bold,
                                    color: _colorBlack,
                                  ),
                                  textAlign: pw.TextAlign.left,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Cintillo Participando (pill-participando)
                pw.Positioned(
                  top: 76 * mm,
                  left: 5 * mm,
                  child: pw.Container(
                    width: 88 * mm,
                    decoration: pw.BoxDecoration(
                      color: _colorCardBg,
                      borderRadius: pw.BorderRadius.circular(3 * mm),
                    ),
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 1.5 * mm,
                      horizontal: 3 * mm,
                    ),
                    child: pw.Text(
                      'Participando con las(s) siguientes(s) piezas(s)',
                      style: pw.TextStyle(
                        fontSize: 3.0 * mm,
                        fontWeight: pw.FontWeight.bold,
                        color: _colorBlack,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ),

                // Tarjeta Pieza (A) (sec-pieza-a)
                pw.Positioned(
                  top: 105 * mm,
                  left: 5 * mm,
                  child: pw.Container(
                    width: 88 * mm,
                    height: 25 * mm,
                    decoration: pw.BoxDecoration(
                      color: _colorCardBg,
                      borderRadius: pw.BorderRadius.circular(4 * mm),
                    ),
                    padding: const pw.EdgeInsets.all(3 * mm),
                    child: pw.Stack(
                      children: [
                        pw.Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: pw.Table(
                            columnWidths: const {
                              0: pw.FixedColumnWidth(20 * mm),
                              1: pw.FlexColumnWidth(),
                            },
                            children: [
                              pw.TableRow(
                                children: [
                                  pw.Text(
                                    'Pieza (A):',
                                    style: pw.TextStyle(
                                      fontSize: 2.7 * mm,
                                      fontWeight: pw.FontWeight.bold,
                                      color: _colorBlack,
                                    ),
                                  ),
                                  pw.Text(
                                    piezaANombre,
                                    style: pw.TextStyle(
                                      fontSize: 2.7 * mm,
                                      fontWeight: pw.FontWeight.bold,
                                      color: _colorBlack,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        pw.Positioned(
                          bottom: 0,
                          right: 0,
                          child: pw.Text(
                            'con valor de:     \$ ${numberFormat.format(piezaAValor)}',
                            style: pw.TextStyle(
                              fontSize: 2.7 * mm,
                              fontWeight: pw.FontWeight.bold,
                              color: _colorBlack,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tarjeta Pieza (B) (sec-pieza-b)
                if (hasPiezaB)
                  pw.Positioned(
                    top: 162 * mm,
                    left: 5 * mm,
                    child: pw.Container(
                      width: 88 * mm,
                      height: 25 * mm,
                      decoration: pw.BoxDecoration(
                        color: _colorCardBg,
                        borderRadius: pw.BorderRadius.circular(4 * mm),
                      ),
                      padding: const pw.EdgeInsets.all(3 * mm),
                      child: pw.Stack(
                        children: [
                          pw.Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: pw.Table(
                              columnWidths: const {
                                0: pw.FixedColumnWidth(20 * mm),
                                1: pw.FlexColumnWidth(),
                              },
                              children: [
                                pw.TableRow(
                                  children: [
                                    pw.Text(
                                      'Pieza (B):',
                                      style: pw.TextStyle(
                                        fontSize: 2.7 * mm,
                                        fontWeight: pw.FontWeight.bold,
                                        color: _colorBlack,
                                      ),
                                    ),
                                    pw.Text(
                                      piezaBNombre,
                                      style: pw.TextStyle(
                                        fontSize: 2.7 * mm,
                                        fontWeight: pw.FontWeight.bold,
                                        color: _colorBlack,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          pw.Positioned(
                            bottom: 0,
                            right: 0,
                            child: pw.Text(
                              'con valor de:     \$ ${numberFormat.format(piezaBValor)}',
                              style: pw.TextStyle(
                                fontSize: 2.7 * mm,
                                fontWeight: pw.FontWeight.bold,
                                color: _colorBlack,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Cintillo Folio del Certificado (pill-folio-cert)
                pw.Positioned(
                  top: 197 * mm,
                  left: 28 * mm,
                  child: pw.Container(
                    width: 65 * mm,
                    decoration: pw.BoxDecoration(
                      color: _colorCardBg,
                      borderRadius: pw.BorderRadius.circular(3 * mm),
                    ),
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 1.5 * mm,
                      horizontal: 3 * mm,
                    ),
                    child: pw.RichText(
                      text: pw.TextSpan(
                        style: pw.TextStyle(
                          fontSize: 2.7 * mm,
                          color: _colorBlack,
                        ),
                        children: [
                          pw.TextSpan(
                            text: 'FOLIO DEL CERTIFICADO No: ',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.TextSpan(
                            text: '  $folio',
                            style: pw.TextStyle(
                              color: _colorFolioRed,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 3.7 * mm,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ===== COLUMNA DERECHA =====

                // Bloque Superior Derecho (sec-top-right)
                pw.Positioned(
                  top: 22 * mm,
                  left: 110 * mm,
                  child: pw.SizedBox(
                    width: 90 * mm,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Text(
                          nombreDelConcurso,
                          style: pw.TextStyle(
                            fontSize: 1.7 * mm,
                            fontWeight: pw.FontWeight.bold,
                            color: _colorBlack,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 1 * mm),
                        pw.Container(
                          alignment: pw.Alignment.centerRight,
                          margin: const pw.EdgeInsets.only(bottom: 2 * mm),
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(
                                  text: 'Folio ',
                                  style: pw.TextStyle(
                                    fontSize: 2.5 * mm,
                                    color: _colorMutedGrey,
                                  ),
                                ),
                                pw.TextSpan(
                                  text: folio,
                                  style: pw.TextStyle(
                                    fontSize: 3.7 * mm,
                                    fontWeight: pw.FontWeight.bold,
                                    color: _colorFolioRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        pw.Table(
                          columnWidths: const {
                            0: pw.FixedColumnWidth(25 * mm),
                            1: pw.FlexColumnWidth(),
                          },
                          children: [
                            _buildDetailRow('Artesano:', artesanoNombre),
                            _buildDetailRow(
                              'de la localidad de:',
                              artesanoLocalidad,
                            ),
                            _buildDetailRow('Teléfono:', artesanoTelefono),
                            _buildDetailRow(
                              'Pieza (A):',
                              piezaANombre,
                              paddingTop: 1 * mm,
                            ),
                            _buildDetailRow('Categoria:', piezaACategoria),
                            _buildDetailRow('Tiempo de Elab.:', piezaATiempo),
                            _buildCostRow(
                              'Costo: \$${numberFormat.format(piezaAValor)}',
                            ),
                            if (hasPiezaB) ...[
                              _buildDetailRow(
                                'Pieza (B):',
                                piezaBNombre,
                                paddingTop: 1 * mm,
                              ),
                              _buildDetailRow('Categoria:', piezaBCategoria),
                              _buildDetailRow('Tiempo de Elab.:', piezaBTiempo),
                              _buildCostRow(
                                'Costo: \$${numberFormat.format(piezaBValor)}',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Etiqueta Pieza A (label-block-a)
                pw.Positioned(
                  top: 90 * mm,
                  left: 110 * mm,
                  child: pw.SizedBox(
                    width: 90 * mm,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        // Logos pequeños de la etiqueta
                        pw.Container(
                          height: 6 * mm,
                          margin: const pw.EdgeInsets.only(bottom: 2 * mm),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              if (fonartImage != null)
                                pw.Image(fonartImage, height: 6 * mm)
                              else
                                pw.SizedBox(height: 6 * mm),
                              if (casartSvg != null)
                                pw.SvgImage(svg: casartSvg, height: 6 * mm)
                              else
                                pw.SizedBox(height: 6 * mm),
                            ],
                          ),
                        ),
                        // Folio de pieza A
                        pw.Container(
                          alignment: pw.Alignment.centerRight,
                          margin: const pw.EdgeInsets.only(bottom: 2 * mm),
                          child: pw.RichText(
                            text: pw.TextSpan(
                              style: pw.TextStyle(
                                fontSize: 2.7 * mm,
                                color: _colorBlack,
                              ),
                              children: [
                                const pw.TextSpan(text: 'Folio: '),
                                pw.TextSpan(
                                  text: '${folio}A',
                                  style: pw.TextStyle(
                                    color: _colorFolioRed,
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 3.7 * mm,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Nombre de pieza A
                        pw.Container(
                          margin: const pw.EdgeInsets.only(bottom: 2 * mm),
                          child: pw.RichText(
                            text: pw.TextSpan(
                              style: pw.TextStyle(
                                fontSize: 2.7 * mm,
                                fontWeight: pw.FontWeight.bold,
                                color: _colorBlack,
                              ),
                              children: [
                                const pw.TextSpan(text: 'Pieza (A): '),
                                pw.TextSpan(text: piezaANombre),
                              ],
                            ),
                          ),
                        ),
                        // QR y ficha técnica de pieza A
                        pw.Container(
                          height: 25 * mm,
                          margin: const pw.EdgeInsets.only(top: 2 * mm),
                          child: pw.Stack(
                            children: [
                              pw.Positioned(
                                left: 0,
                                top: 2 * mm,
                                child: pw.BarcodeWidget(
                                  barcode: pw.Barcode.qrCode(),
                                  data: vCardA,
                                  width: 20 * mm,
                                  height: 20 * mm,
                                ),
                              ),
                              pw.Positioned(
                                left: 24 * mm,
                                top: 0,
                                right: 0,
                                child: pw.Table(
                                  columnWidths: const {
                                    0: pw.FixedColumnWidth(30 * mm),
                                    1: pw.FlexColumnWidth(),
                                  },
                                  children: [
                                    _buildLabelRow(
                                      'Venta:',
                                      '\$${numberFormat.format(piezaAVenta)}',
                                    ),
                                    _buildLabelRow(
                                      'Localidad:',
                                      artesanoLocalidad,
                                    ),
                                    pw.TableRow(
                                      children: [
                                        pw.Padding(
                                          padding:
                                              const pw.EdgeInsets.symmetric(
                                                vertical: 0.5 * mm,
                                              ),
                                          child: pw.Text(
                                            'Técnica:',
                                            style: pw.TextStyle(
                                              fontSize: 2.3 * mm,
                                              fontWeight: pw.FontWeight.bold,
                                              color: _colorBlack,
                                            ),
                                            textAlign: pw.TextAlign.right,
                                          ),
                                        ),
                                        pw.Padding(
                                          padding: const pw.EdgeInsets.only(
                                            left: 2 * mm,
                                            top: 0.5 * mm,
                                            bottom: 0.5 * mm,
                                          ),
                                          child: pw.RichText(
                                            text: pw.TextSpan(
                                              style: pw.TextStyle(
                                                fontSize: 2.3 * mm,
                                                color: _colorBlack,
                                                lineSpacing: 1.1,
                                              ),
                                              children: [
                                                pw.TextSpan(
                                                  text: '$piezaACategoria\n',
                                                  style: pw.TextStyle(
                                                    fontWeight:
                                                        pw.FontWeight.bold,
                                                  ),
                                                ),
                                                pw.TextSpan(
                                                  text: piezaATecnica,
                                                  style: pw.TextStyle(
                                                    fontWeight:
                                                        pw.FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    _buildLabelRow(
                                      'Tiempo de Elaboración:',
                                      piezaATiempo,
                                      paddingTop: 1 * mm,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 2 * mm),
                        pw.Text(
                          nombreDelConcurso,
                          style: pw.TextStyle(
                            fontSize: 1.6 * mm,
                            fontWeight: pw.FontWeight.bold,
                            color: _colorBlack,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                // Etiqueta Pieza B (label-block-b)
                if (hasPiezaB)
                  pw.Positioned(
                    top: 155 * mm,
                    left: 110 * mm,
                    child: pw.SizedBox(
                      width: 90 * mm,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          // Logos pequeños de la etiqueta
                          pw.Container(
                            height: 6 * mm,
                            margin: const pw.EdgeInsets.only(bottom: 2 * mm),
                            child: pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                if (fonartImage != null)
                                  pw.Image(fonartImage, height: 6 * mm)
                                else
                                  pw.SizedBox(height: 6 * mm),
                                if (casartSvg != null)
                                  pw.SvgImage(svg: casartSvg, height: 6 * mm)
                                else
                                  pw.SizedBox(height: 6 * mm),
                              ],
                            ),
                          ),
                          // Folio de pieza B
                          pw.Container(
                            alignment: pw.Alignment.centerRight,
                            margin: const pw.EdgeInsets.only(bottom: 2 * mm),
                            child: pw.RichText(
                              text: pw.TextSpan(
                                style: pw.TextStyle(
                                  fontSize: 2.7 * mm,
                                  color: _colorBlack,
                                ),
                                children: [
                                  const pw.TextSpan(text: 'Folio: '),
                                  pw.TextSpan(
                                    text: '${folio}B',
                                    style: pw.TextStyle(
                                      color: _colorFolioRed,
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 3.7 * mm,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Nombre de pieza B
                          pw.Container(
                            margin: const pw.EdgeInsets.only(bottom: 2 * mm),
                            child: pw.RichText(
                              text: pw.TextSpan(
                                style: pw.TextStyle(
                                  fontSize: 2.7 * mm,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _colorBlack,
                                ),
                                children: [
                                  const pw.TextSpan(text: 'Pieza (B): '),
                                  pw.TextSpan(text: piezaBNombre),
                                ],
                              ),
                            ),
                          ),
                          // QR y ficha técnica de pieza B
                          pw.Container(
                            height: 25 * mm,
                            margin: const pw.EdgeInsets.only(top: 2 * mm),
                            child: pw.Stack(
                              children: [
                                pw.Positioned(
                                  left: 0,
                                  top: 2 * mm,
                                  child: pw.BarcodeWidget(
                                    barcode: pw.Barcode.qrCode(),
                                    data: vCardB,
                                    width: 20 * mm,
                                    height: 20 * mm,
                                  ),
                                ),
                                pw.Positioned(
                                  left: 24 * mm,
                                  top: 0,
                                  right: 0,
                                  child: pw.Table(
                                    columnWidths: const {
                                      0: pw.FixedColumnWidth(30 * mm),
                                      1: pw.FlexColumnWidth(),
                                    },
                                    children: [
                                      _buildLabelRow(
                                        'Venta:',
                                        '\$${numberFormat.format(piezaBVenta)}',
                                      ),
                                      _buildLabelRow(
                                        'Localidad:',
                                        artesanoLocalidad,
                                      ),
                                      pw.TableRow(
                                        children: [
                                          pw.Padding(
                                            padding:
                                                const pw.EdgeInsets.symmetric(
                                                  vertical: 0.5 * mm,
                                                ),
                                            child: pw.Text(
                                              'Técnica:',
                                              style: pw.TextStyle(
                                                fontSize: 2.3 * mm,
                                                fontWeight: pw.FontWeight.bold,
                                                color: _colorBlack,
                                              ),
                                              textAlign: pw.TextAlign.right,
                                            ),
                                          ),
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.only(
                                              left: 2 * mm,
                                              top: 0.5 * mm,
                                              bottom: 0.5 * mm,
                                            ),
                                            child: pw.RichText(
                                              text: pw.TextSpan(
                                                style: pw.TextStyle(
                                                  fontSize: 2.3 * mm,
                                                  color: _colorBlack,
                                                  lineSpacing: 1.1,
                                                ),
                                                children: [
                                                  pw.TextSpan(
                                                    text: '$piezaBCategoria\n',
                                                    style: pw.TextStyle(
                                                      fontWeight:
                                                          pw.FontWeight.bold,
                                                    ),
                                                  ),
                                                  pw.TextSpan(
                                                    text: piezaBTecnica,
                                                    style: pw.TextStyle(
                                                      fontWeight:
                                                          pw.FontWeight.normal,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      _buildLabelRow(
                                        'Tiempo de Elaboración:',
                                        piezaBTiempo,
                                        paddingTop: 1 * mm,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 2 * mm),
                          pw.Text(
                            nombreDelConcurso,
                            style: pw.TextStyle(
                              fontSize: 1.6 * mm,
                              fontWeight: pw.FontWeight.bold,
                              color: _colorBlack,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Fila de la tabla de detalles superior derecha
  static pw.TableRow _buildDetailRow(
    String label,
    String value, {
    double paddingTop = 0,
  }) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.only(
            top: paddingTop + 0.5 * mm,
            bottom: 0.5 * mm,
          ),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 2.4 * mm,
              fontWeight: pw.FontWeight.bold,
              color: _colorBlack,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.only(
            left: 3 * mm,
            top: paddingTop + 0.5 * mm,
            bottom: 0.5 * mm,
          ),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 2.4 * mm,
              fontWeight: pw.FontWeight.bold,
              color: _colorBlack,
            ),
          ),
        ),
      ],
    );
  }

  /// Fila del costo total alineado a la derecha en la tabla superior derecha
  static pw.TableRow _buildCostRow(String costText) {
    return pw.TableRow(
      children: [
        pw.SizedBox(),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 1 * mm, bottom: 0.5 * mm),
          child: pw.Text(
            costText,
            style: pw.TextStyle(
              fontSize: 2.4 * mm,
              fontWeight: pw.FontWeight.bold,
              color: _colorBlack,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  /// Fila de tabla para las etiquetas de piezas
  static pw.TableRow _buildLabelRow(
    String label,
    String value, {
    double paddingTop = 0,
  }) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.only(
            top: paddingTop + 0.5 * mm,
            bottom: 0.5 * mm,
          ),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 2.3 * mm,
              fontWeight: pw.FontWeight.bold,
              color: _colorBlack,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.only(
            left: 2 * mm,
            top: paddingTop + 0.5 * mm,
            bottom: 0.5 * mm,
          ),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 2.3 * mm,
              fontWeight: pw.FontWeight.bold,
              color: _colorBlack,
            ),
          ),
        ),
      ],
    );
  }

  /// Envía a imprimir directamente o abre el visor nativo de impresión
  static Future<void> printComprobante(
    RegistroConcurso registro, {
    Concurso? concurso,
  }) async {
    final pdfBytes = await generateComprobanteInscripcion(
      registro,
      concurso: concurso,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Inscripcion_Concurso_Folio_${registro.folio}.pdf',
    );
  }
}
