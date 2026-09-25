import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:casart_concursos_desktop/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('CASART Concursos App smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: CasartConcursosApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify header branding appears (logo image)
    expect(find.byType(Image), findsWidgets);
    expect(find.text('Concursos'), findsOneWidget);

    // Tap on 'Inscripción de Piezas' sidebar item
    await tester.tap(find.text('Inscripción de Piezas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify view navigated successfully without crashing on dropdown assertions
    expect(find.text('Inscripción de Piezas'), findsWidgets);
  });
}
