import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/network_state.dart';
import '../../core/network/api_client.dart';
import '../../core/logging/app_logger.dart';
import '../../providers/database_provider.dart';
import '../../providers/concursos_provider.dart';
import '../../providers/inscripcion_provider.dart';
import '../../core/theme/app_theme.dart';

class NetworkConfigDialog extends ConsumerStatefulWidget {
  const NetworkConfigDialog({super.key});

  @override
  ConsumerState<NetworkConfigDialog> createState() => _NetworkConfigDialogState();
}

class _NetworkConfigDialogState extends ConsumerState<NetworkConfigDialog> {
  late NetworkMode _selectedMode;
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  bool _isTestingConnection = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    final config = ref.read(networkConfigProvider);
    _selectedMode = config.mode;
    _hostCtrl = TextEditingController(text: config.serverHost);
    _portCtrl = TextEditingController(text: config.port.toString());
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _probarConexion() async {
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 8080;

    if (host.isEmpty) {
      setState(() {
        _testSuccess = false;
        _testResult = 'Ingresa la dirección IP del Servidor.';
      });
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _testResult = null;
      _testSuccess = null;
    });

    try {
      final client = ApiClient(baseUrl: 'http://$host:$port/api');
      final ok = await client.checkHealth();

      setState(() {
        _isTestingConnection = false;
        _testSuccess = ok;
        _testResult = ok
            ? '✓ Conexión exitosa con el Servidor CASART en http://$host:$port'
            : '✗ No hubo respuesta del servidor. Verifica que la PC Servidor tenga la app abierta en Modo Servidor y que ambas PCs estén en el mismo Wi-Fi.';
      });
    } catch (e) {
      setState(() {
        _isTestingConnection = false;
        _testSuccess = false;
        _testResult = '✗ Error de red: $e';
      });
    }
  }

  Future<void> _guardarConfiguracion() async {
    final port = int.tryParse(_portCtrl.text.trim()) ?? 8080;
    final host = _hostCtrl.text.trim();

    final notifier = ref.read(networkConfigProvider.notifier);
    notifier.setPort(port);
    notifier.setServerHost(host);
    notifier.setMode(_selectedMode);

    final server = ref.read(embeddedServerProvider);

    if (_selectedMode == NetworkMode.localServer) {
      try {
        await server.start(port: port);
        notifier.setServerRunning(true);
      } catch (_) {}
    } else {
      await server.stop();
      notifier.setServerRunning(false);
      notifier.setConnectedToHost(_testSuccess == true);
    }

    AppLogger.info(
      'Configuración de red actualizada: ${_selectedMode == NetworkMode.localServer ? "Modo Servidor Principal (Base de datos local)" : "Modo Terminal (Conectando a http://$host:$port)"}',
      category: 'RED',
      data: {'modo': _selectedMode.name, 'host': host, 'port': port},
    );

    // Refrescar lista de concursos
    ref.invalidate(concursosListProvider);
    ref.invalidate(registrosConcursoProvider);
    ref.invalidate(nextFolioProvider);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedMode == NetworkMode.localServer
                ? '✓ Modo Servidor Central activado (Base de datos local).'
                : '✓ Modo Terminal activado. Conectado al Servidor: $host:$port',
          ),
          backgroundColor: AppTheme.casart800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(networkConfigProvider);

    return Dialog(
      backgroundColor: AppTheme.dialogBodyBg,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 650,
        color: AppTheme.dialogBodyBg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ENCABEZADO (Blanco con texto negro)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.dialogHeaderBg,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.hub, color: Colors.black87, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configuración de Red Multiequipo',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Text(
                          'Conecta múltiples computadoras vía Wi-Fi o Hotspot celular',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Permite que 2 o 3 computadoras registren concursantes en simultáneo con folios consecutivos automáticos sin internet.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

            // SELECTOR DE MODO
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedMode = NetworkMode.localServer),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _selectedMode == NetworkMode.localServer
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        border: Border.all(
                          color: _selectedMode == NetworkMode.localServer
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                          width: _selectedMode == NetworkMode.localServer ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.dns,
                            size: 32,
                            color: _selectedMode == NetworkMode.localServer
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'PC Principal / Servidor',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Guarda la BD SQLite y atiende peticiones',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedMode = NetworkMode.terminalClient),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _selectedMode == NetworkMode.terminalClient
                            ? AppTheme.azulLight
                            : Colors.transparent,
                        border: Border.all(
                          color: _selectedMode == NetworkMode.terminalClient
                              ? AppTheme.azulAccent
                              : Colors.grey.shade300,
                          width: _selectedMode == NetworkMode.terminalClient ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.laptop_chromebook,
                            size: 32,
                            color: _selectedMode == NetworkMode.terminalClient ? AppTheme.azulAccent : Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'PC Terminal / Cliente',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Se conecta a la PC Servidor vía Wi-Fi local',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // CONTENIDO SEGÚN EL MODO
            if (_selectedMode == NetworkMode.localServer) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.verdeLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.verdeBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wifi, color: AppTheme.verdeSuccess, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Direcciones IP locales de este equipo:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.verdeSuccess),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (config.localIps.isEmpty)
                      const Text(
                        'No se detectó red Wi-Fi o Ethernet activa. Conéctate a un router o hotspot para compartir.',
                        style: TextStyle(color: Colors.black87, fontSize: 12),
                      )
                    else
                      Column(
                        children: config.localIps.map((ip) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SelectableText(
                                  'http://$ip:${_portCtrl.text.trim()}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace'),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  icon: const Icon(Icons.copy, size: 14),
                                  label: const Text('Copiar IP'),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: ip));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('IP $ip copiada al portapapeles.')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pasa esta dirección IP a tus compañeros en las otras PCs para que la ingresen en su app.',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.ocreAccentLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.ocreAccentBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.security, size: 18, color: AppTheme.ocre10),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Si las terminales no logran conectar, autoriza el puerto 8080 en el Firewall de Windows.',
                              style: TextStyle(fontSize: 11, color: AppTheme.ocre10),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.copy, size: 14),
                            label: const Text('Comando PowerShell', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              const cmd = 'New-NetFirewallRule -DisplayName "CASART Concursos Server" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow';
                              Clipboard.setData(const ClipboardData(text: cmd));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Comando de Firewall copiado. Pégalo en PowerShell como Administrador.')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // MODO TERMINAL: INGRESO DE IP
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                       controller: _hostCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Dirección IP del Servidor Central *',
                        hintText: 'Ej: 192.168.1.50',
                        prefixIcon: Icon(Icons.router),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _portCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Puerto',
                        hintText: '8080',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isTestingConnection ? null : _probarConexion,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      backgroundColor: AppTheme.azulAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: _isTestingConnection
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Probar'),
                  ),
                ],
              ),
              if (_testResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _testSuccess == true ? AppTheme.verdeLight : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _testSuccess == true ? AppTheme.verdeBorder : Colors.red),
                  ),
                  child: Text(
                    _testResult!,
                    style: TextStyle(
                      color: _testSuccess == true ? AppTheme.verdeSuccess : Colors.red.shade900,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 24),

            // BOTONES DE PIE
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: AppTheme.cancelButtonStyle,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Aplicar y Guardar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.verdeSuccess,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _guardarConfiguracion,
                ),
              ],
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
