import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../logging/app_logger.dart';

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String title;
  final String releaseNotes;
  final String? downloadUrl;
  final String? assetName;
  final int? assetSizeBytes;
  final DateTime? publishedAt;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    required this.title,
    required this.releaseNotes,
    this.downloadUrl,
    this.assetName,
    this.assetSizeBytes,
    this.publishedAt,
  });
}

class UpdateService {
  static const String owner = 'Angel-developpeur';
  static const String repo = 'CASART_concursos_app';
  static const String currentVersion = '1.0.3';

  /// Consulta la API pública de GitHub Releases para comprobar si hay una versión superior
  static Future<UpdateInfo> checkForUpdate() async {
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/releases/latest',
    );

    try {
      final response = await http
          .get(
            url,
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'CASART-Concursos-Desktop',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 404) {
        // No hay releases creados aún en el repositorio de GitHub
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          hasUpdate: false,
          title: 'Versión v$currentVersion',
          releaseNotes:
              'Tu aplicación está al día. Aún no hay versiones publicadas en GitHub Releases.',
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          'El servidor de GitHub respondió con código: ${response.statusCode}',
        );
      }

      final data =
          json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String? ?? '').trim();
      final releaseName = (data['name'] as String? ?? tagName).trim();
      final releaseNotes = (data['body'] as String? ?? '').trim();
      final publishedAtStr = data['published_at'] as String?;
      final publishedAt = publishedAtStr != null
          ? DateTime.tryParse(publishedAtStr)
          : null;

      // Buscar el archivo instalador ejecutable (.exe)
      String? downloadUrl;
      String? assetName;
      int? assetSizeBytes;

      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.exe')) {
          downloadUrl = asset['browser_download_url'] as String?;
          assetName = asset['name'] as String?;
          assetSizeBytes = asset['size'] as int?;
          break;
        }
      }

      final latestCleanVersion = _cleanVersion(tagName);
      final hasUpdate = _isVersionGreater(latestCleanVersion, currentVersion);

      return UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestCleanVersion,
        hasUpdate: hasUpdate,
        title: releaseName.isNotEmpty
            ? releaseName
            : 'Versión $latestCleanVersion',
        releaseNotes: releaseNotes.isNotEmpty
            ? releaseNotes
            : 'Sin notas de versión disponibles.',
        downloadUrl: downloadUrl,
        assetName: assetName,
        assetSizeBytes: assetSizeBytes,
        publishedAt: publishedAt,
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error al comprobar actualizaciones en GitHub: $e',
        category: 'UPDATE',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Limpia prefijos como 'v' o 'V' de las versiones
  static String _cleanVersion(String v) {
    var clean = v.trim();
    if (clean.toLowerCase().startsWith('v')) {
      clean = clean.substring(1).trim();
    }
    return clean;
  }

  /// Compara dos strings semver ("1.0.1" > "1.0.0")
  static bool _isVersionGreater(String remote, String local) {
    try {
      final remoteParts = remote
          .split('.')
          .map((s) => int.tryParse(s.replaceAll(RegExp(r'\D'), '')) ?? 0)
          .toList();
      final localParts = local
          .split('.')
          .map((s) => int.tryParse(s.replaceAll(RegExp(r'\D'), '')) ?? 0)
          .toList();

      for (int i = 0; i < 3; i++) {
        final r = i < remoteParts.length ? remoteParts[i] : 0;
        final l = i < localParts.length ? localParts[i] : 0;
        if (r > l) return true;
        if (r < l) return false;
      }
      return false;
    } catch (_) {
      return remote != local;
    }
  }

  /// Descarga el instalador reportando progreso (0.0 a 1.0)
  static Future<String> downloadInstaller({
    required String downloadUrl,
    required String fileName,
    required Function(double progress, int receivedBytes, int totalBytes)
    onProgress,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'CASART-Concursos-Desktop';
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception(
          'Error al descargar instalador: HTTP ${response.statusCode}',
        );
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final tempDir = Directory.systemTemp;
      final targetFile = File(p.join(tempDir.path, fileName));
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      final sink = targetFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(receivedBytes / totalBytes, receivedBytes, totalBytes);
        } else {
          onProgress(0.0, receivedBytes, 0);
        }
      }

      await sink.flush();
      await sink.close();

      AppLogger.info(
        'Instalador descargado exitosamente en: ${targetFile.path}',
        category: 'UPDATE',
      );
      return targetFile.path;
    } finally {
      client.close();
    }
  }

  /// Ejecuta el instalador descargado y cierra la aplicación para permitir el reemplazo
  static Future<void> launchInstallerAndExit(String installerPath) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'El instalador automático solo está disponible en Windows',
      );
    }

    AppLogger.info(
      'Lanzando instalador: $installerPath y cerrando aplicación',
      category: 'UPDATE',
    );

    // Ejecuta el instalador en modo desasociado (detached)
    await Process.start(installerPath, [], mode: ProcessStartMode.detached);

    // Cierra la aplicación actual de inmediato para liberar dlls y ejecutables
    exit(0);
  }
}
