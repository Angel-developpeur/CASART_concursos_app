import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../logging/app_logger.dart';
import '../theme/app_theme.dart';
import '../../models/concurso.dart';
import 'numero_a_letras.dart';

class ExcelReportsService {
  static final ExcelColor _colorGuinda = ExcelColor.fromHexString('#AE286E');
  static final ExcelColor _colorBlanco = ExcelColor.fromHexString('#FFFFFF');
  static final ExcelColor _colorGrisGrupo = ExcelColor.fromHexString('#E5E7EB');
  static final ExcelColor _colorTextoOscuro = ExcelColor.fromHexString('#1F2937');

  /// Exporta el Formato A: Ganadores agrupados por Galardones, Especiales y Categorías
  static Future<bool> exportarGanadoresFormatoA({
    required BuildContext context,
    required Concurso concurso,
    required AppDatabase dbHelper,
  }) async {
    try {
      final db = await dbHelper.database;

      // 1. Obtener categorías y subcategorías
      final categoriasRows = await db.query(
        'categoria_concurso',
        where: 'id_concurso = ?',
        whereArgs: [concurso.id],
        orderBy: 'id ASC',
      );

      final subcategoriasRows = await db.rawQuery('''
        SELECT s.* FROM sub_categoria_concurso s
        JOIN categoria_concurso c ON s.id_categoria = c.id
        WHERE c.id_concurso = ?
        ORDER BY s.id ASC
      ''', [concurso.id]);

      // 2. Obtener todas las premiaciones otorgadas
      final premiaciones = await db.rawQuery('''
        SELECT 
          pr.id as premiacion_id,
          pr.lugar as premiacion_lugar,
          p.id as premio_id,
          p.nombre as premio_nombre,
          p.monto as premio_monto,
          p.lugar as premio_lugar,
          p.id_tipo_premio,
          p.id_categoria as premio_id_categoria,
          p.id_sub_categoria as premio_id_sub_categoria,
          a.id as artesania_id,
          a.nombre as artesania_nombre,
          a.id_categoria_concurso,
          a.id_sub_categoria_concurso,
          r.folio as registro_folio,
          r.id as registro_id,
          r.id_artesania_1,
          r.id_artesania_2,
          art.nombre as artesano_nombre,
          art.ap_paterno as artesano_paterno,
          art.ap_materno as artesano_materno,
          res.municipio,
          res.localidad,
          et.nombre as etnia_nombre
        FROM premiacion pr
        JOIN premio p ON pr.id_premio = p.id
        JOIN artesania_concurso a ON pr.id_artesania = a.id
        JOIN registro_concurso r ON (r.id_artesania_1 = a.id OR r.id_artesania_2 = a.id)
        JOIN artesano art ON r.id_artesano = art.id
        LEFT JOIN residencia res ON art.id_residencia = res.id
        LEFT JOIN etnia et ON art.id_etnia = et.id
        WHERE pr.id_concurso = ?
        ORDER BY p.id_tipo_premio ASC, p.monto DESC, pr.lugar ASC, p.lugar ASC
      ''', [concurso.id]);

      if (premiaciones.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay premiaciones registradas para este concurso aún.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }

      final excel = Excel.createExcel();
      const sheetName = 'Ganadores (F-A)';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);
      if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

      // Título en Fila 1 (A1:H1)
      final titulo = '“${concurso.nombre.toUpperCase()} ${concurso.ejercicio}” (FORMATO A)';
      sheet.appendRow([TextCellValue(titulo)]);
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('H1'));

