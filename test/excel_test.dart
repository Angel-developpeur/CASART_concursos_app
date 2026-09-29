import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:casart_concursos_desktop/core/utils/excel_reports_service.dart';

void main() {
  test('Excel creation, autoFitColumns, and styling test', () {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    
    // Row 1: Merged Title (debe ignorarse para que no ensanche la col 0)
    sheet.appendRow([TextCellValue('TITULO DEL CONCURSO ARTESANAL ESTATAL')]);
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('H1'));
    expect(sheet.spannedItems, contains('A1:H1'));
    
    // Styling title
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 13,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    
    // Row 2: Empty
    sheet.appendRow([null]);
    
    // Row 3: Headers
    sheet.appendRow([
      TextCellValue('N°'),
      TextCellValue('PREMIO'),
      TextCellValue('NOMBRE'),
      TextCellValue('PROCEDENCIA'),
      TextCellValue('PUEBLO'),
      TextCellValue('OBRA'),
      TextCellValue('MONTO'),
      TextCellValue('REGISTRO'),
    ]);
    
    for (int col = 0; col < 8; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 2));
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#AE286E'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    sheet.appendRow([
      IntCellValue(1),
      TextCellValue('PRIMER LUGAR'),
      TextCellValue('MARÍA GUADALUPE HERNÁNDEZ RODRÍGUEZ'),
      TextCellValue('SANTA CLARA DEL COBRE'),
      TextCellValue('PURÉPECHA'),
      TextCellValue('JARRÓN DE COBRE MARTILLADO CON ASAS'),
      TextCellValue('\$25,000.00'),
      TextCellValue('101-A'),
    ]);

    expect(sheet.maxRows, equals(4));
    expect(sheet.maxColumns, equals(8));

    ExcelReportsService.autoFitColumns(sheet);

    expect(sheet.getColumnWidth(0), equals(10.0)); // minWidth aplicado, título ignorado
    expect(sheet.getColumnWidth(1), equals(16.0)); // 'PRIMER LUGAR' (12) + 4
    expect(sheet.getColumnWidth(2), equals(39.0)); // Nombre (35) + 4
    expect(sheet.getColumnWidth(3), equals(25.0)); // Procedencia (21) + 4
    expect(sheet.getColumnWidth(4), equals(13.0)); // Pueblo (9) + 4
    expect(sheet.getColumnWidth(5), equals(39.0)); // Obra (35) + 4
    expect(sheet.getColumnWidth(6), equals(14.0)); // Monto (10) + 4
    expect(sheet.getColumnWidth(7), equals(14.0)); // REGISTRO en negritas (ceil(8*1.15)=10) + 4

    final bytes = excel.save();
    expect(bytes, isNotNull);
    expect(bytes!.isNotEmpty, isTrue);

    final reloaded = Excel.decodeBytes(bytes!);
    final reloadedSheet = reloaded['Sheet1'];
    expect(reloadedSheet.getColumnWidth(0), closeTo(10.0, 0.1));
    expect(reloadedSheet.getColumnWidth(2), closeTo(39.0, 0.1));
  });

  test('autoFitColumns maneja saltos de línea sin inflar el ancho', () {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    
    // Encabezado con salto de línea: 19 caracteres en la línea más larga
    sheet.appendRow([
      TextCellValue('FECHA DE NACIMIENTO\nDD/MM/AAAA'),
    ]);

    ExcelReportsService.autoFitColumns(sheet);

    // 19 + 4 = 23 (no 31 + 4 = 35)
    expect(sheet.getColumnWidth(0), equals(23.0));
  });

  test('setColumnWidth saves and restores correctly', () {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.appendRow([TextCellValue('Hola'), TextCellValue('Mundo Extra Largo')]);
    sheet.setColumnWidth(0, 15.0);
    sheet.setColumnWidth(1, 30.5);

    final bytes = excel.save()!;
    final decoded = Excel.decodeBytes(bytes);
    final decodedSheet = decoded['Sheet1'];
    expect(decodedSheet.getColumnWidth(0), closeTo(15.0, 0.1));
    expect(decodedSheet.getColumnWidth(1), closeTo(30.5, 0.1));
  });
}

