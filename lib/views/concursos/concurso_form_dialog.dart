import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/concurso.dart';
import '../../models/categoria.dart';
import '../../models/subcategoria.dart';
import '../../models/aportacion.dart';
import '../../providers/database_provider.dart';
import '../../providers/concursos_provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/theme/app_theme.dart';
import 'dialogo_autorizacion_concurso.dart';

class ConcursoFormDialog extends ConsumerStatefulWidget {
  final Concurso? concursoToEdit;

  const ConcursoFormDialog({super.key, this.concursoToEdit});

  @override
  ConsumerState<ConcursoFormDialog> createState() => _ConcursoFormDialogState();
}

class _ConcursoFormDialogState extends ConsumerState<ConcursoFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nombreCtrl;
  late TextEditingController _lugarCtrl;
  late TextEditingController _ejercicioCtrl;
  late TextEditingController _ivaCtrl;
  late TextEditingController _utilidadCtrl;
  late TextEditingController _fechaInicioCtrl;
  late TextEditingController _fechaLimiteCtrl;
  late TextEditingController _fechaDictamenCtrl;
  late TextEditingController _fechaPremiacionCtrl;

  int _selectedTipoConcurso = 1;
  List<Map<String, dynamic>> _tiposConcurso = [];
  bool _finalizado = false;

  // Categorías en memoria
  List<_CategoriaDraft> _categorias = [];

  // Aportaciones multi-fila en memoria
  List<_AportacionDraft> _aportaciones = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final c = widget.concursoToEdit;

    _finalizado = c?.finalizado ?? false;
    _nombreCtrl = TextEditingController(text: c?.nombre ?? '');
    _lugarCtrl = TextEditingController(text: c?.lugar ?? '');
    _ejercicioCtrl = TextEditingController(text: c?.ejercicio ?? DateTime.now().year.toString());
    _ivaCtrl = TextEditingController(text: c != null ? c.iva.toString() : '16');
    _utilidadCtrl = TextEditingController(text: c != null ? c.utilidad.toString() : '0');
    _fechaInicioCtrl = TextEditingController(text: c?.fechaInicioRegistro ?? '');
    _fechaLimiteCtrl = TextEditingController(text: c?.fechaLimiteRegistro ?? '');
    _fechaDictamenCtrl = TextEditingController(text: c?.fechaDictamen ?? '');
    _fechaPremiacionCtrl = TextEditingController(text: c?.fechaPremiacion ?? '');

    _selectedTipoConcurso = c?.idTipoConcurso ?? 1;

    if (c != null && c.categorias.isNotEmpty) {
      _categorias = c.categorias.map((cat) {
        return _CategoriaDraft(
          id: cat.id,
          nombreCtrl: TextEditingController(text: cat.nombre),
          subcategorias: cat.subcategorias.map((sub) {
            return _SubcategoriaDraft(
              id: sub.id,
              nombreCtrl: TextEditingController(text: sub.nombre),
            );
          }).toList(),
        );
      }).toList();
    } else {
      _categorias = [
        _CategoriaDraft(nombreCtrl: TextEditingController(), subcategorias: []),
      ];
    }

    if (c != null && c.aportaciones.isNotEmpty) {
      _aportaciones = c.aportaciones.map((a) {
        return _AportacionDraft(
          id: a.id,
          nombreCtrl: TextEditingController(text: a.nombre),
          cantidadCtrl: TextEditingController(text: a.cantidad.toString()),
        );
      }).toList();
    } else {
      _aportaciones = [
        _AportacionDraft(
          nombreCtrl: TextEditingController(),
          cantidadCtrl: TextEditingController(),
        ),
      ];
    }

    _loadTiposConcurso();
  }

  Future<void> _loadTiposConcurso() async {
    final repo = ref.read(concursoRepositoryProvider);
    final list = await repo.getTiposConcurso();
    setState(() {
      _tiposConcurso = list;
    });
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _lugarCtrl.dispose();
    _ejercicioCtrl.dispose();
    _ivaCtrl.dispose();
    _utilidadCtrl.dispose();
    _fechaInicioCtrl.dispose();
    _fechaLimiteCtrl.dispose();
    _fechaDictamenCtrl.dispose();
    _fechaPremiacionCtrl.dispose();

    for (final cat in _categorias) {
      cat.nombreCtrl.dispose();
      for (final sub in cat.subcategorias) {
        sub.nombreCtrl.dispose();
      }
    }

    for (final a in _aportaciones) {
      a.nombreCtrl.dispose();
      a.cantidadCtrl.dispose();
    }

    super.dispose();
  }

  double get _totalBolsaAportaciones {
    double sum = 0.0;
    for (final a in _aportaciones) {
      final val = double.tryParse(a.cantidadCtrl.text.trim()) ?? 0.0;
      sum += val;
    }
    return sum;
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final now = DateTime.now();
    DateTime initialDate = now;
    if (controller.text.trim().isNotEmpty) {
      try {
        initialDate = DateTime.parse(controller.text.trim());
      } catch (_) {}
    }

    if (initialDate.isBefore(DateTime(2020))) initialDate = DateTime(2020);
    if (initialDate.isAfter(DateTime(2035))) initialDate = DateTime(2035);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('es', 'MX'),
      helpText: 'SELECCIONAR FECHA',
      cancelText: 'CANCELAR',
      confirmText: 'ACEPTAR',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.casart800,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formatted = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      setState(() {
        controller.text = formatted;
      });
    }
  }

  Future<void> _selectDateTime(TextEditingController controller) async {
    final now = DateTime.now();
    DateTime initialDate = now;
    TimeOfDay initialTime = TimeOfDay.now();

    if (controller.text.trim().isNotEmpty) {
      try {
        final parsed = DateTime.parse(controller.text.trim());
        initialDate = parsed;
        if (controller.text.contains(':')) {
          initialTime = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
        }
      } catch (_) {}
    }

    if (initialDate.isBefore(DateTime(2020))) initialDate = DateTime(2020);
    if (initialDate.isAfter(DateTime(2035))) initialDate = DateTime(2035);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('es', 'MX'),
      helpText: 'SELECCIONAR FECHA',
      cancelText: 'CANCELAR',
      confirmText: 'SIGUIENTE',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.casart800,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;
    if (!mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'SELECCIONAR HORA',
      cancelText: 'CANCELAR',
      confirmText: 'ACEPTAR',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.casart800,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return;

    final y = pickedDate.year.toString().padLeft(4, '0');
    final m = pickedDate.month.toString().padLeft(2, '0');
    final d = pickedDate.day.toString().padLeft(2, '0');
    final hh = pickedTime.hour.toString().padLeft(2, '0');
    final mm = pickedTime.minute.toString().padLeft(2, '0');

    final formatted = "$y-$m-$d $hh:$mm";
    setState(() {
      controller.text = formatted;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(concursoRepositoryProvider);

      final categoriasList = _categorias
          .where((cat) => cat.nombreCtrl.text.trim().isNotEmpty)
          .map((cat) {
        final subs = cat.subcategorias
            .where((s) => s.nombreCtrl.text.trim().isNotEmpty)
            .map((s) => Subcategoria(id: s.id, nombre: s.nombreCtrl.text.trim()))
            .toList();
        return Categoria(id: cat.id, nombre: cat.nombreCtrl.text.trim(), subcategorias: subs);
      }).toList();

      final aportacionesList = _aportaciones
          .where((a) => a.nombreCtrl.text.trim().isNotEmpty)
          .map((a) {
        final cantidad = double.tryParse(a.cantidadCtrl.text.trim()) ?? 0.0;
        return Aportacion(
          id: a.id,
          nombre: a.nombreCtrl.text.trim(),
          cantidad: cantidad,
        );
      }).toList();

      final concurso = Concurso(
        id: widget.concursoToEdit?.id,
        nombre: _nombreCtrl.text.trim(),
        idTipoConcurso: _selectedTipoConcurso,
        lugar: _lugarCtrl.text.trim(),
        ejercicio: _ejercicioCtrl.text.trim(),
        iva: int.tryParse(_ivaCtrl.text.trim()) ?? 16,
        utilidad: double.tryParse(_utilidadCtrl.text.trim()) ?? 0.0,
        fechaInicioRegistro: _fechaInicioCtrl.text.trim(),
        fechaLimiteRegistro: _fechaLimiteCtrl.text.trim(),
        fechaDictamen: _fechaDictamenCtrl.text.trim(),
        fechaPremiacion: _fechaPremiacionCtrl.text.trim(),
        finalizado: _finalizado,
        categorias: categoriasList,
        aportaciones: aportacionesList,
      );

      if (widget.concursoToEdit == null) {
        await repo.createConcurso(concurso);
      } else {
        await repo.updateConcurso(concurso);
      }

      ref.invalidate(concursosListProvider);
      ref.invalidate(selectedConcursoProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.concursoToEdit == null
                ? 'Concurso creado exitosamente.'
                : 'Concurso actualizado.'),
            backgroundColor: AppTheme.casart800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar concurso: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        width: 1000,
        constraints: const BoxConstraints(maxHeight: 800),
        color: AppTheme.dialogBodyBg,
        child: Column(
          children: [
            // HEADER DEL DIÁLOGO (Blanco con texto negro)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.dialogHeaderBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.black87, size: 26),
                  const SizedBox(width: 12),
                  Text(
                    widget.concursoToEdit == null
                        ? 'Crear Nuevo Concurso'
                        : 'Editar Concurso',
                    style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
            ),

            // FORMULARIO CON SCROLL
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // 1. DATOS GENERALES
                    _buildSectionHeader('1. Información General del Concurso'),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _nombreCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del Concurso *',
                              hintText: 'Ej: LIV Concurso Estatal de Artesanías de Domingo de Ramos',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'El nombre es obligatorio' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedTipoConcurso,
                            decoration: const InputDecoration(labelText: 'Modalidad / Tipo *'),
                            items: _tiposConcurso.map((t) {
                              return DropdownMenuItem<int>(
                                value: t['id'] as int,
                                child: Text(t['nombre'] as String),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedTipoConcurso = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _ejercicioCtrl,
                            decoration: const InputDecoration(labelText: 'Ejercicio (Año) *'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _lugarCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Lugar de Celebración *',
                              hintText: 'Ej: Uruapan, Michoacán (Plaza Morelos)',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'El lugar es obligatorio' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _ivaCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: 'IVA (%) *'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _utilidadCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Utilidad (%) *'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // FECHAS
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _fechaInicioCtrl,
                            readOnly: true,
                            onTap: () => _selectDate(_fechaInicioCtrl),
                            decoration: InputDecoration(
                              labelText: 'Inicio Registro *',
                              prefixIcon: const Icon(Icons.calendar_today, size: 18),
                              suffixIcon: _fechaInicioCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      tooltip: 'Limpiar',
                                      onPressed: () => setState(() => _fechaInicioCtrl.clear()),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _fechaLimiteCtrl,
                            readOnly: true,
                            onTap: () => _selectDate(_fechaLimiteCtrl),
                            decoration: InputDecoration(
                              labelText: 'Límite Registro *',
                              prefixIcon: const Icon(Icons.event_busy, size: 18),
                              suffixIcon: _fechaLimiteCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      tooltip: 'Limpiar',
                                      onPressed: () => setState(() => _fechaLimiteCtrl.clear()),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _fechaDictamenCtrl,
                            readOnly: true,
                            onTap: () => _selectDateTime(_fechaDictamenCtrl),
                            decoration: InputDecoration(
                              labelText: 'Dictamen (Fecha/Hora) *',
                              hintText: 'AAAA-MM-DD HH:MM',
                              prefixIcon: const Icon(Icons.rate_review, size: 18),
                              suffixIcon: _fechaDictamenCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      tooltip: 'Limpiar',
                                      onPressed: () => setState(() => _fechaDictamenCtrl.clear()),
                                    )
                                  : const Icon(Icons.access_time, size: 18, color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _fechaPremiacionCtrl,
                            readOnly: true,
                            onTap: () => _selectDateTime(_fechaPremiacionCtrl),
                            decoration: InputDecoration(
                              labelText: 'Premiación (Fecha/Hora) *',
                              hintText: 'AAAA-MM-DD HH:MM',
                              prefixIcon: const Icon(Icons.military_tech, size: 18),
                              suffixIcon: _fechaPremiacionCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      tooltip: 'Limpiar',
                                      onPressed: () => setState(() => _fechaPremiacionCtrl.clear()),
                                    )
                                  : const Icon(Icons.access_time, size: 18, color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ESTATUS DEL CONCURSO (FINALIZADO / EN PROCESO)
                    Material(
                      color: _finalizado
                          ? (Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2A282D)
                              : Colors.grey.withValues(alpha: 0.12))
                          : (Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF142B20)
                              : AppTheme.verdeLight.withValues(alpha: 0.45)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: _finalizado ? Colors.grey.shade400 : AppTheme.verdeBorder,
                          width: 1.2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SwitchListTile(
                        value: _finalizado,
                        activeThumbColor: AppTheme.casart800,
                        onChanged: (val) async {
                          if (val == _finalizado) return;
                          final autorizado = await DialogoAutorizacionConcurso.mostrar(
                            context,
                            concursoNombre: _nombreCtrl.text.trim().isNotEmpty
                                ? _nombreCtrl.text.trim()
                                : (widget.concursoToEdit?.nombre ?? 'Concurso'),
                            willFinalize: val,
                          );
                          if (autorizado) {
                            setState(() => _finalizado = val);
                          }
                        },
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _finalizado
                                ? Colors.grey.withValues(alpha: 0.2)
                                : AppTheme.verdeLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _finalizado ? Icons.check_circle : Icons.hourglass_top,
                            color: _finalizado ? Colors.blueGrey : AppTheme.verdeSuccess,
                            size: 24,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _finalizado
                                    ? 'Estatus: Concurso Finalizado'
                                    : 'Estatus: Concurso En Proceso (Abierto)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _finalizado
                                      ? (Theme.of(context).brightness == Brightness.dark
                                          ? Colors.grey.shade300
                                          : Colors.blueGrey.shade900)
                                      : AppTheme.verdeSuccess,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.amber.shade700, width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_outline, size: 12, color: Colors.amber.shade900),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Protegido con clave',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          _finalizado
                              ? 'El concurso está concluido. El periodo de recepción de piezas y dictamen ha finalizado.'
                              : 'El concurso está abierto y disponible para recibir inscripciones y evaluar piezas.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 2. SECCIÓN DE CATEGORÍAS Y SUBCATEGORÍAS
                    _buildSectionHeader('2. Categorías y Subcategorías del Concurso'),
                    const SizedBox(height: 12),
                    ..._categorias.asMap().entries.map((entry) {
                      final catIndex = entry.key;
                      final cat = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: cat.nombreCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'Categoría ${catIndex + 1} *',
                                        hintText: 'Ej: Alfarería Vidriada, Rebozos, Guitarras...',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'Eliminar Categoría',
                                    onPressed: () {
                                      setState(() {
                                        if (_categorias.length > 1) {
                                          _categorias.removeAt(catIndex);
                                        } else {
                                          cat.nombreCtrl.clear();
                                          cat.subcategorias.clear();
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (cat.subcategorias.isNotEmpty) const SizedBox(height: 12),
                              ...cat.subcategorias.asMap().entries.map((subEntry) {
                                final subIndex = subEntry.key;
                                final sub = subEntry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 24, bottom: 8),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.subdirectory_arrow_right, size: 20, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          controller: sub.nombreCtrl,
                                          decoration: InputDecoration(
                                            labelText: 'Subcategoría ${subIndex + 1}',
                                            hintText: 'Ej: Olla, Jarra, Plato...',
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                        onPressed: () {
                                          setState(() => cat.subcategorias.removeAt(subIndex));
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Agregar Subcategoría'),
                                  onPressed: () {
                                    setState(() {
                                      cat.subcategorias.add(_SubcategoriaDraft(nombreCtrl: TextEditingController()));
                                    });
                                  },
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar Categoría'),
                        onPressed: () {
                          setState(() {
                            _categorias.add(_CategoriaDraft(nombreCtrl: TextEditingController(), subcategorias: []));
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 3. SECCIÓN DE APORTACIONES AL CONCURSO (MULTI-ROW)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildSectionHeader('3. Aportaciones / Patrocinios de la Bolsa (Multi-fila)'),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.verdeLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.verdeBorder),
                          ),
                          child: Text(
                            'Bolsa Total: ${Formatters.formatCurrency(_totalBolsaAportaciones)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.verdeSuccess),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._aportaciones.asMap().entries.map((entry) {
                      final aIndex = entry.key;
                      final a = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: a.nombreCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Institución / Aportante #${aIndex + 1}',
                                    hintText: 'Ej: FONART, Ayuntamiento de Pátzcuaro, CASART...',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: a.cantidadCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    labelText: 'Cantidad (\$ MXN)',
                                    hintText: '0.00',
                                    isDense: true,
                                    prefixText: '\$ ',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Eliminar fila',
                                onPressed: () {
                                  setState(() {
                                    if (_aportaciones.length > 1) {
                                      _aportaciones.removeAt(aIndex);
                                    } else {
                                      a.nombreCtrl.clear();
                                      a.cantidadCtrl.clear();
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar Aportación'),
                        onPressed: () {
                          setState(() {
                            _aportaciones.add(_AportacionDraft(
                              nombreCtrl: TextEditingController(),
                              cantidadCtrl: TextEditingController(),
                            ));
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // BOTONES DE ACCIÓN
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.dialogHeaderBg,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: AppTheme.cancelButtonStyle,
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.verdeSuccess,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check),
                    label: Text(_isLoading ? 'Guardando...' : 'Guardar Concurso'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    );
  }
}

class _CategoriaDraft {
  final int? id;
  final TextEditingController nombreCtrl;
  final List<_SubcategoriaDraft> subcategorias;

  _CategoriaDraft({this.id, required this.nombreCtrl, required this.subcategorias});
}

class _SubcategoriaDraft {
  final int? id;
  final TextEditingController nombreCtrl;

  _SubcategoriaDraft({this.id, required this.nombreCtrl});
}

class _AportacionDraft {
  final int? id;
  final TextEditingController nombreCtrl;
  final TextEditingController cantidadCtrl;

  _AportacionDraft({this.id, required this.nombreCtrl, required this.cantidadCtrl});
}
