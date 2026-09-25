import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/logging/app_logger.dart';
import '../../core/theme/app_theme.dart';

class LogViewerDialog extends StatefulWidget {
  const LogViewerDialog({super.key});

  @override
  State<LogViewerDialog> createState() => _LogViewerDialogState();
}

class _LogViewerDialogState extends State<LogViewerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  LogLevel? _selectedFilter;
  List<LogEntry> _filteredEntries = [];

  @override
  void initState() {
    super.initState();
    _applyFilter();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final query = _searchCtrl.text.trim().toLowerCase();
    final all = AppLogger.recentEntries.reversed.toList();

    setState(() {
      _filteredEntries = all.where((e) {
        if (_selectedFilter != null && e.level != _selectedFilter) {
          return false;
        }
        if (query.isNotEmpty) {
          final matchesMsg = e.message.toLowerCase().contains(query);
          final matchesCat = e.category.toLowerCase().contains(query);
          final matchesData = e.data != null && e.data.toString().toLowerCase().contains(query);
          final matchesErr = e.error != null && e.error.toString().toLowerCase().contains(query);
          return matchesMsg || matchesCat || matchesData || matchesErr;
        }
        return true;
      }).toList();
    });
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.create:
        return const Color(0xFF2E7D32); // Verde
      case LogLevel.update:
        return const Color(0xFF1565C0); // Azul
      case LogLevel.delete:
        return const Color(0xFFC62828); // Rojo
      case LogLevel.error:
        return const Color(0xFFB71C1C); // Carmesí oscuro
      case LogLevel.warn:
        return const Color(0xFFE65100); // Naranja
      case LogLevel.info:
        return const Color(0xFF546E7A); // Gris azulado
    }
  }

  IconData _getLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.create:
        return Icons.add_circle_outline;
      case LogLevel.update:
        return Icons.edit_note;
      case LogLevel.delete:
        return Icons.delete_outline;
      case LogLevel.error:
        return Icons.error_outline;
      case LogLevel.warn:
        return Icons.warning_amber_rounded;
      case LogLevel.info:
        return Icons.info_outline;
    }
  }

  Future<void> _exportLogs() async {
    final path = AppLogger.logFilePath;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No existe aún archivo de logs para exportar.')),
        );
      }
      return;
    }

    final bytes = await file.readAsBytes();
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Exportar archivo de logs de actividades',
      fileName: 'casart_actividad_${DateTime.now().millisecondsSinceEpoch}.log',
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['log', 'txt'],
    );

    if (uri != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Logs exportados con éxito en: ${uri.toFilePath()}'),
          backgroundColor: AppTheme.casart800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = AppLogger.logFilePath ?? 'No disponible';
    final isPortable = AppLogger.isPortableMode;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 1050,
        height: 750,
        child: Column(
          children: [
            // HEADER INSTITUCIONAL
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              color: AppTheme.casart800,
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bitácora del Sistema y Registro de Actividades',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPortable ? Colors.amber.shade700 : Colors.white24,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isPortable ? 'MODO PORTABLE' : 'MODO DOCUMENTOS',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                path,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // BARRA DE HERRAMIENTAS Y ACCIONES RÁPIDAS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  // Campo de búsqueda
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Buscar por texto, folio, artesano, CURP o error...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _applyFilter();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Botón Abrir con Notepad
                  OutlinedButton.icon(
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Abrir en Notepad'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onPressed: () => AppLogger.openLogFile(),
                  ),
                  const SizedBox(width: 8),

                  // Botón Abrir Carpeta
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Abrir Carpeta'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onPressed: () => AppLogger.openLogFolder(),
                  ),
                  const SizedBox(width: 8),

                  // Botón Exportar
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Exportar a USB'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.casart800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onPressed: _exportLogs,
                  ),
                ],
              ),
            ),

            // CHIPS DE FILTRO POR NIVEL
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('Filtrar por:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                    const SizedBox(width: 10),
                    FilterChip(
                      label: const Text('Todos'),
                      selected: _selectedFilter == null,
                      onSelected: (val) {
                        setState(() => _selectedFilter = null);
                        _applyFilter();
                      },
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      avatar: const Icon(Icons.add_circle, color: Color(0xFF2E7D32), size: 16),
                      label: const Text('Creaciones (CREATE)'),
                      selected: _selectedFilter == LogLevel.create,
                      onSelected: (val) {
                        setState(() => _selectedFilter = val ? LogLevel.create : null);
                        _applyFilter();
                      },
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      avatar: const Icon(Icons.edit, color: Color(0xFF1565C0), size: 16),
                      label: const Text('Modificaciones (UPDATE)'),
                      selected: _selectedFilter == LogLevel.update,
                      onSelected: (val) {
                        setState(() => _selectedFilter = val ? LogLevel.update : null);
                        _applyFilter();
                      },
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      avatar: const Icon(Icons.delete, color: Color(0xFFC62828), size: 16),
                      label: const Text('Eliminaciones (DELETE)'),
                      selected: _selectedFilter == LogLevel.delete,
                      onSelected: (val) {
                        setState(() => _selectedFilter = val ? LogLevel.delete : null);
                        _applyFilter();
                      },
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      avatar: const Icon(Icons.error, color: Color(0xFFB71C1C), size: 16),
                      label: const Text('Errores (ERROR)'),
                      selected: _selectedFilter == LogLevel.error,
                      onSelected: (val) {
                        setState(() => _selectedFilter = val ? LogLevel.error : null);
                        _applyFilter();
                      },
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      avatar: const Icon(Icons.info, color: Color(0xFF546E7A), size: 16),
                      label: const Text('Sistema / Info'),
                      selected: _selectedFilter == LogLevel.info,
                      onSelected: (val) {
                        setState(() => _selectedFilter = val ? LogLevel.info : null);
                        _applyFilter();
                      },
                    ),
                  ],
                ),
              ),
            ),

            // LISTA DE ENTRADAS DE LOG
            Expanded(
              child: _filteredEntries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_edu, size: 54, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            _searchCtrl.text.isNotEmpty || _selectedFilter != null
                                ? 'No se encontraron eventos con los filtros seleccionados.'
                                : 'Aún no hay registros de actividad en esta sesión.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredEntries.length,
                      separatorBuilder: (_, _) => const Divider(height: 8, thickness: 0.5),
                      itemBuilder: (ctx, idx) {
                        final entry = _filteredEntries[idx];
                        final levelColor = _getLevelColor(entry.level);
                        final icon = _getLevelIcon(entry.level);

                        final y = entry.timestamp.year.toString().padLeft(4, '0');
                        final m = entry.timestamp.month.toString().padLeft(2, '0');
                        final d = entry.timestamp.day.toString().padLeft(2, '0');
                        final hh = entry.timestamp.hour.toString().padLeft(2, '0');
                        final mm = entry.timestamp.minute.toString().padLeft(2, '0');
                        final ss = entry.timestamp.second.toString().padLeft(2, '0');
                        final timeStr = '$y-$m-$d $hh:$mm:$ss';

                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: entry.level == LogLevel.error
                                ? Colors.red.shade50.withValues(alpha: 0.6)
                                : Colors.grey.shade50.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: entry.level == LogLevel.error
                                  ? Colors.red.shade200
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: levelColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icon, size: 14, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text(
                                          entry.level.label,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      entry.category,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey.shade800,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 16),
                                    tooltip: 'Copiar registro al portapapeles',
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: entry.formatForFile()));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Registro copiado al portapapeles.'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SelectableText(
                                entry.message,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: entry.level == LogLevel.error ? Colors.red.shade900 : Colors.black87,
                                ),
                              ),
                              if (entry.data != null && entry.data!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: SelectableText(
                                    'Datos: ${entry.data}',
                                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black87),
                                  ),
                                ),
                              ],
                              if (entry.error != null) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: SelectableText(
                                    'Detalle Error: ${entry.error}',
                                    style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.red.shade900),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // FOOTER CON RESUMEN
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  Text(
                    'Mostrando ${_filteredEntries.length} de ${AppLogger.recentEntries.length} eventos recientes',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Actualizar'),
                    onPressed: _applyFilter,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
