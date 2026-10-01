import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/concursos_provider.dart';

/// Vista de Tutorial interactivo y Guía Operativa Completa
/// para la gestión de concursos artesanales CASART.
class TutorialView extends ConsumerStatefulWidget {
  final void Function(int tabIndex)? onNavigate;

  const TutorialView({super.key, this.onNavigate});

  @override
  ConsumerState<TutorialView> createState() => _TutorialViewState();
}

class _TutorialViewState extends ConsumerState<TutorialView> {
  int _selectedSection = 0;
  final TextEditingController _searchCtrl = TextEditingController();
  String _filterQuery = '';

  final List<_TutorialSectionData> _sections = [
    _TutorialSectionData(
      id: 0,
      title: 'Flujo General del Sistema',
      subtitle:
          'Ciclo de vida completo: Concurso → Premios → Inscripción → Dictamen → Cierre',
      icon: Icons.account_tree_outlined,
      activeIcon: Icons.account_tree,
      badgeColor: AppTheme.casart800,
    ),
    _TutorialSectionData(
      id: 1,
      title: '1. Registro de Concursos',
      subtitle:
          'Convocatorias, fechas clave, categorías, aportaciones y activación',
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events,
      badgeColor: Color(0xFFB8860B),
      imageAsset: 'assets/images/tutorial_concurso.jpg',
      navTargetTab: 0,
    ),
    _TutorialSectionData(
      id: 2,
      title: '2. Bolsa de Premios',
      subtitle:
          'Estructuración de galardones, lugares por categoría, montos y patrocinadores',
      icon: Icons.military_tech_outlined,
      activeIcon: Icons.military_tech,
      badgeColor: AppTheme.ocreAccent,
      imageAsset: 'assets/images/tutorial_premios.jpg',
      navTargetTab: 2,
    ),
    _TutorialSectionData(
      id: 3,
      title: '3. Inscripción de Artesanos y Piezas',
      subtitle:
          'Búsqueda CURP, captura de Pieza 1 y 2, costos e impresión de boletas y cédulas',
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment,
      badgeColor: AppTheme.verdeSuccess,
      imageAsset: 'assets/images/tutorial_inscripcion.jpg',
      navTargetTab: 1,
    ),
    _TutorialSectionData(
      id: 4,
      title: '4. Edición y Reimpresión',
      subtitle:
          'Búsqueda en padrón, corrección de obras y reimpresión de comprobantes oficiales',
      icon: Icons.edit_note_outlined,
      activeIcon: Icons.edit_note,
      badgeColor: AppTheme.azulAccent,
      navTargetTab: 1,
    ),
    _TutorialSectionData(
      id: 5,
      title: '5. Dictamen y Premiación',
      subtitle:
          'Calificación con jurado, asignación de piezas ganadoras y validaciones de cuota',
      icon: Icons.workspace_premium_outlined,
      activeIcon: Icons.workspace_premium,
      badgeColor: Color(0xFFD97706),
      imageAsset: 'assets/images/tutorial_premiacion.jpg',
      navTargetTab: 2,
    ),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showImageZoomDialog(
    BuildContext context,
    String assetPath,
    String title,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 850),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra superior modal
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  color: AppTheme.casart800,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.image_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Captura del Sistema: $title',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Cerrar vista previa',
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              // Imagen con zoom interactivo
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 3.5,
                      child: Image.asset(
                        assetPath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          padding: const EdgeInsets.all(32),
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: Text(
                              'Vista previa ilustrativa no disponible.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pellizque o use la rueda del mouse para hacer zoom en la captura.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedConcurso = ref.watch(selectedConcursoProvider).asData?.value;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 900;

          return Column(
            children: [
              // ENCABEZADO SUPERIOR DEL MANUAL
              _buildHeader(selectedConcurso, isNarrow),

              // CUERPO: NAVEGACIÓN LATERAL DE TEMAS + CONTENIDO DETALLADO
              Expanded(
                child: isNarrow
                    ? _buildNarrowLayout(context)
                    : _buildWideLayout(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(dynamic selectedConcurso, bool isNarrow) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 16 : 24,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.casart50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.casart200),
            ),
            child: const Icon(
              Icons.menu_book,
              color: AppTheme.casart800,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Manual de Usuario y Guía Operativa',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  selectedConcurso != null
                      ? 'Concurso actual en gestión: ${selectedConcurso.nombre}'
                      : 'Guía paso a paso para operar el sistemar',
                  style: TextStyle(
                    fontSize: 12,
                    color: selectedConcurso != null
                        ? AppTheme.casart800
                        : Colors.grey.shade600,
                    fontWeight: selectedConcurso != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Buscador rápido de temas
          SizedBox(
            width: isNarrow ? 150 : 260,
            height: 38,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) {
                setState(() => _filterQuery = val.trim().toLowerCase());
              },
              decoration: InputDecoration(
                hintText: isNarrow ? 'Buscar...' : 'Buscar en el manual...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: Colors.grey,
                ),
                suffixIcon: _filterQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _filterQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // MENÚ LATERAL DE ÍNDICE
        SizedBox(
          width: 320,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: _buildSectionsList(),
          ),
        ),

        // CONTENIDO CENTRAL DEL TEMA SELECCIONADO
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: _buildSelectedSectionContent(context),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return Column(
      children: [
        // Pestañas horizontales para pantallas compactas
        Container(
          height: 52,
          color: Colors.white,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _sections.length,
            itemBuilder: (context, index) {
              final sec = _sections[index];
              final isSelected = _selectedSection == sec.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? sec.activeIcon : sec.icon,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sec.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.casart800,
                  backgroundColor: Colors.grey.shade100,
                  onSelected: (val) {
                    if (val) setState(() => _selectedSection = sec.id);
                  },
                ),
              );
            },
          ),
        ),
        const Divider(height: 1, thickness: 1),
        // Contenido scrollable
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildSelectedSectionContent(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionsList() {
    final filtered = _sections.where((s) {
      if (_filterQuery.isEmpty) return true;
      return s.title.toLowerCase().contains(_filterQuery) ||
          s.subtitle.toLowerCase().contains(_filterQuery);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Text(
            'TABLA DE CONTENIDO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final sec = filtered[index];
              final isSelected = _selectedSection == sec.id;

              return InkWell(
                onTap: () => setState(() => _selectedSection = sec.id),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.casart50 : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.casart300
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.casart800
                              : sec.badgeColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSelected ? sec.activeIcon : sec.icon,
                          size: 16,
                          color: isSelected ? Colors.white : sec.badgeColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sec.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: isSelected
                                    ? AppTheme.casart800
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sec.subtitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected
                                    ? AppTheme.casart700.withValues(alpha: 0.8)
                                    : Colors.grey.shade600,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Acceso rápido al pie del índice
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: AppTheme.casart800,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Haga clic en cualquier tema para ver pasos detallados y capturas.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedSectionContent(BuildContext context) {
    switch (_selectedSection) {
      case 0:
        return _buildSectionFlujoGeneral(context);
      case 1:
        return _buildSectionConcursos(context);
      case 2:
        return _buildSectionPremios(context);
      case 3:
        return _buildSectionInscripcion(context);
      case 4:
        return _buildSectionEdicion(context);
      case 5:
        return _buildSectionPremiacion(context);

      default:
        return _buildSectionFlujoGeneral(context);
    }
  }

  // ===========================================================================
  // SECCIÓN 0: FLUJO GENERAL DEL SISTEMA
  // ===========================================================================
  Widget _buildSectionFlujoGeneral(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Flujo Completo del sistema de concursos',
          'consta de 5 etapas para la correcta operacion de un concurso',
          Icons.account_tree,
          AppTheme.casart800,
        ),
        const SizedBox(height: 16),

        _buildCallout(
          icon: Icons.lightbulb_outline,
          color: AppTheme.casart800,
          title: '¿Cómo funciona el sistema en una jornada de concurso?',
          message:
              'La aplicion esta disenada para tabrajar ya sea individual (una sola persona inscribiendo ) o en equipo (varias personas inscribiendo ), cuando es en equipo es importante elejir una computadora como servidor, en este equipo es donde se estaran guardando los datos, el resto de equipos deberan configurarse como clientes las cuales guardan los datos de inscripcion en el equipo elegido como servidor, una nota importante es recomendable que la computadora  elejida como servidor cumpla este rol en todos los concursos para que la informacion de todos los concursos este concentrada en un solo equipo y no este regada en todas las computadoras, con la clara excepcion de cuando sucedan 2 concursos en simultaneo.',
        ),

        const SizedBox(height: 24),
        _buildWorkflowStepper(context),

        const SizedBox(height: 28),
        const Text(
          'Matriz Rápida de Responsabilidades y Módulos',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        _buildResponsibilitiesTable(),

        const SizedBox(height: 24),
        _buildShortcutButtonsRow(
          onTapConcursos: () => setState(() => _selectedSection = 1),
          onTapPremios: () => setState(() => _selectedSection = 2),
          onTapInscripcion: () => setState(() => _selectedSection = 3),
        ),
      ],
    );
  }

  Widget _buildWorkflowStepper(BuildContext context) {
    final steps = [
      {
        'num': '1',
        'title': 'Configuración de la Convocatoria',
        'desc':
            'Se crea el Concurso en el catálogo con sus fechas límite, categorías participantes (Alfarería, Textil, etc.) y las aportaciones económicas asignadas.',
        'icon': Icons.emoji_events,
        'color': const Color(0xFFB8860B),
        'tab': 1,
      },
      {
        'num': '2',
        'title': 'Definición de la Bolsa de Premios',
        'desc':
            'Se registran los galardones magnos, 1os, 2os y 3os lugares por categoría con sus montos en pesos (\$ MXN) y la institución aportante (FONART / CASART).',
        'icon': Icons.military_tech,
        'color': AppTheme.ocreAccent,
        'tab': 2,
      },
      {
        'num': '3',
        'title': 'Ventanilla: Inscripción de Artesanos y Obras',
        'desc':
            'Se busca por CURP al artesano (autocompletado instantáneo). Se registra la Pieza 1 (obligatoria) y Pieza 2 (opcional), se cobra la cuota y se imprimen las Boletas y Cédulas con códigos QR.',
        'icon': Icons.assignment,
        'color': AppTheme.verdeSuccess,
        'tab': 3,
      },
      {
        'num': '4',
        'title': 'Jurado Calificador y Dictamen',
        'desc':
            'Los jueces evalúan físicamente las piezas con sus cédulas numeradas. Se asignan las obras ganadoras a cada premio en el sistema, validando categorías y cuotas.',
        'icon': Icons.workspace_premium,
        'color': const Color(0xFFD97706),
        'tab': 5,
      },
    ];

    return Column(
      children: steps.map((s) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (s['color'] as Color).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: s['color'] as Color, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    s['num'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: s['color'] as Color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          s['icon'] as IconData,
                          size: 18,
                          color: s['color'] as Color,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s['title'] as String,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s['desc'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () =>
                    setState(() => _selectedSection = s['tab'] as int),
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: const Text('Ver Guía', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.casart50,
                  foregroundColor: AppTheme.casart800,
                  elevation: 0,
                  side: const BorderSide(color: AppTheme.casart200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResponsibilitiesTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.4),
          1: FlexColumnWidth(1.8),
          2: FlexColumnWidth(2.8),
        },
        border: TableBorder.symmetric(
          inside: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(9),
              ),
            ),
            children: const [
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Fase / Módulo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Usuario Responsable',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Entregable Clave',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          _buildTableRow(
            '1. Concursos',
            'Administrador / Coordinador',
            'Concurso activo configurado con categorías y calendario oficial.',
          ),
          _buildTableRow(
            '2. Bolsa de Premios',
            'Administrador / Finanzas',
            'Premios dados de alta con montos validados vs. presupuesto.',
          ),
          _buildTableRow(
            '3. Inscripción',
            'Capturistas en Ventanilla',
            'Boletas firmadas y Cédulas adheridas a las obras recibidas.',
          ),
          _buildTableRow(
            '4. Dictamen',
            'Jurado y Moderador CASART',
            'Piezas ganadoras asignadas y Acta de Dictamen firmada.',
          ),
          _buildTableRow(
            '5. Respaldos',
            'Coordinador de Sistemas',
            'Excel Formatos A/B/C exportados y Respaldo USB resguardado.',
          ),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String col1, String col2, String col3) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Text(
            col1,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Text(
            col2,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Text(
            col3,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SECCIÓN 1: CÓMO REGISTRAR UN CONCURSO
  // ===========================================================================
  Widget _buildSectionConcursos(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          '1. Registro y Configuración de Concursos',
          'Aprende a crear una nueva convocatoria, establecer fechas, ramas artesanales y aportaciones.',
          Icons.emoji_events,
          const Color(0xFFB8860B),
        ),
        const SizedBox(height: 16),

        // Captura visual destacada
        _buildImageCard(
          context: context,
          title: 'Pantalla de Catálogo y Configuración de Concursos',
          assetPath: 'assets/images/tutorial_concurso.jpg',
          caption:
              'Visualización del panel de concursos con buscador, tarjetas informativas, estado activo y modal de edición.',
        ),

        const SizedBox(height: 24),
        const Text(
          'Instrucciones Paso a Paso:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),

        _buildStepCard(
          step: '1',
          title: 'Acceder al Módulo de Concursos',
          description:
              'En el menú lateral izquierdo, haz clic en "Concursos". Se listarán todas las convocatorias vigentes e históricas registradas en el sistema.',
        ),
        _buildStepCard(
          step: '2',
          title: 'Crear un Nuevo Concurso',
          description:
              'Haz clic en el botón superior "+ Nuevo Concurso". Se abrirá el formulario modal estructurado en 3 pestañas principales.',
        ),
        _buildStepCard(
          step: '3',
          title: 'Completar Datos Generales y Fechas Oficiales',
          description:
              '• Nombre del Concurso: Ejemplo: "XLVIII Concurso Estatal de Artesanías", (sin incluir la anualidad).\n'
              '• Lugar: La direccion completa de donde se realizara la incripcion, tal y como aparece en la convocatoria.\n'
              '• Ejercicio Fiscal: Año en curso presupuestal.\n'
              '• Fechas Oficiales: Inicio y Límite de Registro, Fecha y hora de Dictamen (cuando se realiza la calificacion) y Fecha y hora de Premiación.\n'
              '• Parámetros Financieros: IVA y utilidad dejarlos siempre en 0 para concursos locales y regionales',
        ),
        _buildStepCard(
          step: '4',
          title: 'Definir Categorías y Subcategorías Participantes',
          description:
              'En la pestaña "Categorías", es donde podemos agregar las categorias del concurso, debajo del input para el nombre de la categoria se encuentra un boton para agregar las subcategorias que existan de esa categoria en especifico, mas abajo se encuentra el boton para agregar una nueva categoria y repetir el ciclo .',
        ),
        _buildStepCard(
          step: '5',
          title: 'Registrar Aportaciones Institucionales',
          description:
              'En la pestaña "Aportaciones", registra los montos que aporto cada institucion a la bolsa de premios del concurso (CASART, FONART, Gobierno del Estado de México, Ayuntamiento Municipal)',
        ),
        _buildStepCard(
          step: '6',
          title: 'Activar el Concurso de Trabajo',
          description:
              'Una vez guardado, puedes dar clic sobre el nombre del concurso que has creado para seleccionarlo y el resto del sistema trabaje sobre este concurso, en la parte superior se mostrara un recuadro amarillo con el nombre del concurso, este es el idicativo de en que concurso se esta tranbajando, tambien puedes oprimir el boton de inscribir piezas y se selccionara igualmente ademas de dirigirte a la vista de inscripcion.',
        ),

        const SizedBox(height: 16),
        _buildCallout(
          icon: Icons.security,
          color: Colors.blueGrey,
          title: 'Regla de Integridad: Concurso Finalizado',
          message:
              'Cuando un concurso se marca como "Finalizado" (o cerrado), entra en modo de Solo Lectura. No se podrán inscribir más artesanos ni alterar los premios otorgados, garantizando la certeza jurídica de la premiación.',
        ),

        const SizedBox(height: 20),
        _buildGoToModuleButton(
          title: 'Abrir Módulo de Concursos',
          icon: Icons.emoji_events,
          color: const Color(0xFFB8860B),
          onPressed: () => widget.onNavigate?.call(0),
        ),
      ],
    );
  }

  // ===========================================================================
  // SECCIÓN 2: CÓMO REGISTRAR PREMIOS
  // ===========================================================================
  Widget _buildSectionPremios(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          '2. Gestión de la Bolsa de Premios',
          'Configura los galardones, lugares por categoría y montos económicos antes de iniciar la recepción.',
          Icons.military_tech,
          AppTheme.ocreAccent,
        ),
        const SizedBox(height: 16),

        _buildImageCard(
          context: context,
          title: 'Panel de Bolsa de Premios',
          assetPath: 'assets/images/tutorial_premios.jpg',
          caption:
              'Estructura de premios por categoría, montos asignados en MXN, patrocinador FONART/CASART y formulario de alta.',
        ),

        const SizedBox(height: 24),
        const Text(
          'Pasos para Configurar los Premios de la Convocatoria:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),

        _buildStepCard(
          step: '1',
          title: 'Verificar el Concurso Activo',
          description:
              'Asegúrate de que en la barra superior esté seleccionado el concurso correcto. La bolsa de premios pertenece exclusivamente a la convocatoria activa.',
        ),
        _buildStepCard(
          step: '2',
          title: 'Revisar el Resumen de Presupuesto',
          description:
              'En la parte superior verás un indicador de color azul:\n'
              '• Total Bolsa: Suma del monto monetario de los premios configurados, debera coincidir con la bolsa declarada en la convoctoria.\n',
        ),
        _buildStepCard(
          step: '3',
          title: 'Dar de Alta Premios Individuales',
          description:
              'Haz clic en "Agregar Premio" y completa:\n'
              '• Monto (\$ MXN): Importe monetario exacto del premio, solo numeros si coma ni signo de pesos\n'
              '• Tipo de premio: selecciona ya sea un premio comun, un premio especial o galardo\n'
              '• limite de otorgacion: cuantas veces se le puede otorgar este premio a piezas distintas, por defecto y casi siempre es 1\n'
              '• lugar: cuando se selecciona un premio de tipo comun se podra elejir si se trata de 1, 2 o 3 lugar\n'
              '• Categoría: si es un premio comun selecciona la categoria del premio, y si esta categoria tiene subcategoria tambien la podras elejir, cuando se trate un premio especial o galardon no es necesario elejir esto.\n'
              '• Nombre del Premio: en los premios comunues el nombre se autocompeta, pero puedes editarlo \n',
        ),

        const SizedBox(height: 16),
        _buildCallout(
          icon: Icons.check_circle_outline,
          color: AppTheme.verdeSuccess,
          title: 'Buenas Prácticas de Presupuesto',
          message:
              'Es recomendable capturar la totalidad de los premios antes de iniciar la ventanilla de registro. De este modo, los reportes financieros preliminares cuadrarán con las bases de la convocatoria publicada.',
        ),

        const SizedBox(height: 20),
        _buildGoToModuleButton(
          title: 'Abrir Módulo de Bolsa de Premios',
          icon: Icons.military_tech,
          color: AppTheme.ocreAccent,
          onPressed: () => widget.onNavigate?.call(2),
        ),
      ],
    );
  }

  // ===========================================================================
  // SECCIÓN 3: CÓMO INSCRIBIR PIEZAS
  // ===========================================================================
  Widget _buildSectionInscripcion(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          '3. Inscripción de Artesanos y Registro de Piezas',
          'Procedimiento operativo de ventanilla: búsqueda por CURP, captura de obras, cobro de cuota y expedición de boletas.',
          Icons.assignment,
          AppTheme.verdeSuccess,
        ),
        const SizedBox(height: 16),

        _buildImageCard(
          context: context,
          title: 'Ventanilla de Inscripción y Recepción de Piezas',
          assetPath: 'assets/images/tutorial_inscripcion.jpg',
          caption:
              'Búsqueda por CURP con autocompletado, ficha del artesano, captura de Pieza 1 obligatoria y Pieza 2 opcional con avalúo.',
        ),

        const SizedBox(height: 24),
        const Text(
          'Flujo de inscripcion (Paso a Paso):',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),

        _buildStepCard(
          step: '1',
          title: 'Datos del artesano',
          description:
              '• Lo primero es deducir si el artesano ya esta registrado en el sistema, si es el caso solo debemos ingresar la curp del artesano y darle clic en buscar para enlazarlo con la inscripcion, si no es el caso deberemos capturar la iformacion del artesano, para esto debemos de darle clic al boton superior de "Nuevo Artesano", el cual nos mostrara campos para ingresar los datos del artesano, el cual quedara registrado y en el proximo concurso podremos enlazarlo con la curp inicamente.\n',
        ),
        _buildStepCard(
          step: '2',
          title: 'Registro de la Pieza 1 (Obligatoria)',
          description:
              'Captura los detalles técnicos de la primera obra:\n'
              '• Título de la Pieza: Nombre artístico o descriptivo de la obra.\n'
              '• categoria, categoria y subcategoria: Rama artesanal es el listado de ramas artesanales oficiales, no es lo mismo que las catetgorias del concurso, y categoría y subcategorias son la spublicadas en la combocatoria, por ejemplo en opopeo una silla entra en la rama de maderas, y seria de la categoria sillas.\n'
              '• Costo de Recuperación / Avalúo: Valor comercial estimado sin coma ni signo de \$.\n'
              '• Tiempo de Elaboración: Cantidad en numero y unidad (días, semanas, meses).\n'
              '• Materiales y descripocion: indica los materiales con los cuales fue elaborada la pieza, la descripcion es opcional.',
        ),
        _buildStepCard(
          step: '3',
          title: 'Registro de la Pieza 2 (Opcional)',
          description:
              'Si el artesano presenta una segunda pieza:\n'
              '• Activa el interruptor "solo 1 Piza".\n'
              '• Completa los campos correspondientes a la Pieza 2 (pueden ser de ramas o categorías distintas según la convocatoria).',
        ),

        _buildStepCard(
          step: '4',
          title: 'Guardar e Impresión Automática de Boletas',
          description:
              'Haz clic en el botón principal "Guardar e Imprimir Boletas". El sistema asigna de forma instantánea el Folio Único Consecutivo y abre la ventana de impresión para generar, al imprimir seleccionar horientacion vertical\n'
              '1. Talón del Artesano: Comprobante oficial de entrega con firma de recibido y fecha.\n'
              '2. Cédula de la Obra: Etiqueta con código QR.',
        ),

        const SizedBox(height: 16),
        _buildCallout(
          icon: Icons.qr_code_2,
          color: AppTheme.casart800,
          title: 'Uso del Código QR y Código de Barras',
          message:
              'El Qr tiene la informacion de contacto del artesano, util durante la exposicion en concursos estatales',
        ),

        const SizedBox(height: 20),
        _buildGoToModuleButton(
          title: 'Abrir Módulo de Inscripción',
          icon: Icons.assignment,
          color: AppTheme.verdeSuccess,
          onPressed: () => widget.onNavigate?.call(1),
        ),
      ],
    );
  }

  // ===========================================================================
  // SECCIÓN 4: CÓMO EDITAR Y REIMPRIMIR
  // ===========================================================================
  Widget _buildSectionEdicion(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          '4. Edición, Corrección y Reimpresión de Boletas',
          'Gestión de registros existentes, búsqueda en el padrón, corrección de errores ortográficos o técnicos y reimpresión de comprobantes.',
          Icons.edit_note,
          AppTheme.azulAccent,
        ),
        const SizedBox(height: 16),

        _buildCallout(
          icon: Icons.search,
          color: AppTheme.azulAccent,
          title: '¿Dónde encuentro los registros ya guardados?',
          message:
              'Dentro del módulo "Inscripción de Piezas", haz clic en la segunda pestaña titulada "Piezas Inscritas". Allí encontrarás la tabla con todas las obras y artesanos registrados en el concurso actual.',
        ),

        const SizedBox(height: 24),
        const Text(
          'Operaciones del Padrón de Inscritos:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),

        _buildStepCard(
          step: '1',
          title: 'Búsqueda Dinámica y Filtros',
          description:
              'Utiliza la barra de búsqueda superior para localizar rápidamente cualquier registro escribiendo:\n'
              '• Número de Folio (ej. "0042"). inscribelo sin "0" quedaria 42\n'
              '• Nombre o apellidos del artesano.\n'
              '• CURP o Municipio de procedencia.\n'
              '• Filtro por Categoría para ver únicamente piezas de cierta rama.',
        ),
        _buildStepCard(
          step: '2',
          title: 'Reimpresión de Boletas y Cédulas (Ícono Impresora)',
          description:
              'Si el artesano extravió su talón de recepción o la etiqueta de la pieza se maltrató durante el montaje:\n'
              '1. Localiza la fila del artesano en la tabla.\n'
              '2. Haz clic en el botón que dice Reimprimit.\n'
              '3. Se abrirá el diálogo con la vista previa del comprobante listo para mandar a la impresora o guardar como archivo PDF.',
        ),
        _buildStepCard(
          step: '3',
          title: 'Edición de Datos de la Inscripción (Ícono Lápiz)',
          description:
              'Para corregir información capturada incorrectamente:\n'
              '1. Haz clic en el botón Editar  en la fila del registro.\n'
              '2. Se abrirá la ventana "Editar Inscripción", permitiendo corregir:\n'
              '   • Teléfono o localidad del artesano.\n'
              '   • Nombre de la obra, técnica o medidas.\n'
              '   • Costo de recuperación o tiempo de elaboración.\n'
              '   • Agregar o retirar la segunda pieza si fue necesario.\n'
              '3. Presiona "Guardar Cambios". La información se actualiza al instante sin cambiar el número de folio.',
        ),

        const SizedBox(height: 20),
        _buildGoToModuleButton(
          title: 'Ir al Padrón de Inscripciones',
          icon: Icons.table_view,
          color: AppTheme.azulAccent,
          onPressed: () => widget.onNavigate?.call(1),
        ),
      ],
    );
  }

  // ===========================================================================
  // SECCIÓN 5: CÓMO PREMIAR Y EMITIR DICTAMEN
  // ===========================================================================
  Widget _buildSectionPremiacion(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          '5. Calificación, Dictamen y Premiación',
          'Asignación oficial de ganadores conforme a las decisiones del Jurado Calificador y validaciones de cuota.',
          Icons.workspace_premium,
          const Color(0xFFD97706),
        ),
        const SizedBox(height: 16),

        _buildImageCard(
          context: context,
          title: 'Módulo de Premiación y Dictamen del Jurado',
          assetPath: 'assets/images/tutorial_premiacion.jpg',
          caption:
              'Asignación de premios: lista de galardones con estatus Asignado/Pendiente, buscador de pieza nominada y desglose de monto.',
        ),

        const SizedBox(height: 24),
        const Text(
          'Proceso de Premiación con el Jurado:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),

        _buildStepCard(
          step: '1',
          title: 'Método Rápido: Premiar desde el Padrón de Inscritos',
          description:
              '1. Para poder premiar es necesario haber configurado los premios como se muestra en el paso 2 y marcar el concurso como finalizado, esto se hace en la lista de concursos en el boton verde que dice "En proceso".\n'
              '2. Una vez marcado como finalizado un concurso dirigeter a la lista de piezas inscritas, busca el artesano por nombre o folio de la boleta (si los 0) Haz clic en el botón con ícono de Trofeo / Medalla (🏆) que dice premiar.\n'
              '3. Selecciona cuál de las dos piezas del artesano es la ganadora (Pieza 1 o Pieza 2).\n'
              '4. El sistema listará únicamente los premios configurados disponibles que coincidan con la categoría de la pieza (o los galardones magnos generales).\n'
              '5. Selecciona el premio correspondiente y haz clic en "Confirmar Ganador".',
        ),

        _buildStepCard(
          step: '2',
          title: 'Generación del Acta Oficial de Dictamen',
          description:
              'Al concluir la califiacion podras descargar la lista de ganadores ya sea resumida o compelta (formato A y B ) respectivamente esto en el boton verde que dice Exportar Excel disponible en la lista de piezas inscritas o en el modulo de premios',
        ),

        _buildStepCard(
          step: '3',
          title: 'Estadisticas del concurso',
          description:
              'En la seccion de concursos podras encontrar un boton que dice "estadisticas" al lado del nombre del concurso respectivo, este te mostrara los datos del concurso como total de artesanos, piezas inscritas, etc, este funciona en tiempo real',
        ),

        const SizedBox(height: 20),
        _buildGoToModuleButton(
          title: 'Abrir Módulo de Premios',
          icon: Icons.military_tech,
          color: const Color(0xFFD97706),
          onPressed: () => widget.onNavigate?.call(2),
        ),
      ],
    );
  }

  // ===========================================================================
  // SECCIÓN 6: REPORTES EXCEL, RESPALDOS Y TRABAJO EN RED
  // ===========================================================================

  // ===========================================================================
  // WIDGETS AUXILIARES Y COMPONENTES VISUALES
  // ===========================================================================

  Widget _buildSectionTitle(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard({
    required BuildContext context,
    required String title,
    required String assetPath,
    required String caption,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de ventana simulada
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5F56),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFBD2E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF27C93F),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _showImageZoomDialog(context, assetPath, title),
                  icon: const Icon(Icons.zoom_in, size: 14),
                  label: const Text(
                    'Ampliar Captura',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    side: BorderSide(color: Colors.grey.shade400),
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Imagen clickeable
          InkWell(
            onTap: () => _showImageZoomDialog(context, assetPath, title),
            child: ClipRect(
              child: Stack(
                children: [
                  Image.asset(
                    assetPath,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: Text(
                          'Captura ilustrativa cargándose...',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Clic para ampliar',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Pie de foto descriptivo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(11),
              ),
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 15,
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    caption,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String step,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.casart800,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallout({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF334155),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoToModuleButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.open_in_new, size: 18, color: color),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '¿Deseas poner en práctica este procedimiento ahora mismo?',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 15),
            label: Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutButtonsRow({
    required VoidCallback onTapConcursos,
    required VoidCallback onTapPremios,
    required VoidCallback onTapInscripcion,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.casart50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.casart200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Atajos a Guías de Módulos Específicos:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.casart800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ActionChip(
                avatar: const Icon(
                  Icons.emoji_events,
                  size: 16,
                  color: Color(0xFFB8860B),
                ),
                label: const Text('1. Guía de Concursos'),
                onPressed: onTapConcursos,
                backgroundColor: Colors.white,
              ),
              ActionChip(
                avatar: const Icon(
                  Icons.military_tech,
                  size: 16,
                  color: AppTheme.ocreAccent,
                ),
                label: const Text('2. Guía de Premios'),
                onPressed: onTapPremios,
                backgroundColor: Colors.white,
              ),
              ActionChip(
                avatar: const Icon(
                  Icons.assignment,
                  size: 16,
                  color: AppTheme.verdeSuccess,
                ),
                label: const Text('3. Guía de Inscripción'),
                onPressed: onTapInscripcion,
                backgroundColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TutorialSectionData {
  final int id;
  final String title;
  final String subtitle;
  final IconData icon;
  final IconData activeIcon;
  final Color badgeColor;
  final String? imageAsset;
  final int? navTargetTab;

  _TutorialSectionData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.activeIcon,
    required this.badgeColor,
    this.imageAsset,
    this.navTargetTab,
  });
}
