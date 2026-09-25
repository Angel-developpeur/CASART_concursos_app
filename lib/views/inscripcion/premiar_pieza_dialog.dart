import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/concurso.dart';
import '../../models/premio.dart';
import '../../models/registro_concurso.dart';
import '../../providers/database_provider.dart';

class PremiarPiezaDialog extends ConsumerStatefulWidget {
  final RegistroConcurso registro;
  final Concurso concurso;

  const PremiarPiezaDialog({
    super.key,
    required this.registro,
    required this.concurso,
  });

  @override
  ConsumerState<PremiarPiezaDialog> createState() => _PremiarPiezaDialogState();
}

class _PremiarPiezaDialogState extends ConsumerState<PremiarPiezaDialog> {
  bool _isLoading = true;
  bool _isSaving = false;

  List<Premio> _premios = [];
  Map<int, int> _conteoOtorgados = {};

  // Índice de la pieza seleccionada (1 = Pieza A, 2 = Pieza B)
  int _selectedPieza = 1;

  // Premios asignados en este diálogo (inicializados con los actuales)
  int? _premioIdPieza1;
  int? _premioIdPieza2;

  // Premios originales para detectar cambios
  int? _origPremioIdPieza1;
  int? _origPremioIdPieza2;

  @override
  void initState() {
    super.initState();
    _origPremioIdPieza1 = widget.registro.artesania1?.idPremio;
    _origPremioIdPieza2 = widget.registro.artesania2?.idPremio;

    _premioIdPieza1 = _origPremioIdPieza1;
    _premioIdPieza2 = _origPremioIdPieza2;

    _cargarPremios();
  }

  Future<void> _cargarPremios() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(premioRepositoryProvider);
      final list = await repo.getPremiosByConcurso(widget.concurso.id!);
      final conteo = await repo.getConteoPremiosOtorgados(widget.concurso.id!);

