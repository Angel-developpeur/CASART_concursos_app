import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import '../../providers/concursos_provider.dart';
import '../../models/concurso.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/excel_reports_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/logging/app_logger.dart';
import '../../core/services/update_service.dart';
import '../common/update_dialog.dart';
import 'log_viewer_dialog.dart';

class BackupView extends ConsumerStatefulWidget {
  const BackupView({super.key});

  @override
  ConsumerState<BackupView> createState() => _BackupViewState();
}

class _BackupViewState extends ConsumerState<BackupView> {
  String _dbPath = '';
  int _dbSizeInBytes = 0;
  bool _isLoading = false;
  int? _selectedConcursoIdForExport;

  @override
  void initState() {
    super.initState();
    _loadDatabaseInfo();
  }

  Future<void> _loadDatabaseInfo() async {
    final dbHelper = ref.read(appDatabaseProvider);
    final path = await dbHelper.getDatabasePath();
    final file = File(path);
    int size = 0;
    if (await file.exists()) {
      size = await file.length();
    }

    if (mounted) {
      setState(() {
        _dbPath = path;
        _dbSizeInBytes = size;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _respaldarEnUsb() async {
    try {
      final dbHelper = ref.read(appDatabaseProvider);
      final currentPath = await dbHelper.getDatabasePath();
      final currentFile = File(currentPath);
      if (!await currentFile.exists()) {
        throw Exception('No se encontró el archivo de base de datos local');
      }

      final bytes = await currentFile.readAsBytes();
      final now = DateFormat('yyyy_MM_dd_HHmm').format(DateTime.now());
      final defaultFileName = 'CASART_Concursos_Respaldo_$now.db';

      setState(() => _isLoading = true);

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Guardar respaldo de base de datos en USB o disco',
        fileName: defaultFileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite'],
      );

      if (uri == null) return;

      AppLogger.create(
        'Respaldo de base de datos generado exitosamente en: ${uri.toFilePath()}',
        category: 'RESPALDO',
        data: {'destino': uri.toFilePath()},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Respaldo completado con éxito en: ${uri.toFilePath()}',
          ),
          backgroundColor: AppTheme.casart800,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error al realizar respaldo en USB/disco: $e',
        category: 'RESPALDO',
        error: e,
        stackTrace: stack,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al realizar respaldo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _loadDatabaseInfo();
      }
    }
  }

  Future<void> _restaurarBaseDatos() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('¿Restaurar Base de Datos?'),
          ],
        ),
        content: const Text(
          'ADVERTENCIA: Esta acción reemplazará toda la información actual de la aplicación con la del archivo de respaldo que selecciones.\n\n¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            style: AppTheme.cancelButtonStyle,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, Seleccionar Archivo'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final selectedFiles = await FilePicker.pickFiles(
        dialogTitle: 'Seleccionar archivo de respaldo (.db)',
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite'],
      );

      if (selectedFiles.isEmpty || selectedFiles.first.path == null) return;

      final backupFilePath = selectedFiles.first.path!;
      final backupFile = File(backupFilePath);

      if (!await backupFile.exists()) {
        throw Exception('El archivo seleccionado no existe');
      }

      setState(() => _isLoading = true);

      // Cerrar y reemplazar
      final dbHelper = ref.read(appDatabaseProvider);
      final currentDb = await dbHelper.database;
      await currentDb.close();

      final currentPath = await dbHelper.getDatabasePath();
      await backupFile.copy(currentPath);

      AppLogger.update(
        'Base de datos restaurada completamente desde archivo de respaldo: $backupFilePath',
        category: 'RESTAURACION',
        data: {'origen': backupFilePath, 'destino': currentPath},
      );

      // Forzar relectura
      ref.invalidate(concursosListProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '✓ Base de datos restaurada correctamente. Recargando información...',
          ),
          backgroundColor: AppTheme.casart800,
        ),
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error al restaurar base de datos: $e',
        category: 'RESTAURACION',
        error: e,
        stackTrace: stack,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al restaurar base de datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _loadDatabaseInfo();
      }
    }
  }

  Future<void> _exportarConcursoAExcel(Concurso concurso) async {
    setState(() => _isLoading = true);

    try {
      final regRepo = ref.read(registroRepositoryProvider);
      final premioRepo = ref.read(premioRepositoryProvider);

      final registros = await regRepo.getRegistrosByConcurso(concurso.id!);
      final premios = await premioRepo.getPremiosByConcurso(concurso.id!);

      final excel = Excel.createExcel();

      // ==========================================
      // 1. Hoja: Inscripciones
      // ==========================================
      final Sheet sheetInscripciones = excel['Inscripciones'];
      excel.setDefaultSheet('Inscripciones');
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      sheetInscripciones.appendRow([
        TextCellValue('Folio'),
        TextCellValue('Artesano'),
        TextCellValue('CURP'),
        TextCellValue('Teléfono'),
        TextCellValue('Municipio'),
        TextCellValue('Localidad'),
        TextCellValue('Etnia'),
        TextCellValue('Estado Civil'),
        TextCellValue('Pieza 1 - Nombre'),
        TextCellValue('Pieza 1 - Rama'),
        TextCellValue('Pieza 1 - Categoría'),
        TextCellValue('Pieza 1 - Subcategoría'),
        TextCellValue('Pieza 1 - Costo Producción'),
        TextCellValue('Pieza 1 - Precio Venta'),
        TextCellValue('Pieza 1 - Material'),
        TextCellValue('Pieza 1 - Tiempo Elaboración'),
        TextCellValue('Pieza 2 - Nombre'),
        TextCellValue('Pieza 2 - Rama'),
        TextCellValue('Pieza 2 - Categoría'),
        TextCellValue('Pieza 2 - Subcategoría'),
        TextCellValue('Pieza 2 - Costo Producción'),
        TextCellValue('Pieza 2 - Precio Venta'),
        TextCellValue('Pieza 2 - Material'),
        TextCellValue('Pieza 2 - Tiempo Elaboración'),
        TextCellValue('Fecha Registro'),
      ]);

      for (final r in registros) {
        final a = r.artesano;
        final p1 = r.artesania1;
        final p2 = r.artesania2;

        sheetInscripciones.appendRow([
          IntCellValue(r.folio),
          TextCellValue(a?.nombreCompleto ?? ''),
          TextCellValue(a?.curp ?? ''),
          TextCellValue(a?.telefono ?? ''),
          TextCellValue(a?.municipio ?? ''),
          TextCellValue(a?.localidad ?? ''),
          TextCellValue(a?.etniaNombre ?? ''),
          TextCellValue(a?.estadoCivilNombre ?? ''),
          TextCellValue(p1?.nombre ?? ''),
          TextCellValue(p1?.ramaNombre ?? ''),
          TextCellValue(p1?.categoriaNombre ?? ''),
          TextCellValue(p1?.subcategoriaNombre ?? ''),
          DoubleCellValue(p1?.costoProduccion ?? 0.0),
          DoubleCellValue(p1?.costoVenta ?? 0.0),
          TextCellValue(p1?.materialElaboracion ?? ''),
          TextCellValue(
            p1 != null ? '${p1.tiempoElaboracion} ${p1.plazoElaboracion}' : '',
          ),
          TextCellValue(p2?.nombre ?? ''),
          TextCellValue(p2?.ramaNombre ?? ''),
          TextCellValue(p2?.categoriaNombre ?? ''),
          TextCellValue(p2?.subcategoriaNombre ?? ''),
          DoubleCellValue(p2?.costoProduccion ?? 0.0),
          DoubleCellValue(p2?.costoVenta ?? 0.0),
          TextCellValue(p2?.materialElaboracion ?? ''),
          TextCellValue(
            p2 != null ? '${p2.tiempoElaboracion} ${p2.plazoElaboracion}' : '',
          ),
          TextCellValue(Formatters.formatDateTime(r.createdAt)),
        ]);
      }

      // ==========================================
      // 2. Hoja: Aportaciones
      // ==========================================
      final Sheet sheetAportaciones = excel['Aportaciones'];
      sheetAportaciones.appendRow([
        TextCellValue('ID'),
        TextCellValue('Institución / Aportante'),
        TextCellValue('Monto Aportado (\$ MXN)'),
      ]);

      for (final ap in concurso.aportaciones) {
        sheetAportaciones.appendRow([
          IntCellValue(ap.id ?? 0),
          TextCellValue(ap.nombre),
          DoubleCellValue(ap.cantidad),
        ]);
      }

      // Total aportaciones
      sheetAportaciones.appendRow([
        TextCellValue(''),
        TextCellValue('TOTAL APORTACIONES:'),
        DoubleCellValue(concurso.totalAportaciones),
      ]);

      // ==========================================
      // 3. Hoja: Bolsa de Premios
      // ==========================================
      final Sheet sheetPremios = excel['Premios'];
      sheetPremios.appendRow([
        TextCellValue('ID'),
        TextCellValue('Nombre del Premio'),
        TextCellValue('Tipo de Premio'),
        TextCellValue('Monto (\$ MXN)'),
        TextCellValue('Categoría Asignada'),
        TextCellValue('Subcategoría'),
      ]);

      for (final pr in premios) {
        sheetPremios.appendRow([
          IntCellValue(pr.id ?? 0),
          TextCellValue(pr.nombre),
          TextCellValue(pr.tipoPremioNombre ?? ''),
          DoubleCellValue(pr.monto),
          TextCellValue(pr.categoriaNombre ?? 'Global'),
          TextCellValue(pr.subcategoriaNombre ?? 'Todas'),
        ]);
      }

      // Auto-adaptar columnas al contenido en todas las hojas
      for (final s in excel.sheets.values) {
        ExcelReportsService.autoFitColumns(s);
      }

      final fileBytes = excel.save();
      if (fileBytes == null) {
        throw Exception('No se pudo generar el archivo Excel.');
      }

      final sanitizedName = concurso.nombre
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');
      final defaultFileName =
          'CASART_${sanitizedName}_${concurso.ejercicio}.xlsx';

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Guardar Cédulas en Excel (.xlsx)',
        fileName: defaultFileName,
        bytes: Uint8List.fromList(fileBytes),
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (uri == null) return;

      AppLogger.info(
        'Archivo Excel generado exitosamente para Concurso "${concurso.nombre}": ${uri.toFilePath()}',
        category: 'EXPORTACION',
        data: {'concurso': concurso.nombre, 'destino': uri.toFilePath()},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Archivo Excel generado con éxito:\n${uri.toFilePath()}',
          ),
          backgroundColor: AppTheme.verdeSuccess,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error al exportar a Excel: $e',
        category: 'EXPORTACION',
        error: e,
        stackTrace: stack,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar a Excel: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportarCorteJson(Concurso concurso) async {
    setState(() => _isLoading = true);

    try {
      final regRepo = ref.read(registroRepositoryProvider);
      final premioRepo = ref.read(premioRepositoryProvider);

      final registros = await regRepo.getRegistrosByConcurso(concurso.id!);
      final premios = await premioRepo.getPremiosByConcurso(concurso.id!);
      final ganadores = await premioRepo.getGanadoresByConcurso(concurso.id!);

      final totalPiezas = registros.fold<int>(
        0,
        (sum, r) => sum + 1 + (r.artesania2 != null ? 1 : 0),
      );

      final payload = {
        'export_metadata': {
          'sistema': 'CASART Concursos Desktop Standalone',
          'version': '1.0.0',
          'fecha_exportacion': DateTime.now().toIso8601String(),
          'total_inscritos': registros.length,
          'total_piezas': totalPiezas,
          'total_premios': premios.length,
          'total_ganadores': ganadores.length,
        },
        'concurso': concurso.toMap(),
        'inscripciones': registros.map((r) {
          final m = r.toMap();
          if (r.artesano != null) m['artesano'] = r.artesano!.toMap();
          if (r.artesania1 != null) m['artesania1'] = r.artesania1!.toMap();
          if (r.artesania2 != null) m['artesania2'] = r.artesania2!.toMap();
          return m;
        }).toList(),
        'premios': premios.map((p) => p.toMap()).toList(),
        'ganadores': ganadores,
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      final sanitizedName = concurso.nombre
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');
      final now = DateFormat('yyyy_MM_dd_HHmm').format(DateTime.now());
      final defaultFileName = 'CASART_Corte_${sanitizedName}_$now.json';

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Guardar Corte para Sistema Web (.json)',
        fileName: defaultFileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (uri == null) return;

      AppLogger.info(
        'Corte JSON exportado con éxito para Concurso "${concurso.nombre}": ${uri.toFilePath()} ($totalPiezas piezas de ${registros.length} artesanos)',
        category: 'EXPORTACION',
        data: {
          'totalPiezas': totalPiezas,
          'totalInscritos': registros.length,
          'destino': uri.toFilePath(),
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Archivo de corte JSON exportado con éxito:\n${uri.toFilePath()}\n($totalPiezas piezas de ${registros.length} artesanos)',
          ),
          backgroundColor: AppTheme.azulAccent,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error al exportar corte JSON: $e',
        category: 'EXPORTACION',
        error: e,
        stackTrace: stack,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar corte JSON: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final concursosAsync = ref.watch(concursosListProvider);
    final activeConcursoId = ref.watch(selectedConcursoIdProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // HEADER
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Respaldos y Exportación',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gestión de copias de seguridad de la base de datos local y exportación a hojas de cálculo',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // SECCIÓN 1: ESTADO Y RESPALDO DE BASE DE DATOS
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.storage,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Base de Datos Local',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Autocontenida en este equipo',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Divider(height: 32),

                    // DETALLES DEL ARCHIVO
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.folder_open,
                                size: 20,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Ruta de almacenamiento:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SelectableText(
                                  _dbPath,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.open_in_new, size: 18),
                                tooltip: 'Abrir carpeta en el Explorador',
                                onPressed: () {
                                  if (_dbPath.isNotEmpty) {
                                    Process.run('explorer.exe', [
                                      File(_dbPath).parent.path,
                                    ]);
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.analytics_outlined,
                                size: 20,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Tamaño actual:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatFileSize(_dbSizeInBytes),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.verdeSuccess,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // BOTONES DE ACCIÓN
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.usb),
                          label: const Text('Hacer Respaldo en USB / Disco'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isLoading ? null : _respaldarEnUsb,
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.restore_page_outlined),
                          label: const Text('Restaurar desde Respaldo (.db)'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                          onPressed: _isLoading ? null : _restaurarBaseDatos,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // SECCIÓN 2: EXPORTACIÓN A EXCEL
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.verdeLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.table_chart,
                            color: AppTheme.verdeSuccess,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Exportar en Excel',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Generar excel con datos de  Inscripción, Aportaciones y Premios',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Divider(height: 32),

                    concursosAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Text(
                        'Error al cargar concursos: $err',
                        style: const TextStyle(color: Colors.red),
                      ),
                      data: (concursos) {
                        if (concursos.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'No hay concursos registrados en la base de datos para exportar.',
                            ),
                          );
                        }

                        final selectedId =
                            _selectedConcursoIdForExport ??
                            activeConcursoId ??
                            concursos.first.id;
                        final currentConcurso = concursos.firstWhere(
                          (c) => c.id == selectedId,
                          orElse: () => concursos.first,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isCompact = constraints.maxWidth < 650;
                                final dropdownWidget = DropdownButtonFormField<int>(
                                  initialValue: currentConcurso.id,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Selecciona el Concurso a Exportar',
                                    prefixIcon: Icon(
                                      Icons.emoji_events_outlined,
                                    ),
                                  ),
                                  items: concursos.map((c) {
                                    return DropdownMenuItem<int>(
                                      value: c.id,
                                      child: Text(
                                        '${c.nombre} (${c.ejercicio})',
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(
                                        () => _selectedConcursoIdForExport =
                                            val,
                                      );
                                    }
                                  },
                                );

                                final buttonWidget = ElevatedButton.icon(
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.download),
                                  label: const Text(
                                    'Exportar a Excel (.xlsx)',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    backgroundColor: AppTheme.verdeSuccess,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _isLoading
                                      ? null
                                      : () => _exportarConcursoAExcel(
                                          currentConcurso,
                                        ),
                                );

                                if (isCompact) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      dropdownWidget,
                                      const SizedBox(height: 12),
                                      buttonWidget,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: dropdownWidget,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 2,
                                      child: buttonWidget,
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.ocreAccentLight,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.ocreAccentBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: AppTheme.ocreAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'El archivo generado contendrá 3 pestañas: "Inscripciones" (datos del artesano, curp y piezas), "Aportaciones" (fondos económicos de instituciones) y "Premios" (bolsa asignada).',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.ocre10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // SECCIÓN 3: SINCRONIZACIÓN DE RETORNO WEB (JSON)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.azulLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.cloud_upload_outlined,
                            color: AppTheme.azulAccent,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Exportar en Yeizon',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Exporta un corte completo',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Divider(height: 32),

                    concursosAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Text(
                        'Error al cargar concursos: $err',
                        style: const TextStyle(color: Colors.red),
                      ),
                      data: (concursos) {
                        if (concursos.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'No hay concursos registrados en la base de datos para exportar.',
                            ),
                          );
                        }

                        final selectedId =
                            _selectedConcursoIdForExport ??
                            activeConcursoId ??
                            concursos.first.id;
                        final currentConcurso = concursos.firstWhere(
                          (c) => c.id == selectedId,
                          orElse: () => concursos.first,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<int>(
                                    initialValue: currentConcurso.id,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Selecciona el Concurso para Corte Web',
                                      prefixIcon: Icon(
                                        Icons.emoji_events_outlined,
                                      ),
                                    ),
                                    items: concursos.map((c) {
                                      return DropdownMenuItem<int>(
                                        value: c.id,
                                        child: Text(
                                          '${c.nombre} (${c.ejercicio})',
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(
                                          () => _selectedConcursoIdForExport =
                                              val,
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    icon: _isLoading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.sync_alt),
                                    label: const Text('Exportar (.json)'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 16,
                                      ),
                                      backgroundColor: AppTheme.azulAccent,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: _isLoading
                                        ? null
                                        : () => _exportarCorteJson(
                                            currentConcurso,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.azulLight,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.azulBorder),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: AppTheme.azulAccent,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Dtos del concurso',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.azul10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ==========================================
            // 5. BITÁCORA Y REGISTRO DE LOGS (.LOG)
            // ==========================================
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.casart800.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            color: AppTheme.casart800,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bitácora del Sistema y Archivos de Logs (.log)',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.casart800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Auditoría continua de creaciones, modificaciones, eliminaciones y errores en modo estándar y portable.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // RUTA Y DETALLES DEL ARCHIVO
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppLogger.isPortableMode
                                      ? Colors.amber.shade800
                                      : AppTheme.azulAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  AppLogger.isPortableMode
                                      ? 'VERSIÓN PORTABLE (CARPETA DE LA APP)'
                                      : 'MODO ESTÁNDAR (DOCUMENTOS)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Eventos en memoria: ${AppLogger.recentEntries.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            AppLogger.logFilePath ?? 'Cargando ruta de logs...',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // BOTONES DE ACCIÓN PARA LOGS
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('Ver Bitácora en Pantalla'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.casart800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => const LogViewerDialog(),
                            );
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(
                            Icons.description_outlined,
                            size: 18,
                          ),
                          label: const Text('Abrir en Notepad'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onPressed: () async {
                            final ok = await AppLogger.openLogFile();
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No se pudo abrir el editor de texto.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Abrir Carpeta de Logs'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onPressed: () async {
                            final ok = await AppLogger.openLogFolder();
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No se pudo abrir el explorador de archivos.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Exportar Logs (.log) a USB'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onPressed: () async {
                            final path = AppLogger.logFilePath;
                            if (path == null) return;
                            final file = File(path);
                            if (!await file.exists()) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Aún no existe el archivo de logs.',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }
                            final bytes = await file.readAsBytes();
                            final uri = await FilePicker.saveFile(
                              dialogTitle:
                                  'Exportar archivo de logs de actividades',
                              fileName:
                                  'CASART_Actividad_${DateFormat('yyyy_MM_dd_HHmm').format(DateTime.now())}.log',
                              bytes: bytes,
                              type: FileType.custom,
                              allowedExtensions: ['log', 'txt'],
                            );
                            if (uri != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '✓ Logs exportados con éxito en: ${uri.toFilePath()}',
                                  ),
                                  backgroundColor: AppTheme.casart800,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.ocreAccentLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.ocreAccentBorder),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.security,
                            color: AppTheme.ocreAccent,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'En la versión Portable, el archivo casart_actividad.log se almacena directamente en la subcarpeta "logs/" de la aplicación, viajando intacto al transportar la carpeta o memoria USB.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.ocreText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ==========================================
            // 6. ACTUALIZACIONES DEL SISTEMA (GITHUB)
            // ==========================================
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.casart800.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.system_update_alt,
                            color: AppTheme.casart800,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Actualizaciones del Software',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Comprobación automática y descarga de nuevas versiones desde GitHub Releases.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 20,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Versión instalada:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'v${UpdateService.currentVersion}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.casart800,
                            ),
                          ),
                          const SizedBox(width: 24),

                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.sync),
                      label: const Text('Buscar Actualizaciones Ahora'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.casart800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => const UpdateDialog(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
