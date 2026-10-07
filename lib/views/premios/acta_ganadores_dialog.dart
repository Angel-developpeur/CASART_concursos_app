import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../models/concurso.dart';
import '../../core/utils/pdf_generator.dart';
import '../../core/theme/app_theme.dart';

enum TipoDocumentoGanadores {
  actaOficial,
  distintivos,
}

class ActaGanadoresDialog extends StatefulWidget {
  final Concurso concurso;
  final List<Map<String, dynamic>> ganadores;
  final TipoDocumentoGanadores initialType;

  const ActaGanadoresDialog({
    super.key,
    required this.concurso,
    required this.ganadores,
    this.initialType = TipoDocumentoGanadores.actaOficial,
  });

  @override
  State<ActaGanadoresDialog> createState() => _ActaGanadoresDialogState();
}

class _ActaGanadoresDialogState extends State<ActaGanadoresDialog> {
  late TipoDocumentoGanadores _currentType;

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;
  }

  String _cleanFileName(String name) {
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  @override
  Widget build(BuildContext context) {
    final concursoNombreClean = _cleanFileName(widget.concurso.nombre);
    final isActa = _currentType == TipoDocumentoGanadores.actaOficial;

    return Dialog(
      backgroundColor: AppTheme.dialogBodyBg,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 1050,
        height: 820,
        color: AppTheme.dialogBodyBg,
        child: Column(
          children: [
            // Header del diálogo con selector de vista
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.dialogHeaderBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isActa ? Icons.description_outlined : Icons.badge_outlined,
                      color: Colors.amber.shade900,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isActa
                              ? 'Acta Oficial de Ganadores (PDF)'
                              : 'Distintivos de Piezas Premiadas (PDF)',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.concurso.nombre} • ${widget.ganadores.length} premios asignados',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Selector entre Acta y Distintivos
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            if (_currentType != TipoDocumentoGanadores.actaOficial) {
                              setState(() => _currentType = TipoDocumentoGanadores.actaOficial);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActa ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: isActa
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.table_chart_outlined,
                                  size: 16,
                                  color: isActa ? AppTheme.casart800 : Colors.grey.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Acta de Resultados',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isActa ? FontWeight.bold : FontWeight.normal,
                                    color: isActa ? AppTheme.casart800 : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            if (_currentType != TipoDocumentoGanadores.distintivos) {
                              setState(() => _currentType = TipoDocumentoGanadores.distintivos);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: !isActa ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: !isActa
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.badge_outlined,
                                  size: 16,
                                  color: !isActa ? AppTheme.casart800 : Colors.grey.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Distintivos de Pieza',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: !isActa ? FontWeight.bold : FontWeight.normal,
                                    color: !isActa ? AppTheme.casart800 : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Visor PDF interactivo (vista previa, impresión nativa y descarga)
            Expanded(
              child: KeyedSubtree(
                key: ValueKey(_currentType),
                child: PdfPreview(
                  build: (format) {
                    if (_currentType == TipoDocumentoGanadores.actaOficial) {
                      return PdfGenerator.generateActaGanadores(
                        concurso: widget.concurso,
                        ganadores: widget.ganadores,
                      );
                    } else {
                      return PdfGenerator.generateDistintivosGanadores(
                        concurso: widget.concurso,
                        ganadores: widget.ganadores,
                      );
                    }
                  },
                  initialPageFormat: isActa
                      ? PdfPageFormat.letter.landscape
                      : PdfPageFormat.letter,
                  canChangePageFormat: false,
                  previewPageMargin: const EdgeInsets.all(16),
                  pdfFileName: isActa
                      ? 'Acta_Ganadores_${concursoNombreClean}_${widget.concurso.ejercicio}.pdf'
                      : 'Distintivos_Piezas_Premiadas_${concursoNombreClean}_${widget.concurso.ejercicio}.pdf',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
