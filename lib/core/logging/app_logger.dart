import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum LogLevel {
  info('INFO'),
  create('CREATE'),
  update('UPDATE'),
  delete('DELETE'),
  warn('WARN'),
  error('ERROR');

  final String label;
  const LogLevel(this.label);
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String category;
  final String message;
  final Map<String, dynamic>? data;
  final Object? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.data,
    this.error,
    this.stackTrace,
  });

  String formatForFile() {
    final y = timestamp.year.toString().padLeft(4, '0');
    final m = timestamp.month.toString().padLeft(2, '0');
    final d = timestamp.day.toString().padLeft(2, '0');
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    final ss = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    final timeStr = '$y-$m-$d $hh:$mm:$ss.$ms';

    final sb = StringBuffer();
    sb.write('[$timeStr] [${level.label}] [${category.toUpperCase()}] $message');

    if (data != null && data!.isNotEmpty) {
      sb.write(' | Datos: $data');
    }

    if (error != null) {
      sb.write(' | Detalle Error: $error');
    }

    if (stackTrace != null) {
      final cleanStack = stackTrace.toString().split('\n').take(6).join(' -> ');
      sb.write(' | Stack: $cleanStack');
    }

    return sb.toString();
  }
}

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  static String? _logFilePath;
  static bool _isPortableMode = false;
  static bool _initialized = false;
  static IOSink? _sink;
  static final List<LogEntry> _recentEntries = [];
  static final ValueNotifier<int> logChangeNotifier = ValueNotifier<int>(0);

  static const int _maxInMemoryEntries = 250;
  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  static String? get logFilePath => _logFilePath;
  static bool get isPortableMode => _isPortableMode;
  static List<LogEntry> get recentEntries => List.unmodifiable(_recentEntries);

  /// Inicializa la ubicación del archivo de logs detectando si es versión portable o instalada
  static Future<void> init() async {
    if (_initialized) return;

    try {
      _logFilePath = await _resolveLogFilePath();
      final file = File(_logFilePath!);

      // Crear directorio padre si no existe
      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      // Rotación si supera el tamaño límite
      if (await file.exists() && (await file.length()) > _maxFileSizeBytes) {
        await _rotateLogFile(file);
      }

      _sink = file.openWrite(mode: FileMode.append);
      _initialized = true;

      // Registrar inicio de la aplicación
      final os = Platform.operatingSystem;
      final modeStr = _isPortableMode ? 'PORTABLE (en carpeta del ejecutable)' : 'ESTÁNDAR (en Documentos)';
      info(
        '=== APLICACIÓN CASART INICIADA === [Modo: $modeStr] [SO: $os] [Ruta de logs: $_logFilePath]',
        category: 'SISTEMA',
      );
    } catch (e, stack) {
      debugPrint('Error al inicializar AppLogger: $e\n$stack');
    }
  }

  /// Resuelve la ruta ideal para los logs:
  /// - En versión Portable (Windows/Linux/Mac): subcarpeta "logs/" junto al ejecutable
  /// - En caso de permisos restringidos o entorno instalado: subcarpeta "CASART_Concursos/logs" en Documentos
  /// - En pruebas unitarias (FLUTTER_TEST): directorio temporal del sistema
  static Future<String> _resolveLogFilePath() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      final temp = Directory.systemTemp;
      final testDir = Directory(p.join(temp.path, 'casart_test_logs'));
      if (!await testDir.exists()) await testDir.create(recursive: true);
      _isPortableMode = false;
      return p.join(testDir.path, 'casart_actividad_test.log');
    }

    // 1. Probar ruta portable (al lado del ejecutable)
    try {
      final exeFile = File(Platform.resolvedExecutable);
      final exeDir = exeFile.parent;

      // Detectar si estamos en el directorio de la aplicación compilada
      final hasExe = await File(p.join(exeDir.path, 'casart_concursos_desktop.exe')).exists();
      final hasDll = await File(p.join(exeDir.path, 'flutter_windows.dll')).exists();
      final hasData = await Directory(p.join(exeDir.path, 'data')).exists();

      if (hasExe || hasDll || hasData) {
        final portableLogsDir = Directory(p.join(exeDir.path, 'logs'));
        if (!await portableLogsDir.exists()) {
          await portableLogsDir.create(recursive: true);
        }

        // Probar permisos reales de escritura en el directorio del ejecutable
        final testFile = File(p.join(portableLogsDir.path, '.perm_test'));
        await testFile.writeAsString('ok');
        await testFile.delete();

        // Es portable y escribible
        _isPortableMode = true;
        return p.join(portableLogsDir.path, 'casart_actividad.log');
      }
    } catch (_) {
      // Fallback a Documentos si no hay permisos de escritura en la carpeta del ejecutable
    }

    // 2. Ruta estándar de Documentos
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final logsDir = Directory(p.join(docsDir.path, 'CASART_Concursos', 'logs'));
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }
      _isPortableMode = false;
      return p.join(logsDir.path, 'casart_actividad.log');
    } catch (_) {
      // Fallback de emergencia a sistema temporal
      _isPortableMode = false;
      return p.join(Directory.systemTemp.path, 'casart_actividad.log');
    }
  }

  static Future<void> _rotateLogFile(File file) async {
    try {
      final rotatedPath = '${file.path}.old';
      final rotatedFile = File(rotatedPath);
      if (await rotatedFile.exists()) {
        await rotatedFile.delete();
      }
      await file.rename(rotatedPath);
    } catch (e) {
      debugPrint('No se pudo rotar el archivo de log: $e');
    }
  }

  static void log(
    LogLevel level,
    String message, {
    required String category,
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );

    // Guardar en buffer en memoria para la interfaz
    _recentEntries.add(entry);
    if (_recentEntries.length > _maxInMemoryEntries) {
      _recentEntries.removeAt(0);
    }
    logChangeNotifier.value++;

    // Salida a consola en modo desarrollo
    if (kDebugMode) {
      debugPrint('[CASART_LOG] ${entry.formatForFile()}');
    }

    // Escribir en archivo de logs
    _writeToFile(entry.formatForFile());
  }

  static void info(String message, {String category = 'SISTEMA', Map<String, dynamic>? data}) {
    log(LogLevel.info, message, category: category, data: data);
  }

  static void create(String message, {required String category, Map<String, dynamic>? data}) {
    log(LogLevel.create, message, category: category, data: data);
  }

  static void update(String message, {required String category, Map<String, dynamic>? data}) {
    log(LogLevel.update, message, category: category, data: data);
  }

  static void delete(String message, {required String category, Map<String, dynamic>? data}) {
    log(LogLevel.delete, message, category: category, data: data);
  }

  static void warn(String message, {String category = 'ADVERTENCIA', Map<String, dynamic>? data}) {
    log(LogLevel.warn, message, category: category, data: data);
  }

  static void error(
    String message, {
    String category = 'ERROR',
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    log(
      LogLevel.error,
      message,
      category: category,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void _writeToFile(String line) {
    try {
      if (_sink != null) {
        _sink!.writeln(line);
        _sink!.flush();
      } else if (_logFilePath != null) {
        // En caso de que el sink no estuviera abierto
        File(_logFilePath!).writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
      }
    } catch (e) {
      debugPrint('Error escribiendo en log file: $e');
    }
  }

  /// Fuerza el vaciado del buffer de escritura a disco
  static Future<void> flush() async {
    try {
      await _sink?.flush();
    } catch (_) {}
  }

  /// Abre el archivo de log en el editor predeterminado del sistema (Notepad en Windows)
  static Future<bool> openLogFile() async {
    if (_logFilePath == null) return false;
    final file = File(_logFilePath!);
    if (!await file.exists()) {
      await file.writeAsString('=== CASART ARCHIVO DE LOGS ===\n');
    }

    try {
      if (Platform.isWindows) {
        await Process.run('notepad.exe', [file.absolute.path]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [file.absolute.path]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [file.absolute.path]);
        return true;
      }
    } catch (e) {
      debugPrint('Error al abrir archivo de log: $e');
    }
    return false;
  }

  /// Abre la carpeta que contiene el archivo de logs en el explorador de archivos
  static Future<bool> openLogFolder() async {
    if (_logFilePath == null) return false;
    final file = File(_logFilePath!);
    final folder = file.parent;

    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [folder.absolute.path]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [folder.absolute.path]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [folder.absolute.path]);
        return true;
      }
    } catch (e) {
      debugPrint('Error al abrir carpeta de logs: $e');
    }
    return false;
  }

  /// Cierra el sink del archivo al salir de la aplicación
  static Future<void> dispose() async {
    try {
      await _sink?.flush();
      await _sink?.close();
      _sink = null;
    } catch (_) {}
  }
}
