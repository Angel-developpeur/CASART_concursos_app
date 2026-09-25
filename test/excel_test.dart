import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart' hide Border;

void main() {
  test('Excel creation and styling test', () {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    
    // Row 1: Merged Title
    sheet.appendRow([TextCellValue('TITULO DEL CONCURSO')]);
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('H1'));
    
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
    
    final bytes = excel.save();
    expect(bytes, isNotNull);
    expect(bytes!.isNotEmpty, isTrue);
  });
}
