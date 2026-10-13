import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/logging/app_logger.dart';

/// Diálogo asistido de selección de impresoras y guardado en PDF.
///
/// Previene los congelamientos ("No responde") en Windows 11 y macOS
/// originados cuando la impresora predeterminada del sistema está desconectada u offline.
class ImpresoraSelectorDialog extends StatefulWidget {
  final FutureOr<Uint8List> Function(PdfPageFormat format) buildPdf;
  final String documentName;
  final PdfPageFormat pageFormat;

  /// Delegados opcionales para pruebas unitarias
  final Future<List<Printer>> Function()? listPrintersOverride;
  final Future<bool> Function(Printer printer, Uint8List bytes)? directPrintOverride;

  const ImpresoraSelectorDialog({
    super.key,
    required this.buildPdf,
    required this.documentName,
    this.pageFormat = PdfPageFormat.standard,
    this.listPrintersOverride,
    this.directPrintOverride,
  });

  /// Abre el diálogo asistido de selección de impresoras y ejecuta la impresión.
  static Future<bool> imprimirConAsistente({
    required BuildContext context,
    required FutureOr<Uint8List> Function(PdfPageFormat format) buildPdf,
    required String documentName,
    PdfPageFormat pageFormat = PdfPageFormat.standard,
    Future<List<Printer>> Function()? listPrintersOverride,
    Future<bool> Function(Printer printer, Uint8List bytes)? directPrintOverride,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ImpresoraSelectorDialog(
        buildPdf: buildPdf,
        documentName: documentName,
        pageFormat: pageFormat,
        listPrintersOverride: listPrintersOverride,
        directPrintOverride: directPrintOverride,
      ),
    );
    return result ?? false;
  }

