import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../models/registro_concurso.dart';
import '../../models/concurso.dart';
import '../../core/utils/pdf_generator.dart';
import '../../core/theme/app_theme.dart';

class ComprobanteDialog extends StatelessWidget {
  final RegistroConcurso registro;
  final Concurso? concurso;

  const ComprobanteDialog({super.key, required this.registro, this.concurso});

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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.print, color: Colors.black87),
                  const SizedBox(width: 10),
                  Text(
                    'Cédula de Inscripción - Folio #${registro.folio}',
                    style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
            ),
            Expanded(
              child: PdfPreview(
                build: (format) => PdfGenerator.generateComprobanteInscripcion(
                  registro,
                  concurso: concurso,
                ),
                initialPageFormat: const PdfPageFormat(
                  215 * PdfPageFormat.mm,
                  215 * PdfPageFormat.mm,
                ),
                canChangePageFormat: false,
                canChangeOrientation: false,
                previewPageMargin: const EdgeInsets.all(16),
                pdfFileName: 'Cedula_Inscripcion_Folio_${registro.folio}.pdf',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
