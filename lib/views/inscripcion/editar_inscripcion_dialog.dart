import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/registro_concurso.dart';
import '../../models/concurso.dart';
import '../../models/artesano.dart';
import '../../models/artesania.dart';
import '../../models/subcategoria.dart';
import '../../providers/database_provider.dart';
import '../../providers/inscripcion_provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/data/municipios_data.dart';

class EditarInscripcionDialog extends ConsumerStatefulWidget {
  final RegistroConcurso registro;
  final Concurso concurso;
  final bool isReadOnly;

  const EditarInscripcionDialog({
    super.key,
    required this.registro,
    required this.concurso,
    this.isReadOnly = false,
  });

  @override
  ConsumerState<EditarInscripcionDialog> createState() =>
      _EditarInscripcionDialogState();
}

class _EditarInscripcionDialogState
    extends ConsumerState<EditarInscripcionDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  bool get _isReadOnly => widget.isReadOnly || widget.concurso.finalizado;

  // Artesano
  late TextEditingController _artNombreCtrl;
  late TextEditingController _artApPaternoCtrl;
  late TextEditingController _artApMaternoCtrl;
  late TextEditingController _artCurpCtrl;
  late TextEditingController _artRfcCtrl;
  late TextEditingController _artFechaNacimientoCtrl;
  String? _artGenero;
  late TextEditingController _artTelefonoCtrl;
  String? _artMunicipio;
  String? _artLocalidad;
  late TextEditingController _artMunicipioCtrl;
  late TextEditingController _artLocalidadCtrl;
  late TextEditingController _artColoniaCtrl;
  late TextEditingController _artCalleCtrl;
  late TextEditingController _artNumExteriorCtrl;
  late TextEditingController _artCodigoPostalCtrl;
  int? _artEtniaId;
  int? _artEstadoCivilId;
  int _artNivelEducativo = 0;

  static const List<String> _nivelesEducativos = [
    'Ninguno',
    'Primaria inc.',
    'Primaria comp.',
    'Secundaria inc.',
    'Secundaria comp.',
    'Prepa inc.',
    'Prepa comp.',
    'Universidad inc.',
    'Universidad comp.',
    'Posgrado',
  ];

  static const List<String> _nivelesEducativosDetalle = [
    'Ninguno (Sin escolaridad)',
    'Primaria incompleta',
    'Primaria completa',
    'Secundaria incompleta',
    'Secundaria completa',
    'Preparatoria incompleta',
    'Preparatoria completa',
    'Universidad incompleta',
    'Universidad completa',
    'Posgrado',
  ];

  // Pieza 1
  late TextEditingController _p1NombreCtrl;
  int? _p1RamaId;
  int? _p1CategoriaId;
  int? _p1SubcategoriaId;
  late TextEditingController _p1CostoCtrl;
  late TextEditingController _p1TiempoCtrl;
  late String _p1Plazo;
  late TextEditingController _p1MaterialCtrl;
  late TextEditingController _p1DescripcionCtrl;

  // Pieza 2
  late bool _incluirPieza2;
  late TextEditingController _p2NombreCtrl;
  int? _p2RamaId;
  int? _p2CategoriaId;
  int? _p2SubcategoriaId;
  late TextEditingController _p2CostoCtrl;
  late TextEditingController _p2TiempoCtrl;
  late String _p2Plazo;
  late TextEditingController _p2MaterialCtrl;
  late TextEditingController _p2DescripcionCtrl;

  // Catálogos
  List<Map<String, dynamic>> _ramas = [];
  List<Map<String, dynamic>> _etnias = [];
  List<Map<String, dynamic>> _estadosCiviles = [];

  bool _isLoadingCatalogos = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final a = widget.registro.artesano;
    _artNombreCtrl = TextEditingController(text: a?.nombre ?? '');
    _artApPaternoCtrl = TextEditingController(text: a?.apPaterno ?? '');
    _artApMaternoCtrl = TextEditingController(text: a?.apMaterno ?? '');
    _artCurpCtrl = TextEditingController(text: a?.curp ?? '');
    _artRfcCtrl = TextEditingController(text: a?.rfc ?? '');
    _artFechaNacimientoCtrl = TextEditingController(
      text: a?.fechaNacimiento ?? '',
    );
    final g = a?.genero?.toUpperCase();
    if (g == 'M' || g == 'HOMBRE' || g == 'MASCULINO') {
      _artGenero = 'M';
    } else if (g == 'F' || g == 'MUJER' || g == 'FEMENINO') {
      _artGenero = 'F';
    } else if (g == 'O' || g == 'OTRO') {
      _artGenero = 'O';
    } else {
      _artGenero = null;
    }
    _artTelefonoCtrl = TextEditingController(text: a?.telefono ?? '');
    final rawMun = a?.municipio.trim();
    _artMunicipio = _resolveMunicipio(rawMun);
    _artMunicipioCtrl = TextEditingController(
      text: _artMunicipio ?? (rawMun ?? ''),
    );
    final rawLoc = a?.localidad.trim();
    _artLocalidad = rawLoc;
    _artLocalidadCtrl = TextEditingController(
      text: _artLocalidad ?? (rawLoc ?? ''),
    );
    _artColoniaCtrl = TextEditingController(text: a?.colonia ?? '');
    _artCalleCtrl = TextEditingController(text: a?.calle ?? '');
    _artNumExteriorCtrl = TextEditingController(text: a?.numeroExterior ?? '');
    _artCodigoPostalCtrl = TextEditingController(text: a?.codigoPostal ?? '');
    _artEtniaId = a?.idEtnia;
    _artEstadoCivilId = a?.idEstadoCivil;
    final rawNivel = int.tryParse(a?.nivelEducativo ?? '0') ?? 0;
    _artNivelEducativo = (rawNivel >= 0 && rawNivel <= 9) ? rawNivel : 0;

    final p1 = widget.registro.artesania1;
    _p1NombreCtrl = TextEditingController(text: p1?.nombre ?? '');
    _p1RamaId = p1?.idRamaArtesanal;
    _p1CategoriaId = p1?.idCategoriaConcurso;
    _p1SubcategoriaId = p1?.idSubCategoriaConcurso;
    _p1CostoCtrl = TextEditingController(
      text: p1 != null ? p1.costoProduccion.toStringAsFixed(2) : '0.00',
    );
    _p1TiempoCtrl = TextEditingController(
      text: p1 != null ? p1.tiempoElaboracion.toString() : '1.0',
    );
    _p1Plazo = p1?.plazoElaboracion ?? 'semanas';
    _p1MaterialCtrl = TextEditingController(
      text: p1?.materialElaboracion ?? '',
    );
    _p1DescripcionCtrl = TextEditingController(text: p1?.descripcion ?? '');

    final p2 = widget.registro.artesania2;
    _incluirPieza2 = p2 != null && p2.nombre.trim().isNotEmpty;
    _p2NombreCtrl = TextEditingController(text: p2?.nombre ?? '');
    _p2RamaId = p2?.idRamaArtesanal;
    _p2CategoriaId = p2?.idCategoriaConcurso;
    _p2SubcategoriaId = p2?.idSubCategoriaConcurso;
    _p2CostoCtrl = TextEditingController(
      text: p2 != null ? p2.costoProduccion.toStringAsFixed(2) : '0.00',
    );
    _p2TiempoCtrl = TextEditingController(
      text: p2 != null ? p2.tiempoElaboracion.toString() : '1.0',
    );
    _p2Plazo = p2?.plazoElaboracion ?? 'semanas';
    _p2MaterialCtrl = TextEditingController(
      text: p2?.materialElaboracion ?? '',
    );
    _p2DescripcionCtrl = TextEditingController(text: p2?.descripcion ?? '');

    _loadCatalogos();
  }

  Future<void> _loadCatalogos() async {
    try {
      final repo = ref.read(artesanoRepositoryProvider);
      final ramas = await repo.getRamasArtesanales();
      final etnias = await repo.getEtnias();
      final estadosCiviles = await repo.getEstadosCiviles();

      if (mounted) {
        setState(() {
          _ramas = ramas;
          _etnias = etnias;
          _estadosCiviles = estadosCiviles;
          _isLoadingCatalogos = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCatalogos = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _artNombreCtrl.dispose();
    _artApPaternoCtrl.dispose();
    _artApMaternoCtrl.dispose();
    _artCurpCtrl.dispose();
    _artRfcCtrl.dispose();
    _artFechaNacimientoCtrl.dispose();
    _artTelefonoCtrl.dispose();
    _artMunicipioCtrl.dispose();
    _artLocalidadCtrl.dispose();
    _artColoniaCtrl.dispose();
    _artCalleCtrl.dispose();
    _artNumExteriorCtrl.dispose();
    _artCodigoPostalCtrl.dispose();

    _p1NombreCtrl.dispose();
    _p1CostoCtrl.dispose();
    _p1TiempoCtrl.dispose();
    _p1MaterialCtrl.dispose();
    _p1DescripcionCtrl.dispose();

    _p2NombreCtrl.dispose();
    _p2CostoCtrl.dispose();
    _p2TiempoCtrl.dispose();
    _p2MaterialCtrl.dispose();
    _p2DescripcionCtrl.dispose();
    super.dispose();
  }

  String? _resolveMunicipio(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (MunicipiosData.municipios.contains(trimmed)) {
      return trimmed;
    }
    final rawLower = trimmed.toLowerCase();
    for (final m in MunicipiosData.municipios) {
      if (m.toLowerCase() == rawLower ||
          m.toLowerCase().startsWith(rawLower) ||
          rawLower.startsWith(m.toLowerCase().split(' zona')[0])) {
        return m;
      }
    }
    return trimmed;
  }

  Future<void> _seleccionarFechaNacimiento(
    TextEditingController controller,
  ) async {
    if (_isReadOnly) return;
    DateTime initialDate = DateTime(1980, 1, 1);
    if (controller.text.trim().isNotEmpty) {
      try {
        initialDate = DateTime.parse(controller.text.trim());
      } catch (_) {}
    }

    if (initialDate.isBefore(DateTime(1920))) initialDate = DateTime(1920);
    if (initialDate.isAfter(DateTime.now())) initialDate = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'MX'),
      helpText: 'FECHA DE NACIMIENTO',
      cancelText: 'CANCELAR',
      confirmText: 'ACEPTAR',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.casart800),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted =
          "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      setState(() {
        controller.text = formatted;
      });
    }
  }

  double _calcularCostoVenta(double costoProd) {
    final factor =
        1.0 + ((widget.concurso.iva + widget.concurso.utilidad) / 100.0);
    return costoProd * factor;
  }

  Future<void> _guardarCambios() async {
    if (_isReadOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pueden guardar cambios: el concurso está finalizado (modo solo lectura).',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final safeP1Cat =
        (_p1CategoriaId != null &&
            widget.concurso.categorias.any((c) => c.id == _p1CategoriaId))
        ? _p1CategoriaId
        : null;
    final safeP1Rama =
        (_p1RamaId != null && _ramas.any((r) => r['id'] == _p1RamaId))
        ? _p1RamaId
        : null;

    if (safeP1Cat == null) {
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una categoría válida para la Pieza 1.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (safeP1Rama == null) {
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una rama válida para la Pieza 1.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int? safeP2Cat;
    int? safeP2Rama;
    if (_incluirPieza2) {
      safeP2Cat =
          (_p2CategoriaId != null &&
              widget.concurso.categorias.any((c) => c.id == _p2CategoriaId))
          ? _p2CategoriaId
          : null;
      safeP2Rama =
          (_p2RamaId != null && _ramas.any((r) => r['id'] == _p2RamaId))
          ? _p2RamaId
          : null;
      if (_p2NombreCtrl.text.trim().isEmpty ||
          safeP2Cat == null ||
          safeP2Rama == null) {
        _tabController.animateTo(2);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Completa nombre, categoría y rama válidas para la Pieza 2.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(registroRepositoryProvider);

      final artesano = Artesano(
        id: widget.registro.idArtesano,
        nombre: _artNombreCtrl.text.trim(),
        apPaterno: _artApPaternoCtrl.text.trim(),
        apMaterno: _artApMaternoCtrl.text.trim().isNotEmpty
            ? _artApMaternoCtrl.text.trim()
            : null,
        curp: _artCurpCtrl.text.trim().toUpperCase(),
        rfc: _artRfcCtrl.text.trim().isNotEmpty
            ? _artRfcCtrl.text.trim().toUpperCase()
            : null,
        fechaNacimiento: _artFechaNacimientoCtrl.text.trim().isNotEmpty
            ? _artFechaNacimientoCtrl.text.trim()
            : null,
        genero: _artGenero,
        telefono: _artTelefonoCtrl.text.trim().isNotEmpty
            ? _artTelefonoCtrl.text.trim()
            : null,
        municipio: _artMunicipioCtrl.text.trim(),
        localidad: _artLocalidadCtrl.text.trim(),
        colonia: _artColoniaCtrl.text.trim().isNotEmpty
            ? _artColoniaCtrl.text.trim()
            : null,
        calle: _artCalleCtrl.text.trim().isNotEmpty
            ? _artCalleCtrl.text.trim()
            : null,
        numeroExterior: _artNumExteriorCtrl.text.trim().isNotEmpty
            ? _artNumExteriorCtrl.text.trim()
            : null,
        codigoPostal: _artCodigoPostalCtrl.text.trim().isNotEmpty
            ? _artCodigoPostalCtrl.text.trim()
            : null,
        idEtnia: _artEtniaId,
        idEstadoCivil: _artEstadoCivilId,
        nivelEducativo: _artNivelEducativo.toString(),
      );

      final p1Costo = double.tryParse(_p1CostoCtrl.text.trim()) ?? 0.0;
      final pieza1 = Artesania(
        id: widget.registro.idArtesania1,
        nombre: _p1NombreCtrl.text.trim(),
        costoProduccion: p1Costo,
        costoVenta: _calcularCostoVenta(p1Costo),
        estado: widget.registro.artesania1?.estado,
        tiempoElaboracion: double.tryParse(_p1TiempoCtrl.text.trim()) ?? 1.0,
        plazoElaboracion: _p1Plazo,
        materialElaboracion: _p1MaterialCtrl.text.trim(),
        descripcion: _p1DescripcionCtrl.text.trim(),
        idRamaArtesanal: safeP1Rama,
        idImagen: widget.registro.artesania1?.idImagen,
        idPremio: widget.registro.artesania1?.idPremio,
        idCategoriaConcurso: safeP1Cat,
        idSubCategoriaConcurso: _p1SubcategoriaId,
        createdAt: widget.registro.artesania1?.createdAt,
      );

      Artesania? pieza2;
      if (_incluirPieza2 && safeP2Cat != null && safeP2Rama != null) {
        final p2Costo = double.tryParse(_p2CostoCtrl.text.trim()) ?? 0.0;
        pieza2 = Artesania(
          id: widget.registro.idArtesania2,
          nombre: _p2NombreCtrl.text.trim(),
          costoProduccion: p2Costo,
          costoVenta: _calcularCostoVenta(p2Costo),
          estado: widget.registro.artesania2?.estado,
          tiempoElaboracion: double.tryParse(_p2TiempoCtrl.text.trim()) ?? 1.0,
          plazoElaboracion: _p2Plazo,
          materialElaboracion: _p2MaterialCtrl.text.trim(),
          descripcion: _p2DescripcionCtrl.text.trim(),
          idRamaArtesanal: safeP2Rama,
          idImagen: widget.registro.artesania2?.idImagen,
          idPremio: widget.registro.artesania2?.idPremio,
          idCategoriaConcurso: safeP2Cat,
          idSubCategoriaConcurso: _p2SubcategoriaId,
          createdAt: widget.registro.artesania2?.createdAt,
        );
      }

      final regActualizado = await repo.actualizarInscripcion(
        idRegistro: widget.registro.id!,
        idConcurso: widget.concurso.id!,
        artesano: artesano,
        pieza1: pieza1,
        pieza2: pieza2,
      );

      ref.invalidate(registrosConcursoProvider);

      if (mounted) {
        Navigator.of(context).pop(regActualizado);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar inscripción: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        height: 720,
        color: AppTheme.dialogBodyBg,
        child: _isLoadingCatalogos
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ENCABEZADO (Blanco con texto negro)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.dialogHeaderBg,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[700],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'FOLIO #${widget.registro.folio.toString().padLeft(4, '0')}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (_isReadOnly) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.blueGrey.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    size: 14,
                                    color: Colors.blueGrey.shade800,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'SOLO LECTURA',
                                    style: TextStyle(
                                      color: Colors.blueGrey.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(width: 14),
                          Text(
                            _isReadOnly
                                ? 'Cédula de Inscripción'
                                : 'Editar / Corregir Cédula de Inscripción',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.black54,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    // TAB BAR
                    Container(
                      color: Colors.grey.shade100,
                      child: TabBar(
                        controller: _tabController,
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Colors.grey.shade600,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        indicatorWeight: 3,
                        tabs: const [
                          Tab(
                            icon: Icon(Icons.person),
                            text: '1. Datos del Artesano',
                          ),
                          Tab(
                            icon: Icon(Icons.palette),
                            text: '2. Pieza 1 (Principal)',
                          ),
                          Tab(
                            icon: Icon(Icons.style),
                            text: '3. Pieza 2 (Segunda Pieza)',
                          ),
                        ],
                      ),
                    ),

                    if (_isReadOnly)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        color: Colors.blueGrey.shade50,
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.blueGrey.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Este concurso se encuentra finalizado. Los datos se muestran en modo solo lectura.',
                                style: TextStyle(
                                  color: Colors.blueGrey.shade800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // CUERPO DE PESTAÑAS
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTabArtesano(),
                          _buildTabPieza1(),
                          _buildTabPieza2(),
                        ],
                      ),
                    ),

                    // ACCIONES DE PIE
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.dialogHeaderBg,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Concurso: ${widget.concurso.nombre}${_isReadOnly ? ' (Finalizado)' : ''}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          if (_isReadOnly)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('CERRAR'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            )
                          else ...[
                            TextButton(
                              style: AppTheme.cancelButtonStyle,
                              onPressed: _isSaving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(
                                _isSaving
                                    ? 'Guardando...'
                                    : 'GUARDAR CORRECCIONES',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.verdeSuccess,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                              ),
                              onPressed: _isSaving ? null : _guardarCambios,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTabArtesano() {
    final safeEtniaId =
        (_artEtniaId != null && _etnias.any((e) => e['id'] == _artEtniaId))
        ? _artEtniaId
        : null;
    final safeEstadoCivilId =
        (_artEstadoCivilId != null &&
            _estadosCiviles.any((ec) => ec['id'] == _artEstadoCivilId))
        ? _artEstadoCivilId
        : null;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        IgnorePointer(
          ignoring: _isReadOnly,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _artNombreCtrl,
                      readOnly: _isReadOnly,
                      decoration: const InputDecoration(
                        labelText: 'Nombre(s) *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _artApPaternoCtrl,
                      readOnly: _isReadOnly,
                      decoration: const InputDecoration(
                        labelText: 'Primer Apellido *',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _artApMaternoCtrl,
                      readOnly: _isReadOnly,
                      decoration: const InputDecoration(
                        labelText: 'Segundo Apellido (Opcional)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _artCurpCtrl,
                      readOnly: _isReadOnly,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(18),
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9]'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'CURP (18 caracteres) *',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'La CURP es requerida';
                        if (v.trim().length != 18)
                          return 'La CURP debe tener exactamente 18 caracteres';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _artFechaNacimientoCtrl,
                      readOnly: _isReadOnly,
                      decoration: InputDecoration(
                        labelText: 'Fecha de Nacimiento *',
                        hintText: 'AAAA-MM-DD',
                        prefixIcon: const Icon(Icons.cake_outlined),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 20,
                          ),
                          onPressed: _isReadOnly
                              ? null
                              : () => _seleccionarFechaNacimiento(
                                  _artFechaNacimientoCtrl,
                                ),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey('edit_art_genero_$_artGenero'),
                      initialValue: _artGenero,
                      decoration: const InputDecoration(
                        labelText: 'Género *',
                        prefixIcon: Icon(Icons.wc_outlined),
                      ),
                      items: const [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Selecciona...'),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'M',
                          child: Text('Hombre'),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'F',
                          child: Text('Mujer'),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'O',
                          child: Text('Otro'),
                        ),
                      ],
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Requerido' : null,
                      onChanged: _isReadOnly
                          ? null
                          : (v) => setState(() => _artGenero = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _artTelefonoCtrl,
                      readOnly: _isReadOnly,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Teléfono de Contacto (Opcional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (val.isNotEmpty && val.length != 10) {
                          return 'Debe tener exactamente 10 dígitos';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _artRfcCtrl,
                      readOnly: _isReadOnly,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'RFC (Opcional)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey('edit_art_etnia_$safeEtniaId'),
                      initialValue: safeEtniaId,
                      decoration: const InputDecoration(labelText: 'Etnia *'),
                      items: _etnias
                          .where((e) => e['id'] != null)
                          .map(
                            (e) => DropdownMenuItem<int?>(
                              value: e['id'] as int,
                              child: Text(e['nombre'] as String),
                            ),
                          )
                          .toList(),
                      validator: (v) =>
                          v == null ? 'Selecciona una etnia' : null,
                      onChanged: _isReadOnly
                          ? null
                          : (v) => setState(() => _artEtniaId = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey('edit_art_civil_$safeEstadoCivilId'),
                      initialValue: safeEstadoCivilId,
                      decoration: const InputDecoration(
                        labelText: 'Estado Civil *',
                      ),
                      items: _estadosCiviles
                          .where((ec) => ec['id'] != null)
                          .map(
                            (ec) => DropdownMenuItem<int?>(
                              value: ec['id'] as int,
                              child: Text(ec['nombre'] as String),
                            ),
                          )
                          .toList(),
                      validator: (v) =>
                          v == null ? 'Selecciona un estado civil' : null,
                      onChanged: _isReadOnly
                          ? null
                          : (v) => setState(() => _artEstadoCivilId = v),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // BARRA DESLIZABLE DE ESCOLARIDAD (NIVEL EDUCATIVO)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E1E24)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade800
                        : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: 20,
                              color: AppTheme.casart800,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Escolaridad / Nivel Educativo *',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.casart100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.casart300),
                          ),
                          child: Text(
                            _nivelesEducativosDetalle[_artNivelEducativo],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppTheme.casart900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.casart800,
                        inactiveTrackColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade700
                            : Colors.grey.shade300,
                        thumbColor: AppTheme.casart800,
                        overlayColor: AppTheme.casart800.withValues(alpha: 0.2),
                        trackHeight: 6,
                        tickMarkShape: const RoundSliderTickMarkShape(
                          tickMarkRadius: 3,
                        ),
                        activeTickMarkColor: Colors.white,
                        inactiveTickMarkColor: Colors.grey.shade500,
                      ),
                      child: Slider(
                        value: _artNivelEducativo.toDouble(),
                        min: 0,
                        max: 9,
                        divisions: 9,
                        label: _nivelesEducativosDetalle[_artNivelEducativo],
                        onChanged: _isReadOnly
                            ? null
                            : (val) {
                                setState(() {
                                  _artNivelEducativo = val.round();
                                });
                              },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(_nivelesEducativos.length, (
                          index,
                        ) {
                          final isSelected = index == _artNivelEducativo;
                          return Text(
                            _nivelesEducativos[index],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.casart800
                                  : (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // SUBSECCIÓN: INFORMACIÓN DEL DOMICILIO
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueGrey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.home_outlined,
                      size: 20,
                      color: AppTheme.casart800,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'INFORMACIÓN DEL DOMICILIO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.casart800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selector de Municipio
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey('edit_art_mun_$_artMunicipio'),
                      initialValue: _artMunicipio,
                      isExpanded: true,
                      menuMaxHeight: 350,
                      decoration: const InputDecoration(
                        labelText: 'Municipio *',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      hint: const Text('Selecciona un municipio'),
                      items:
                          [
                                ...MunicipiosData.municipios,
                                if (_artMunicipio != null &&
                                    _artMunicipio!.trim().isNotEmpty &&
                                    !MunicipiosData.municipios.contains(
                                      _artMunicipio,
                                    ))
                                  _artMunicipio!,
                              ]
                              .map(
                                (mun) => DropdownMenuItem<String?>(
                                  value: mun,
                                  child: Text(
                                    mun,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requerido' : null,
                      onChanged: _isReadOnly
                          ? null
                          : (val) {
                              setState(() {
                                _artMunicipio = val;
                                _artMunicipioCtrl.text = val ?? '';
                                _artLocalidad = null;
                                _artLocalidadCtrl.clear();
                              });
                            },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Selector de Localidad dependiente
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final locs = MunicipiosData.obtenerLocalidades(
                          _artMunicipio,
                        );
                        final hasMun =
                            _artMunicipio != null &&
                            _artMunicipio!.trim().isNotEmpty;
                        final items = [
                          ...locs,
                          if (_artLocalidad != null &&
                              _artLocalidad!.trim().isNotEmpty &&
                              !locs.contains(_artLocalidad))
                            _artLocalidad!,
                        ];

                        return DropdownButtonFormField<String?>(
                          key: ValueKey(
                            'edit_art_loc_${_artMunicipio}_$_artLocalidad',
                          ),
                          initialValue: _artLocalidad,
                          isExpanded: true,
                          menuMaxHeight: 350,
                          decoration: InputDecoration(
                            labelText: 'Localidad *',
                            prefixIcon: const Icon(Icons.place_outlined),
                            helperText: hasMun
                                ? null
                                : 'Primero selecciona un municipio',
                          ),
                          hint: Text(
                            hasMun
                                ? 'Selecciona una localidad'
                                : 'Selecciona un municipio primero',
                          ),
                          disabledHint: const Text(
                            'Selecciona un municipio primero',
                          ),
                          items: !hasMun
                              ? null
                              : items
                                    .map(
                                      (loc) => DropdownMenuItem<String?>(
                                        value: loc,
                                        child: Text(
                                          loc,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Requerido'
                              : null,
                          onChanged: (_isReadOnly || !hasMun)
                              ? null
                              : (val) {
                                  setState(() {
                                    _artLocalidad = val;
                                    _artLocalidadCtrl.text = val ?? '';
                                  });
                                },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _artCodigoPostalCtrl,
                      readOnly: _isReadOnly,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Código Postal *',
                        prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'El Código Postal es obligatorio';
                        if (v.trim().length != 5) return 'Debe tener 5 dígitos';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _artCalleCtrl,
                      readOnly: _isReadOnly,
                      decoration: const InputDecoration(
                        labelText: 'Calle (Opcional)',
                        prefixIcon: Icon(Icons.signpost_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _artNumExteriorCtrl,
                      readOnly: _isReadOnly,
                      decoration: const InputDecoration(
                        labelText: 'Número Exterior (Opcional)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _artColoniaCtrl,
                      readOnly: _isReadOnly,
                      decoration: const InputDecoration(
                        labelText: 'Colonia (Opcional)',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabPieza1() {
    final p1Costo = double.tryParse(_p1CostoCtrl.text.trim()) ?? 0.0;
    final p1Venta = _calcularCostoVenta(p1Costo);

    final safeP1RamaId =
        (_p1RamaId != null && _ramas.any((r) => r['id'] == _p1RamaId))
        ? _p1RamaId
        : null;
    final safeP1CategoriaId =
        (_p1CategoriaId != null &&
            widget.concurso.categorias.any((c) => c.id == _p1CategoriaId))
        ? _p1CategoriaId
        : null;
    final p1Subcategorias = safeP1CategoriaId != null
        ? (widget.concurso.categorias
                  .where((c) => c.id == safeP1CategoriaId)
                  .firstOrNull
                  ?.subcategorias
                  .where((s) => s.id != null)
                  .toList() ??
              <Subcategoria>[])
        : <Subcategoria>[];
    final safeP1SubcategoriaId =
        (_p1SubcategoriaId != null &&
            p1Subcategorias.any((s) => s.id == _p1SubcategoriaId))
        ? _p1SubcategoriaId
        : null;
    final safeP1Plazo =
        const ['dias', 'semanas', 'meses', 'anos'].contains(_p1Plazo)
        ? _p1Plazo
        : 'semanas';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        IgnorePointer(
          ignoring: _isReadOnly,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _p1NombreCtrl,
                      readOnly: _isReadOnly,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la Artesanía *',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey('edit_p1_rama_$safeP1RamaId'),
                      initialValue: safeP1RamaId,
                      decoration: const InputDecoration(
                        labelText: 'Rama Artesanal *',
                      ),
                      items: _ramas
                          .where((r) => r['id'] != null)
                          .map(
                            (r) => DropdownMenuItem<int?>(
                              value: r['id'] as int,
                              child: Text(r['nombre'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: _isReadOnly
                          ? null
                          : (val) => setState(() => _p1RamaId = val),
                      validator: (v) => v == null ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey(
                        'edit_p1_cat_${widget.concurso.id}_$safeP1CategoriaId',
                      ),
                      initialValue: safeP1CategoriaId,
                      decoration: const InputDecoration(
                        labelText: 'Categoría del Concurso *',
                      ),
                      items: widget.concurso.categorias
                          .where((c) => c.id != null)
                          .map(
                            (c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(c.nombre),
                            ),
                          )
                          .toList(),
                      onChanged: _isReadOnly
                          ? null
                          : (val) {
                              setState(() {
                                _p1CategoriaId = val;
                                _p1SubcategoriaId = null;
                              });
                            },
                      validator: (v) => v == null ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey(
                        'edit_p1_sub_${safeP1CategoriaId}_$safeP1SubcategoriaId',
                      ),
                      initialValue: safeP1SubcategoriaId,
                      decoration: const InputDecoration(
                        labelText: 'Subcategoría (Opcional)',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Sin subcategoría'),
                        ),
                        ...p1Subcategorias
                            .where((s) => s.id != null)
                            .map(
                              (Subcategoria s) => DropdownMenuItem<int?>(
                                value: s.id,
                                child: Text(s.nombre),
                              ),
                            ),
                      ],
                      onChanged: _isReadOnly
                          ? null
                          : (val) => setState(() => _p1SubcategoriaId = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _p1CostoCtrl,
                      readOnly: _isReadOnly,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Costo de Producción (\$ MXN) *',
                        prefixText: '\$ ',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                          (double.tryParse(v ?? '') == null ||
                              double.parse(v!) <= 0)
                          ? 'Monto inválido'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.verdeLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.verdeBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Precio Sugerido Venta (+${widget.concurso.iva + widget.concurso.utilidad}%)',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.verdeSuccess,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            Formatters.formatCurrency(p1Venta),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.verdeSuccess,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _p1TiempoCtrl,
                      readOnly: _isReadOnly,
                      decoration: const InputDecoration(
                        labelText: 'Tiempo de Elab. *',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('edit_p1_plazo_$safeP1Plazo'),
                      initialValue: safeP1Plazo,
                      decoration: const InputDecoration(labelText: 'Plazo *'),
                      items: const [
                        DropdownMenuItem(value: 'dias', child: Text('Días')),
                        DropdownMenuItem(
                          value: 'semanas',
                          child: Text('Semanas'),
                        ),
                        DropdownMenuItem(value: 'meses', child: Text('Meses')),
                        DropdownMenuItem(value: 'anos', child: Text('Años')),
                      ],
                      onChanged: _isReadOnly
                          ? null
                          : (val) {
                              if (val != null) setState(() => _p1Plazo = val);
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _p1MaterialCtrl,
                readOnly: _isReadOnly,
                decoration: const InputDecoration(
                  labelText: 'Material de Elaboración *',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _p1DescripcionCtrl,
                readOnly: _isReadOnly,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción de la Pieza (Opcional)',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabPieza2() {
    final p2Costo = double.tryParse(_p2CostoCtrl.text.trim()) ?? 0.0;
    final p2Venta = _calcularCostoVenta(p2Costo);

    final safeP2RamaId =
        (_p2RamaId != null && _ramas.any((r) => r['id'] == _p2RamaId))
        ? _p2RamaId
        : null;
    final safeP2CategoriaId =
        (_p2CategoriaId != null &&
            widget.concurso.categorias.any((c) => c.id == _p2CategoriaId))
        ? _p2CategoriaId
        : null;
    final p2Subcategorias = safeP2CategoriaId != null
        ? (widget.concurso.categorias
                  .where((c) => c.id == safeP2CategoriaId)
                  .firstOrNull
                  ?.subcategorias
                  .where((s) => s.id != null)
                  .toList() ??
              <Subcategoria>[])
        : <Subcategoria>[];
    final safeP2SubcategoriaId =
        (_p2SubcategoriaId != null &&
            p2Subcategorias.any((s) => s.id == _p2SubcategoriaId))
        ? _p2SubcategoriaId
        : null;
    final safeP2Plazo =
        const ['dias', 'semanas', 'meses', 'anos'].contains(_p2Plazo)
        ? _p2Plazo
        : 'semanas';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        IgnorePointer(
          ignoring: _isReadOnly,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '¿Registrar o Conservar Pieza 2?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Activa esta opción si el artesano concursa con una segunda pieza.',
                ),
                value: _incluirPieza2,
                onChanged: _isReadOnly
                    ? null
                    : (val) => setState(() => _incluirPieza2 = val),
              ),
              const Divider(height: 24),
              if (!_incluirPieza2)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: const Text(
                    'No se registrará segunda pieza para esta cédula.\nSi el artesano entrega otra pieza más tarde, activa la casilla superior.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _p2NombreCtrl,
                        readOnly: _isReadOnly,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la Pieza 2 *',
                        ),
                        validator: (v) =>
                            _incluirPieza2 && (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int?>(
                        key: ValueKey('edit_p2_rama_$safeP2RamaId'),
                        initialValue: safeP2RamaId,
                        decoration: const InputDecoration(
                          labelText: 'Rama Artesanal 2 *',
                        ),
                        items: _ramas
                            .where((r) => r['id'] != null)
                            .map(
                              (r) => DropdownMenuItem<int?>(
                                value: r['id'] as int,
                                child: Text(r['nombre'] as String),
                              ),
                            )
                            .toList(),
                        onChanged: _isReadOnly
                            ? null
                            : (val) => setState(() => _p2RamaId = val),
                        validator: (v) =>
                            _incluirPieza2 && v == null ? 'Requerido' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        key: ValueKey(
                          'edit_p2_cat_${widget.concurso.id}_$safeP2CategoriaId',
                        ),
                        initialValue: safeP2CategoriaId,
                        decoration: const InputDecoration(
                          labelText: 'Categoría Pieza 2 *',
                        ),
                        items: widget.concurso.categorias
                            .where((c) => c.id != null)
                            .map(
                              (c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text(c.nombre),
                              ),
                            )
                            .toList(),
                        onChanged: _isReadOnly
                            ? null
                            : (val) {
                                setState(() {
                                  _p2CategoriaId = val;
                                  _p2SubcategoriaId = null;
                                });
                              },
                        validator: (v) =>
                            _incluirPieza2 && v == null ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        key: ValueKey(
                          'edit_p2_sub_${safeP2CategoriaId}_$safeP2SubcategoriaId',
                        ),
                        initialValue: safeP2SubcategoriaId,
                        decoration: const InputDecoration(
                          labelText: 'Subcategoría Pieza 2 (Opcional)',
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Sin subcategoría'),
                          ),
                          ...p2Subcategorias
                              .where((s) => s.id != null)
                              .map(
                                (Subcategoria s) => DropdownMenuItem<int?>(
                                  value: s.id,
                                  child: Text(s.nombre),
                                ),
                              ),
                        ],
                        onChanged: _isReadOnly
                            ? null
                            : (val) => setState(() => _p2SubcategoriaId = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _p2CostoCtrl,
                        readOnly: _isReadOnly,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Costo de Producción 2 (\$ MXN) *',
                          prefixText: '\$ ',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) =>
                            _incluirPieza2 &&
                                (double.tryParse(v ?? '') == null ||
                                    double.parse(v!) <= 0)
                            ? 'Monto inválido'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.verdeLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.verdeBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Precio Sugerido 2 (+${widget.concurso.iva + widget.concurso.utilidad}%)',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.verdeSuccess,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              Formatters.formatCurrency(p2Venta),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.verdeSuccess,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _p2TiempoCtrl,
                        readOnly: _isReadOnly,
                        decoration: const InputDecoration(
                          labelText: 'Tiempo 2 *',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('edit_p2_plazo_$safeP2Plazo'),
                        initialValue: safeP2Plazo,
                        decoration: const InputDecoration(
                          labelText: 'Plazo 2 *',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'dias', child: Text('Días')),
                          DropdownMenuItem(
                            value: 'semanas',
                            child: Text('Semanas'),
                          ),
                          DropdownMenuItem(
                            value: 'meses',
                            child: Text('Meses'),
                          ),
                          DropdownMenuItem(value: 'anos', child: Text('Años')),
                        ],
                        onChanged: _isReadOnly
                            ? null
                            : (val) {
                                if (val != null) setState(() => _p2Plazo = val);
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _p2MaterialCtrl,
                  readOnly: _isReadOnly,
                  decoration: const InputDecoration(
                    labelText: 'Material de Elaboración 2 *',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _p2DescripcionCtrl,
                  readOnly: _isReadOnly,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripción Pieza 2 (Opcional)',
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