  /// Permite guardar el documento directamente como archivo PDF en disco.
  static Future<bool> guardarComoPdf({
    required BuildContext context,
    required FutureOr<Uint8List> Function() getPdfBytes,
    required String defaultFileName,
    String dialogTitle = 'Guardar documento en PDF',
  }) async {
    try {
      final bytes = await getPdfBytes();
      final uri = await FilePicker.saveFile(
        dialogTitle: dialogTitle,
        fileName: defaultFileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (uri == null) return false;

      final String pathDisplay = uri.toFilePath();
      AppLogger.info(
        'Documento PDF guardado exitosamente en: $pathDisplay',
        category: 'IMPRESION',
        data: {'archivo': defaultFileName, 'ruta': pathDisplay},
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Documento PDF guardado con éxito:\n$pathDisplay'),
            backgroundColor: AppTheme.verdeSuccess,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return true;
    } catch (e) {
      AppLogger.error(
        'Error al guardar archivo PDF "$defaultFileName": $e',
        category: 'IMPRESION',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el archivo PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  @override
  State<ImpresoraSelectorDialog> createState() => _ImpresoraSelectorDialogState();
}

class _ImpresoraSelectorDialogState extends State<ImpresoraSelectorDialog> {
  bool _isLoadingPrinters = true;
  String? _errorMessage;
  List<Printer> _printers = [];
  Printer? _selectedPrinter;
  bool _isProcessing = false;
  String _processingMessage = '';

  @override
  void initState() {
    super.initState();
    _cargarImpresoras();
  }

  Future<void> _cargarImpresoras() async {
    setState(() {
      _isLoadingPrinters = true;
      _errorMessage = null;
    });

    try {
      final printers = widget.listPrintersOverride != null
          ? await widget.listPrintersOverride!()
          : await Printing.listPrinters();

      // Ordenar:
      // 1. Predeterminada primero
      // 2. Disponibles antes de no disponibles
      // 3. Alfabético por nombre
      final sorted = List<Printer>.from(printers);
      sorted.sort((a, b) {
        if (a.isDefault && !b.isDefault) return -1;
        if (!a.isDefault && b.isDefault) return 1;
        if (a.isAvailable && !b.isAvailable) return -1;
        if (!a.isAvailable && b.isAvailable) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      if (mounted) {
        setState(() {
          _printers = sorted;
          _isLoadingPrinters = false;
          if (_printers.isNotEmpty) {
            // Seleccionar por defecto la primera disponible, o la default si está disponible
            final defaultAvailable = _printers.where((p) => p.isDefault && p.isAvailable).firstOrNull;
            final anyAvailable = _printers.where((p) => p.isAvailable).firstOrNull;
            _selectedPrinter = defaultAvailable ?? anyAvailable ?? _printers.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'No se pudieron consultar las impresoras del sistema: $e';
          _isLoadingPrinters = false;
        });
      }
    }
  }

  Future<void> _ejecutarImpresion(Printer printer) async {
    if (!printer.isAvailable) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
              SizedBox(width: 10),
              Text('Impresora no disponible', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'La impresora "${printer.name}" reporta estar desconectada o fuera de línea.\n\n'
            'Si intentas imprimir, el sistema podría tardar en responder o cancelar el trabajo.\n\n'
            '¿Deseas intentar enviar la impresión de todos modos?',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade900),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Intentar de todos modos'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
    }

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Enviando documento a "${printer.name}"...';
    });

    try {
      final pdfBytes = await widget.buildPdf(widget.pageFormat);

      bool result = false;
      if (widget.directPrintOverride != null) {
        result = await widget.directPrintOverride!(printer, pdfBytes);
      } else {
        result = await Future.any<bool>([
          Future(() async => await Printing.directPrintPdf(
            printer: printer,
            onLayout: (_) async => pdfBytes,
            name: widget.documentName,
            format: widget.pageFormat,
            usePrinterSettings: false,
          )),
          Future.delayed(const Duration(seconds: 15)).then((_) {
            throw TimeoutException('Tiempo de espera agotado al conectar con la impresora.');
          }),
        ]);
      }

      AppLogger.info(
        'Impresión enviada exitosamente a "${printer.name}"',
        category: 'IMPRESION',
        data: {'impresora': printer.name, 'documento': widget.documentName},
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Trabajo enviado a la impresora "${printer.name}" exitosamente.'),
          backgroundColor: AppTheme.verdeSuccess,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      AppLogger.error(
        'Fallo al enviar impresión a "${printer.name}": $e',
        category: 'IMPRESION',
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text('Error al imprimir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'No se pudo completar el envío del documento a "${printer.name}".\n\n'
            'Detalle: $e\n\n'
            'Verifica que la impresora esté encendida, conectada por cable o red, y sin atascos de papel.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.download_rounded),
              label: const Text('Guardar como PDF'),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await ImpresoraSelectorDialog.guardarComoPdf(
                  context: context,
                  getPdfBytes: () => widget.buildPdf(widget.pageFormat),
                  defaultFileName: widget.documentName,
                );
              },
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _abrirDialogoSistema() async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Abriendo diálogo de impresión del sistema...';
    });

    try {
      final pdfBytes = await widget.buildPdf(widget.pageFormat);
      final res = await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: widget.documentName,
        format: widget.pageFormat,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (res) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en el diálogo del sistema: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _guardarPdf() async {
    await ImpresoraSelectorDialog.guardarComoPdf(
      context: context,
      getPdfBytes: () => widget.buildPdf(widget.pageFormat),
      defaultFileName: widget.documentName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 650,
        height: 620,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecera
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.dialogHeaderBg,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.casart100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.print_rounded, color: AppTheme.casart800, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Seleccionar Impresora',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Elige una impresora disponible para imprimir sin bloqueos',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualizar lista',
                        icon: const Icon(Icons.refresh, color: Colors.black54),
                        onPressed: _isLoadingPrinters || _isProcessing ? null : _cargarImpresoras,
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Contenido principal
                Expanded(
                  child: _buildContenido(),
                ),

                // Pie del diálogo con acciones alternativas
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 8,
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Guardar PDF'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade800,
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        onPressed: _isProcessing ? null : _guardarPdf,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.settings_outlined, size: 17),
                            label: const Text('Diálogo del sistema'),
                            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                            onPressed: _isProcessing ? null : _abrirDialogoSistema,
                          ),
                          FilledButton.icon(
                            icon: const Icon(Icons.print, size: 18),
                            label: const Text('Imprimir'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.casart800,
                            ),
                            onPressed: _selectedPrinter == null || _isProcessing
                                ? null
                                : () => _ejecutarImpresion(_selectedPrinter!),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Overlay de proceso en curso
            if (_isProcessing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: AppTheme.casart800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _processingMessage,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Por favor espera un momento...',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContenido() {
    if (_isLoadingPrinters) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 3, color: AppTheme.casart800),
              SizedBox(height: 16),
              Text(
                'Detectando impresoras del sistema...',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.amber.shade800),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                onPressed: _cargarImpresoras,
              ),
            ],
          ),
        ),
      );
    }

    if (_printers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.print_disabled_outlined, size: 54, color: Colors.grey.shade400),
              const SizedBox(height: 14),
              const Text(
                'No se detectaron impresoras instaladas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 6),
              Text(
                'Conecta una impresora por cable USB o enciende tu impresora de red.\nTambién puedes guardar el archivo en formato PDF.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_rounded),
                label: const Text('Guardar como PDF'),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.casart800),
                onPressed: _guardarPdf,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: _printers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final printer = _printers[index];
        final isSelected = _selectedPrinter?.url == printer.url;

        return Material(
          color: isSelected ? AppTheme.casart50 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected
                  ? AppTheme.casart800
                  : (printer.isAvailable ? Colors.grey.shade300 : Colors.grey.shade200),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() => _selectedPrinter = printer);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Icono indicador de estado
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: printer.isAvailable
                          ? AppTheme.verdeLight
                          : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      printer.isAvailable ? Icons.print_rounded : Icons.print_disabled_rounded,
                      color: printer.isAvailable ? AppTheme.verdeSuccess : Colors.grey.shade500,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Nombre e información
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                printer.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: printer.isAvailable ? Colors.black87 : Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (printer.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.casart100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.casart300),
                                ),
                                child: const Text(
                                  'Predeterminada',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.casart800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: printer.isAvailable ? AppTheme.verdeSuccess : Colors.amber.shade700,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              printer.isAvailable ? 'Disponible / En línea' : 'Sin conexión / Fuera de línea',
                              style: TextStyle(
                                fontSize: 11,
                                color: printer.isAvailable ? AppTheme.verdeSuccess : Colors.amber.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (printer.model != null && printer.model!.isNotEmpty) ...[
                              Text(
                                ' • ${printer.model}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Selector radial
                  Radio<String>(
                    value: printer.url,
                    groupValue: _selectedPrinter?.url,
                    activeColor: AppTheme.casart800,
                    onChanged: (val) {
                      setState(() => _selectedPrinter = printer);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
