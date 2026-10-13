import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:casart_concursos_desktop/views/common/impresora_selector_dialog.dart';

void main() {
  group('ImpresoraSelectorDialog Tests', () {
    const printerDefaultOffline = Printer(
      url: 'winspool://NetworkPrinter',
      name: 'HP LaserJet Network (Desconectada)',
      isDefault: true,
      isAvailable: false,
    );

    const printerUsbAvailable = Printer(
      url: 'winspool://EpsonL3150',
      name: 'EPSON L3150 Series (USB)',
      isDefault: false,
      isAvailable: true,
    );

    const printerPdfAvailable = Printer(
      url: 'winspool://MicrosoftPDF',
      name: 'Microsoft Print to PDF',
      isDefault: false,
      isAvailable: true,
    );

    testWidgets('Muestra lista de impresoras, orden y badges de disponibilidad', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImpresoraSelectorDialog(
              buildPdf: (format) async => Uint8List(10),
              documentName: 'test.pdf',
              listPrintersOverride: () async => [
                printerUsbAvailable,
                printerDefaultOffline,
                printerPdfAvailable,
              ],
            ),
          ),
        ),
      );

      // Esperar a que cargue la lista
      await tester.pumpAndSettle();

      // Verificar que aparezcan los nombres de las impresoras
      expect(find.text('HP LaserJet Network (Desconectada)'), findsOneWidget);
      expect(find.text('EPSON L3150 Series (USB)'), findsOneWidget);
      expect(find.text('Microsoft Print to PDF'), findsOneWidget);

      // Verificar badges
      expect(find.text('Predeterminada'), findsOneWidget);
      expect(find.text('Sin conexión / Fuera de línea'), findsOneWidget);
      expect(find.text('Disponible / En línea'), findsNWidgets(2));
    });

    testWidgets('Seleccionar impresora disponible y enviar a imprimir exitosamente', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));

      Printer? printedTo;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImpresoraSelectorDialog(
              buildPdf: (format) async => Uint8List.fromList([1, 2, 3]),
              documentName: 'cedula_123.pdf',
              listPrintersOverride: () async => [
                printerDefaultOffline,
                printerUsbAvailable,
              ],
              directPrintOverride: (printer, bytes) async {
                printedTo = printer;
                return true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Hacer clic sobre la impresora disponible
      await tester.tap(find.text('EPSON L3150 Series (USB)'));
      await tester.pumpAndSettle();

      // Clic en el botón Imprimir
      await tester.tap(find.widgetWithText(FilledButton, 'Imprimir'));
      await tester.pumpAndSettle();

      expect(printedTo, isNotNull);
      expect(printedTo?.name, 'EPSON L3150 Series (USB)');
    });

    testWidgets('Muestra advertencia de confirmación al intentar imprimir en impresora fuera de línea', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));

      bool printAttempted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImpresoraSelectorDialog(
              buildPdf: (format) async => Uint8List(5),
              documentName: 'cedula.pdf',
              listPrintersOverride: () async => [
                printerDefaultOffline,
                printerUsbAvailable,
              ],
              directPrintOverride: (printer, bytes) async {
                printAttempted = true;
                return true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Seleccionar la impresora fuera de línea
      await tester.tap(find.text('HP LaserJet Network (Desconectada)'));
      await tester.pumpAndSettle();

      // Clic en Imprimir
      await tester.tap(find.widgetWithText(FilledButton, 'Imprimir'));
      await tester.pumpAndSettle();

      // Debe aparecer el diálogo de advertencia
      expect(find.text('Impresora no disponible'), findsOneWidget);
      expect(find.textContaining('reporta estar desconectada o fuera de línea'), findsOneWidget);

      // Cancelar no debe ejecutar la impresión
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(printAttempted, isFalse);

      // Volver a dar clic en Imprimir y ahora aceptar
      await tester.tap(find.widgetWithText(FilledButton, 'Imprimir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Intentar de todos modos'));
      await tester.pumpAndSettle();

      expect(printAttempted, isTrue);
    });

    testWidgets('Muestra estado vacío amigable cuando no hay impresoras instaladas', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImpresoraSelectorDialog(
              buildPdf: (format) async => Uint8List(5),
              documentName: 'cedula.pdf',
              listPrintersOverride: () async => [],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No se detectaron impresoras instaladas'), findsOneWidget);
      expect(find.byIcon(Icons.print_disabled_outlined), findsOneWidget);
    });

    testWidgets('Maneja excepciones de comunicación con la impresora sin romper la aplicación', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImpresoraSelectorDialog(
              buildPdf: (format) async => Uint8List(5),
              documentName: 'cedula.pdf',
              listPrintersOverride: () async => [printerUsbAvailable],
              directPrintOverride: (printer, bytes) async {
                throw Exception('Error WinSpool: Conexión rechazada por dispositivo');
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Intentar imprimir
      await tester.tap(find.widgetWithText(FilledButton, 'Imprimir'));
      await tester.pumpAndSettle();

      // Debe mostrar diálogo de error amigable con botón de respaldo Guardar PDF
      expect(find.text('Error al imprimir'), findsOneWidget);
      expect(find.textContaining('Conexión rechazada por dispositivo'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Guardar como PDF'), findsOneWidget);
    });
  });
}