      if (mounted) {
        setState(() {
          _premios = list;
          _conteoOtorgados = conteo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar premios: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  String _getPremioNombre(int? idPremio) {
    if (idPremio == null) return 'Sin premio';
    final match = _premios.where((p) => p.id == idPremio);
    if (match.isNotEmpty) return match.first.nombre;
    if (idPremio == widget.registro.artesania1?.idPremio) {
      return widget.registro.artesania1?.premioNombre ?? 'Premio #$idPremio';
    }
    if (idPremio == widget.registro.artesania2?.idPremio) {
      return widget.registro.artesania2?.premioNombre ?? 'Premio #$idPremio';
    }
    return 'Premio #$idPremio';
  }

  /// Calcula la disponibilidad de un premio para la pieza actualmente seleccionada
  bool _isPremioDisponibleParaPieza(Premio premio, int piezaIndex) {
    final int? premioActualEstaPieza = (piezaIndex == 1) ? _premioIdPieza1 : _premioIdPieza2;
    if (premioActualEstaPieza == premio.id) {
      return true; // Ya lo tiene asignado esta pieza
    }

    final int? premioOtraPieza = (piezaIndex == 1) ? _premioIdPieza2 : _premioIdPieza1;
    final int usoEnOtraPiezaEsteRegistro = (premioOtraPieza == premio.id) ? 1 : 0;

    // Cuántas piezas en la BD (excluyendo las piezas de este registro) tienen este premio
    int usoEnOtrasInscripciones = _conteoOtorgados[premio.id] ?? 0;
    if (_origPremioIdPieza1 == premio.id) usoEnOtrasInscripciones--;
    if (_origPremioIdPieza2 == premio.id) usoEnOtrasInscripciones--;
    if (usoEnOtrasInscripciones < 0) usoEnOtrasInscripciones = 0;

    final int cuposOcupados = usoEnOtrasInscripciones + usoEnOtraPiezaEsteRegistro;
    final int cuposRestantes = premio.limiteOtorgacion - cuposOcupados;

    return cuposRestantes > 0;
  }

  int _getCuposRestantes(Premio premio, int piezaIndex) {
    final int? premioOtraPieza = (piezaIndex == 1) ? _premioIdPieza2 : _premioIdPieza1;
    final int usoEnOtraPiezaEsteRegistro = (premioOtraPieza == premio.id) ? 1 : 0;

    int usoEnOtrasInscripciones = _conteoOtorgados[premio.id] ?? 0;
    if (_origPremioIdPieza1 == premio.id) usoEnOtrasInscripciones--;
    if (_origPremioIdPieza2 == premio.id) usoEnOtrasInscripciones--;
    if (usoEnOtrasInscripciones < 0) usoEnOtrasInscripciones = 0;

    final int cuposOcupados = usoEnOtrasInscripciones + usoEnOtraPiezaEsteRegistro;
    return premio.limiteOtorgacion - cuposOcupados;
  }

  Future<void> _guardarPremiacion() async {
    final p1 = widget.registro.artesania1;
    final p2 = widget.registro.artesania2;
    final repo = ref.read(premioRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);
    try {
      // 1. Procesar Pieza 1 si cambió
      if (p1 != null && _premioIdPieza1 != _origPremioIdPieza1) {
        if (_premioIdPieza1 == null) {
          await repo.removerPremiacion(
            idConcurso: widget.concurso.id!,
            idArtesania: p1.id!,
          );
        } else {
          final premio = _premios.firstWhere((p) => p.id == _premioIdPieza1);
          await repo.asignarPremiacion(
            idConcurso: widget.concurso.id!,
            idPremio: _premioIdPieza1!,
            idArtesania: p1.id!,
            idCategoria: premio.idCategoria ?? p1.idCategoriaConcurso,
            lugar: premio.lugar,
          );
        }
      }

      // 2. Procesar Pieza 2 si cambió
      if (p2 != null && _premioIdPieza2 != _origPremioIdPieza2) {
        if (_premioIdPieza2 == null) {
          await repo.removerPremiacion(
            idConcurso: widget.concurso.id!,
            idArtesania: p2.id!,
          );
        } else {
          final premio = _premios.firstWhere((p) => p.id == _premioIdPieza2);
          await repo.asignarPremiacion(
            idConcurso: widget.concurso.id!,
            idPremio: _premioIdPieza2!,
            idArtesania: p2.id!,
            idCategoria: premio.idCategoria ?? p2.idCategoriaConcurso,
            lugar: premio.lugar,
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '✓ Premiación de Folio #${widget.registro.folio} guardada con éxito.',
            ),
            backgroundColor: AppTheme.verdeSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error al guardar premiación: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p1 = widget.registro.artesania1;
    final p2 = widget.registro.artesania2;
    final bool hasPieza2 = p2 != null && p2.nombre.trim().isNotEmpty && p2.nombre.trim().toUpperCase() != 'N/A';

    final piezaActual = _selectedPieza == 1 ? p1 : p2;
    final int? premioSeleccionadoEstaPieza = _selectedPieza == 1 ? _premioIdPieza1 : _premioIdPieza2;

    return Dialog(
      backgroundColor: AppTheme.dialogBodyBg,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 780,
        height: 700,
        color: AppTheme.dialogBodyBg,
        child: Column(
          children: [
            // ENCABEZADO
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                    child: Icon(Icons.emoji_events, color: Colors.amber.shade900, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Premiar Piezas',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red.shade300),
                              ),
                              child: Text(
                                'Folio #${widget.registro.folio}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Artesano: ${widget.registro.artesano?.nombreCompleto ?? 'N/A'} • Localidad: ${widget.registro.artesano?.localidad ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            // CUERPO
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // PASO 1: SELECCIÓN DE PIEZA (SI TIENE 2 PIEZAS)
                          const Text(
                            '1. Selecciona la pieza a premiar:',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.casart900),
                          ),
                          const SizedBox(height: 8),

                          if (hasPieza2)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPiezaCard(
                                    piezaLetra: 'A',
                                    piezaNombre: p1?.nombre ?? 'Pieza 1',
                                    categoria: p1?.categoriaNombre ?? p1?.ramaNombre ?? 'General',
                                    costoVenta: p1?.costoVenta ?? 0.0,
                                    premioId: _premioIdPieza1,
                                    isSelected: _selectedPieza == 1,
                                    onTap: () => setState(() => _selectedPieza = 1),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _buildPiezaCard(
                                    piezaLetra: 'B',
                                    piezaNombre: p2.nombre,
                                    categoria: p2.categoriaNombre ?? p2.ramaNombre ?? 'General',
                                    costoVenta: p2.costoVenta,
                                    premioId: _premioIdPieza2,
                                    isSelected: _selectedPieza == 2,
                                    onTap: () => setState(() => _selectedPieza = 2),
                                  ),
                                ),
                              ],
                            )
                          else
                            _buildPiezaCard(
                              piezaLetra: 'A',
                              piezaNombre: p1?.nombre ?? 'Pieza 1',
                              categoria: p1?.categoriaNombre ?? p1?.ramaNombre ?? 'General',
                              costoVenta: p1?.costoVenta ?? 0.0,
                              premioId: _premioIdPieza1,
                              isSelected: true,
                              onTap: () {},
                            ),

                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // PASO 2: SELECCIÓN DE PREMIO
                          Row(
                            children: [
                              Text(
                                '2. Asignar premio a Pieza (${_selectedPieza == 1 ? 'A' : 'B'}):',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.casart900),
                              ),
                              const Spacer(),
                              Text(
                                '${_premios.length} premio${_premios.length == 1 ? '' : 's'} en convocatoria',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // LISTA DE PREMIOS
                          Expanded(
                            child: _premios.isEmpty
                                ? Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.amber.shade200),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.info_outline, size: 36, color: Colors.amber.shade800),
                                          const SizedBox(height: 10),
                                          Text(
                                            'No hay premios registrados para este concurso.',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Puedes registrar la bolsa de premios en el módulo "Premios y Convocatoria".',
                                            style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: ListView.separated(
                                      itemCount: _premios.length + 1,
                                      separatorBuilder: (_, _) => const Divider(height: 1),
                                      itemBuilder: (ctx, idx) {
                                        // OPCIÓN 0: QUITAR PREMIO / SIN PREMIO
                                        if (idx == 0) {
                                          final isSinPremio = premioSeleccionadoEstaPieza == null;
                                          return ListTile(
                                            dense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                            leading: Radio<int?>(
                                              value: null,
                                              groupValue: premioSeleccionadoEstaPieza,
                                              onChanged: (val) {
                                                setState(() {
                                                  if (_selectedPieza == 1) {
                                                    _premioIdPieza1 = null;
                                                  } else {
                                                    _premioIdPieza2 = null;
                                                  }
                                                });
                                              },
                                            ),
                                            title: const Text(
                                              'Sin Premio (Ninguno / Quitar premio)',
                                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                            ),
                                            subtitle: const Text(
                                              'La pieza no recibirá premio',
                                              style: TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                            trailing: isSinPremio
                                                ? Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade200,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text('Actual', style: TextStyle(fontSize: 11, color: Colors.black87)),
                                                  )
                                                : null,
                                            onTap: () {
                                              setState(() {
                                                if (_selectedPieza == 1) {
                                                  _premioIdPieza1 = null;
                                                } else {
                                                  _premioIdPieza2 = null;
                                                }
                                              });
                                            },
                                          );
                                        }

                                        // OPCIONES 1..N: PREMIOS DEL CONCURSO
                                        final premio = _premios[idx - 1];
                                        final bool isAsignadoAEstaPieza = premioSeleccionadoEstaPieza == premio.id;
                                        final bool isDisponible = _isPremioDisponibleParaPieza(premio, _selectedPieza);
                                        final int cuposRestantes = _getCuposRestantes(premio, _selectedPieza);

                                        // Comprobación si la categoría coincide
                                        final bool coincideCategoria = premio.idCategoria == null ||
                                            premio.idCategoria == piezaActual?.idCategoriaConcurso;

                                        return ListTile(
                                          dense: true,
                                          enabled: isDisponible,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                          leading: Radio<int?>(
                                            value: premio.id,
                                            groupValue: premioSeleccionadoEstaPieza,
                                            onChanged: isDisponible
                                                ? (val) {
                                                    setState(() {
                                                      if (_selectedPieza == 1) {
                                                        _premioIdPieza1 = val;
                                                      } else {
                                                        _premioIdPieza2 = val;
                                                      }
                                                    });
                                                  }
                                                : null,
                                          ),
                                          title: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  premio.nombre,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: isDisponible ? Colors.black87 : Colors.grey.shade500,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                Formatters.formatCurrency(premio.monto),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: isDisponible ? AppTheme.verdeSuccess : Colors.grey.shade400,
                                                ),
                                              ),
                                            ],
                                          ),
                                          subtitle: Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Row(
                                              children: [
                                                // Etiqueta de Categoría
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: coincideCategoria ? Colors.blue.shade50 : Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(3),
                                                    border: Border.all(
                                                      color: coincideCategoria ? Colors.blue.shade200 : Colors.grey.shade300,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    premio.categoriaNombre != null
                                                        ? 'Cat: ${premio.categoriaNombre}'
                                                        : 'Global (Cualquier categoría)',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: coincideCategoria ? Colors.blue.shade800 : Colors.grey.shade600,
                                                      fontWeight: coincideCategoria ? FontWeight.w600 : FontWeight.normal,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),

                                                // Estatus de disponibilidad
                                                if (isAsignadoAEstaPieza)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber.shade100,
                                                      borderRadius: BorderRadius.circular(3),
                                                      border: Border.all(color: Colors.amber.shade400),
                                                    ),
                                                    child: Text(
                                                      '✓ Asignado a esta pieza',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.amber.shade900,
                                                      ),
                                                    ),
                                                  )
                                                else if (isDisponible)
                                                  Text(
                                                    'Disponible ($cuposRestantes de ${premio.limiteOtorgacion} restante${premio.limiteOtorgacion > 1 ? 's' : ''})',
                                                    style: TextStyle(fontSize: 10.5, color: Colors.green.shade700),
                                                  )
                                                else
                                                  Text(
                                                    'Agotado (${premio.limiteOtorgacion}/${premio.limiteOtorgacion} otorgados)',
                                                    style: TextStyle(fontSize: 10.5, color: Colors.red.shade700, fontWeight: FontWeight.bold),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          onTap: isDisponible
                                              ? () {
                                                  setState(() {
                                                    if (_selectedPieza == 1) {
                                                      _premioIdPieza1 = premio.id;
                                                    } else {
                                                      _premioIdPieza2 = premio.id;
                                                    }
                                                  });
                                                }
                                              : null,
                                        );
                                      },
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
            ),

            // FOOTER CON BOTONES
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: AppTheme.cancelButtonStyle,
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isSaving ? null : _guardarPremiacion,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle, size: 18),
                    label: Text(_isSaving ? 'Guardando...' : 'Guardar Premiación'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPiezaCard({
    required String piezaLetra,
    required String piezaNombre,
    required String categoria,
    required double costoVenta,
    required int? premioId,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final bool hasPremio = premioId != null;
    final String premioNombre = _getPremioNombre(premioId);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber.shade50.withValues(alpha: 0.6) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.amber.shade800 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.amber.shade200.withValues(alpha: 0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.amber.shade800 : AppTheme.casart800,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Pieza ($piezaLetra)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const Spacer(),
                Text(
                  Formatters.formatCurrency(costoVenta),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.verdeSuccess),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              piezaNombre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              'Categoría: $categoria',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // BADGE DE PREMIO ACTUAL
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: hasPremio ? Colors.amber.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: hasPremio ? Colors.amber.shade400 : Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasPremio ? Icons.emoji_events : Icons.remove_circle_outline,
                    size: 13,
                    color: hasPremio ? Colors.amber.shade900 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      hasPremio ? '🏆 $premioNombre' : 'Sin premio asignado',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: hasPremio ? FontWeight.bold : FontWeight.normal,
                        color: hasPremio ? Colors.amber.shade900 : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
