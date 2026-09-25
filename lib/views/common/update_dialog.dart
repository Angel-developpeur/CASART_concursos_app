import 'package:flutter/material.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_theme.dart';

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

enum _UpdateState {
  checking,
  upToDate,
  updateAvailable,
  downloading,
  installing,
  error,
}

class _UpdateDialogState extends State<UpdateDialog> {
  _UpdateState _state = _UpdateState.checking;
  UpdateInfo? _info;
  String _errorMessage = '';
  double _downloadProgress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _state = _UpdateState.checking;
      _errorMessage = '';
    });

    try {
      final info = await UpdateService.checkForUpdate();
      if (!mounted) return;

      setState(() {
        _info = info;
        _state = info.hasUpdate
            ? _UpdateState.updateAvailable
            : _UpdateState.upToDate;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _UpdateState.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _startDownloadAndInstall() async {
    if (_info == null || _info!.downloadUrl == null) return;

    setState(() {
      _state = _UpdateState.downloading;
      _downloadProgress = 0.0;
      _receivedBytes = 0;
      _totalBytes = _info!.assetSizeBytes ?? 0;
    });

    try {
      final fileName = _info!.assetName ?? 'Instalador_Concursos_CASART.exe';
      final installerPath = await UpdateService.downloadInstaller(
        downloadUrl: _info!.downloadUrl!,
        fileName: fileName,
        onProgress: (progress, received, total) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
              _receivedBytes = received;
              _totalBytes = total;
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _state = _UpdateState.installing;
      });

      await Future.delayed(const Duration(milliseconds: 600));
      await UpdateService.launchInstallerAndExit(installerPath);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _UpdateState.error;
        _errorMessage = 'Error en la descarga: $e';
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ENCABEZADO
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.casart800.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.system_update_alt,
                      color: AppTheme.casart800,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Actualizaciones del Sistema',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.casart800,
                          ),
                        ),
                        Text(
                          'Concursos CASART',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_state != _UpdateState.downloading &&
                      _state != _UpdateState.installing)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // CONTENIDO SEGÚN ESTADO
              _buildContent(),

              const SizedBox(height: 24),

              // ACCIONES
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case _UpdateState.checking:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              CircularProgressIndicator(color: AppTheme.casart800),
              SizedBox(height: 16),
              Text(
                'Comprobando nuevas versiones en GitHub...',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ],
          ),
        );

      case _UpdateState.upToDate:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 56,
              ),
              const SizedBox(height: 12),
              const Text(
                '¡El sistema está actualizado!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tienes instalada la versión más reciente: v${_info?.currentVersion ?? UpdateService.currentVersion}',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      case _UpdateState.updateAvailable:
        final info = _info!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.ocreAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.ocreAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.new_releases,
                    color: AppTheme.casart800,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¡Nueva versión disponible: v${info.latestVersion}!',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.casart800,
                          ),
                        ),
                        Text(
                          'Versión instalada: v${info.currentVersion}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Novedades y cambios:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 120,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                child: Text(
                  info.releaseNotes,
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ),
            if (info.downloadUrl == null) ...[
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'No se encontró instalador .exe adjunto en el release de GitHub.',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );

      case _UpdateState.downloading:
        final pct = (_downloadProgress * 100).toInt();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Descargando actualización...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.casart800,
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.casart800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.casart800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'El instalador se ejecutará automáticamente al finalizar la descarga.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        );

      case _UpdateState.installing:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              CircularProgressIndicator(color: AppTheme.casart800),
              SizedBox(height: 16),
              Text(
                'Iniciando el instalador...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.casart800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'La aplicación se cerrará para aplicar los cambios.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        );

      case _UpdateState.error:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'No se pudo verificar actualizaciones',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : 'Revisa tu conexión a internet o intenta más tarde.',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
    }
  }

  Widget _buildActions() {
    switch (_state) {
      case _UpdateState.checking:
        return const SizedBox.shrink();

      case _UpdateState.upToDate:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: _checkForUpdates,
              child: const Text('Volver a comprobar'),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.casart800,
                foregroundColor: Colors.white,
              ),
              child: const Text('Aceptar'),
            ),
          ],
        );

      case _UpdateState.updateAvailable:
        final hasInstaller = _info?.downloadUrl != null;
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Más tarde'),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: hasInstaller ? _startDownloadAndInstall : null,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Descargar e Instalar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.casart800,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );

      case _UpdateState.downloading:
      case _UpdateState.installing:
        return const SizedBox.shrink();

      case _UpdateState.error:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _checkForUpdates,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.casart800,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
    }
  }
}
