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
import '../premios/acta_ganadores_dialog.dart';
import '../common/excel_export_dropdown.dart';
import '../common/key_selectable_dropdown_form_field.dart';
import '../common/searchable_select_form_field.dart';
import '../common/autocomplete_text_form_field.dart';

class InscripcionView extends ConsumerStatefulWidget {
  const InscripcionView({super.key});

  @override
  ConsumerState<InscripcionView> createState() => _InscripcionViewState();
}

class _InscripcionViewState extends ConsumerState<InscripcionView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();

  // Búsqueda de artesano y nodos de foco para atajos de teclado / autofocus
  final _busquedaCurpCtrl = TextEditingController();
  final _busquedaCurpFocusNode = FocusNode(debugLabel: 'busqueda_curp');
  final _artNombreFocusNode = FocusNode(debugLabel: 'art_nombre');
  final _p1NombreFocusNode = FocusNode(debugLabel: 'p1_nombre');
  final _p2NombreFocusNode = FocusNode(debugLabel: 'p2_nombre');
  Artesano? _selectedArtesano;
  bool _esNuevoArtesano = false;

  // Datos de nuevo artesano
  final _artNombreCtrl = TextEditingController();
  final _artApPaternoCtrl = TextEditingController();
  final _artApMaternoCtrl = TextEditingController();
  final _artCurpCtrl = TextEditingController();
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

  // Valores fijados (Pin 📌) para conservar entre registros en concursos locales/regionales
  bool _fijarEtnia = false;
  int? _pinnedEtniaId;
  bool _fijarMunicipio = false;
  String? _pinnedMunicipio;
  bool _fijarLocalidad = false;
  String? _pinnedLocalidad;

  // Pieza 1
  final _p1NombreCtrl = TextEditingController();
  int? _p1CategoriaId;
  int? _p1SubcategoriaId;
  final _p1CostoCtrl = TextEditingController();
  final _p1TiempoCtrl = TextEditingController();
  String _p1Plazo = 'semanas';
  final _p1MaterialCtrl = TextEditingController();
  final _p1DescripcionCtrl = TextEditingController();

  // Pieza 2
  bool _incluirPieza2 = false;
  final _p2NombreCtrl = TextEditingController();
  int? _p2CategoriaId;
  int? _p2SubcategoriaId;
  final _p2CostoCtrl = TextEditingController();
  final _p2TiempoCtrl = TextEditingController();
  String _p2Plazo = 'semanas';
  final _p2MaterialCtrl = TextEditingController();
  final _p2DescripcionCtrl = TextEditingController();

  // Catálogos
  List<Map<String, dynamic>> _etnias = [];
  List<Map<String, dynamic>> _estadosCiviles = [];
  Map<String, List<String>> _sugerencias = const {};

  bool _isSaving = false;
  int? _lastConcursoId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    HardwareKeyboard.instance.addHandler(_onHardwareKeyEvent);
    _loadCatalogos();
  }

  Future<void> _loadCatalogos() async {
    final repo = ref.read(artesanoRepositoryProvider);
    final etnias = await repo.getEtnias();
    final estadosCiviles = await repo.getEstadosCiviles();
    final sugerencias = await repo.getSugerenciasFormulario();

    if (mounted) {
      setState(() {
        _etnias = etnias;
        _estadosCiviles = estadosCiviles;
        _sugerencias = sugerencias;
      });
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKeyEvent);
    _tabController.dispose();
    _busquedaCurpCtrl.dispose();
    _busquedaCurpFocusNode.dispose();
    _artNombreFocusNode.dispose();
    _p1NombreFocusNode.dispose();
    _p2NombreFocusNode.dispose();
    _artNombreCtrl.dispose();
    _artApPaternoCtrl.dispose();
    _artApMaternoCtrl.dispose();
    _artCurpCtrl.dispose();
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

  void _cargarDatosArtesano(Artesano a) {
    _artNombreCtrl.text = a.nombre;
    _artApPaternoCtrl.text = a.apPaterno;
    _artApMaternoCtrl.text = a.apMaterno ?? '';
    _artCurpCtrl.text = a.curp;
    _artFechaNacimientoCtrl.text = a.fechaNacimiento ?? '';

    final g = a.genero?.toUpperCase();
    if (g == 'M' || g == 'HOMBRE' || g == 'MASCULINO') {
      _artGenero = 'M';
    } else if (g == 'F' || g == 'MUJER' || g == 'FEMENINO') {
      _artGenero = 'F';
    } else if (g == 'O' || g == 'OTRO') {
      _artGenero = 'O';
    } else {
      _artGenero = null;
    }

    _artTelefonoCtrl.text = a.telefono ?? '';

    final rawMun = a.municipio.trim();
    if (rawMun.isNotEmpty) {
      _artMunicipio = _resolveMunicipio(rawMun);
      _artMunicipioCtrl.text = _artMunicipio ?? rawMun;
    } else if (_fijarMunicipio && _pinnedMunicipio != null) {
      _artMunicipio = _pinnedMunicipio;
      _artMunicipioCtrl.text = _pinnedMunicipio!;
    } else {
      _artMunicipio = null;
      _artMunicipioCtrl.clear();
    }

    final rawLoc = a.localidad.trim();
    if (rawLoc.isNotEmpty) {
      _artLocalidad = rawLoc;
      _artLocalidadCtrl.text = rawLoc;
    } else if (_fijarLocalidad &&
        _pinnedLocalidad != null &&
        _artMunicipio == _pinnedMunicipio) {
      _artLocalidad = _pinnedLocalidad;
      _artLocalidadCtrl.text = _pinnedLocalidad!;
    } else {
      _artLocalidad = null;
      _artLocalidadCtrl.clear();
    }

    _artColoniaCtrl.text = a.colonia ?? '';
    _artCalleCtrl.text = a.calle ?? '';
    _artNumExteriorCtrl.text = a.numeroExterior ?? '';
    _artCodigoPostalCtrl.text = a.codigoPostal ?? '';

    _artEtniaId = a.idEtnia ?? (_fijarEtnia ? _pinnedEtniaId : null);
    _artEstadoCivilId = a.idEstadoCivil;

    if (_artFechaNacimientoCtrl.text.trim().isEmpty || _artGenero == null) {
      _extraerFechaYGeneroDeCurp(a.curp);
    }
  }

  void _extraerFechaYGeneroDeCurp(String rawCurp) {
    final curp = rawCurp.trim().toUpperCase();
    if (curp.length >= 10) {
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
        if (_artFechaNacimientoCtrl.text.trim().isEmpty) {
          _artFechaNacimientoCtrl.text = formattedDate;
        }
      }

      if (curp.length >= 11 && _artGenero == null) {
        final generoChar = curp.substring(10, 11);
        if (generoChar == 'M') {
          _artGenero = 'F';
        } else if (generoChar == 'H') {
          _artGenero = 'M';
        }
      }
    }
  }

  void _limpiarCamposArtesano() {
    _busquedaCurpCtrl.clear();
    _artNombreCtrl.clear();
    _artApPaternoCtrl.clear();
    _artApMaternoCtrl.clear();
    _artCurpCtrl.clear();
    _artFechaNacimientoCtrl.clear();
    _artGenero = null;
    _artTelefonoCtrl.clear();

    if (_fijarMunicipio) {
      _artMunicipio = _pinnedMunicipio ?? _artMunicipio;
      _artMunicipioCtrl.text = _artMunicipio ?? '';
    } else {
      _artMunicipio = null;
      _artMunicipioCtrl.clear();
    }

    if (_fijarLocalidad &&
        _artMunicipio != null &&
        _artMunicipio!.trim().isNotEmpty) {
      _artLocalidad = _pinnedLocalidad ?? _artLocalidad;
      _artLocalidadCtrl.text = _artLocalidad ?? '';
    } else {
      _artLocalidad = null;
      _artLocalidadCtrl.clear();
    }

    _artColoniaCtrl.clear();
    _artCalleCtrl.clear();
    _artNumExteriorCtrl.clear();
    _artCodigoPostalCtrl.clear();

    if (_fijarEtnia) {
      _artEtniaId = _pinnedEtniaId ?? _artEtniaId;
    } else {
      _artEtniaId = null;
    }

    _artEstadoCivilId = null;
  }

  void _togglePinEtnia() {
    setState(() {
      _fijarEtnia = !_fijarEtnia;
      _pinnedEtniaId = _fijarEtnia ? _artEtniaId : null;
    });
  }

  void _togglePinMunicipio() {
    setState(() {
      _fijarMunicipio = !_fijarMunicipio;
      if (_fijarMunicipio) {
        _pinnedMunicipio = _artMunicipio;
      } else {
        _pinnedMunicipio = null;
        _fijarLocalidad = false;
        _pinnedLocalidad = null;
      }
    });
  }

  void _togglePinLocalidad() {
    setState(() {
      _fijarLocalidad = !_fijarLocalidad;
      if (_fijarLocalidad) {
        _pinnedLocalidad = _artLocalidad;
        if (_artMunicipio != null && _artMunicipio!.trim().isNotEmpty) {
          _fijarMunicipio = true;
          _pinnedMunicipio = _artMunicipio;
        }
      } else {
        _pinnedLocalidad = null;
      }
    });
  }

  void _desfijarValoresFrecuentes() {
    setState(() {
      _fijarEtnia = false;
      _pinnedEtniaId = null;
      _fijarMunicipio = false;
      _pinnedMunicipio = null;
      _fijarLocalidad = false;
      _pinnedLocalidad = null;
    });
  }

  Widget _buildPinFieldButton({
    required Key key,
    required bool isPinned,
    required String fieldLabel,
    required VoidCallback onPressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Tooltip(
        message: isPinned
            ? '$fieldLabel fijado entre registros (clic para desfijar)'
            : 'Fijar $fieldLabel para conservarlo entre registros',
        child: Material(
          color: isPinned
              ? Colors.amber.shade100
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isPinned
                  ? Colors.amber.shade700
                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
              width: isPinned ? 1.5 : 1.0,
            ),
          ),
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 18,
                color: isPinned
                    ? Colors.amber.shade900
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _autocompletarDesdeCurp(String rawCurp, Concurso concurso) {
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

        if (curp.length == 18) {
          _verificarCurpEnConcurso(curp, concurso);
        }
      } catch (_) {}
    }
  }

  Future<void> _verificarCurpEnConcurso(String curp, Concurso concurso) async {
    if (concurso.id == null) return;
    final regRepo = ref.read(registroRepositoryProvider);
    final regExistente = await regRepo.getRegistroByCurp(
      idConcurso: concurso.id!,
      curp: curp,
    );
    if (regExistente != null && mounted) {
      await _mostrarAlertaArtesanoYaInscrito(regExistente, concurso);
    }
  }

  double _calcularCostoVenta(double costoProd, Concurso c) {
    final factor = 1.0 + ((c.iva + c.utilidad) / 100.0);
    return costoProd * factor;
  }

  Future<void> _mostrarAlertaArtesanoYaInscrito(
    RegistroConcurso registroExistente,
    Concurso concurso,
  ) async {
    final folio = registroExistente.folio;
    final nombre =
        registroExistente.artesano?.nombreCompleto ?? 'El artesano';
    final curp = registroExistente.artesano?.curp ?? '';
    final tieneP2 = registroExistente.artesania2 != null;
    final p1Nombre = registroExistente.artesania1?.nombre ?? 'Pieza 1';
    final p2Nombre = registroExistente.artesania2?.nombre;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber.shade900,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Artesano Ya Inscrito',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text: 'Este artesano ya está inscrito en este concurso con el ',
                style: const TextStyle(fontSize: 14),
                children: [
                  TextSpan(
                    text: 'folio de la boleta #$folio.\n',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const TextSpan(
                    text:
                        'No se permite registrar al mismo participante más de una vez en el mismo concurso.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (curp.isNotEmpty)
                    Text(
                      'CURP: $curp',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  const Divider(height: 12),
                  Text(
                    '• Pieza 1: $p1Nombre',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    tieneP2
                        ? '• Pieza 2: $p2Nombre'
                        : '• Pieza 2: (Sin registrar)',
                    style: TextStyle(
                      fontSize: 12,
                      color: tieneP2 ? Colors.black87 : Colors.blueGrey,
                      fontStyle:
                          tieneP2 ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tieneP2
                  ? 'El artesano ya tiene sus 2 piezas registradas en esa boleta.'
                  : 'Si deseas agregar su segunda pieza o modificar sus datos, puedes abrir directamente su boleta de inscripción.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
          if (!concurso.finalizado)
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_document, size: 18),
              label: Text('Abrir Boleta #$folio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.casart700,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final resultado = await showDialog<RegistroConcurso>(
                  context: context,
                  builder: (c) => EditarInscripcionDialog(
                    registro: registroExistente,
                    concurso: concurso,
                    isReadOnly: concurso.finalizado,
                  ),
                );
                if (resultado != null && mounted) {
                  ref.invalidate(registrosConcursoProvider);
                  _limpiarFormulario();
                }
              },
            ),
        ],
      ),
    );
  }

  Future<void> _buscarArtesano(String query, Concurso concurso) async {
    if (query.trim().isEmpty) return;
    final repo = ref.read(artesanoRepositoryProvider);
    final artesanos = await repo.searchArtesanos(query: query, limit: 1);

    if (!mounted) return;

    if (artesanos.isNotEmpty) {
      final encontrado = artesanos.first;
      if (concurso.id != null) {
        final regRepo = ref.read(registroRepositoryProvider);
        final regExistente = await regRepo.getRegistroByCurp(
          idConcurso: concurso.id!,
          curp: encontrado.curp,
        );

        if (!mounted) return;

        if (regExistente != null) {
          setState(() {
            _selectedArtesano = null;
            _esNuevoArtesano = false;
            _limpiarCamposArtesano();
          });
          await _mostrarAlertaArtesanoYaInscrito(regExistente, concurso);
          return;
        }
      }

      setState(() {
        _selectedArtesano = encontrado;
        _esNuevoArtesano = false;
        _cargarDatosArtesano(encontrado);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _p1NombreFocusNode.requestFocus();
        }
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
      final queryTrim = query.trim();
      final esPosibleCurp = int.tryParse(queryTrim) == null;
      final curpInicial = esPosibleCurp ? queryTrim.toUpperCase() : '';
      setState(() {
        _selectedArtesano = null;
        _esNuevoArtesano = true;
        _limpiarCamposArtesano();
        if (esPosibleCurp) {
          _artCurpCtrl.text = curpInicial;
        }
      });
      if (esPosibleCurp && curpInicial.isNotEmpty) {
        _autocompletarDesdeCurp(curpInicial, concurso);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _artNombreFocusNode.requestFocus();
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

    if (_selectedArtesano == null && !_esNuevoArtesano) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes buscar y seleccionar un artesano o elegir "Nuevo Artesano".'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_artGenero == null || _artGenero!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar el género del artesano.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validación preventiva por CURP: verificar que no esté ya inscrito en este concurso
    final curpAValidar = _artCurpCtrl.text.trim().toUpperCase();

    if (curpAValidar.isNotEmpty && concurso.id != null) {
      final repo = ref.read(registroRepositoryProvider);
      final regExistente = await repo.getRegistroByCurp(
        idConcurso: concurso.id!,
        curp: curpAValidar,
      );
      if (!mounted) return;
      if (regExistente != null) {
        await _mostrarAlertaArtesanoYaInscrito(regExistente, concurso);
        return;
      }
    }

    final safeP1Cat =
        (_p1CategoriaId != null &&
            concurso.categorias.any((c) => c.id == _p1CategoriaId))
        ? _p1CategoriaId
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

    int? safeP2Cat;
    if (_incluirPieza2) {
      safeP2Cat =
          (_p2CategoriaId != null &&
              concurso.categorias.any((c) => c.id == _p2CategoriaId))
          ? _p2CategoriaId
          : null;
      final p2CostoVal = double.tryParse(_p2CostoCtrl.text.trim());
      if (_p2NombreCtrl.text.trim().isEmpty ||
          safeP2Cat == null ||
          p2CostoVal == null ||
          p2CostoVal <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Completa nombre, categoría y un costo de producción válido para la Pieza 2.',
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

      final safeEtnia =
          (_artEtniaId != null && _etnias.any((e) => e['id'] == _artEtniaId))
              ? _artEtniaId
              : null;
      final safeEstadoCivil =
          (_artEstadoCivilId != null &&
                  _estadosCiviles.any((ec) => ec['id'] == _artEstadoCivilId))
              ? _artEstadoCivilId
              : null;

      // Artesano (toma los valores actuales editados/completados en el formulario)
      final Artesano artesanoFinal = Artesano(
        id: _selectedArtesano?.id,
        idInfoContacto: _selectedArtesano?.idInfoContacto,
        idResidencia: _selectedArtesano?.idResidencia,
        nombre: _artNombreCtrl.text.trim(),
        apPaterno: _artApPaternoCtrl.text.trim(),
        apMaterno: _artApMaternoCtrl.text.trim().isNotEmpty
            ? _artApMaternoCtrl.text.trim()
            : null,
        curp: _artCurpCtrl.text.trim().toUpperCase(),
        rfc: _selectedArtesano?.rfc,
        fechaNacimiento: _artFechaNacimientoCtrl.text.trim().isNotEmpty
            ? _artFechaNacimientoCtrl.text.trim()
            : null,
        genero: _artGenero,
        telefono: _artTelefonoCtrl.text.trim().isNotEmpty
            ? _artTelefonoCtrl.text.trim()
            : null,
        municipio: _artMunicipioCtrl.text.trim().isNotEmpty
            ? _artMunicipioCtrl.text.trim()
            : (_artMunicipio ?? ''),
        localidad: _artLocalidadCtrl.text.trim().isNotEmpty
            ? _artLocalidadCtrl.text.trim()
            : (_artLocalidad ?? ''),
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
        idEtnia: safeEtnia,
        idEstadoCivil: safeEstadoCivil,
        nivelEducativo: (_selectedArtesano?.nivelEducativo != null &&
                _selectedArtesano!.nivelEducativo!.trim().isNotEmpty)
            ? _selectedArtesano!.nivelEducativo!
            : '1',
      );

      // Pieza 1
      final p1CostoProd = double.tryParse(_p1CostoCtrl.text.trim()) ?? 0.0;
      final p1CostoVent = _calcularCostoVenta(p1CostoProd, concurso);

      final pieza1 = Artesania(
        nombre: _p1NombreCtrl.text.trim(),
        idRamaArtesanal: 1,
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
      if (_incluirPieza2 && safeP2Cat != null) {
        final p2CostoProd = double.tryParse(_p2CostoCtrl.text.trim()) ?? 0.0;
        final p2CostoVent = _calcularCostoVenta(p2CostoProd, concurso);

        pieza2 = Artesania(
          nombre: _p2NombreCtrl.text.trim(),
          idRamaArtesanal: 1,
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

      // Limpiar formulario y actualizar sugerencias de autocompletado
      _limpiarFormulario();
      _loadCatalogos();
      _limpiarFormulario();

      if (mounted) {
        // Abrir visor de impresión directamente y al cerrar reenfocar buscador de CURP
        await showDialog<void>(
          context: context,
          builder: (ctx) => ComprobanteDialog(
            registro: nuevoRegistro,
            concurso: concurso,
          ),
        );
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_esNuevoArtesano) {
              _busquedaCurpFocusNode.requestFocus();
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final errStr = e
            .toString()
            .replaceAll('StateError: ', '')
            .replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errStr),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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
      _limpiarCamposArtesano();

      _p1NombreCtrl.clear();
      _p1CategoriaId = null;
      _p1SubcategoriaId = null;
      _p1CostoCtrl.clear();
      _p1TiempoCtrl.clear();
      _p1Plazo = 'semanas';
      _p1MaterialCtrl.clear();
      _p1DescripcionCtrl.clear();

      _incluirPieza2 = false;
      _p2NombreCtrl.clear();
      _p2CategoriaId = null;
      _p2SubcategoriaId = null;
      _p2CostoCtrl.clear();
      _p2TiempoCtrl.clear();
      _p2Plazo = 'semanas';
      _p2MaterialCtrl.clear();
      _p2DescripcionCtrl.clear();
    });
  }

  void _activarModoBuscarArtesano() {
    if (_esNuevoArtesano) {
      setState(() {
        _esNuevoArtesano = false;
        _selectedArtesano = null;
        _limpiarCamposArtesano();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _busquedaCurpFocusNode.requestFocus();
        if (_busquedaCurpCtrl.text.isNotEmpty) {
          _busquedaCurpCtrl.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _busquedaCurpCtrl.text.length,
          );
        }
      }
    });
  }

  void _activarModoNuevoArtesano() {
    if (!_esNuevoArtesano) {
      setState(() {
        _esNuevoArtesano = true;
        _selectedArtesano = null;
        _limpiarCamposArtesano();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _artNombreFocusNode.requestFocus();
      }
    });
  }

  void _alternarSegundaPieza({bool? forzarValor}) {
    final nuevoValor = forzarValor ?? !_incluirPieza2;
    setState(() {
      _incluirPieza2 = nuevoValor;
    });
    if (nuevoValor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _p2NombreFocusNode.requestFocus();
        }
      });
    }
  }

  bool _onHardwareKeyEvent(KeyEvent event) {
    if (!mounted) return false;
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    final concurso = ref.read(selectedConcursoProvider).value;
    if (concurso == null) return false;
    return _handleKeyEvent(event, concurso) == KeyEventResult.handled;
  }

  KeyEventResult _handleKeyEvent(KeyEvent event, Concurso concurso) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (concurso.finalizado || _tabController.index != 0) {
      return KeyEventResult.ignored;
    }

    final keyboard = HardwareKeyboard.instance;
    final isCtrl = keyboard.isControlPressed || keyboard.isMetaPressed;
    final isAlt = keyboard.isAltPressed;
    final key = event.logicalKey;

    // F2: Enfocar buscador de CURP / Artesano
    if (!isCtrl && !isAlt && key == LogicalKeyboardKey.f2) {
      _activarModoBuscarArtesano();
      return KeyEventResult.handled;
    }

    // Ctrl + Enter o F9: Guardar inscripción e imprimir comprobante
    if ((isCtrl &&
            (key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.numpadEnter)) ||
        (!isCtrl && !isAlt && key == LogicalKeyboardKey.f9)) {
      if (!_isSaving) {
        _guardarInscripcion(concurso);
      }
      return KeyEventResult.handled;
    }

    // Alt + N: Cambiar a "Nuevo Artesano" y enfocar Nombre(s)
    if (isAlt && !isCtrl && key == LogicalKeyboardKey.keyN) {
      _activarModoNuevoArtesano();
      return KeyEventResult.handled;
    }

    // Alt + B: Cambiar a "Buscar Registrado" y enfocar buscador CURP
    if (isAlt && !isCtrl && key == LogicalKeyboardKey.keyB) {
      _activarModoBuscarArtesano();
      return KeyEventResult.handled;
    }

    // Alt + 2: Activar/desactivar Segunda Pieza y enfocar Nombre de Pieza 2
    if (isAlt &&
        !isCtrl &&
        (key == LogicalKeyboardKey.digit2 ||
            key == LogicalKeyboardKey.numpad2)) {
      _alternarSegundaPieza();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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

    return Focus(
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // BANNER DEL FOLIO ASIGNADO
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.confirmation_number_outlined,
                        color: Colors.red,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
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
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'IVA: ${concurso.iva}% | Utilidad: ${concurso.utilidad}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_alt_outlined,
                            size: 14,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Atajos rápidos:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'F2 / Alt+B: Buscar CURP',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        'Alt+N: Nuevo Artesano',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        'Alt+2: 2da Pieza',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        'Ctrl+Enter / F9: Guardar e Imprimir',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
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
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          '1. Datos del Artesano',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ChoiceChip(
                              tooltip: 'Atajo: Alt + B o F2',
                              label: const Text('Buscar Registrado'),
                              selected: !_esNuevoArtesano,
                              onSelected: (val) {
                                if (val) {
                                  _activarModoBuscarArtesano();
                                }
                              },
                            ),
                            ChoiceChip(
                              tooltip: 'Atajo: Alt + N',
                              label: const Text('Nuevo Artesano'),
                              selected: _esNuevoArtesano,
                              onSelected: (val) {
                                if (val) {
                                  _activarModoNuevoArtesano();
                                }
                              },
                            ),
                          ],
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
                              focusNode: _busquedaCurpFocusNode,
                              autofocus: true,
                              decoration: const InputDecoration(
                                hintText: 'Ingresa ID o CURP del artesano...',
                                suffixText: 'F2',
                                prefixIcon: Icon(Icons.search),
                                isDense: true,
                              ),
                              onSubmitted: (q) => _buscarArtesano(q, concurso),
                            ),
                          ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.search, size: 18),
                          onPressed: () =>
                              _buscarArtesano(_busquedaCurpCtrl.text, concurso),
                          label: const Text('Buscar'),
                        ),
                      ],
                    ),
                    if (_selectedArtesano == null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade900
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blueGrey.shade600),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Ingresa la CURP o ID del artesano registrado y presiona "Buscar" para cargar sus datos en el formulario y editarlos o completarlos si es necesario. Si el artesano no está registrado en el padrón, selecciona "Nuevo Artesano" arriba.',
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey.shade300
                                      : Colors.blueGrey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.casart50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.casart200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.casart700,
                              foregroundColor: Colors.white,
                              child: const Icon(Icons.person, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        _selectedArtesano!.nombreCompleto,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.green.shade400),
                                        ),
                                        child: Text(
                                          'Artesano Registrado (ID: ${_selectedArtesano!.id ?? 'S/N'})',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Los datos del artesano han sido cargados en los campos de abajo. Puedes editar o completar la información si es necesario; los cambios se actualizarán automáticamente en la tabla al guardar la inscripción.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blueGrey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Cambiar'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedArtesano = null;
                                  _limpiarCamposArtesano();
                                });
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    _busquedaCurpFocusNode.requestFocus();
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    // MODO NUEVO ARTESANO
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_add_alt_1_outlined, color: Colors.amber.shade900),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Captura los datos del nuevo artesano. Se guardará automáticamente en el padrón de artesanos al registrar la inscripción.',
                              style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_esNuevoArtesano || _selectedArtesano != null) ...[
                    const SizedBox(height: 16),
                    // CAMPOS DE ARTESANO - DATOS PERSONALES
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _artNombreCtrl,
                            focusNode: _artNombreFocusNode,
                            decoration: const InputDecoration(
                              labelText: 'Nombre(s) *',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AutocompleteTextFormField(
                            controller: _artApPaternoCtrl,
                            suggestions: _sugerencias['ap_paterno'] ?? const [],
                            decoration: const InputDecoration(
                              labelText: 'Primer Apellido *',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AutocompleteTextFormField(
                            controller: _artApMaternoCtrl,
                            suggestions: _sugerencias['ap_materno'] ?? const [],
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
                            onChanged: (v) => _autocompletarDesdeCurp(v, concurso),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'La CURP es requerida';
                              }
                              if (v.trim().length != 18) {
                                return 'La CURP debe tener exactamente 18 caracteres';
                              }
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
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: KeySelectableDropdownFormField<String?>(
                            key: const ValueKey('art_genero'),
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
                            validator: (v) => (v == null || v.isEmpty)
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
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: KeySelectableDropdownFormField<int?>(
                                  key: const ValueKey('art_etnia'),
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
                                  validator: (v) => v == null
                                      ? 'Selecciona una etnia'
                                      : null,
                                  onChanged: (v) => setState(() {
                                    _artEtniaId = v;
                                    if (_fijarEtnia && _pinnedEtniaId == null) {
                                      _pinnedEtniaId = v;
                                    }
                                  }),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildPinFieldButton(
                                key: const ValueKey('pin_etnia'),
                                isPinned: _fijarEtnia,
                                fieldLabel: 'Etnia',
                                onPressed: _togglePinEtnia,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: KeySelectableDropdownFormField<int?>(
                            key: const ValueKey('art_civil'),
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
                            validator: (v) => v == null
                                ? 'Selecciona un estado civil'
                                : null,
                            onChanged: (v) =>
                                setState(() => _artEstadoCivilId = v),
                          ),
                        ),
                      ],
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
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
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
                          if (_fijarEtnia || _fijarMunicipio || _fijarLocalidad)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.push_pin,
                                  size: 14,
                                  color: Colors.amber.shade900,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Fijados: ${[
                                    if (_fijarEtnia) 'Etnia',
                                    if (_fijarMunicipio) 'Municipio',
                                    if (_fijarLocalidad) 'Localidad',
                                  ].join(', ')}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  key: const ValueKey('btn_desfijar_todos'),
                                  onTap: _desfijarValoresFrecuentes,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      'Desfijar todos',
                                      style: TextStyle(
                                        fontSize: 11,
                                        decoration: TextDecoration.underline,
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Selector de Municipio con Búsqueda + Pin
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: SearchableSelectFormField(
                                  key: const ValueKey('art_mun'),
                                  value: _artMunicipio,
                                  items: [
                                    ...MunicipiosData.municipios,
                                    if (_artMunicipio != null &&
                                        _artMunicipio!.trim().isNotEmpty &&
                                        !MunicipiosData.municipios.contains(
                                          _artMunicipio,
                                        ))
                                      _artMunicipio!,
                                  ],
                                  labelText: 'Municipio *',
                                  prefixIcon: Icons.location_city_outlined,
                                  searchTitle: 'Buscar Municipio',
                                  searchHint:
                                      'Escribe una letra o nombre del municipio...',
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'Selecciona un municipio'
                                      : null,
                                  onChanged: (val) {
                                    setState(() {
                                      _artMunicipio = val;
                                      _artMunicipioCtrl.text = val ?? '';
                                      if (_fijarMunicipio &&
                                          _pinnedMunicipio == null) {
                                        _pinnedMunicipio = val;
                                      }
                                      _artLocalidad = null;
                                      _artLocalidadCtrl.clear();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildPinFieldButton(
                                key: const ValueKey('pin_municipio'),
                                isPinned: _fijarMunicipio,
                                fieldLabel: 'Municipio',
                                onPressed: _togglePinMunicipio,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Selector de Localidad dependiente con Búsqueda + Pin
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

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: SearchableSelectFormField(
                                      key: const ValueKey('art_loc'),
                                      value: _artLocalidad,
                                      items: items,
                                      labelText: 'Localidad *',
                                      prefixIcon: Icons.place_outlined,
                                      helperText: hasMun
                                          ? null
                                          : 'Primero selecciona un municipio',
                                      enabled: hasMun,
                                      searchTitle: 'Buscar Localidad',
                                      searchSubtitle: _artMunicipio != null
                                          ? 'Municipio: $_artMunicipio'
                                          : null,
                                      searchHint:
                                          'Escribe una letra o nombre de la localidad...',
                                      allowCustomValue: true,
                                      customValueLabel: 'localidad',
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                          ? 'Selecciona una localidad'
                                          : null,
                                      onChanged: !hasMun
                                          ? null
                                          : (val) {
                                              setState(() {
                                                _artLocalidad = val;
                                                _artLocalidadCtrl.text =
                                                    val ?? '';
                                                if (_fijarLocalidad &&
                                                    _pinnedLocalidad == null) {
                                                  _pinnedLocalidad = val;
                                                  if (_artMunicipio != null &&
                                                      _artMunicipio!
                                                          .trim()
                                                          .isNotEmpty) {
                                                    _fijarMunicipio = true;
                                                    _pinnedMunicipio ??=
                                                        _artMunicipio;
                                                  }
                                                }
                                              });
                                            },
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildPinFieldButton(
                                    key: const ValueKey('pin_localidad'),
                                    isPinned: _fijarLocalidad,
                                    fieldLabel: 'Localidad',
                                    onPressed: _togglePinLocalidad,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AutocompleteTextFormField(
                            controller: _artCodigoPostalCtrl,
                            suggestions: _sugerencias['cp'] ?? const [],
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
                              if (v == null || v.trim().isEmpty) {
                                return 'El Código Postal es obligatorio';
                              }
                              if (v.trim().length != 5) {
                                return 'Debe tener 5 dígitos';
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
                          flex: 3,
                          child: AutocompleteTextFormField(
                            controller: _artCalleCtrl,
                            suggestions: _sugerencias['calle'] ?? const [],
                            decoration: const InputDecoration(
                              labelText: 'Calle (Opcional)',
                              prefixIcon: Icon(Icons.signpost_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: AutocompleteTextFormField(
                            controller: _artNumExteriorCtrl,
                            suggestions:
                                _sugerencias['numero_exterior'] ?? const [],
                            decoration: const InputDecoration(
                              labelText: 'Número Exterior (Opcional)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: AutocompleteTextFormField(
                            controller: _artColoniaCtrl,
                            suggestions: _sugerencias['colonia'] ?? const [],
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
                  TextFormField(
                    controller: _p1NombreCtrl,
                    focusNode: _p1NombreFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la Artesanía *',
                      hintText:
                          'Ej: Olla de barro negro bruñido con flores',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Requerido'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: KeySelectableDropdownFormField<int?>(
                          key: ValueKey(
                            'p1_cat_${concurso.id}',
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
                        child: KeySelectableDropdownFormField<int?>(
                          key: ValueKey(
                            'p1_sub_$safeP1CategoriaId',
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
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Requerido';
                            }
                            final monto = double.tryParse(v.trim());
                            if (monto == null || monto <= 0) {
                              return 'Monto inválido';
                            }
                            return null;
                          },
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
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Tiempo Elaboración *',
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Requerido'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: KeySelectableDropdownFormField<String>(
                          key: const ValueKey('p1_plazo'),
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
                  AutocompleteTextFormField(
                    controller: _p1MaterialCtrl,
                    suggestions:
                        _sugerencias['material_elaboracion'] ?? const [],
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
                      const Expanded(
                        child: Text(
                          '3. Segunda Pieza (Opcional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Tooltip(
                        message: 'Atajo: Alt + 2',
                        child: Switch(
                          value: _incluirPieza2,
                          onChanged: (val) =>
                              _alternarSegundaPieza(forzarValor: val),
                        ),
                      ),
                      Text(
                        _incluirPieza2 ? 'Registrar 2da Pieza' : 'Solo 1 Pieza',
                      ),
                    ],
                  ),
                  if (_incluirPieza2) ...[
                    const Divider(height: 24),
                    TextFormField(
                      controller: _p2NombreCtrl,
                      focusNode: _p2NombreFocusNode,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la Pieza 2 *',
                      ),
                      validator: (v) =>
                          _incluirPieza2 &&
                              (v == null || v.trim().isEmpty)
                          ? 'Requerido'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: KeySelectableDropdownFormField<int?>(
                            key: ValueKey(
                              'p2_cat_${concurso.id}',
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
                          child: KeySelectableDropdownFormField<int?>(
                            key: ValueKey(
                              'p2_sub_$safeP2CategoriaId',
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
                            validator: (v) {
                              if (!_incluirPieza2) return null;
                              if (v == null || v.trim().isEmpty) {
                                return 'Requerido';
                              }
                              final monto = double.tryParse(v.trim());
                              if (monto == null || monto <= 0) {
                                return 'Monto inválido';
                              }
                              return null;
                            },
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
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Tiempo 2 *',
                            ),
                            validator: (v) => _incluirPieza2 && (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: KeySelectableDropdownFormField<String>(
                            key: const ValueKey('p2_plazo'),
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
                    AutocompleteTextFormField(
                      controller: _p2MaterialCtrl,
                      suggestions:
                          _sugerencias['material_elaboracion'] ?? const [],
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
    ),
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
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
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
                        mainAxisSize: MainAxisSize.min,
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
                        mainAxisSize: MainAxisSize.min,
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
                        child: LayoutBuilder(
                          builder: (cardCtx, cardConstraints) {
                            final textScale = MediaQuery.textScalerOf(
                              cardCtx,
                            ).scale(1.0);
                            final isCardNarrow =
                                (cardConstraints.maxWidth / textScale) < 650;

                            final folioWidget = Container(
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
                            );

                            final artesanoInfo = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a?.nombreCompleto ?? 'Artesano Desconocido',
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
                            );

                            final actionsButtons = Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
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
                                      builder: (c) => ComprobanteDialog(
                                        registro: r,
                                        concurso: concurso,
                                      ),
                                    );
                                  },
                                ),
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
                                      builder: (c) => EditarInscripcionDialog(
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
                                                  concurso: concurso,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                if (concurso.finalizado)
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
                            );

                            final piece1Widget = Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Flexible(
                                        child: Text(
                                          'Pieza 1 (Principal):',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: AppTheme.casart800,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
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
                                    Tooltip(
                                      message: 'Clic para ver o imprimir distintivo de la pieza premiada',
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(4),
                                        onTap: () {
                                          final gMap = {
                                            'premio_nombre': p1.premioNombre,
                                            'folio_concurso': '${r.folio}A',
                                            'artesania_nombre': p1.nombre,
                                            'artesano_nombre': a?.nombre,
                                            'artesano_paterno': a?.apPaterno,
                                            'artesano_materno': a?.apMaterno,
                                            'localidad': a?.localidad,
                                            'municipio': a?.municipio,
                                            'rama_nombre': p1.ramaNombre,
                                            'categoria_nombre': p1.categoriaNombre,
                                            'subcategoria_nombre': p1.subcategoriaNombre,
                                            'premio_monto': 0.0,
                                          };
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => ActaGanadoresDialog(
                                              concurso: concurso,
                                              ganadores: [gMap],
                                              initialType: TipoDocumentoGanadores.distintivos,
                                            ),
                                          );
                                        },
                                        child: Container(
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
                                              const SizedBox(width: 6),
                                              Icon(
                                                Icons.print_outlined,
                                                size: 13,
                                                color: Colors.amber.shade900,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );

                            final hasPiece2 =
                                p2 != null && p2.nombre.trim().isNotEmpty;
                            final piece2Widget = hasPiece2
                                ? Container(
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
                                            const Flexible(
                                              child: Text(
                                                'Pieza 2 (Segunda Pieza):',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: AppTheme.casart800,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              Formatters.formatCurrency(
                                                p2.costoVenta,
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
                                          Tooltip(
                                            message: 'Clic para ver o imprimir distintivo de la pieza premiada',
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(4),
                                              onTap: () {
                                                final gMap = {
                                                  'premio_nombre': p2.premioNombre,
                                                  'folio_concurso': '${r.folio}B',
                                                  'artesania_nombre': p2.nombre,
                                                  'artesano_nombre': a?.nombre,
                                                  'artesano_paterno': a?.apPaterno,
                                                  'artesano_materno': a?.apMaterno,
                                                  'localidad': a?.localidad,
                                                  'municipio': a?.municipio,
                                                  'rama_nombre': p2.ramaNombre,
                                                  'categoria_nombre': p2.categoriaNombre,
                                                  'subcategoria_nombre': p2.subcategoriaNombre,
                                                  'premio_monto': 0.0,
                                                };
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => ActaGanadoresDialog(
                                                    concurso: concurso,
                                                    ganadores: [gMap],
                                                    initialType: TipoDocumentoGanadores.distintivos,
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
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
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 11,
                                                          color: Colors.amber.shade900,
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Icon(
                                                      Icons.print_outlined,
                                                      size: 13,
                                                      color: Colors.amber.shade900,
                                                    ),
                                                  ],
                                                ),
                                              ),
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
                                      borderRadius: BorderRadius.circular(6),
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
                                  );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isCardNarrow)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      folioWidget,
                                      const SizedBox(width: 14),
                                      Expanded(child: artesanoInfo),
                                      const SizedBox(width: 8),
                                      actionsButtons,
                                    ],
                                  )
                                else ...[
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      folioWidget,
                                      const SizedBox(width: 14),
                                      Expanded(child: artesanoInfo),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  actionsButtons,
                                ],
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 12),
                                if (isCardNarrow)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      piece1Widget,
                                      if (hasPiece2) ...[
                                        const SizedBox(height: 10),
                                        piece2Widget,
                                      ],
                                    ],
                                  )
                                else
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: piece1Widget),
                                      const SizedBox(width: 12),
                                      Expanded(child: piece2Widget),
                                    ],
                                  ),
                              ],
                            );
                          },
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
