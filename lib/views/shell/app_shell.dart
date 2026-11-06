import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/network_state.dart';
import '../../core/network/embedded_server.dart';
import '../../providers/database_provider.dart';
import '../../providers/concursos_provider.dart';
import '../../providers/ui_zoom_provider.dart';
import '../concursos/concursos_list_view.dart';
import '../inscripcion/inscripcion_view.dart';
import '../premios/premios_view.dart';
import '../backup/backup_view.dart';
import '../tutorial/tutorial_view.dart';
import '../backup/log_viewer_dialog.dart';
import '../network/network_config_dialog.dart';
import '../common/update_dialog.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_theme.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;
  EmbeddedServer? _server;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initServer();
    });
  }

  Future<void> _initServer() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;

    final config = ref.read(networkConfigProvider);
    if (config.isServer) {
      try {
        _server = ref.read(embeddedServerProvider);
        await _server?.start(port: config.port);
        ref.read(networkConfigProvider.notifier).setServerRunning(true);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _server?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedConcursoAsync = ref.watch(selectedConcursoProvider);
    final netConfig = ref.watch(networkConfigProvider);

    return Scaffold(
      body: Row(
        children: [
          // ==========================================
          // BARRA LATERAL INSTITUCIONAL (SIDEBAR)
          // ==========================================
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: AppTheme.casart800, // Color Principal CASART (#90245A)
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // BRANDING CASART
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/logo_casart.png',
                      height: 52,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        final file = File('assets/images/logo_casart.png');
                        if (file.existsSync()) {
                          return Image.file(
                            file,
                            height: 52,
                            fit: BoxFit.contain,
                          );
                        }
                        final absFile = File(
                          r'C:\Users\CASART\Desktop\CASART\codigo\sistema_gestor\casart_concursos_desktop\assets\images\logo_casart.png',
                        );
                        if (absFile.existsSync()) {
                          return Image.file(
                            absFile,
                            height: 52,
                            fit: BoxFit.contain,
                          );
                        }
                        return const Text(
                          'CASART',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ELEMENTOS DE NAVEGACIÓN
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    children: [
                      _buildNavItem(
                        index: 0,
                        icon: Icons.emoji_events_outlined,
                        activeIcon: Icons.emoji_events,
                        title: 'Concursos',
                      ),
                      const SizedBox(height: 6),
                      _buildNavItem(
                        index: 1,
                        icon: Icons.assignment_outlined,
                        activeIcon: Icons.assignment,
                        title: 'Inscripción de Piezas',
                      ),
                      const SizedBox(height: 6),
                      _buildNavItem(
                        index: 2,
                        icon: Icons.military_tech_outlined,
                        activeIcon: Icons.military_tech,
                        title: 'Bolsa de Premios',
                      ),
                      const SizedBox(height: 6),
                      _buildNavItem(
                        index: 3,
                        icon: Icons.usb_outlined,
                        activeIcon: Icons.usb,
                        title: 'Respaldos y Excel',
                      ),
                      const SizedBox(height: 6),
                      _buildNavItem(
                        index: 4,
                        icon: Icons.menu_book_outlined,
                        activeIcon: Icons.menu_book,
                        title: 'Tutorial y Guía',
                      ),
                    ],
                  ),
                ),

                // BADGE OFFLINE Y PIE DE SIDEBAR
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => showDialog(
                          context: context,
                          builder: (ctx) => const NetworkConfigDialog(),
                        ),
                        borderRadius: BorderRadius.circular(20),
                        child: FittedBox(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: netConfig.isServer
                                  ? Colors.black.withValues(alpha: 0.3)
                                  : Colors.blue.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: netConfig.isServer
                                    ? AppTheme.ocreAccent
                                    : Colors.lightBlueAccent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  netConfig.isServer
                                      ? Icons.dns
                                      : Icons.laptop_chromebook,
                                  size: 14,
                                  color: netConfig.isServer
                                      ? AppTheme.ocreAccent
                                      : Colors.lightBlueAccent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  netConfig.isServer
                                      ? 'Servidor Principal (BD)'
                                      : 'Terminal Conectada',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'v${UpdateService.currentVersion}\nAngel developpeur',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () => showDialog(
                          context: context,
                          builder: (ctx) => const UpdateDialog(),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.ocreAccent.withValues(
                                  alpha: 0.5,
                                ),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.system_update_alt,
                                  size: 13,
                                  color: AppTheme.ocreAccent,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Buscar actualizaciones',
                                  style: TextStyle(
                                    color: AppTheme.ocreAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ==========================================
          // CONTENIDO PRINCIPAL Y BARRA SUPERIOR
          // ==========================================
          Expanded(
            child: Column(
              children: [
                // TOP BAR: CONCURSO ACTIVO Y RED MULTIEQUIPO
                Container(
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, topBarConstraints) {
                      final zoomScale = ref.watch(uiZoomProvider);
                      final effectiveWidth =
                          topBarConstraints.maxWidth / zoomScale;
                      final isCompact = effectiveWidth < 980;
                      final isUltraCompact = effectiveWidth < 680;

                      return Row(
                        children: [
                          Expanded(
                            child: selectedConcursoAsync.when(
                              loading: () => const Text(
                                'Cargando concurso seleccionado...',
                              ),
                              error: (_, _) => const SizedBox.shrink(),
                              data: (concurso) {
                                if (concurso == null) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.orange.shade200,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            color: Colors.orange,
                                            size: 16,
                                          ),
                                          SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              'Ningún concurso activo.',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.ocreAccentLight,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppTheme.ocreAccentBorder,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.emoji_events,
                                          color: AppTheme.ocreAccent,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            isUltraCompact
                                                ? concurso.nombre
                                                : (!isCompact &&
                                                          concurso.lugar !=
                                                              null &&
                                                          concurso
                                                              .lugar!
                                                              .isNotEmpty
                                                      ? 'Concurso Activo: ${concurso.nombre} (${concurso.ejercicio}) • ${concurso.lugar}'
                                                      : 'Concurso Activo: ${concurso.nombre} (${concurso.ejercicio})'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppTheme.ocreText,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                        if (!isUltraCompact) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: concurso.finalizado
                                                  ? Colors.blueGrey.shade100
                                                  : AppTheme.verdeLight,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: concurso.finalizado
                                                    ? Colors.blueGrey.shade300
                                                    : AppTheme.verdeBorder,
                                              ),
                                            ),
                                            child: Text(
                                              concurso.finalizado
                                                  ? 'FINALIZADO'
                                                  : 'EN PROCESO',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: concurso.finalizado
                                                    ? Colors.blueGrey.shade800
                                                    : AppTheme.verdeSuccess,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),

                          // ACCIONES SUPERIORES EN FILA COMPACTA
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // CONTROL DE ZOOM DE TEXTO (ACCESIBILIDAD VISUAL)
                              _buildZoomControl(isUltraCompact),
                              const SizedBox(width: 8),

                              // BOTÓN ESTADO DE RED MULTIEQUIPO (INDICADOR DE IP)
                              if (isUltraCompact)
                                IconButton(
                                  icon: Icon(
                                    netConfig.isServer ? Icons.hub : Icons.link,
                                    size: 20,
                                    color: AppTheme.azulAccent,
                                  ),
                                  tooltip: netConfig.isServer
                                      ? 'Servidor Local (IP: ${netConfig.localIps.isNotEmpty ? netConfig.localIps.first : '0.0.0.0'})'
                                      : 'Terminal -> ${netConfig.serverHost}',
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) =>
                                          const NetworkConfigDialog(),
                                    );
                                  },
                                )
                              else
                                OutlinedButton.icon(
                                  icon: Icon(
                                    netConfig.isServer ? Icons.hub : Icons.link,
                                    size: 16,
                                    color: AppTheme.azulAccent,
                                  ),
                                  label: Text(
                                    isCompact
                                        ? (netConfig.isServer
                                              ? 'IP: ${netConfig.localIps.isNotEmpty ? netConfig.localIps.first : '0.0.0.0'}'
                                              : 'Terminal')
                                        : (netConfig.isServer
                                              ? 'Servidor Local (IP: ${netConfig.localIps.isNotEmpty ? netConfig.localIps.first : '0.0.0.0'})'
                                              : 'Terminal -> ${netConfig.serverHost}'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.azulAccent,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    side: const BorderSide(
                                      color: AppTheme.azulBorder,
                                    ),
                                    backgroundColor: AppTheme.azulLight,
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) =>
                                          const NetworkConfigDialog(),
                                    );
                                  },
                                ),

                              const SizedBox(width: 8),

                              // BOTÓN ACCESO DIRECTO A LOGS / BITÁCORA
                              if (isCompact)
                                IconButton(
                                  icon: const Icon(
                                    Icons.receipt_long,
                                    size: 18,
                                    color: Colors.blueGrey,
                                  ),
                                  tooltip: 'Logs / Bitácora',
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => const LogViewerDialog(),
                                    );
                                  },
                                )
                              else
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.receipt_long,
                                    size: 16,
                                    color: Colors.blueGrey,
                                  ),
                                  label: const Text(
                                    'Logs',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    side: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => const LogViewerDialog(),
                                    );
                                  },
                                ),

                              if (_currentIndex != 0) ...[
                                const SizedBox(width: 8),
                                if (isCompact)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.swap_horiz,
                                      size: 20,
                                    ),
                                    tooltip: 'Cambiar Concurso',
                                    onPressed: () {
                                      setState(() => _currentIndex = 0);
                                    },
                                  )
                                else
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.swap_horiz,
                                      size: 18,
                                    ),
                                    label: const Text('Cambiar Concurso'),
                                    onPressed: () {
                                      setState(() => _currentIndex = 0);
                                    },
                                  ),
                              ],
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // VISTAS MODULARES
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      ConcursosListView(
                        onSelectConcurso: (idConcurso) {
                          ref.read(selectedConcursoIdProvider.notifier).state =
                              idConcurso;
                          setState(
                            () => _currentIndex = 1,
                          ); // Redirigir a Inscripción
                        },
                      ),
                      const InscripcionView(),
                      const PremiosView(),
                      const BackupView(),
                      TutorialView(
                        onNavigate: (tabIndex) =>
                            setState(() => _currentIndex = tabIndex),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControl(bool isUltraCompact) {
    final zoomScale = ref.watch(uiZoomProvider);
    final zoomNotifier = ref.read(uiZoomProvider.notifier);
    final pct = (zoomScale * 100).round();
    final isZoomed = pct != 100;

    if (isUltraCompact) {
      return PopupMenuButton<double>(
        tooltip: 'Tamaño de letra ($pct%)',
        icon: Icon(
          Icons.text_fields,
          size: 20,
          color: isZoomed ? AppTheme.casart800 : Colors.blueGrey,
        ),
        onSelected: zoomNotifier.setZoom,
        itemBuilder: (ctx) => UiZoomNotifier.zoomSteps.map((step) {
          final selected = (step - zoomScale).abs() < 0.01;
          return PopupMenuItem<double>(
            value: step,
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 18,
                  color: selected ? AppTheme.casart800 : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  UiZoomNotifier.labelFor(step),
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? AppTheme.casart800 : Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      decoration: BoxDecoration(
        color: isZoomed ? AppTheme.casart50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isZoomed ? AppTheme.casart300 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Reducir tamaño de letra (Ctrl + -)',
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(7),
              ),
              onTap: zoomNotifier.canZoomOut ? zoomNotifier.zoomOut : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'A-',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: zoomNotifier.canZoomOut
                        ? AppTheme.casart800
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 18,
            color: isZoomed ? AppTheme.casart200 : Colors.grey.shade300,
          ),
          PopupMenuButton<double>(
            tooltip: 'Seleccionar tamaño de letra (Ctrl + 0 para restablecer)',
            onSelected: zoomNotifier.setZoom,
            itemBuilder: (ctx) => UiZoomNotifier.zoomSteps.map((step) {
              final selected = (step - zoomScale).abs() < 0.01;
              return PopupMenuItem<double>(
                value: step,
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 18,
                      color: selected ? AppTheme.casart800 : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      UiZoomNotifier.labelFor(step),
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                        color: selected ? AppTheme.casart800 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.text_fields,
                    size: 14,
                    color: isZoomed
                        ? AppTheme.casart800
                        : Colors.blueGrey.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isZoomed
                          ? AppTheme.casart800
                          : Colors.blueGrey.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 18,
            color: isZoomed ? AppTheme.casart200 : Colors.grey.shade300,
          ),
          Tooltip(
            message: 'Aumentar tamaño de letra (Ctrl + +)',
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(7),
              ),
              onTap: zoomNotifier.canZoomIn ? zoomNotifier.zoomIn : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'A+',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: zoomNotifier.canZoomIn
                        ? AppTheme.casart800
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String title,
  }) {
    final isSelected = _currentIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.casart950 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? Colors.white : Colors.white70,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
