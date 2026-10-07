import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casart_concursos_desktop/core/constants/security_constants.dart';
import 'package:casart_concursos_desktop/core/theme/app_theme.dart';
import 'package:casart_concursos_desktop/views/concursos/dialogo_autorizacion_concurso.dart';

void main() {
  test('SecurityConstants define la clave de concurso correcta', () {
    expect(SecurityConstants.claveConcursoStatus, equals('fZwZg9Rk*'));
  });

  group('DialogoAutorizacionConcurso Widget Tests', () {
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(1280, 800);
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });
    Widget buildTestDialog({
      required String concursoNombre,
      required bool willFinalize,
      void Function(bool?)? onResult,
    }) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final res = await DialogoAutorizacionConcurso.mostrar(
                  context,
                  concursoNombre: concursoNombre,
                  willFinalize: willFinalize,
                );
                onResult?.call(res);
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      );
    }

    testWidgets('Muestra interfaz de Finalizar Concurso correctamente', (tester) async {
      await tester.pumpWidget(
        buildTestDialog(
          concursoNombre: 'Concurso Estatal Michoacán 2026',
          willFinalize: true,
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Finalizar Concurso'), findsOneWidget);
      expect(find.text('Concurso Estatal Michoacán 2026'), findsOneWidget);
      expect(find.text('Marcar Finalizado'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Muestra interfaz de Reabrir Concurso correctamente', (tester) async {
      await tester.pumpWidget(
        buildTestDialog(
          concursoNombre: 'Concurso Estatal Michoacán 2026',
          willFinalize: false,
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Reabrir Concurso'), findsNWidgets(2));
      expect(find.text('Concurso Estatal Michoacán 2026'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('Validación: Campo vacío muestra mensaje de error y no cierra el diálogo', (tester) async {
      bool? resultado;
      await tester.pumpWidget(
        buildTestDialog(
          concursoNombre: 'Concurso Prueba',
          willFinalize: true,
          onResult: (r) => resultado = r,
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // Clic directo en Marcar Finalizado sin ingresar clave
      await tester.tap(find.text('Marcar Finalizado'));
      await tester.pumpAndSettle();

      expect(find.text('Por favor ingresa la clave de autorización.'), findsOneWidget);
      expect(resultado, isNull); // El diálogo sigue abierto
    });

    testWidgets('Validación: Clave errónea muestra mensaje de error y no autoriza la acción', (tester) async {
      bool? resultado;
      await tester.pumpWidget(
        buildTestDialog(
          concursoNombre: 'Concurso Prueba',
          willFinalize: true,
          onResult: (r) => resultado = r,
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'claveIncorrecta123');
      await tester.tap(find.text('Marcar Finalizado'));
      await tester.pumpAndSettle();

      expect(find.text('Clave incorrecta. Verifica la contraseña e intenta nuevamente.'), findsOneWidget);
      expect(resultado, isNull); // El diálogo sigue abierto
    });

    testWidgets('Validación: Clave correcta "fZwZg9Rk*" autoriza la acción y retorna true', (tester) async {
      bool? resultado;
      await tester.pumpWidget(
        buildTestDialog(
          concursoNombre: 'Concurso Prueba',
          willFinalize: true,
          onResult: (r) => resultado = r,
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'fZwZg9Rk*');
      await tester.tap(find.text('Marcar Finalizado'));
      await tester.pumpAndSettle();

      expect(resultado, isTrue);
      expect(find.byType(DialogoAutorizacionConcurso), findsNothing);
    });

    testWidgets('Validación: Presionar Enter con clave correcta autoriza la acción', (tester) async {
      bool? resultado;
      await tester.pumpWidget(
        buildTestDialog(
          concursoNombre: 'Concurso Prueba',
          willFinalize: false,
          onResult: (r) => resultado = r,
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'fZwZg9Rk*');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(resultado, isTrue);
      expect(find.byType(DialogoAutorizacionConcurso), findsNothing);
    });

    testWidgets('Cancelar retorna false y cierra el diálogo sin autorizar', (tester) async {
      bool? resultado;
      await tester.pumpWidget(
        buildTestDialog(
          concursoNombre: 'Concurso Prueba',
          willFinalize: true,
          onResult: (r) => resultado = r,
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(resultado, isFalse);
      expect(find.byType(DialogoAutorizacionConcurso), findsNothing);
    });
  });
}