      final cellTitulo = sheet.cell(CellIndex.indexByString('A1'));
      cellTitulo.cellStyle = CellStyle(
        bold: true,
        fontSize: 13,
        fontColorHex: _colorTextoOscuro,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      // Fila 2: Vacía
      sheet.appendRow([null]);

      // Fila 3: Encabezados (A3:H3)
      final headers = [
        'N°',
        'PREMIO',
        'NOMBRE DE LA PERSONA ARTESANA GANADORA',
        'PROCEDENCIA',
        'PUEBLO INDÍGENA',
        'OBRA',
        'MONTO PREMIO',
        'NUMERO DE REGISTRO',
      ];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2));
        cell.cellStyle = CellStyle(
          bold: true,
          fontSize: 10,
          fontColorHex: _colorBlanco,
          backgroundColorHex: _colorGuinda,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }

      int counter = 1;
      int currentRow = 3; // 0-indexed: Row 4
      final Set<int> assignedPremiacionIds = {};

      void addGroupHeader(String title) {
        sheet.appendRow([TextCellValue(title)]);
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
          CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow),
        );
        for (int c = 0; c < 8; c++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: currentRow));
          cell.cellStyle = CellStyle(
            bold: true,
            fontSize: 11,
            fontColorHex: _colorTextoOscuro,
            backgroundColorHex: _colorGrisGrupo,
            horizontalAlign: HorizontalAlign.Center,
            verticalAlign: VerticalAlign.Center,
          );
        }
        currentRow++;
      }

      void addWinnerRow(Map<String, dynamic> p) {
        final lugarNum = p['premiacion_lugar'] ?? p['premio_lugar'];
        String nombrePremio = '';
        if (lugarNum == 1) {
          nombrePremio = 'Primer Lugar';
        } else if (lugarNum == 2) {
          nombrePremio = 'Segundo Lugar';
        } else if (lugarNum == 3) {
          nombrePremio = 'Tercer Lugar';
        } else {
          nombrePremio = p['premio_nombre']?.toString() ?? 'Premio';
        }

        final nombreCompleto = '${p['artesano_nombre'] ?? ''} ${p['artesano_paterno'] ?? ''} ${p['artesano_materno'] ?? ''}'.trim();
        final localidadRaw = p['localidad']?.toString().trim() ?? '';
        final municipioRaw = p['municipio']?.toString().trim() ?? '';
        final procedencia = localidadRaw.isNotEmpty
            ? localidadRaw
            : (municipioRaw.isNotEmpty ? municipioRaw : 'N/A');

        final etnia = (p['etnia_nombre'] != null &&
                p['etnia_nombre'].toString().isNotEmpty &&
                !p['etnia_nombre'].toString().toLowerCase().contains('ninguna'))
            ? p['etnia_nombre'].toString()
            : 'N/A';

        final double montoVal = (p['premio_monto'] as num?)?.toDouble() ?? 0.0;
        final montoFormatted = '\$${NumberFormat('#,##0.00', 'en_US').format(montoVal)}';

        final baseFolio = p['registro_folio']?.toString() ?? p['registro_id']?.toString() ?? '0';
        final isPieza2 = p['artesania_id'] == p['id_artesania_2'];
        final numRegistro = isPieza2 ? '$baseFolio-B' : '$baseFolio-A';

        sheet.appendRow([
          IntCellValue(counter++),
          TextCellValue(nombrePremio.toUpperCase()),
          TextCellValue(nombreCompleto.toUpperCase()),
          TextCellValue(procedencia.toUpperCase()),
          TextCellValue(etnia.toUpperCase()),
          TextCellValue((p['artesania_nombre'] ?? 'N/A').toString().toUpperCase()),
          TextCellValue(montoFormatted),
          TextCellValue(numRegistro),
        ]);

        // Estilos de la fila de datos
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle =
            CellStyle(horizontalAlign: HorizontalAlign.Center);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow)).cellStyle =
            CellStyle(horizontalAlign: HorizontalAlign.Right);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow)).cellStyle =
            CellStyle(horizontalAlign: HorizontalAlign.Center);

        assignedPremiacionIds.add(p['premiacion_id'] as int);
        currentRow++;
      }

      // 4.1 Galardones (id_tipo_premio = 1)
      final galardones = premiaciones.where((p) => p['id_tipo_premio'] == 1).toList();
      if (galardones.isNotEmpty) {
        addGroupHeader('GALARDONES');
        for (final p in galardones) {
          addWinnerRow(p);
        }
      }

      // 4.2 Premios Especiales (id_tipo_premio = 2)
      final especiales = premiaciones.where((p) => p['id_tipo_premio'] == 2).toList();
      if (especiales.isNotEmpty) {
        addGroupHeader('PREMIOS ESPECIALES');
        for (final p in especiales) {
          addWinnerRow(p);
        }
      }

      // 4.3 Premios Comunes (id_tipo_premio = 3) agrupados por Categoría y Subcategoría
      final comunes = premiaciones.where((p) => p['id_tipo_premio'] == 3).toList();
      int catCounter = 0;

      for (final cat in categoriasRows) {
        final catId = cat['id'] as int;
        final rawCatNombre = cat['nombre']?.toString().trim() ?? 'Categoría';
        final catNombre = rawCatNombre.replaceFirst(RegExp(r'^[A-Za-z]\.\s*'), '');

        final catSubs = subcategoriasRows.where((s) => s['id_categoria'] == catId).toList();

        // Verificar si la categoría tiene ganadores antes de asignarle letra
        bool hasWinners = false;
        if (catSubs.isNotEmpty) {
          final subIds = catSubs.map((s) => s['id'] as int).toList();
          for (final sub in catSubs) {
            final subId = sub['id'] as int;
            final subWinners = comunes.where((p) {
              final pCatId = p['premio_id_categoria'] ?? p['id_categoria_concurso'];
              final pSubCatId = p['premio_id_sub_categoria'] ?? p['id_sub_categoria_concurso'];
              return (pCatId == catId || pCatId == null) && pSubCatId == subId;
            }).toList();
            if (subWinners.isNotEmpty) {
              hasWinners = true;
              break;
            }
          }
          if (!hasWinners) {
            final directWinners = comunes.where((p) {
              final pCatId = p['premio_id_categoria'] ?? p['id_categoria_concurso'];
              final pSubCatId = p['premio_id_sub_categoria'] ?? p['id_sub_categoria_concurso'];
              return pCatId == catId && (pSubCatId == null || !subIds.contains(pSubCatId));
            }).toList();
            if (directWinners.isNotEmpty) hasWinners = true;
          }
        } else {
          final catWinners = comunes.where((p) {
            final pCatId = p['premio_id_categoria'] ?? p['id_categoria_concurso'];
            return pCatId == catId;
          }).toList();
          if (catWinners.isNotEmpty) hasWinners = true;
        }

        if (!hasWinners) continue;

        final catLetter = _categoryLetter(catCounter++);
        final catLetterLower = catLetter.toLowerCase();

        if (catSubs.isNotEmpty) {
          final subIds = catSubs.map((s) => s['id'] as int).toList();
          int subCounter = 1;

          for (final sub in catSubs) {
            final subId = sub['id'] as int;
            final rawSubNombre = sub['nombre']?.toString().trim() ?? 'Subcategoría';
            final subNombre = rawSubNombre.replaceFirst(RegExp(r'^[a-z]\.\d+\s*'), '');

            final subWinners = comunes.where((p) {
              final pCatId = p['premio_id_categoria'] ?? p['id_categoria_concurso'];
              final pSubCatId = p['premio_id_sub_categoria'] ?? p['id_sub_categoria_concurso'];
              return (pCatId == catId || pCatId == null) && pSubCatId == subId;
            }).toList();

            if (subWinners.isNotEmpty) {
              final subCode = '$catLetterLower.$subCounter';
              addGroupHeader('$catLetter. ${catNombre.toUpperCase()} $subCode ${subNombre.toUpperCase()}');
              for (final p in subWinners) {
                addWinnerRow(p);
              }
              subCounter++;
            }
          }

          // Ganadores de la categoría sin subcategoría
          final directWinners = comunes.where((p) {
            final pCatId = p['premio_id_categoria'] ?? p['id_categoria_concurso'];
            final pSubCatId = p['premio_id_sub_categoria'] ?? p['id_sub_categoria_concurso'];
            return pCatId == catId && (pSubCatId == null || !subIds.contains(pSubCatId));
          }).toList();

          if (directWinners.isNotEmpty) {
            addGroupHeader('$catLetter. ${catNombre.toUpperCase()}');
            for (final p in directWinners) {
              addWinnerRow(p);
            }
          }
        } else {
          // Categoría sin subcategorías
          final catWinners = comunes.where((p) {
            final pCatId = p['premio_id_categoria'] ?? p['id_categoria_concurso'];
            return pCatId == catId;
          }).toList();

          if (catWinners.isNotEmpty) {
            addGroupHeader('$catLetter. ${catNombre.toUpperCase()}');
            for (final p in catWinners) {
              addWinnerRow(p);
            }
          }
        }
      }

      // 4.4 Premios comunes restantes sin categoría
      final unassigned = comunes.where((p) => !assignedPremiacionIds.contains(p['premiacion_id'])).toList();
      if (unassigned.isNotEmpty) {
        addGroupHeader('PREMIOS COMUNES - GENERAL');
        for (final p in unassigned) {
          addWinnerRow(p);
        }
      }

      return await _guardarArchivoExcel(
        context: context,
        excel: excel,
        defaultFileName: 'Ganadores_${_sanitizeName(concurso.nombre)}_${concurso.ejercicio}_(Formato_A).xlsx',
        dialogTitle: 'Exportar Ganadores (Formato A)',
        logDescription: 'Ganadores Formato A generado para "${concurso.nombre}"',
      );
    } catch (e, stack) {
      AppLogger.error('Error al exportar Ganadores Formato A: $e', category: 'EXPORTACION', error: e, stackTrace: stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar a Excel: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  /// Exporta el Formato B: Ganadores Completo (31 columnas institucionales)
  static Future<bool> exportarGanadoresCompletoFormatoB({
    required BuildContext context,
    required Concurso concurso,
    required AppDatabase dbHelper,
  }) async {
    try {
      final db = await dbHelper.database;

      final premiaciones = await db.rawQuery('''
        SELECT 
          pr.id as premiacion_id,
          pr.lugar as premiacion_lugar,
          p.id as premio_id,
          p.nombre as premio_nombre,
          p.monto as premio_monto,
          p.lugar as premio_lugar,
          a.id as artesania_id,
          a.nombre as artesania_nombre,
          a.descripcion as artesania_descripcion,
          a.material_elaboracion,
          a.tiempo_elaboracion,
          a.plazo_elaboracion,
          a.id_categoria_concurso,
          a.id_sub_categoria_concurso,
          r.folio as registro_folio,
          r.id as registro_id,
          r.id_artesania_1,
          r.id_artesania_2,
          art.nombre as artesano_nombre,
          art.ap_paterno as artesano_paterno,
          art.ap_materno as artesano_materno,
          art.genero as artesano_genero,
          art.curp as artesano_curp,
          art.fecha_nacimiento as artesano_fecha_nacimiento,
          art.max_nivel_academico as artesano_escolaridad,
          res.municipio,
          res.localidad,
          res.colonia,
          res.calle,
          res.numero_exterior,
          res.cp,
          et.nombre as etnia_nombre,
          ec.nombre as estado_civil_nombre,
          ic.telefono,
          cat.nombre as categoria_nombre,
          sub.nombre as subcategoria_nombre,
          rama.nombre as rama_nombre
        FROM premiacion pr
        JOIN premio p ON pr.id_premio = p.id
        JOIN artesania_concurso a ON pr.id_artesania = a.id
        JOIN registro_concurso r ON (r.id_artesania_1 = a.id OR r.id_artesania_2 = a.id)
        JOIN artesano art ON r.id_artesano = art.id
        LEFT JOIN residencia res ON art.id_residencia = res.id
        LEFT JOIN etnia et ON art.id_etnia = et.id
        LEFT JOIN estado_civil ec ON art.id_estado_civil = ec.id
        LEFT JOIN info_contacto ic ON art.id_info_contacto = ic.id
        LEFT JOIN categoria_concurso cat ON a.id_categoria_concurso = cat.id
        LEFT JOIN sub_categoria_concurso sub ON a.id_sub_categoria_concurso = sub.id
        LEFT JOIN rama_artesanal rama ON a.id_rama_artesanal = rama.id
        WHERE pr.id_concurso = ?
        ORDER BY p.id_tipo_premio ASC, p.monto DESC, pr.lugar ASC, p.lugar ASC
      ''', [concurso.id]);

      if (premiaciones.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay premiaciones registradas para este concurso aún.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }

      final excel = Excel.createExcel();
      const sheetName = 'Ganadores Completo (F-B)';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);
      if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

      // Título en A1:AE1
      final titulo = '“${concurso.nombre.toUpperCase()} ${concurso.ejercicio}” (FORMATO B)';
      sheet.appendRow([TextCellValue(titulo)]);
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('AE1'));

      final cellTitulo = sheet.cell(CellIndex.indexByString('A1'));
      cellTitulo.cellStyle = CellStyle(
        bold: true,
        fontSize: 13,
        fontColorHex: _colorTextoOscuro,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      // Fila 2: Vacía
      sheet.appendRow([null]);

      // Fila 3: Encabezados (31 columnas)
      final headers = [
        'NÚM.',
        'REGISTRO',
        'NOMBRE DE LA PERSONA GANADORA',
        'GÉNERO (H/M)',
        'PUEBLO INDÍGENA',
        'MONTO APORTACIÓN (FONART)',
        'MONTO APORTACIÓN FONART (LETRA)',
        'CURP',
        'CLAVE INTERBANCARIA',
        'INSTITUCIÓN BANCARIA',
        'ESTADO CIVIL',
        'FECHA DE NACIMIENTO\nDD/MM/AAAA',
        'ESCOLARIDAD',
        'PREMIO RECIBIDO CON CATEGORÍA',
        'TÍTULO O NOMBRE DE LA OBRA',
        'TÉCNICA DE ELABORACIÓN',
        'MATERIAL DE ELABORACIÓN',
        'TIEMPO DE ELABORACIÓN',
        'CAPACIDAD DE PRODUCCIÓN MENSUAL',
        'ENTIDAD FEDERATIVA',
        'MUNICIPIO',
        'COMUNIDAD',
        'CÓDIGO POSTAL',
        'DOMICILIO',
        'TELÉFONO',
        'DESCRIPCIÓN DE LA OBRA',
        'NOMBRE DE CONVOCATORIA',
        'FECHA DE DICTAMINACIÓN',
        'FECHA DE PREMIACIÓN',
        'HORA DE PREMIACIÓN',
        'LUGAR DE PREMIACIÓN',
      ];

      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2));
        cell.cellStyle = CellStyle(
          bold: true,
          fontSize: 10,
          fontColorHex: _colorBlanco,
          backgroundColorHex: _colorGuinda,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }

      int counter = 1;
      int currentRow = 3;

      for (final p in premiaciones) {
        final baseFolio = p['registro_folio']?.toString() ?? p['registro_id']?.toString() ?? '0';
        final isPieza2 = p['artesania_id'] == p['id_artesania_2'];
        final numRegistro = isPieza2 ? '$baseFolio-B' : '$baseFolio-A';

        final nombreCompleto = '${p['artesano_nombre'] ?? ''} ${p['artesano_paterno'] ?? ''} ${p['artesano_materno'] ?? ''}'.trim();

        // Género
        String genero = 'N/A';
        final genRaw = (p['artesano_genero']?.toString() ?? '').trim().toUpperCase();
        if (genRaw == 'MASCULINO' || genRaw == 'H' || genRaw == 'HOMBRE') {
          genero = 'H';
        } else if (genRaw == 'FEMENINO' || genRaw == 'M' || genRaw == 'MUJER') {
          genero = 'M';
        }

        // Pueblo Indígena
        String puebloIndigena = 'NO APLICA';
        final etnia = p['etnia_nombre']?.toString().trim();
        if (etnia != null && etnia.isNotEmpty && !etnia.toLowerCase().contains('ninguna') && !etnia.toLowerCase().contains('no aplica')) {
          puebloIndigena = etnia.toUpperCase();
        }

        // Monto
        final double montoVal = (p['premio_monto'] as num?)?.toDouble() ?? 0.0;
        final montoFormatted = '\$${NumberFormat('#,##0.00', 'en_US').format(montoVal)}';
        final montoLetra = NumeroALetras.numeroAMonedaLetras(montoVal);

        // Curp
        final curp = p['artesano_curp']?.toString().toUpperCase() ?? '';

        // Estado civil
        final estadoCivil = p['estado_civil_nombre']?.toString().toUpperCase() ?? '';

        // Fecha nacimiento dd/MM/yyyy
        String fechaNac = '';
        if (p['artesano_fecha_nacimiento'] != null) {
          try {
            final dt = DateTime.parse(p['artesano_fecha_nacimiento'].toString());
            fechaNac = DateFormat('dd/MM/yyyy').format(dt);
          } catch (_) {
            fechaNac = p['artesano_fecha_nacimiento'].toString();
          }
        }

        // Escolaridad
        final escolaridad = _formatEscolaridad(p['artesano_escolaridad']);

        // Premio con categoría
        final lugarNum = p['premiacion_lugar'] ?? p['premio_lugar'];
        String nombrePremio = '';
        if (lugarNum == 1) {
          nombrePremio = 'PRIMER LUGAR';
        } else if (lugarNum == 2) {
          nombrePremio = 'SEGUNDO LUGAR';
        } else if (lugarNum == 3) {
          nombrePremio = 'TERCER LUGAR';
        } else {
          nombrePremio = (p['premio_nombre']?.toString() ?? 'PREMIO').toUpperCase();
        }

        final catNom = p['categoria_nombre']?.toString().trim() ?? '';
        final subNom = p['subcategoria_nombre']?.toString().trim() ?? '';
        final catCompleta = '$catNom $subNom'.trim();
        final premioConCategoria = catCompleta.isNotEmpty
            ? '$nombrePremio EN LA CATEGORIA ${catCompleta.toUpperCase()}'
            : nombrePremio;

        // Obra y técnica
        final obra = p['artesania_nombre']?.toString().toUpperCase() ?? 'N/A';
        String tecnica = catCompleta.toUpperCase();
        if (tecnica.isEmpty && p['rama_nombre'] != null) {
          tecnica = p['rama_nombre'].toString().toUpperCase();
        }
        if (tecnica.isEmpty) tecnica = 'N/A';

        final material = p['material_elaboracion']?.toString().toUpperCase() ?? '';
        final tiempoStr = '${p['tiempo_elaboracion'] ?? ''} ${p['plazo_elaboracion'] ?? ''}'.trim().toUpperCase();

        // Capacidad mensual
        final capacidad = _calcularCapacidadProduccion(
          tiempo: (p['tiempo_elaboracion'] as num?)?.toDouble(),
          plazo: p['plazo_elaboracion']?.toString(),
        );

        final municipio = p['municipio']?.toString().toUpperCase() ?? '';
        final comunidad = p['localidad']?.toString().toUpperCase() ?? '';
        final cp = p['cp']?.toString() ?? '';

        // Domicilio
        final calle = p['calle']?.toString().trim() ?? '';
        final numExt = p['numero_exterior']?.toString().trim() ?? '';
        final coloniaRaw = p['colonia']?.toString().trim() ?? '';
        final localidadRaw = p['localidad']?.toString().trim() ?? '';
        final colonia = (coloniaRaw.isNotEmpty ? coloniaRaw : localidadRaw).toUpperCase();
        final domParts = [
          if (calle.isNotEmpty) 'C $calle',
          if (numExt.isNotEmpty) '#$numExt' else 'S/N',
          if (colonia.isNotEmpty) 'COL. $colonia',
        ];
        final domicilio = domParts.join(', ').toUpperCase();

        final telefono = p['telefono']?.toString() ?? '';
        final descripcionObra = p['artesania_descripcion']?.toString().toUpperCase() ?? '';
        final nombreConvocatoria = '“${concurso.nombre.toUpperCase()}”';

        final fechaDictamen = _formatFechaLarga(concurso.fechaDictamen);
        final fechaPremiacion = _formatFechaLarga(concurso.fechaPremiacion);
        final horaPremiacion = _formatHora(concurso.fechaPremiacion) ?? '12 H';
        final lugarPremiacion = concurso.lugar?.toUpperCase() ?? '';

        sheet.appendRow([
          IntCellValue(counter++),
          TextCellValue(numRegistro),
          TextCellValue(nombreCompleto.toUpperCase()),
          TextCellValue(genero),
          TextCellValue(puebloIndigena),
          TextCellValue(montoFormatted),
          TextCellValue(montoLetra),
          TextCellValue(curp),
          TextCellValue(''), // Clave Interbancaria
          TextCellValue(''), // Institución Bancaria
          TextCellValue(estadoCivil),
          TextCellValue(fechaNac),
          TextCellValue(escolaridad),
          TextCellValue(premioConCategoria),
          TextCellValue(obra),
          TextCellValue(tecnica),
          TextCellValue(material),
          TextCellValue(tiempoStr),
          TextCellValue(capacidad),
          TextCellValue('MICHOACÁN DE OCAMPO'),
          TextCellValue(municipio),
          TextCellValue(comunidad),
          TextCellValue(cp),
          TextCellValue(domicilio),
          TextCellValue(telefono),
          TextCellValue(descripcionObra),
          TextCellValue(nombreConvocatoria),
          TextCellValue(fechaDictamen),
          TextCellValue(fechaPremiacion),
          TextCellValue(horaPremiacion),
          TextCellValue(lugarPremiacion),
        ]);

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow)).cellStyle =
            CellStyle(horizontalAlign: HorizontalAlign.Center);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow)).cellStyle =
            CellStyle(horizontalAlign: HorizontalAlign.Center);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow)).cellStyle =
            CellStyle(horizontalAlign: HorizontalAlign.Right);

        currentRow++;
      }

      return await _guardarArchivoExcel(
        context: context,
        excel: excel,
        defaultFileName: 'Ganadores_Completo_${_sanitizeName(concurso.nombre)}_${concurso.ejercicio}_(Formato_B).xlsx',
        dialogTitle: 'Exportar Ganadores Completo (Formato B)',
        logDescription: 'Ganadores Formato B generado para "${concurso.nombre}"',
      );
    } catch (e, stack) {
      AppLogger.error('Error al exportar Ganadores Formato B: $e', category: 'EXPORTACION', error: e, stackTrace: stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar a Excel: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  /// Exporta el Formato C: Artesanías Inscritas (26 columnas)
  static Future<bool> exportarArtesaniasInscritasFormatoC({
    required BuildContext context,
    required Concurso concurso,
    required AppDatabase dbHelper,
  }) async {
    try {
      final db = await dbHelper.database;

      final rows = await db.rawQuery('''
        SELECT 
          r.id as registro_id,
          r.folio as folio_boleta,
          art.id as artesano_id,
          art.nombre as artesano_nombre,
          art.ap_paterno as artesano_paterno,
          art.ap_materno as artesano_materno,
          art.curp,
          art.rfc,
          art.fecha_nacimiento,
          art.genero,
          res.municipio,
          res.localidad,
          res.colonia,
          res.calle,
          res.numero_exterior,
          res.cp,
          et.nombre as etnia_nombre,
          ic.correo,
          ic.telefono,
          ic.telefono_emergencia,
          r.id_artesania_1,
          r.id_artesania_2,
          p1.nombre as p1_nombre,
          p1.costo_produccion as p1_costo_produccion,
          p1.costo_venta as p1_costo_venta,
          p1.estado as p1_estado,
          cat1.nombre as p1_categoria,
          sub1.nombre as p1_subcategoria,
          rama1.nombre as p1_rama,
          p2.nombre as p2_nombre,
          p2.costo_produccion as p2_costo_produccion,
          p2.costo_venta as p2_costo_venta,
          p2.estado as p2_estado,
          cat2.nombre as p2_categoria,
          sub2.nombre as p2_subcategoria,
          rama2.nombre as p2_rama
        FROM registro_concurso r
        JOIN artesano art ON r.id_artesano = art.id
        LEFT JOIN residencia res ON art.id_residencia = res.id
        LEFT JOIN etnia et ON art.id_etnia = et.id
        LEFT JOIN info_contacto ic ON art.id_info_contacto = ic.id
        LEFT JOIN artesania_concurso p1 ON r.id_artesania_1 = p1.id
        LEFT JOIN categoria_concurso cat1 ON p1.id_categoria_concurso = cat1.id
        LEFT JOIN sub_categoria_concurso sub1 ON p1.id_sub_categoria_concurso = sub1.id
        LEFT JOIN rama_artesanal rama1 ON p1.id_rama_artesanal = rama1.id
        LEFT JOIN artesania_concurso p2 ON r.id_artesania_2 = p2.id
        LEFT JOIN categoria_concurso cat2 ON p2.id_categoria_concurso = cat2.id
        LEFT JOIN sub_categoria_concurso sub2 ON p2.id_sub_categoria_concurso = sub2.id
        LEFT JOIN rama_artesanal rama2 ON p2.id_rama_artesanal = rama2.id
        WHERE r.id_concurso = ?
        ORDER BY r.folio ASC
      ''', [concurso.id]);

      if (rows.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay piezas inscritas registradas para este concurso aún.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }

      final excel = Excel.createExcel();
      const sheetName = 'Artesanías Inscritas (F-C)';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);
      if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

      // Título en A1:Z1
      final titulo = '“${concurso.nombre.toUpperCase()} ${concurso.ejercicio}” (FORMATO C)';
      sheet.appendRow([TextCellValue(titulo)]);
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('Z1'));

      final cellTitulo = sheet.cell(CellIndex.indexByString('A1'));
      cellTitulo.cellStyle = CellStyle(
        bold: true,
        fontSize: 13,
        fontColorHex: _colorTextoOscuro,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      // Fila 2: Vacía
      sheet.appendRow([null]);

      // Fila 3: Encabezados (26 columnas)
      final headers = [
        'FOLIO ARTESANO',
        'FOLIO BOLETA',
        'ARTESANO',
        'PATERNO',
        'MATERNO',
        'CURP',
        'RFC',
        'FECHA NACIMIENTO',
        'GENERO',
        'CORREO',
        'MUNICIPIO',
        'LOCALIDAD',
        'COLONIA',
        'CALLE',
        'TELEFONO',
        'CELULAR',
        'CP',
        'REPRESENTANTE',
        'PRODUCTO',
        'RAMA',
        'SUBRAMA',
        'COSTO',
        'COSTO VENTA',
        'CLAVE PRODUCTO',
        'ESTADO',
        'ETNIA',
      ];

      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2));
        cell.cellStyle = CellStyle(
          bold: true,
          fontSize: 10,
          fontColorHex: _colorBlanco,
          backgroundColorHex: _colorGuinda,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }

      for (final r in rows) {
        final folioArtesano = (r['artesano_id'] != null)
            ? r['artesano_id'].toString().padLeft(4, '0')
            : '';

        final baseFolio = (r['folio_boleta'] != null)
            ? r['folio_boleta'].toString().padLeft(4, '0')
            : (r['registro_id']?.toString().padLeft(4, '0') ?? '');

        final nombre = r['artesano_nombre']?.toString().toUpperCase() ?? '';
        final paterno = r['artesano_paterno']?.toString().toUpperCase() ?? '';
        final materno = r['artesano_materno']?.toString().toUpperCase() ?? '';
        final curp = r['curp']?.toString().toUpperCase() ?? '';
        final rfc = r['rfc']?.toString().toUpperCase() ?? '';

        String fechaNac = '';
        if (r['fecha_nacimiento'] != null) {
          try {
            final dt = DateTime.parse(r['fecha_nacimiento'].toString());
            fechaNac = DateFormat('dd/MM/yyyy').format(dt);
          } catch (_) {
            fechaNac = r['fecha_nacimiento'].toString();
          }
        }

        final genero = r['genero']?.toString().toUpperCase() ?? '';
        final correo = r['correo']?.toString() ?? '';
        final telefono = r['telefono_emergencia']?.toString() ?? '';
        final celular = r['telefono']?.toString() ?? '';

        final municipio = r['municipio']?.toString().trim().toUpperCase() ?? '';
        final localidad = r['localidad']?.toString().trim().toUpperCase() ?? '';
        final coloniaRaw = r['colonia']?.toString().trim() ?? '';
        final colonia = (coloniaRaw.isNotEmpty ? coloniaRaw : localidad).toUpperCase();
        final calleStr = '${r['calle'] ?? ''} ${r['numero_exterior'] ?? ''}'.trim().toUpperCase();
        final cp = r['cp']?.toString() ?? '';
        final etnia = r['etnia_nombre']?.toString() ?? '';

        // Pieza 1 (A)
        if (r['id_artesania_1'] != null) {
          final producto = r['p1_nombre']?.toString().toUpperCase() ?? '';
          final rama = (r['p1_categoria'] != null && r['p1_categoria'].toString().isNotEmpty)
              ? r['p1_categoria'].toString().toUpperCase()
              : (r['p1_rama']?.toString().toUpperCase() ?? '');
          final subrama = r['p1_subcategoria']?.toString().toUpperCase() ?? '';
          final double costo = (r['p1_costo_produccion'] as num?)?.toDouble() ?? 0.0;
          final double costoVenta = (r['p1_costo_venta'] as num?)?.toDouble() ?? 0.0;
          final clave = '${baseFolio}A';
          final estado = r['p1_estado']?.toString() ?? 'Registrado';

          sheet.appendRow([
            TextCellValue(folioArtesano),
            TextCellValue(baseFolio),
            TextCellValue(nombre),
            TextCellValue(paterno),
            TextCellValue(materno),
            TextCellValue(curp),
            TextCellValue(rfc),
            TextCellValue(fechaNac),
            TextCellValue(genero),
            TextCellValue(correo),
            TextCellValue(municipio),
            TextCellValue(localidad),
            TextCellValue(colonia),
            TextCellValue(calleStr),
            TextCellValue(telefono),
            TextCellValue(celular),
            TextCellValue(cp),
            TextCellValue(''), // Representante
            TextCellValue(producto),
            TextCellValue(rama),
            TextCellValue(subrama),
            DoubleCellValue(costo),
            DoubleCellValue(costoVenta),
            TextCellValue(clave),
            TextCellValue(estado),
            TextCellValue(etnia),
          ]);
        }

        // Pieza 2 (B)
        if (r['id_artesania_2'] != null && (r['p2_nombre']?.toString().trim().isNotEmpty ?? false)) {
          final producto = r['p2_nombre']?.toString().toUpperCase() ?? '';
          final rama = (r['p2_categoria'] != null && r['p2_categoria'].toString().isNotEmpty)
              ? r['p2_categoria'].toString().toUpperCase()
              : (r['p2_rama']?.toString().toUpperCase() ?? '');
          final subrama = r['p2_subcategoria']?.toString().toUpperCase() ?? '';
          final double costo = (r['p2_costo_produccion'] as num?)?.toDouble() ?? 0.0;
          final double costoVenta = (r['p2_costo_venta'] as num?)?.toDouble() ?? 0.0;
          final clave = '${baseFolio}B';
          final estado = r['p2_estado']?.toString() ?? 'Registrado';

          sheet.appendRow([
            TextCellValue(folioArtesano),
            TextCellValue(baseFolio),
            TextCellValue(nombre),
            TextCellValue(paterno),
            TextCellValue(materno),
            TextCellValue(curp),
            TextCellValue(rfc),
            TextCellValue(fechaNac),
            TextCellValue(genero),
            TextCellValue(correo),
            TextCellValue(municipio),
            TextCellValue(localidad),
            TextCellValue(colonia),
            TextCellValue(calleStr),
            TextCellValue(telefono),
            TextCellValue(celular),
            TextCellValue(cp),
            TextCellValue(''), // Representante
            TextCellValue(producto),
            TextCellValue(rama),
            TextCellValue(subrama),
            DoubleCellValue(costo),
            DoubleCellValue(costoVenta),
            TextCellValue(clave),
            TextCellValue(estado),
            TextCellValue(etnia),
          ]);
        }
      }

      return await _guardarArchivoExcel(
        context: context,
        excel: excel,
        defaultFileName: 'Artesanias_Inscritas_${_sanitizeName(concurso.nombre)}_${concurso.ejercicio}_(Formato_C).xlsx',
        dialogTitle: 'Exportar Artesanías Inscritas (Formato C)',
        logDescription: 'Artesanías Inscritas Formato C generado para "${concurso.nombre}"',
      );
    } catch (e, stack) {
      AppLogger.error('Error al exportar Artesanías Inscritas Formato C: $e', category: 'EXPORTACION', error: e, stackTrace: stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar a Excel: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  /// Exporta el Formato D: Artesanías Resumen (9 columnas)
  static Future<bool> exportarArtesaniasResumenFormatoD({
    required BuildContext context,
    required Concurso concurso,
    required AppDatabase dbHelper,
  }) async {
    try {
      final db = await dbHelper.database;

      final rows = await db.rawQuery('''
        SELECT 
          r.id as registro_id,
          r.folio as folio_boleta,
          art.nombre as artesano_nombre,
          art.ap_paterno as artesano_paterno,
          art.ap_materno as artesano_materno,
          r.id_artesania_1,
          r.id_artesania_2,
          p1.nombre as p1_nombre,
          p1.costo_produccion as p1_costo_produccion,
          p1.costo_venta as p1_costo_venta,
          cat1.nombre as p1_categoria,
          sub1.nombre as p1_subcategoria,
          rama1.nombre as p1_rama,
          p2.nombre as p2_nombre,
          p2.costo_produccion as p2_costo_produccion,
          p2.costo_venta as p2_costo_venta,
          cat2.nombre as p2_categoria,
          sub2.nombre as p2_subcategoria,
          rama2.nombre as p2_rama
        FROM registro_concurso r
        JOIN artesano art ON r.id_artesano = art.id
        LEFT JOIN artesania_concurso p1 ON r.id_artesania_1 = p1.id
        LEFT JOIN categoria_concurso cat1 ON p1.id_categoria_concurso = cat1.id
        LEFT JOIN sub_categoria_concurso sub1 ON p1.id_sub_categoria_concurso = sub1.id
        LEFT JOIN rama_artesanal rama1 ON p1.id_rama_artesanal = rama1.id
        LEFT JOIN artesania_concurso p2 ON r.id_artesania_2 = p2.id
        LEFT JOIN categoria_concurso cat2 ON p2.id_categoria_concurso = cat2.id
        LEFT JOIN sub_categoria_concurso sub2 ON p2.id_sub_categoria_concurso = sub2.id
        LEFT JOIN rama_artesanal rama2 ON p2.id_rama_artesanal = rama2.id
        WHERE r.id_concurso = ?
        ORDER BY r.folio ASC
      ''', [concurso.id]);

      if (rows.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay piezas inscritas registradas para este concurso aún.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }

      final excel = Excel.createExcel();
      const sheetName = 'Artesanías Resumen (F-D)';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);
      if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

      // Título en A1:I1
      final titulo = '${concurso.nombre.toUpperCase()} ${concurso.ejercicio} (FORMATO D)';
      sheet.appendRow([TextCellValue(titulo)]);
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('I1'));

      final cellTitulo = sheet.cell(CellIndex.indexByString('A1'));
      cellTitulo.cellStyle = CellStyle(
        bold: true,
        fontSize: 12,
        fontColorHex: _colorTextoOscuro,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      // Fila 2: Vacía
      sheet.appendRow([null]);

      // Fila 3: Encabezados (9 columnas)
      final headers = [
        'ARTESANO',
        'PATERNO',
        'MATERNO',
        'PRODUCTO',
        'RAMA',
        'SUBRAMA',
        'COSTO',
        'COSTO VENTA',
        'CLAVE PRODUCTO',
      ];

      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2));
        cell.cellStyle = CellStyle(
          bold: true,
          fontSize: 10,
          fontColorHex: _colorBlanco,
          backgroundColorHex: _colorGuinda,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }

      for (final r in rows) {
        final baseFolio = (r['folio_boleta'] != null)
            ? r['folio_boleta'].toString().padLeft(4, '0')
            : (r['registro_id']?.toString().padLeft(4, '0') ?? '');

        final nombre = r['artesano_nombre']?.toString().toUpperCase() ?? '';
        final paterno = r['artesano_paterno']?.toString().toUpperCase() ?? '';
        final materno = r['artesano_materno']?.toString().toUpperCase() ?? '';

        // Pieza 1 (A)
        if (r['id_artesania_1'] != null) {
          final producto = r['p1_nombre']?.toString().toUpperCase() ?? '';
          final rama = (r['p1_categoria'] != null && r['p1_categoria'].toString().isNotEmpty)
              ? r['p1_categoria'].toString().toUpperCase()
              : (r['p1_rama']?.toString().toUpperCase() ?? '');
          final subrama = r['p1_subcategoria']?.toString().toUpperCase() ?? '';
          final double costo = (r['p1_costo_produccion'] as num?)?.toDouble() ?? 0.0;
          final double costoVenta = (r['p1_costo_venta'] as num?)?.toDouble() ?? 0.0;
          final clave = '${baseFolio}A';

          sheet.appendRow([
            TextCellValue(nombre),
            TextCellValue(paterno),
            TextCellValue(materno),
            TextCellValue(producto),
            TextCellValue(rama),
            TextCellValue(subrama),
            DoubleCellValue(costo),
            DoubleCellValue(costoVenta),
            TextCellValue(clave),
          ]);
        }

        // Pieza 2 (B)
        if (r['id_artesania_2'] != null && (r['p2_nombre']?.toString().trim().isNotEmpty ?? false)) {
          final producto = r['p2_nombre']?.toString().toUpperCase() ?? '';
          final rama = (r['p2_categoria'] != null && r['p2_categoria'].toString().isNotEmpty)
              ? r['p2_categoria'].toString().toUpperCase()
              : (r['p2_rama']?.toString().toUpperCase() ?? '');
          final subrama = r['p2_subcategoria']?.toString().toUpperCase() ?? '';
          final double costo = (r['p2_costo_produccion'] as num?)?.toDouble() ?? 0.0;
          final double costoVenta = (r['p2_costo_venta'] as num?)?.toDouble() ?? 0.0;
          final clave = '${baseFolio}B';

          sheet.appendRow([
            TextCellValue(nombre),
            TextCellValue(paterno),
            TextCellValue(materno),
            TextCellValue(producto),
            TextCellValue(rama),
            TextCellValue(subrama),
            DoubleCellValue(costo),
            DoubleCellValue(costoVenta),
            TextCellValue(clave),
          ]);
        }
      }

      return await _guardarArchivoExcel(
        context: context,
        excel: excel,
        defaultFileName: 'Artesanias_Resumen_${_sanitizeName(concurso.nombre)}_${concurso.ejercicio}_(Formato_D).xlsx',
        dialogTitle: 'Exportar Artesanías Resumen (Formato D)',
        logDescription: 'Artesanías Resumen Formato D generado para "${concurso.nombre}"',
      );
    } catch (e, stack) {
      AppLogger.error('Error al exportar Artesanías Resumen Formato D: $e', category: 'EXPORTACION', error: e, stackTrace: stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar a Excel: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  // --- HELPERS INTERNOS ---

  static String _sanitizeName(String name) {
    return name.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');
  }

  static String _categoryLetter(int index) {
    if (index < 0) return 'A';
    String result = '';
    int n = index;
    while (n >= 0) {
      result = String.fromCharCode((n % 26) + 65) + result;
      n = (n ~/ 26) - 1;
    }
    return result;
  }

  static String _formatEscolaridad(dynamic nivel) {
    if (nivel == null) return '';
    final val = nivel.toString().trim();
    switch (val) {
      case '0':
        return 'NINGUNO';
      case '1':
        return 'PRIMARIA (INCOMPLETA)';
      case '2':
        return 'PRIMARIA (COMPLETA)';
      case '3':
        return 'SECUNDARIA (INCOMPLETA)';
      case '4':
        return 'SECUNDARIA (COMPLETA)';
      case '5':
        return 'PREPARATORIA (INCOMPLETA)';
      case '6':
        return 'PREPARATORIA (COMPLETA)';
      case '7':
        return 'UNIVERSIDAD (INCOMPLETA)';
      case '8':
        return 'UNIVERSIDAD (COMPLETA)';
      case '9':
        return 'POSGRADO';
      default:
        return val.toUpperCase();
    }
  }

  static String _calcularCapacidadProduccion({double? tiempo, String? plazo}) {
    if (tiempo == null || tiempo <= 0 || plazo == null || plazo.trim().isEmpty) {
      return 'N/A';
    }
    final p = plazo.toLowerCase().trim();
    double capacidad;
    if (p.contains('dia') || p.contains('día')) {
      capacidad = 30 / tiempo;
    } else if (p.contains('semana')) {
      capacidad = 4 / tiempo;
    } else if (p.contains('mes')) {
      capacidad = 1 / tiempo;
    } else if (p.contains('ano') || p.contains('año')) {
      capacidad = 1 / (tiempo * 12);
    } else {
      capacidad = 30 / tiempo;
    }

    if (capacidad == capacidad.floorToDouble()) {
      return capacidad.toInt().toString();
    } else {
      return capacidad.toStringAsFixed(2);
    }
  }

  static String _formatFechaLarga(String? fechaStr) {
    if (fechaStr == null || fechaStr.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(fechaStr);
      return DateFormat("d 'DE' MMMM 'DE' y", 'es_MX').format(dt).toUpperCase();
    } catch (_) {
      return fechaStr.toUpperCase();
    }
  }

  static String? _formatHora(String? fechaStr) {
    if (fechaStr == null || !fechaStr.contains(':')) return null;
    try {
      final dt = DateTime.parse(fechaStr);
      return '${DateFormat('HH:mm').format(dt)} H';
    } catch (_) {
      return null;
    }
  }

  /// Ajusta automáticamente el ancho de las columnas de una hoja de cálculo
  /// al tamaño del contenido de sus celdas para evitar que los textos o números
  /// queden cortados u ocultos al visualizar el archivo Excel.
  /// 
  /// Ignora celdas que forman parte de combinaciones horizontales (títulos o
  /// encabezados de sección que abarcan varias columnas) para no distorsionar
  /// el ancho de columnas individuales (como número progresivo o folios).
  static void autoFitColumns(
    Sheet sheet, {
    double minWidth = 10.0,
    double maxWidth = 100.0,
    double padding = 4.0,
  }) {
    if (sheet.maxColumns == 0 || sheet.maxRows == 0) return;

    // 1. Identificar celdas que forman parte de combinaciones horizontales (colSpan > 1)
    final multiColumnMergedCells = <String>{};
    for (final span in sheet.spannedItems) {
      final parts = span.split(':');
      if (parts.length == 2) {
        final start = CellIndex.indexByString(parts[0]);
        final end = CellIndex.indexByString(parts[1]);
        if (start.columnIndex != end.columnIndex) {
          final minCol = start.columnIndex < end.columnIndex ? start.columnIndex : end.columnIndex;
          final maxCol = start.columnIndex > end.columnIndex ? start.columnIndex : end.columnIndex;
          final minRow = start.rowIndex < end.rowIndex ? start.rowIndex : end.rowIndex;
          final maxRow = start.rowIndex > end.rowIndex ? start.rowIndex : end.rowIndex;
          for (int r = minRow; r <= maxRow; r++) {
            for (int c = minCol; c <= maxCol; c++) {
              multiColumnMergedCells.add('$c,$r');
            }
          }
        }
      }
    }

    // 2. Medir longitud máxima de contenido por columna
    final Map<int, double> maxColWidths = {};
    final rows = sheet.rows;

    for (int r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (int c = 0; c < row.length; c++) {
        // Ignorar celdas combinadas horizontalmente (como títulos o cintillos)
        if (multiColumnMergedCells.contains('$c,$r')) continue;

        final cell = row[c];
        if (cell == null || cell.value == null) continue;

        final val = cell.value;
        String text = '';
        if (val is TextCellValue) {
          text = val.value.toString();
        } else if (val is FormulaCellValue) {
          text = val.formula ?? '';
        } else {
          text = val.toString();
        }

        if (text.isEmpty) continue;

        // Si contiene saltos de línea (\n), medimos la línea más larga
        int maxLineLength = 0;
        final lines = text.split('\n');
        for (final line in lines) {
          final len = line.replaceAll('\r', '').trim().length;
          if (len > maxLineLength) {
            maxLineLength = len;
          }
        }

        if (maxLineLength > 0) {
          // El texto en negrita (ej. encabezados) ocupa ~15% más espacio horizontal
          final isBold = cell.cellStyle?.isBold ?? false;
          final effectiveLength = isBold ? (maxLineLength * 1.15).ceilToDouble() : maxLineLength.toDouble();
          final currentMax = maxColWidths[c] ?? 0.0;
          if (effectiveLength > currentMax) {
            maxColWidths[c] = effectiveLength;
          }
        }
      }
    }

    // 3. Aplicar anchos calculados a cada columna
    final totalColumns = sheet.maxColumns;
    for (int c = 0; c < totalColumns; c++) {
      final contentWidth = maxColWidths[c] ?? 0.0;
      final calculatedWidth = contentWidth > 0
          ? (contentWidth + padding).clamp(minWidth, maxWidth)
          : minWidth;
      sheet.setColumnWidth(c, calculatedWidth);
    }
  }

  static Future<bool> _guardarArchivoExcel({
    required BuildContext context,
    required Excel excel,
    required String defaultFileName,
    required String dialogTitle,
    required String logDescription,
  }) async {
    // Auto-adaptar columnas al contenido en todas las hojas del libro
    for (final sheet in excel.sheets.values) {
      autoFitColumns(sheet);
    }

    final fileBytes = excel.save();
    if (fileBytes == null) {
      throw Exception('No se pudieron codificar los bytes del archivo Excel.');
    }

    final uri = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: defaultFileName,
      bytes: Uint8List.fromList(fileBytes),
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (uri == null) return false;

    final String pathDisplay = uri.toFilePath();

    AppLogger.info(
      '$logDescription en $pathDisplay',
      category: 'EXPORTACION',
      data: {'archivo': defaultFileName, 'ruta': pathDisplay},
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Archivo Excel exportado con éxito:\n$pathDisplay'),
          backgroundColor: AppTheme.verdeSuccess,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    return true;
  }
}
