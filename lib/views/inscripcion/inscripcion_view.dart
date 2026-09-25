import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/concurso.dart';
import '../../models/artesano.dart';
import '../../models/artesania.dart';
import '../../models/subcategoria.dart';
import '../../models/registro_concurso.dart';
import '../../providers/database_provider.dart';
import '../../providers/concursos_provider.dart';
import '../../providers/inscripcion_provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/data/municipios_data.dart';
import 'comprobante_dialog.dart';
import 'editar_inscripcion_dialog.dart';
import 'premiar_pieza_dialog.dart';
import '../common/excel_export_dropdown.dart';

class InscripcionView extends ConsumerStatefulWidget {
  const InscripcionView({super.key});

  @override
  ConsumerState<InscripcionView> createState() => _InscripcionViewState();
}

class _InscripcionViewState extends ConsumerState<InscripcionView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();

  // Búsqueda de artesano
  final _busquedaCurpCtrl = TextEditingController();
  Artesano? _selectedArtesano;
  bool _esNuevoArtesano = false;

  // Datos de nuevo artesano
  final _artNombreCtrl = TextEditingController();
  final _artApPaternoCtrl = TextEditingController();
  final _artApMaternoCtrl = TextEditingController();
  final _artCurpCtrl = TextEditingController();
  final _artRfcCtrl = TextEditingController();
  final _artFechaNacimientoCtrl = TextEditingController();
  String? _artGenero;
  final _artTelefonoCtrl = TextEditingController();
  String? _artMunicipio;
  String? _artLocalidad;
  final _artMunicipioCtrl = TextEditingController();
  final _artLocalidadCtrl = TextEditingController();
  final _artColoniaCtrl = TextEditingController();
  final _artCalleCtrl = TextEditingController();
  final _artNumExteriorCtrl = TextEditingController();
  final _artCodigoPostalCtrl = TextEditingController();
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

  static String _getNivelEducativoTexto(String? raw) {
    if (raw == null || raw.isEmpty) return 'No especificado';
    final index = int.tryParse(raw);
    if (index != null &&
        index >= 0 &&
        index < _nivelesEducativosDetalle.length) {
      return _nivelesEducativosDetalle[index];
    }
    return raw;
  }

  // Pieza 1
  final _p1NombreCtrl = TextEditingController();
  int? _p1RamaId;
  int? _p1CategoriaId;
  int? _p1SubcategoriaId;
  final _p1CostoCtrl = TextEditingController();
  final _p1TiempoCtrl = TextEditingController(text: '1.0');
  String _p1Plazo = 'semanas';
  final _p1MaterialCtrl = TextEditingController();
  final _p1DescripcionCtrl = TextEditingController();

  // Pieza 2
  bool _incluirPieza2 = false;
  final _p2NombreCtrl = TextEditingController();
  int? _p2RamaId;
  int? _p2CategoriaId;
  int? _p2SubcategoriaId;
  final _p2CostoCtrl = TextEditingController();
  final _p2TiempoCtrl = TextEditingController(text: '1.0');
  String _p2Plazo = 'semanas';
  final _p2MaterialCtrl = TextEditingController();
  final _p2DescripcionCtrl = TextEditingController();

  // Catálogos
  List<Map<String, dynamic>> _ramas = [];
  List<Map<String, dynamic>> _etnias = [];
  List<Map<String, dynamic>> _estadosCiviles = [];

  bool _isSaving = false;
  int? _lastConcursoId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCatalogos();
  }

  Future<void> _loadCatalogos() async {
    final repo = ref.read(artesanoRepositoryProvider);
    final ramas = await repo.getRamasArtesanales();
    final etnias = await repo.getEtnias();
    final estadosCiviles = await repo.getEstadosCiviles();

    if (mounted) {
      setState(() {
        _ramas = ramas;
        _etnias = etnias;
        _estadosCiviles = estadosCiviles;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _busquedaCurpCtrl.dispose();
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

  Future<void> _seleccionarFechaNacimiento(
    TextEditingController controller,
  ) async {
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

  void _autocompletarDesdeCurp(String rawCurp) {
    final curp = rawCurp.trim().toUpperCase();
    if (curp.length >= 10) {
      try {
        final yearStr = curp.substring(4, 6);
        final monthStr = curp.substring(6, 8);
        final dayStr = curp.substring(8, 10);
        final yearInt = int.tryParse(yearStr);
        final monthInt = int.tryParse(monthStr);
        final dayInt = int.tryParse(dayStr);

        if (yearInt != null &&
            monthInt != null &&
            dayInt != null &&
            monthInt >= 1 &&
            monthInt <= 12 &&
            dayInt >= 1 &&
            dayInt <= 31) {
          final currentYearShort = DateTime.now().year % 100;
          final fullYear = (yearInt > currentYearShort)
              ? 1900 + yearInt
              : 2000 + yearInt;
          final formattedDate =
              "$fullYear-${monthStr.padLeft(2, '0')}-${dayStr.padLeft(2, '0')}";
          if (_artFechaNacimientoCtrl.text.isEmpty) {
            _artFechaNacimientoCtrl.text = formattedDate;
          }
        }

        if (curp.length >= 11 && _artGenero == null) {
          final generoChar = curp.substring(10, 11);
          if (generoChar == 'M') {
            setState(() => _artGenero = 'F');
          } else if (generoChar == 'H') {
            setState(() => _artGenero = 'M');
          }
        }
      } catch (_) {}
    }
  }

  double _calcularCostoVenta(double costoProd, Concurso c) {
    final factor = 1.0 + ((c.iva + c.utilidad) / 100.0);
    return costoProd * factor;
  }

  Future<void> _buscarArtesano(String query) async {
    if (query.trim().isEmpty) return;
    final repo = ref.read(artesanoRepositoryProvider);
    final artesanos = await repo.searchArtesanos(query: query, limit: 1);

    if (!mounted) return;

    if (artesanos.isNotEmpty) {
      setState(() {
        _selectedArtesano = artesanos.first;
        _esNuevoArtesano = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Artesano localizado: ${_selectedArtesano!.nombreCompleto}',
          ),
          backgroundColor: AppTheme.casart800,
        ),
      );
    } else {
      setState(() {
        _selectedArtesano = null;
        _esNuevoArtesano = true;
        if (int.tryParse(query.trim()) == null) {
          _artCurpCtrl.text = query.trim().toUpperCase();
        } else {
          _artCurpCtrl.clear();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se encontró el artesano. Puedes capturar sus datos a continuación.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _guardarInscripcion(Concurso concurso) async {
    if (concurso.finalizado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pueden inscribir piezas: el concurso está finalizado (modo solo lectura).',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedArtesano == null && !_esNuevoArtesano) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar o registrar un artesano.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final safeP1Cat =
        (_p1CategoriaId != null &&
            concurso.categorias.any((c) => c.id == _p1CategoriaId))
        ? _p1CategoriaId
        : null;
    final safeP1Rama =
        (_p1RamaId != null && _ramas.any((r) => r['id'] == _p1RamaId))
        ? _p1RamaId
        : null;

    if (safeP1Cat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una categoría válida para la Pieza 1.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (safeP1Rama == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecciona una rama artesanal válida para la Pieza 1.',
          ),
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
              concurso.categorias.any((c) => c.id == _p2CategoriaId))
          ? _p2CategoriaId
          : null;
      safeP2Rama =
          (_p2RamaId != null && _ramas.any((r) => r['id'] == _p2RamaId))
          ? _p2RamaId
          : null;
      if (_p2NombreCtrl.text.trim().isEmpty ||
          safeP2Cat == null ||
          safeP2Rama == null) {
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

      // Artesano
      final Artesano artesanoFinal = _esNuevoArtesano
          ? Artesano(
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
            )
          : _selectedArtesano!;

      // Pieza 1
      final p1CostoProd = double.tryParse(_p1CostoCtrl.text.trim()) ?? 0.0;
      final p1CostoVent = _calcularCostoVenta(p1CostoProd, concurso);

      final pieza1 = Artesania(
        nombre: _p1NombreCtrl.text.trim(),
        idRamaArtesanal: safeP1Rama,
        costoProduccion: p1CostoProd,
        costoVenta: p1CostoVent,
        tiempoElaboracion: double.tryParse(_p1TiempoCtrl.text.trim()) ?? 1.0,
        plazoElaboracion: _p1Plazo,
        materialElaboracion: _p1MaterialCtrl.text.trim(),
        descripcion: _p1DescripcionCtrl.text.trim(),
        idCategoriaConcurso: safeP1Cat,
        idSubCategoriaConcurso: _p1SubcategoriaId,
      );

      // Pieza 2
      Artesania? pieza2;
      if (_incluirPieza2 && safeP2Cat != null && safeP2Rama != null) {
        final p2CostoProd = double.tryParse(_p2CostoCtrl.text.trim()) ?? 0.0;
        final p2CostoVent = _calcularCostoVenta(p2CostoProd, concurso);

        pieza2 = Artesania(
          nombre: _p2NombreCtrl.text.trim(),
          idRamaArtesanal: safeP2Rama,
          costoProduccion: p2CostoProd,
          costoVenta: p2CostoVent,
          tiempoElaboracion: double.tryParse(_p2TiempoCtrl.text.trim()) ?? 1.0,
          plazoElaboracion: _p2Plazo,
          materialElaboracion: _p2MaterialCtrl.text.trim(),
          descripcion: _p2DescripcionCtrl.text.trim(),
          idCategoriaConcurso: safeP2Cat,
          idSubCategoriaConcurso: _p2SubcategoriaId,
        );
      }

      final nuevoRegistro = await repo.registrarInscripcion(
        idConcurso: concurso.id!,
        artesano: artesanoFinal,
        esNuevoArtesano: _esNuevoArtesano,
        pieza1: pieza1,
        pieza2: pieza2,
      );

      // Refrescar listado
      ref.invalidate(registrosConcursoProvider);
      ref.invalidate(nextFolioProvider);

      // Limpiar formulario
      _limpiarFormulario();

      if (mounted) {
        // Abrir visor de impresión directamente
        showDialog(
          context: context,
          builder: (ctx) => ComprobanteDialog(registro: nuevoRegistro),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar inscripción: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _limpiarFormulario() {
    setState(() {
      _selectedArtesano = null;
      _esNuevoArtesano = false;
      _busquedaCurpCtrl.clear();
      _artNombreCtrl.clear();
      _artApPaternoCtrl.clear();
      _artApMaternoCtrl.clear();
      _artCurpCtrl.clear();
      _artRfcCtrl.clear();
      _artFechaNacimientoCtrl.clear();
      _artGenero = null;
      _artTelefonoCtrl.clear();
      _artMunicipio = null;
      _artMunicipioCtrl.clear();
      _artLocalidad = null;
      _artLocalidadCtrl.clear();
      _artColoniaCtrl.clear();
      _artCalleCtrl.clear();
      _artNumExteriorCtrl.clear();
      _artCodigoPostalCtrl.clear();
      _artEtniaId = null;
      _artEstadoCivilId = null;
      _artNivelEducativo = 0;

      _p1NombreCtrl.clear();
      _p1RamaId = null;
      _p1CategoriaId = null;
      _p1SubcategoriaId = null;
      _p1CostoCtrl.clear();
      _p1TiempoCtrl.text = '1.0';
      _p1Plazo = 'semanas';
      _p1MaterialCtrl.clear();
      _p1DescripcionCtrl.clear();

      _incluirPieza2 = false;
      _p2NombreCtrl.clear();
      _p2RamaId = null;
      _p2CategoriaId = null;
      _p2SubcategoriaId = null;
      _p2CostoCtrl.clear();
      _p2TiempoCtrl.text = '1.0';
      _p2Plazo = 'semanas';
      _p2MaterialCtrl.clear();
      _p2DescripcionCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final concursoAsync = ref.watch(selectedConcursoProvider);
    final nextFolioAsync = ref.watch(nextFolioProvider);

    return concursoAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (concurso) {
        if (concurso == null) {
          _lastConcursoId = null;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Por favor, selecciona un concurso para gestionar inscripciones.',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
        }

        if (_lastConcursoId == null && concurso.finalizado) {
          _lastConcursoId = concurso.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _tabController.index == 0) {
              _tabController.animateTo(1);
            }
          });
        } else if (_lastConcursoId != null && _lastConcursoId != concurso.id) {
          _lastConcursoId = concurso.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _limpiarFormulario();
              if (concurso.finalizado && _tabController.index == 0) {
                _tabController.animateTo(1);
              }
            }
          });
        } else {
          _lastConcursoId = concurso.id;
        }

        final nextFolio = nextFolioAsync.value ?? 1;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  concurso.nombre,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${concurso.lugar ?? ''} | Folio siguiente: #$nextFolio',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: Icon(
                    concurso.finalizado ? Icons.lock_outline : Icons.person_add,
                  ),
                  text: concurso.finalizado
                      ? 'Inscripción Cerrada'
                      : 'Nueva Inscripción',
                ),
                Tab(
                  icon: const Icon(Icons.list_alt),
                  text: concurso.finalizado
                      ? 'Piezas Inscritas (Solo Lectura)'
                      : 'Piezas Inscritas',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: FORMULARIO DE CAPTURA
              _buildFormularioCaptura(concurso, nextFolio),

              // TAB 2: LISTADO DE REGISTROS
              _buildListadoInscripciones(concurso),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormularioCaptura(Concurso concurso, int nextFolio) {
    if (concurso.finalizado) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680),
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blueGrey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blueGrey.shade200,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.lock_clock_outlined,
                    size: 44,
                    color: Colors.blueGrey.shade700,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Concurso Finalizado',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 14,
                        color: Colors.blueGrey.shade800,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'MODO SOLO LECTURA ACTIVO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'El concurso "${concurso.nombre}" se encuentra marcado formalmente como FINALIZADO.\n\nPor medida de seguridad e integridad del concurso, las inscripciones han concluido y ya no se pueden inscribir nuevas piezas ni registrar artesanos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Puedes consultar el listado completo de piezas registradas y reimprimir cédulas o comprobantes desde la pestaña "Piezas Inscritas".',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: const Text('Consultar Piezas Inscritas'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.casart800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                  onPressed: () => _tabController.animateTo(1),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final safeP1RamaId =
        (_p1RamaId != null && _ramas.any((r) => r['id'] == _p1RamaId))
        ? _p1RamaId
        : null;
    final safeP1CategoriaId =
        (_p1CategoriaId != null &&
            concurso.categorias.any((c) => c.id == _p1CategoriaId))
        ? _p1CategoriaId
        : null;
    final p1Subcategorias = safeP1CategoriaId != null
        ? (concurso.categorias
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

    final safeP2RamaId =
        (_p2RamaId != null && _ramas.any((r) => r['id'] == _p2RamaId))
        ? _p2RamaId
        : null;
    final safeP2CategoriaId =
        (_p2CategoriaId != null &&
            concurso.categorias.any((c) => c.id == _p2CategoriaId))
        ? _p2CategoriaId
        : null;
    final p2Subcategorias = safeP2CategoriaId != null
        ? (concurso.categorias
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

    final safeEtniaId =
        (_artEtniaId != null && _etnias.any((e) => e['id'] == _artEtniaId))
        ? _artEtniaId
        : null;
    final safeEstadoCivilId =
        (_artEstadoCivilId != null &&
            _estadosCiviles.any((ec) => ec['id'] == _artEstadoCivilId))
        ? _artEstadoCivilId
        : null;

    final safeP1Plazo =
        const ['dias', 'semanas', 'meses', 'anos'].contains(_p1Plazo)
        ? _p1Plazo
        : 'semanas';
    final safeP2Plazo =
        const ['dias', 'semanas', 'meses', 'anos'].contains(_p2Plazo)
        ? _p2Plazo
        : 'semanas';

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // BANNER DEL FOLIO ASIGNADO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.confirmation_number_outlined,
                  color: Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FOLIO A ASIGNAR EN ESTA INSCRIPCIÓN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    Text(
                      '#${nextFolio.toString().padLeft(4, '0')}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'IVA: ${concurso.iva}% | Utilidad: ${concurso.utilidad}%',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 1. SECCIÓN ARTESANO
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '1. Datos del Artesano',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      ChoiceChip(
                        label: const Text('Buscar Registrado'),
                        selected: !_esNuevoArtesano,
                        onSelected: (val) =>
                            setState(() => _esNuevoArtesano = !val),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Nuevo Artesano'),
                        selected: _esNuevoArtesano,
                        onSelected: (val) =>
                            setState(() => _esNuevoArtesano = val),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  if (!_esNuevoArtesano) ...[
                    // BUSCADOR RÁPIDO
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _busquedaCurpCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Ingresa ID o CURP del artesano...',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                            onSubmitted: _buscarArtesano,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () =>
                              _buscarArtesano(_busquedaCurpCtrl.text),
                          child: const Text('Buscar'),
                        ),
                      ],
                    ),
                    if (_selectedArtesano != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.casart50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.casart200),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(child: Icon(Icons.person)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedArtesano!.nombreCompleto,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'ID: ${_selectedArtesano!.id ?? 'S/N'} | CURP: ${_selectedArtesano!.curp} | Tel: ${_selectedArtesano!.telefono ?? 'S/N'}${_selectedArtesano!.generoDescripcion != null ? ' | Género: ${_selectedArtesano!.generoDescripcion}' : ''}${_selectedArtesano!.nivelEducativo != null && _selectedArtesano!.nivelEducativo!.isNotEmpty ? ' | Escolaridad: ${_getNivelEducativoTexto(_selectedArtesano!.nivelEducativo)}' : ''}',
                                  ),
                                  Text(
                                    'Domicilio: ${_selectedArtesano!.direccionCompleta}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () =>
                                  setState(() => _selectedArtesano = null),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    // CAMPOS DE NUEVO ARTESANO - DATOS PERSONALES
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _artNombreCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nombre(s) *',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) =>
                                _esNuevoArtesano &&
                                    (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _artApPaternoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Primer Apellido *',
                            ),
                            validator: (v) =>
                                _esNuevoArtesano &&
                                    (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _artApMaternoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Segundo Apellido (Opcional)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _artCurpCtrl,
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
                            onChanged: (v) => _autocompletarDesdeCurp(v),
                            validator: (v) {
                              if (!_esNuevoArtesano) return null;
                              if (v == null || v.trim().isEmpty)
                                return 'La CURP es requerida';
                              if (v.trim().length != 18)
                                return 'La CURP debe tener exactamente 18 caracteres';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _artFechaNacimientoCtrl,
                            decoration: InputDecoration(
                              labelText: 'Fecha de Nacimiento *',
                              hintText: 'AAAA-MM-DD',
                              prefixIcon: const Icon(Icons.cake_outlined),
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 20,
                                ),
                                onPressed: () => _seleccionarFechaNacimiento(
                                  _artFechaNacimientoCtrl,
                                ),
                              ),
                            ),
                            validator: (v) =>
                                _esNuevoArtesano &&
                                    (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String?>(
                            key: ValueKey('art_genero_$_artGenero'),
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
                                _esNuevoArtesano && (v == null || v.isEmpty)
                                ? 'Requerido'
                                : null,
                            onChanged: (v) => setState(() => _artGenero = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _artTelefonoCtrl,
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
                              if (!_esNuevoArtesano) return null;
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _artRfcCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'RFC (Opcional)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            key: ValueKey('art_etnia_$safeEtniaId'),
                            initialValue: safeEtniaId,
                            decoration: const InputDecoration(
                              labelText: 'Etnia *',
                            ),
                            items: _etnias
                                .where((e) => e['id'] != null)
                                .map(
                                  (e) => DropdownMenuItem<int?>(
                                    value: e['id'] as int,
                                    child: Text(e['nombre'] as String),
                                  ),
                                )
                                .toList(),
                            validator: (v) => _esNuevoArtesano && v == null
                                ? 'Selecciona una etnia'
                                : null,
                            onChanged: (v) => setState(() => _artEtniaId = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            key: ValueKey('art_civil_$safeEstadoCivilId'),
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
                            validator: (v) => _esNuevoArtesano && v == null
                                ? 'Selecciona un estado civil'
                                : null,
                            onChanged: (v) =>
                                setState(() => _artEstadoCivilId = v),
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
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                              thumbColor: AppTheme.casart800,
                              overlayColor: AppTheme.casart800.withValues(
                                alpha: 0.2,
                              ),
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
                              label:
                                  _nivelesEducativosDetalle[_artNivelEducativo],
                              onChanged: (val) {
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
                              children: List.generate(
                                _nivelesEducativos.length,
                                (index) {
                                  final isSelected =
                                      index == _artNivelEducativo;
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
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

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
                    const SizedBox(height: 14),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Selector de Municipio
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            key: ValueKey('art_mun_$_artMunicipio'),
                            initialValue: _artMunicipio,
                            isExpanded: true,
                            menuMaxHeight: 350,
                            decoration: const InputDecoration(
                              labelText: 'Municipio *',
                              prefixIcon: Icon(Icons.location_city_outlined),
                            ),
                            hint: const Text('Selecciona un municipio'),
                            items: MunicipiosData.municipios
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
                                _esNuevoArtesano &&
                                    (v == null || v.trim().isEmpty)
                                ? 'Selecciona un municipio'
                                : null,
                            onChanged: (val) {
                              setState(() {
                                _artMunicipio = val;
                                _artMunicipioCtrl.text = val ?? '';
                                _artLocalidad = null;
                                _artLocalidadCtrl.clear();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                  'art_loc_${_artMunicipio}_$_artLocalidad',
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
                                validator: (v) =>
                                    _esNuevoArtesano &&
                                        (v == null || v.trim().isEmpty)
                                    ? 'Selecciona una localidad'
                                    : null,
                                onChanged: !hasMun
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _artCodigoPostalCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(5),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Código Postal *',
                              prefixIcon: Icon(
                                Icons.markunread_mailbox_outlined,
                              ),
                            ),
                            validator: (v) {
                              if (!_esNuevoArtesano) return null;
                              if (v == null || v.trim().isEmpty)
                                return 'El Código Postal es obligatorio';
                              if (v.trim().length != 5)
                                return 'Debe tener 5 dígitos';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _artCalleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Calle (Opcional)',
                              prefixIcon: Icon(Icons.signpost_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _artNumExteriorCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Número Exterior (Opcional)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _artColoniaCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Colonia (Opcional)',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 2. SECCIÓN PIEZA 1 (OBLIGATORIA)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '2. Información de la Pieza 1 (Obligatoria)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _p1NombreCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la Artesanía *',
                            hintText:
                                'Ej: Olla de barro negro bruñido con flores',
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Requerido'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int?>(
                          key: ValueKey('p1_rama_$safeP1RamaId'),
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
                          onChanged: (val) => setState(() => _p1RamaId = val),
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
                            'p1_cat_${concurso.id}_$safeP1CategoriaId',
                          ),
                          initialValue: safeP1CategoriaId,
                          decoration: const InputDecoration(
                            labelText: 'Categoría del Concurso *',
                          ),
                          items: concurso.categorias
                              .where((c) => c.id != null)
                              .map(
                                (c) => DropdownMenuItem<int?>(
                                  value: c.id,
                                  child: Text(c.nombre),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
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
                            'p1_sub_${safeP1CategoriaId}_$safeP1SubcategoriaId',
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
                          onChanged: (val) =>
                              setState(() => _p1SubcategoriaId = val),
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
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Costo Producción (\$ MXN) *',
                            prefixText: '\$ ',
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Requerido'
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
                              const Text(
                                'Precio Venta Sugerido (+ IVA + Utilidad)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.verdeSuccess,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                Formatters.formatCurrency(
                                  _calcularCostoVenta(
                                    double.tryParse(_p1CostoCtrl.text) ?? 0.0,
                                    concurso,
                                  ),
                                ),
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
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Tiempo Elaboración *',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('p1_plazo_$safeP1Plazo'),
                          initialValue: safeP1Plazo,
                          decoration: const InputDecoration(
                            labelText: 'Plazo *',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'dias',
                              child: Text('Días'),
                            ),
                            DropdownMenuItem(
                              value: 'semanas',
                              child: Text('Semanas'),
                            ),
                            DropdownMenuItem(
                              value: 'meses',
                              child: Text('Meses'),
                            ),
                            DropdownMenuItem(
                              value: 'anos',
                              child: Text('Años'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _p1Plazo = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _p1MaterialCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Material de Elaboración *',
                      hintText: 'Ej: Barro, pino, cobre martillado...',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _p1DescripcionCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descripción Física / Técnica (Opcional)',
                      hintText: 'Dimensiones, técnica de bruñido, acabado...',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 3. SECCIÓN PIEZA 2 (OPCIONAL)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '3. Segunda Pieza (Opcional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: _incluirPieza2,
                        onChanged: (val) =>
                            setState(() => _incluirPieza2 = val),
                      ),
                      Text(
                        _incluirPieza2 ? 'Registrar 2da Pieza' : 'Solo 1 Pieza',
                      ),
                    ],
                  ),
                  if (_incluirPieza2) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _p2NombreCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nombre de la Pieza 2 *',
                            ),
                            validator: (v) =>
                                _incluirPieza2 &&
                                    (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int?>(
                            key: ValueKey('p2_rama_$safeP2RamaId'),
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
                            onChanged: (val) => setState(() => _p2RamaId = val),
                            validator: (v) => _incluirPieza2 && v == null
                                ? 'Requerido'
                                : null,
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
                              'p2_cat_${concurso.id}_$safeP2CategoriaId',
                            ),
                            initialValue: safeP2CategoriaId,
                            decoration: const InputDecoration(
                              labelText: 'Categoría 2 *',
                            ),
                            items: concurso.categorias
                                .where((c) => c.id != null)
                                .map(
                                  (c) => DropdownMenuItem<int?>(
                                    value: c.id,
                                    child: Text(c.nombre),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _p2CategoriaId = val;
                                _p2SubcategoriaId = null;
                              });
                            },
                            validator: (v) => _incluirPieza2 && v == null
                                ? 'Requerido'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            key: ValueKey(
                              'p2_sub_${safeP2CategoriaId}_$safeP2SubcategoriaId',
                            ),
                            initialValue: safeP2SubcategoriaId,
                            decoration: const InputDecoration(
                              labelText: 'Subcategoría 2 (Opcional)',
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
                            onChanged: (val) =>
                                setState(() => _p2SubcategoriaId = val),
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
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Costo Producción 2 (\$ MXN) *',
                              prefixText: '\$ ',
                            ),
                            onChanged: (_) => setState(() {}),
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
                                const Text(
                                  'Precio Venta Sugerido 2',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.verdeSuccess,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  Formatters.formatCurrency(
                                    _calcularCostoVenta(
                                      double.tryParse(_p2CostoCtrl.text) ?? 0.0,
                                      concurso,
                                    ),
                                  ),
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
                            decoration: const InputDecoration(
                              labelText: 'Tiempo 2 *',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('p2_plazo_$safeP2Plazo'),
                            initialValue: safeP2Plazo,
                            decoration: const InputDecoration(
                              labelText: 'Plazo 2 *',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'dias',
                                child: Text('Días'),
                              ),
                              DropdownMenuItem(
                                value: 'semanas',
                                child: Text('Semanas'),
                              ),
                              DropdownMenuItem(
                                value: 'meses',
                                child: Text('Meses'),
                              ),
                              DropdownMenuItem(
                                value: 'anos',
                                child: Text('Años'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _p2Plazo = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _p2MaterialCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Material de Elaboración 2 *',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _p2DescripcionCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descripción Pieza 2 (Opcional)',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // BOTÓN PRINCIPAL DE GUARDAR E IMPRIMIR
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.print, size: 24),
              label: Text(
                _isSaving
                    ? 'Guardando e imprimiendo...'
                    : 'REGISTRAR E IMPRIMIR CÉDULA (FOLIO #$nextFolio)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.verdeSuccess,
                foregroundColor: Colors.white,
              ),
              onPressed: _isSaving ? null : () => _guardarInscripcion(concurso),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildListadoInscripciones(Concurso concurso) {
    final registrosAsync = ref.watch(registrosConcursoProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // BARRA DE BÚSQUEDA Y ACCIONES
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText:
                        'Buscar por artesano, CURP, folio o nombre de pieza...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    ref.read(registrosSearchProvider.notifier).state = val;
                  },
                ),
              ),
              const SizedBox(width: 12),
              ExcelExportDropdown(concurso: concurso),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar listado',
                onPressed: () => ref.invalidate(registrosConcursoProvider),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (concurso.finalizado)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.only(bottom: 14),
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
                      'Modo Solo Lectura: Este concurso está finalizado. Puedes consultar las piezas inscritas y reimprimir cédulas. No se permiten nuevas inscripciones, modificaciones ni eliminaciones.',
                      style: TextStyle(
                        color: Colors.blueGrey.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // RESUMEN Y CONTADORES
          registrosAsync.maybeWhen(
            data: (registros) {
              final totalInscritos = registros.length;
              final totalPiezas = registros.fold<int>(
                0,
                (acc, r) => acc + 1 + (r.artesania2 != null ? 1 : 0),
              );
              final totalVentaSugerida = registros.fold<double>(
                0.0,
                (acc, r) =>
                    acc +
                    (r.artesania1?.costoVenta ?? 0.0) +
                    (r.artesania2?.costoVenta ?? 0.0),
              );

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.casart50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.casart200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.people_alt_outlined,
                            size: 16,
                            color: AppTheme.casart800,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$totalInscritos Artesanos Inscritos',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppTheme.casart800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.ocreAccentLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.ocreAccentBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.palette_outlined,
                            size: 16,
                            color: AppTheme.ocre10,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$totalPiezas Piezas Registradas',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppTheme.ocre10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Valor Acumulado en Venta: ${Formatters.formatCurrency(totalVentaSugerida)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.verdeSuccess,
                      ),
                    ),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // LISTADO DE CÉDULAS
          Expanded(
            child: registrosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (registros) {
                if (registros.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No hay piezas inscritas aún para este concurso.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: registros.length,
                  itemBuilder: (ctx, idx) {
                    final r = registros[idx];
                    final p1 = r.artesania1;
                    final p2 = r.artesania2;
                    final a = r.artesano;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // CABECERA: FOLIO, ARTESANO Y BOTONES
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red[800],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '#${r.folio.toString().padLeft(4, '0')}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a?.nombreCompleto ??
                                            'Artesano Desconocido',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'CURP: ${a?.curp ?? 'N/A'}${a?.telefono != null && a!.telefono!.isNotEmpty ? ' • Tel: ${a.telefono}' : ''} • ${a?.localidad ?? ''}, ${a?.municipio ?? ''}',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // BOTÓN REIMPRIMIR
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.print, size: 16),
                                  label: const Text('Reimprimir'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (c) =>
                                          ComprobanteDialog(registro: r),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),

                                // BOTÓN EDITAR / CORREGIR (o VER CÉDULA si finalizado)
                                OutlinedButton.icon(
                                  icon: Icon(
                                    concurso.finalizado
                                        ? Icons.visibility_outlined
                                        : Icons.edit,
                                    size: 16,
                                  ),
                                  label: Text(
                                    concurso.finalizado
                                        ? 'Ver Cédula'
                                        : 'Editar/Corregir',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: () async {
                                    final resultado =
                                        await showDialog<RegistroConcurso>(
                                          context: context,
                                          builder: (c) =>
                                              EditarInscripcionDialog(
                                                registro: r,
                                                concurso: concurso,
                                                isReadOnly: concurso.finalizado,
                                              ),
                                        );

                                    if (resultado != null && mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '✓ Inscripción #${resultado.folio} actualizada correctamente.',
                                          ),
                                          backgroundColor: AppTheme.casart800,
                                          action: SnackBarAction(
                                            label: 'Reimprimir',
                                            textColor: AppTheme.ocreAccent,
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (c) =>
                                                    ComprobanteDialog(
                                                      registro: resultado,
                                                    ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                if (concurso.finalizado) ...[
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.emoji_events,
                                      size: 16,
                                    ),
                                    label: const Text('Premiar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber.shade800,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    onPressed: () async {
                                      final resultado =
                                          await showDialog<bool>(
                                        context: context,
                                        builder: (c) => PremiarPiezaDialog(
                                          registro: r,
                                          concurso: concurso,
                                        ),
                                      );
                                      if (resultado == true && mounted) {
                                        ref.invalidate(
                                          registrosConcursoProvider,
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),

                            // DETALLES DE LAS PIEZAS
                            Row(
                              children: [
                                // PIEZA 1
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              'Pieza 1 (Principal):',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: AppTheme.casart800,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              Formatters.formatCurrency(
                                                p1?.costoVenta ?? 0.0,
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: AppTheme.verdeSuccess,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          p1?.nombre ?? 'Sin nombre',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Rama: ${p1?.ramaNombre ?? 'General'} | Cat: ${p1?.categoriaNombre ?? ''}${p1?.subcategoriaNombre != null ? ' - ${p1!.subcategoriaNombre}' : ''}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (p1?.premioNombre != null &&
                                            p1!.premioNombre!.trim().isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.amber.shade600,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.emoji_events,
                                                  size: 14,
                                                  color: Colors.amber.shade900,
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    'Premio: ${p1.premioNombre}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                      color: Colors.amber.shade900,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // PIEZA 2 (SI APLICA)
                                Expanded(
                                  child:
                                      p2 != null && p2.nombre.trim().isNotEmpty
                                      ? Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Text(
                                                    'Pieza 2 (Segunda Pieza):',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                      color: AppTheme.casart800,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Text(
                                                    Formatters.formatCurrency(
                                                      p2.costoVenta,
                                                    ),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                      color:
                                                          AppTheme.verdeSuccess,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                p2.nombre,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Rama: ${p2.ramaNombre ?? 'General'} | Cat: ${p2.categoriaNombre ?? ''}${p2.subcategoriaNombre != null ? ' - ${p2.subcategoriaNombre}' : ''}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 11,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (p2.premioNombre != null &&
                                                  p2.premioNombre!.trim().isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.shade100,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(
                                                      color: Colors.amber.shade600,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.emoji_events,
                                                        size: 14,
                                                        color: Colors.amber.shade900,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          'Premio: ${p2.premioNombre}',
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 11,
                                                            color: Colors.amber.shade900,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade200,
                                              style: BorderStyle.none,
                                            ),
                                          ),
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'Sin segunda pieza registrada',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
