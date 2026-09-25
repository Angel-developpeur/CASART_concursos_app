import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/database/app_database.dart';
import 'core/logging/app_logger.dart';
import 'core/theme/app_theme.dart';
import 'views/shell/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Sistema de Bitácora y Logs (Soporta modo Portable y Estándar)
  await AppLogger.init();

  // Capturar errores no controlados del framework de Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.error(
      'Error en interfaz de usuario Flutter: ${details.exceptionAsString()}',
      category: 'FLUTTER_UI',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // Capturar errores asíncronos globales no controlados (Futures/Streams/Isolates)
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.error(
      'Error asíncrono global no controlado: $error',
      category: 'ERROR_ASINCRONO',
      error: error,
      stackTrace: stack,
    );
    return true; // Evitar cierre inesperado si es recuperable
  };

  // Inicializar SQLite FFI para Windows Desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Precalentar e inicializar base de datos y catálogos
  final dbHelper = AppDatabase();
  await dbHelper.database;

  runApp(const ProviderScope(child: CasartConcursosApp()));
}

class CasartConcursosApp extends StatelessWidget {
  const CasartConcursosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CASART - Concursos (Offline)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'MX'),
        Locale('es', ''),
        Locale('en', ''),
      ],
      locale: const Locale('es', 'MX'),
      home: const AppShell(),
    );
  }
}
