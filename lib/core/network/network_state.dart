import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkMode {
  localServer, // Servidor Local: SQLite local + Servidor HTTP embebido activo
  terminalClient, // Terminal Cliente: Se conecta a la PC Servidor vía HTTP local
}

class NetworkConfig {
  final NetworkMode mode;
  final int port;
  final String serverHost;
  final bool isServerRunning;
  final bool isConnectedToHost;
  final List<String> localIps;
  final String? statusMessage;

  const NetworkConfig({
    this.mode = NetworkMode.localServer,
    this.port = 8080,
    this.serverHost = '192.168.1.50',
    this.isServerRunning = false,
    this.isConnectedToHost = false,
    this.localIps = const [],
    this.statusMessage,
  });

  bool get isServer => mode == NetworkMode.localServer;
  bool get isClient => mode == NetworkMode.terminalClient;

  String get clientBaseUrl => 'http://$serverHost:$port/api';

  NetworkConfig copyWith({
    NetworkMode? mode,
    int? port,
    String? serverHost,
    bool? isServerRunning,
    bool? isConnectedToHost,
    List<String>? localIps,
    String? statusMessage,
    bool clearStatusMessage = false,
  }) {
    return NetworkConfig(
      mode: mode ?? this.mode,
      port: port ?? this.port,
      serverHost: serverHost ?? this.serverHost,
      isServerRunning: isServerRunning ?? this.isServerRunning,
      isConnectedToHost: isConnectedToHost ?? this.isConnectedToHost,
      localIps: localIps ?? this.localIps,
      statusMessage: clearStatusMessage ? null : (statusMessage ?? this.statusMessage),
    );
  }
}

class NetworkConfigNotifier extends Notifier<NetworkConfig> {
  @override
  NetworkConfig build() {
    _fetchLocalIps();
    return const NetworkConfig();
  }

  Future<void> _fetchLocalIps() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      final ips = <String>[];
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.isNotEmpty) {
            ips.add(addr.address);
          }
        }
      }
      state = state.copyWith(localIps: ips);
    } catch (_) {
      // Ignorar si no hay interfaz de red
    }
  }

  void setMode(NetworkMode mode) {
    state = state.copyWith(mode: mode, clearStatusMessage: true);
  }

  void setServerHost(String host) {
    state = state.copyWith(serverHost: host.trim());
  }

  void setPort(int port) {
    state = state.copyWith(port: port);
  }

  void setServerRunning(bool running) {
    state = state.copyWith(isServerRunning: running);
  }

  void setConnectedToHost(bool connected, {String? message}) {
    state = state.copyWith(
      isConnectedToHost: connected,
      statusMessage: message,
    );
  }

  Future<void> refreshLocalIps() async {
    await _fetchLocalIps();
  }
}

final networkConfigProvider =
    NotifierProvider<NetworkConfigNotifier, NetworkConfig>(NetworkConfigNotifier.new);
