import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/excel_reports_service.dart';
import '../../models/concurso.dart';
import '../../providers/database_provider.dart';

import '../premios/acta_ganadores_dialog.dart';

enum TipoExportacionExcel {
  ganadoresFormatoA,
  ganadoresCompletoFormatoB,
  artesaniasInscritasFormatoC,
  artesaniasResumenFormatoD,
  actaGanadoresPdf,
  distintivosPdf,
}

class ExcelExportDropdown extends ConsumerStatefulWidget {
  final Concurso concurso;
  final bool isDense;

  const ExcelExportDropdown({
    super.key,
    required this.concurso,
    this.isDense = false,
  });

  @override
  ConsumerState<ExcelExportDropdown> createState() => _ExcelExportDropdownState();
}

class _ExcelExportDropdownState extends ConsumerState<ExcelExportDropdown> {
  bool _isExporting = false;

  Future<void> _handleExport(TipoExportacionExcel tipo) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final dbHelper = ref.read(appDatabaseProvider);
      final premioRepo = ref.read(premioRepositoryProvider);
      final registroRepo = ref.read(registroRepositoryProvider);

      switch (tipo) {
        case TipoExportacionExcel.ganadoresFormatoA:
          await ExcelReportsService.exportarGanadoresFormatoA(
            context: context,
            concurso: widget.concurso,
            dbHelper: dbHelper,
            premioRepo: premioRepo,
          );
          break;
        case TipoExportacionExcel.ganadoresCompletoFormatoB:
          await ExcelReportsService.exportarGanadoresCompletoFormatoB(
            context: context,
            concurso: widget.concurso,
            dbHelper: dbHelper,
            premioRepo: premioRepo,
          );
          break;
        case TipoExportacionExcel.artesaniasInscritasFormatoC:
          await ExcelReportsService.exportarArtesaniasInscritasFormatoC(
            context: context,
            concurso: widget.concurso,
            dbHelper: dbHelper,
            registroRepo: registroRepo,
          );
          break;
        case TipoExportacionExcel.artesaniasResumenFormatoD:
          await ExcelReportsService.exportarArtesaniasResumenFormatoD(
            context: context,
            concurso: widget.concurso,
            dbHelper: dbHelper,
            registroRepo: registroRepo,
          );
          break;
        case TipoExportacionExcel.actaGanadoresPdf:
        case TipoExportacionExcel.distintivosPdf:
          final ganadores = await premioRepo.getGanadoresByConcurso(widget.concurso.id!);
          if (ganadores.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No hay premiaciones registradas para este concurso aún.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } else {
            if (mounted) {
              await showDialog(
                context: context,
                builder: (ctx) => ActaGanadoresDialog(
                  concurso: widget.concurso,
                  ganadores: ganadores,
                  initialType: tipo == TipoExportacionExcel.distintivosPdf
                      ? TipoDocumentoGanadores.distintivos
                      : TipoDocumentoGanadores.actaOficial,
                ),
              );
            }
          }
          break;
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isExporting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF059669),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 8),
            Text(
              'Exportando...',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 6,
        ),
      ),
      child: PopupMenuButton<TipoExportacionExcel>(
        tooltip: 'Exportar a Microsoft Excel (.xlsx)',
        offset: const Offset(0, 42),
        onSelected: _handleExport,
        itemBuilder: (ctx) => [
          const PopupMenuItem(
            value: TipoExportacionExcel.ganadoresFormatoA,
            child: Row(
              children: [
                Icon(Icons.emoji_events_outlined, color: Color(0xFF059669), size: 18),
                SizedBox(width: 10),
                Text(
                  'Exportar Ganadores (F-A)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
          ),
          const PopupMenuItem(
            value: TipoExportacionExcel.ganadoresCompletoFormatoB,
            child: Row(
              children: [
                Icon(Icons.workspace_premium_outlined, color: Color(0xFF0D9488), size: 18),
                SizedBox(width: 10),
                Text(
                  'Ganadores Completo (F-B)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: TipoExportacionExcel.artesaniasInscritasFormatoC,
            child: Row(
              children: [
                Icon(Icons.format_list_bulleted, color: Color(0xFF4F46E5), size: 18),
                SizedBox(width: 10),
                Text(
                  'Artesanías Inscritas (F-C)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
          ),
          const PopupMenuItem(
            value: TipoExportacionExcel.artesaniasResumenFormatoD,
            child: Row(
              children: [
                Icon(Icons.summarize_outlined, color: Color(0xFF7C3AED), size: 18),
                SizedBox(width: 10),
                Text(
                  'Artesanías Resumen (F-D)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: TipoExportacionExcel.actaGanadoresPdf,
            child: Row(
              children: [
                Icon(Icons.picture_as_pdf, color: Color(0xFFDC2626), size: 18),
                SizedBox(width: 10),
                Text(
                  'Acta de Ganadores (PDF)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
          ),
          const PopupMenuItem(
            value: TipoExportacionExcel.distintivosPdf,
            child: Row(
              children: [
                Icon(Icons.badge_outlined, color: Color(0xFFD97706), size: 18),
                SizedBox(width: 10),
                Text(
                  'Distintivos de Pieza (PDF)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isDense ? 12 : 14,
            vertical: widget.isDense ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF059669), // Emerald 600
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.file_download_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Exportar Excel',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: Colors.white.withValues(alpha: 0.9), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
