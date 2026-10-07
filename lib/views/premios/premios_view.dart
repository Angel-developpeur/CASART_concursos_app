import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/concurso.dart';
import '../../models/premio.dart';
import '../../providers/database_provider.dart';
import '../../providers/concursos_provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../common/excel_export_dropdown.dart';
import 'acta_ganadores_dialog.dart';

class PremiosView extends ConsumerStatefulWidget {
  const PremiosView({super.key});

  @override
  ConsumerState<PremiosView> createState() => _PremiosViewState();
}

class _PremiosViewState extends ConsumerState<PremiosView> {
  List<Premio> _premios = [];
  List<Map<String, dynamic>> _ganadores = [];
  bool _isLoading = false;
  int? _currentConcursoId;

  @override
  void initState() {
    super.initState();
    final idConcurso = ref.read(selectedConcursoIdProvider);
    if (idConcurso != null) {
      _loadData(idConcurso);
    }
  }

  Future<void> _loadData([int? targetId]) async {
    final idConcurso = targetId ?? ref.read(selectedConcursoIdProvider);
    _currentConcursoId = idConcurso;
    if (idConcurso == null) {
      if (mounted) {
        setState(() {
          _premios = [];
          _ganadores = [];
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _premios = [];
      _ganadores = [];
    });
    try {
      final repo = ref.read(premioRepositoryProvider);
      final premios = await repo.getPremiosByConcurso(idConcurso);
      final ganadores = await repo.getGanadoresByConcurso(idConcurso);
      if (mounted && _currentConcursoId == idConcurso) {
        setState(() {
          _premios = premios;
          _ganadores = ganadores;
        });
      }
    } finally {
      if (mounted && _currentConcursoId == idConcurso) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _agregarPremio(Concurso concurso) {
    if (concurso.finalizado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pueden agregar premios: el concurso está finalizado (modo solo lectura).',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return Future.value();
    }
    return _mostrarFormularioPremio(concurso);
  }

  Future<void> _mostrarFormularioPremio(
    Concurso concurso, {
    Premio? premioToEdit,
  }) async {
    final isEdit = premioToEdit != null;
    if (!isEdit && concurso.finalizado) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pueden agregar premios: el concurso está finalizado (modo solo lectura).',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController(text: premioToEdit?.nombre ?? '');
    final montoCtrl = TextEditingController(
      text: premioToEdit != null
          ? (premioToEdit.monto % 1 == 0
                ? premioToEdit.monto.toInt().toString()
                : premioToEdit.monto.toString())
          : '',
    );
    final limiteOtorgacionCtrl = TextEditingController(
      text: (premioToEdit?.limiteOtorgacion ?? 1).toString(),
    );
    int? selectedCategoria = premioToEdit?.idCategoria;
    int? selectedSubcategoria = premioToEdit?.idSubCategoria;
    bool isSaving = false;

    final repo = ref.read(premioRepositoryProvider);
    final concursoRepo = ref.read(concursoRepositoryProvider);

    // Obtener la versión más reciente del concurso para garantizar categorías e IDs sincronizados
    final freshConcurso =
        await concursoRepo.getConcursoById(concurso.id!) ?? concurso;
    final tiposPremio = await repo.getTiposPremio();

    int? defaultTipoComunId;
    try {
      final comunMap = tiposPremio.firstWhere(
        (t) => (t['nombre'] as String? ?? '').toUpperCase().contains('COMUN'),
      );
      defaultTipoComunId = comunMap['id'] as int?;
    } catch (_) {
      defaultTipoComunId = 3;
    }

    int? selectedTipoPremio =
        premioToEdit?.idTipoPremio ?? defaultTipoComunId ?? 3;
    int? selectedLugar = premioToEdit?.lugar ?? (isEdit ? null : 1);
    bool nombreModificadoManualmente = isEdit;

    bool esTipoComun(int? tipoId) {
      if (tipoId == null) return false;
      try {
        final t = tiposPremio.firstWhere((item) => item['id'] == tipoId);
        final n = (t['nombre'] as String? ?? '').toUpperCase();
        return n.contains('COMUN') || tipoId == 3;
      } catch (_) {
        return tipoId == 3;
      }
    }

    void actualizarNombreSugerido() {
      if (nombreModificadoManualmente) return;
      if (!esTipoComun(selectedTipoPremio)) return;
      if (selectedCategoria == null) {
        nombreCtrl.clear();
        return;
      }
      final cat = freshConcurso.categorias
          .where((c) => c.id == selectedCategoria)
          .firstOrNull;
      if (cat == null) return;

      final lugarStr = switch (selectedLugar) {
        1 => '1er Lugar',
        2 => '2do Lugar',
        3 => '3er Lugar',
        _ => '$selectedLugarº Lugar',
      };

      final subcat = selectedSubcategoria != null
          ? cat.subcategorias
                .where((s) => s.id == selectedSubcategoria)
                .firstOrNull
          : null;

      if (subcat != null) {
        nombreCtrl.text = '$lugarStr ${subcat.nombre}';
      } else {
        nombreCtrl.text = '$lugarStr ${cat.nombre}';
      }
    }

    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: AppTheme.dialogBodyBg,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 520,
            color: AppTheme.dialogBodyBg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header (Blanco con texto negro)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.dialogHeaderBg,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.casart100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          color: AppTheme.casart800,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEdit
                              ? 'Editar Premio'
                              : 'Agregar Premio a la Bolsa',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ],
                  ),
                ),
                // Formulario
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: montoCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Monto (\$ MXN) *',
                                    prefixText: '\$ ',
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Ingresa el monto';
                                    }
                                    final cleanVal = v
                                        .replaceAll(',', '')
                                        .trim();
                                    final val = double.tryParse(cleanVal);
                                    if (val == null || val <= 0) {
                                      return 'Monto inválido';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<int>(
                                  initialValue: selectedTipoPremio,
                                  decoration: const InputDecoration(
                                    labelText: 'Tipo de Premio',
                                  ),
                                  items: tiposPremio
                                      .map(
                                        (t) => DropdownMenuItem<int>(
                                          value: t['id'] as int,
                                          child: Text(t['nombre'] as String),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setDialogState(() {
                                    selectedTipoPremio = v;
                                    if (!esTipoComun(v)) {
                                      selectedLugar = null;
                                    } else {
                                      selectedLugar ??= 1;
                                    }
                                    actualizarNombreSugerido();
                                  }),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: limiteOtorgacionCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Límite de Otorgación *',
                                    hintText: '1',
                                    prefixIcon:
                                        Icon(Icons.format_list_numbered),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Ingresa el límite';
                                    }
                                    final val = int.tryParse(v.trim());
                                    if (val == null || val < 1) {
                                      return 'Mínimo 1';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              if (esTipoComun(selectedTipoPremio)) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<int>(
                                    initialValue: selectedLugar,
                                    decoration: const InputDecoration(
                                      labelText: 'Lugar / Posición *',
                                      prefixIcon:
                                          Icon(Icons.emoji_events_outlined),
                                    ),
                                    items: const [
                                      DropdownMenuItem<int>(
                                        value: 1,
                                        child: Text('1er Lugar'),
                                      ),
                                      DropdownMenuItem<int>(
                                        value: 2,
                                        child: Text('2do Lugar'),
                                      ),
                                      DropdownMenuItem<int>(
                                        value: 3,
                                        child: Text('3er Lugar'),
                                      ),
                                    ],
                                    onChanged: (v) => setDialogState(() {
                                      selectedLugar = v;
                                      actualizarNombreSugerido();
                                    }),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<int?>(
                            key: ValueKey('cat_$selectedCategoria'),
                            initialValue: selectedCategoria,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Categoría Asignada (Opcional)',
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Premio Global (Sin Categoría)'),
                              ),
                              ...freshConcurso.categorias
                                  .where((c) => c.id != null)
                                  .map(
                                    (c) => DropdownMenuItem<int?>(
                                      value: c.id,
                                      child: Text(c.nombre),
                                    ),
                                  ),
                            ],
                            onChanged: (v) => setDialogState(() {
                              selectedCategoria = v;
                              selectedSubcategoria = null;
                              actualizarNombreSugerido();
                            }),
                          ),
                          if (selectedCategoria != null) ...[
                            const SizedBox(height: 14),
                            Builder(
                              builder: (context) {
                                final cat = freshConcurso.categorias
                                    .where((c) => c.id == selectedCategoria)
                                    .firstOrNull;
                                final subcats = cat?.subcategorias ?? [];
                                return DropdownButtonFormField<int?>(
                                  key: ValueKey(
                                    'subcat_${selectedCategoria}_$selectedSubcategoria',
                                  ),
                                  initialValue: selectedSubcategoria,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Subcategoría Asignada (Opcional)',
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('Todas las subcategorías'),
                                    ),
                                    ...subcats
                                        .where((s) => s.id != null)
                                        .map(
                                          (s) => DropdownMenuItem<int?>(
                                            value: s.id,
                                            child: Text(s.nombre),
                                          ),
                                        ),
                                  ],
                                  onChanged: (v) => setDialogState(() {
                                    selectedSubcategoria = v;
                                    actualizarNombreSugerido();
                                  }),
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: nombreCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del Premio *',
                              hintText:
                                  'Ej: 1er Lugar Alfarería / Galardón Estatal',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'El nombre del premio es obligatorio';
                              }
                              return null;
                            },
                            onChanged: (v) {
                              nombreModificadoManualmente = v.trim().isNotEmpty;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: AppTheme.cancelButtonStyle,
                        onPressed: isSaving
                            ? null
                            : () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: AppTheme.acceptButtonStyle,
                        icon: isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          isSaving
                              ? 'Guardando...'
                              : (isEdit ? 'Guardar Cambios' : 'Guardar Premio'),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setDialogState(() => isSaving = true);
                                try {
                                  if (!isEdit && freshConcurso.finalizado) {
                                    throw StateError(
                                      'El concurso "${freshConcurso.nombre}" está finalizado. No se permite agregar premios (modo solo lectura).',
                                    );
                                  }
                                  final cleanMonto = montoCtrl.text
                                      .replaceAll(',', '')
                                      .trim();
                                  final monto =
                                      double.tryParse(cleanMonto) ?? 0.0;
                                  final limiteOtorgacion =
                                      int.tryParse(limiteOtorgacionCtrl.text.trim()) ?? 1;
                                  final p = Premio(
                                    id: premioToEdit?.id,
                                    idConcurso: freshConcurso.id!,
                                    nombre: nombreCtrl.text.trim(),
                                    monto: monto,
                                    idTipoPremio: selectedTipoPremio,
                                    idCategoria: selectedCategoria,
                                    idSubCategoria: selectedSubcategoria,
                                    lugar: esTipoComun(selectedTipoPremio)
                                        ? selectedLugar
                                        : null,
                                    limiteOtorgacion: limiteOtorgacion,
                                    activo: premioToEdit?.activo ?? true,
                                  );
                                  await repo.savePremio(p);
                                  if (ctx.mounted) Navigator.pop(ctx, true);
                                } catch (e) {
                                  setDialogState(() => isSaving = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error al guardar premio: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved == true) {
      ref.invalidate(selectedConcursoProvider);
      await _loadData(freshConcurso.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? 'Premio actualizado exitosamente.'
                  : 'Premio registrado exitosamente en la bolsa.',
            ),
            backgroundColor: AppTheme.casart800,
          ),
        );
      }
    }
  }

  // ignore: unused_element
  Future<void> _premiarPieza(Premio premio, Concurso concurso) async {
    final registros = await ref
        .read(registroRepositoryProvider)
        .getRegistrosByConcurso(concurso.id!);

    if (!mounted) return;

    if (registros.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay piezas inscritas para premiar.')),
      );
      return;
    }

    int? selectedArtesaniaId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: AppTheme.dialogBodyBg,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 550,
            color: AppTheme.dialogBodyBg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.dialogHeaderBg,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.casart100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.military_tech,
                          color: AppTheme.casart800,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Asignar "${premio.nombre}"',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monto: ${Formatters.formatCurrency(premio.monto)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.verdeSuccess,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Selecciona la pieza ganadora de este premio:',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: ValueKey('artesania_$selectedArtesaniaId'),
                        initialValue: selectedArtesaniaId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Pieza Participante',
                        ),
                        items: registros.expand((r) {
                          final items = <DropdownMenuItem<int>>[];
                          if (r.artesania1 != null) {
                            items.add(
                              DropdownMenuItem(
                                value: r.artesania1!.id,
                                child: Text(
                                  '[Folio #${r.folio}-1] ${r.artesania1!.nombre} - ${r.artesano?.nombreCompleto ?? ''}',
                                ),
                              ),
                            );
                          }
                          if (r.artesania2 != null) {
                            items.add(
                              DropdownMenuItem(
                                value: r.artesania2!.id,
                                child: Text(
                                  '[Folio #${r.folio}-2] ${r.artesania2!.nombre} - ${r.artesano?.nombreCompleto ?? ''}',
                                ),
                              ),
                            );
                          }
                          return items;
                        }).toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedArtesaniaId = v),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: AppTheme.cancelButtonStyle,
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: AppTheme.acceptButtonStyle,
                        onPressed: selectedArtesaniaId == null
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  await ref
                                      .read(premioRepositoryProvider)
                                      .asignarPremiacion(
                                        idConcurso: concurso.id!,
                                        idPremio: premio.id!,
                                        idArtesania: selectedArtesaniaId!,
                                        idCategoria: premio.idCategoria,
                                        lugar: premio.lugar,
                                      );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _loadData(concurso.id);
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Ganador asignado con éxito.',
                                        ),
                                        backgroundColor: AppTheme.verdeSuccess,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error al asignar ganador: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: const Text('Confirmar Ganador'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(selectedConcursoIdProvider, (previous, next) {
      if (previous != next) {
        _loadData(next);
      }
    });

    final concursoAsync = ref.watch(selectedConcursoProvider);

    return concursoAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (concurso) {
        if (concurso == null) {
          if (_premios.isNotEmpty ||
              _ganadores.isNotEmpty ||
              _currentConcursoId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _premios = [];
                  _ganadores = [];
                  _currentConcursoId = null;
                });
              }
            });
          }
          return const Center(
            child: Text(
              'Selecciona un concurso para gestionar la bolsa de premios.',
            ),
          );
        }

        if (_currentConcursoId != concurso.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadData(concurso.id);
          });
        }

        final totalPremios = _premios.fold(0.0, (sum, p) => sum + p.monto);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Bolsa de Premios - ${concurso.nombre}',
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.azulLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.azulBorder),
                ),
                child: Text(
                  'Total Bolsa: ${Formatters.formatCurrency(totalPremios)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.azulAccent,
                  ),
                ),
              ),
              ExcelExportDropdown(concurso: concurso),
              if (_ganadores.isNotEmpty) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text('Acta PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => ActaGanadoresDialog(
                        concurso: concurso,
                        ganadores: _ganadores,
                        initialType: TipoDocumentoGanadores.actaOficial,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.badge_outlined, size: 16),
                  label: const Text('Distintivos PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => ActaGanadoresDialog(
                        concurso: concurso,
                        ganadores: _ganadores,
                        initialType: TipoDocumentoGanadores.distintivos,
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(width: 12),
              if (!concurso.finalizado)
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo Premio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.verdeSuccess,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _agregarPremio(concurso),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: Colors.blueGrey.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Concurso Finalizado',
                        style: TextStyle(
                          color: Colors.blueGrey.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 16),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      if (concurso.finalizado)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blueGrey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                color: Colors.blueGrey.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Modo Solo Lectura: Este concurso está finalizado. No se permite agregar nuevos premios a la bolsa.',
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade900,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 800) {
                              return DefaultTabController(
                                length: 2,
                                child: Column(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: TabBar(
                                        indicatorSize: TabBarIndicatorSize.tab,
                                        indicator: BoxDecoration(
                                          color: AppTheme.casart800,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        labelColor: Colors.white,
                                        unselectedLabelColor:
                                            Colors.grey.shade700,
                                        labelStyle: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        tabs: [
                                          Tab(
                                            text:
                                                'Premios Registrados (${_premios.length})',
                                          ),
                                          Tab(
                                            text:
                                                'Ganadores (${_ganadores.length})',
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: TabBarView(
                                        children: [
                                          _buildPremiosList(
                                            concurso,
                                            showTitle: false,
                                          ),
                                          _buildGanadoresList(
                                            concurso,
                                            showTitle: false,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // COLUMNA 1: LISTADO DE PREMIOS CONFIGURADOS
                                Expanded(
                                  flex: 3,
                                  child: _buildPremiosList(
                                    concurso,
                                    showTitle: true,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                // COLUMNA 2: GANADORES DICTAMINADOS
                                Expanded(
                                  flex: 2,
                                  child: _buildGanadoresList(
                                    concurso,
                                    showTitle: true,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildPremiosList(Concurso concurso, {required bool showTitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            'Premios Registrados (${_premios.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_premios.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No hay premios agregados a la bolsa de este concurso.',
                    ),
                    if (!concurso.finalizado) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => _agregarPremio(concurso),
                        child: const Text('Agregar Primer Premio'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _premios.length,
              itemBuilder: (ctx, i) {
                final p = _premios[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppTheme.ocreAccent,
                          foregroundColor: Colors.white,
                          radius: 18,
                          child: Icon(Icons.military_tech, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                p.nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${p.categoriaNombre ?? 'Global (Cualquier categoría)'} ${p.subcategoriaNombre != null ? '| ${p.subcategoriaNombre}' : ''} • Límite: ${p.limiteOtorgacion}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              Formatters.formatCurrency(p.monto),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.verdeSuccess,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: AppTheme.casart800,
                                size: 19,
                              ),
                              tooltip: 'Editar premio',
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: () => _mostrarFormularioPremio(
                                concurso,
                                premioToEdit: p,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildGanadoresList(Concurso concurso, {required bool showTitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Row(
            children: [
              const Text(
                'Ganadores Asignados (Dictamen)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_ganadores.isNotEmpty) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFFDC2626)),
                  label: const Text('Ver Acta Oficial (PDF)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => ActaGanadoresDialog(
                        concurso: concurso,
                        ganadores: _ganadores,
                        initialType: TipoDocumentoGanadores.actaOficial,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.badge_outlined, size: 16, color: Color(0xFFD97706)),
                  label: const Text('Ver Distintivos (PDF)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => ActaGanadoresDialog(
                        concurso: concurso,
                        ganadores: _ganadores,
                        initialType: TipoDocumentoGanadores.distintivos,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_ganadores.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Aún no se han asignado ganadores a los premios.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _ganadores.length,
              itemBuilder: (ctx, i) {
                final g = _ganadores[i];
                return Card(
                  color: AppTheme.verdeLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppTheme.verdeBorder),
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.verified,
                          color: AppTheme.verdeSuccess,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                g['premio_nombre'] as String? ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ganador: ${g['artesano_nombre']} ${g['artesano_paterno']}\nPieza: ${g['artesania_nombre']} [Folio #${g['folio_concurso']}]',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Formatters.formatCurrency(
                                (g['premio_monto'] as num?)?.toDouble() ?? 0.0,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.verdeSuccess,
                              ),
                            ),
                            const SizedBox(height: 4),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.badge_outlined, size: 13),
                              label: const Text('Distintivo', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => ActaGanadoresDialog(
                                    concurso: concurso,
                                    ganadores: [g],
                                    initialType: TipoDocumentoGanadores.distintivos,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
