import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/network_state.dart';
import '../../core/network/embedded_server.dart';
import '../../providers/database_provider.dart';
import '../../providers/concursos_provider.dart';
import '../concursos/concursos_list_view.dart';
import '../inscripcion/inscripcion_view.dart';
import '../premios/premios_view.dart';
import '../backup/backup_view.dart';
import '../backup/log_viewer_dialog.dart';
import '../network/network_config_dialog.dart';
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
                      const Text(
                        'v1.0.0\nAngel developpeur',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 10),
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
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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
                  child: Row(
                    children: [
                      Expanded(
                        child: selectedConcursoAsync.when(
                          loading: () =>
                              const Text('Cargando concurso seleccionado...'),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (concurso) {
                            if (concurso == null) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
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
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Ningún concurso activo. Selecciona uno en "Concursos".',
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
                                  horizontal: 14,
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
                                        'Concurso Activo: ${concurso.nombre} (${concurso.ejercicio})',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppTheme.ocreText,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    if (concurso.lugar != null &&
                                        concurso.lugar!.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '• ${concurso.lugar}',
                                        style: const TextStyle(
                                          color: AppTheme.ocreText,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
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
                                        borderRadius: BorderRadius.circular(4),
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
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),

                      // BOTÓN ESTADO DE RED MULTIEQUIPO (INDICADOR DE IP)
                      OutlinedButton.icon(
                        icon: Icon(
                          netConfig.isServer ? Icons.hub : Icons.link,
                          size: 16,
                          color: AppTheme.azulAccent,
                        ),
                        label: Text(
                          netConfig.isServer
                              ? 'Servidor Local (IP: ${netConfig.localIps.isNotEmpty ? netConfig.localIps.first : '0.0.0.0'})'
                              : 'Terminal -> ${netConfig.serverHost}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.azulAccent,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          side: const BorderSide(color: AppTheme.azulBorder),
                          backgroundColor: AppTheme.azulLight,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => const NetworkConfigDialog(),
                          );
                        },
                      ),

                      const SizedBox(width: 8),

                      // BOTÓN ACCESO DIRECTO A LOGS / BITÁCORA
                      OutlinedButton.icon(
                        icon: const Icon(Icons.receipt_long, size: 16, color: Colors.blueGrey),
                        label: const Text(
                          'Logs',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => const LogViewerDialog(),
                          );
                        },
                      ),

                      const SizedBox(width: 12),

                      if (_currentIndex != 0)
                        TextButton.icon(
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          label: const Text('Cambiar Concurso'),
                          onPressed: () {
                            setState(() => _currentIndex = 0);
                          },
                        ),
                    ],
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
