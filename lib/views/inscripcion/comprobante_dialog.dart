import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../models/registro_concurso.dart';
import '../../models/concurso.dart';
import '../../core/utils/pdf_generator.dart';
import '../../core/theme/app_theme.dart';

class ComprobanteDialog extends StatefulWidget {
  final RegistroConcurso registro;
  final Concurso? concurso;

  const ComprobanteDialog({super.key, required this.registro, this.concurso});

  @override
  State<ComprobanteDialog> createState() => _ComprobanteDialogState();
}

class _ComprobanteDialogState extends State<ComprobanteDialog> {
  static const PdfPageFormat _pageFormat = PdfPageFormat(
    215 * PdfPageFormat.mm,
    215 * PdfPageFormat.mm,
  );

  bool _isPrinting = false;

  String get _pdfFileName =>
      'Cedula_Inscripcion_Folio_${widget.registro.folio}.pdf';

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    super.dispose();
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!mounted) return false;

    final isCtrlOrCmd = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (isCtrlOrCmd && event.logicalKey == LogicalKeyboardKey.keyP) {
      _imprimirCedula();
      return true;
    }
    return false;
  }

  Future<void> _imprimirCedula() async {
    if (_isPrinting || !mounted) return;
    setState(() => _isPrinting = true);
    try {
      await Printing.layoutPdf(
        name: _pdfFileName,
        format: _pageFormat,
        onLayout: (format) => PdfGenerator.generateComprobanteInscripcion(
          widget.registro,
          concurso: widget.concurso,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.dialogBodyBg,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 900,
        height: 750,
        color: AppTheme.dialogBodyBg,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.dialogHeaderBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                border:
                    Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.print, color: Colors.black87),
                  const SizedBox(width: 10),
                  Text(
                    'Cédula de Inscripción - Folio #${widget.registro.folio}',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.casart50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.casart200),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.keyboard_outlined,
                          size: 15,
                          color: AppTheme.casart800,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Ctrl + P para imprimir',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.casart800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PdfPreview(
                build: (format) => PdfGenerator.generateComprobanteInscripcion(
                  widget.registro,
                  concurso: widget.concurso,
                ),
                initialPageFormat: _pageFormat,
                canChangePageFormat: false,
                canChangeOrientation: false,
                previewPageMargin: const EdgeInsets.all(16),
                pdfFileName: _pdfFileName,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
