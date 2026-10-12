import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casart_concursos_desktop/core/data/municipios_data.dart';
import 'package:casart_concursos_desktop/views/common/searchable_select_form_field.dart';

void main() {
  group('SearchableSelectFormField Tests', () {
    testWidgets('Muestra el valor inicial y permite abrir diálogo de búsqueda', (tester) async {
      String? selectedMunicipio = 'Morelia zona (I)';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SearchableSelectFormField(
                  value: selectedMunicipio,
                  items: MunicipiosData.municipios,
                  labelText: 'Municipio *',
                  hintText: 'Selecciona o busca un municipio',
                  searchTitle: 'Buscar Municipio',
                  onChanged: (val) {
                    setState(() => selectedMunicipio = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Debe mostrar el valor inicial
      expect(find.text('Morelia zona (I)'), findsOneWidget);

      // Al hacer tap, se abre el diálogo de búsqueda
      await tester.tap(find.text('Morelia zona (I)'));
      await tester.pumpAndSettle();

      expect(find.text('Buscar Municipio'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Escribir 'patz' en el buscador
      await tester.enterText(find.byType(TextField), 'patz');
      await tester.pumpAndSettle();

      // Debe aparecer Pátzcuaro
      expect(find.textContaining('Patzcuaro', findRichText: true), findsOneWidget);

      // Seleccionar Pátzcuaro
      await tester.tap(find.textContaining('Patzcuaro', findRichText: true));
      await tester.pumpAndSettle();

      // El diálogo se cierra y el campo se actualiza
      expect(find.byType(SearchableSelectDialog), findsNothing);
      expect(selectedMunicipio, equals('Patzcuaro zona (I)'));
      expect(find.text('Patzcuaro zona (I)'), findsOneWidget);
    });

    testWidgets('Búsqueda por una letra filtra correctamente sin importar mayúsculas ni acentos', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchableSelectFormField(
              value: null,
              items: MunicipiosData.municipios,
              labelText: 'Municipio *',
              searchTitle: 'Buscar Municipio',
            ),
          ),
        ),
      );

      // Al no haber placeholder, tocar el campo por su etiqueta
      await tester.tap(find.byType(SearchableSelectFormField));
      await tester.pumpAndSettle();

      // Escribir la letra 'z'
      await tester.enterText(find.byType(TextField), 'z');
      await tester.pumpAndSettle();

      // Debe encontrar municipios con 'z' como Zacapu o Zamora
      expect(find.textContaining('Zacapu', findRichText: true), findsOneWidget);
      expect(find.textContaining('Zamora', findRichText: true), findsOneWidget);

      // Probar con acentos: 'alvaro' debe encontrar 'Álvaro Obregon'
      await tester.enterText(find.byType(TextField), 'alvaro');
      await tester.pumpAndSettle();
      expect(find.textContaining('Alvaro Obregon', findRichText: true), findsOneWidget);
    });

    testWidgets('Localidad dependiente y opción de localidad personalizada', (tester) async {
      String? localidad;
      final locsMorelia = MunicipiosData.obtenerLocalidades('Morelia zona (I)');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SearchableSelectFormField(
                  value: localidad,
                  items: locsMorelia,
                  labelText: 'Localidad *',
                  hintText: 'Selecciona o busca una localidad',
                  searchTitle: 'Buscar Localidad',
                  allowCustomValue: true,
                  customValueLabel: 'localidad',
                  onChanged: (val) {
                    setState(() => localidad = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Selecciona o busca una localidad'));
      await tester.pumpAndSettle();

      // Buscar una localidad existente: Capula
      await tester.enterText(find.byType(TextField), 'capula');
      await tester.pumpAndSettle();
      expect(find.textContaining('Capula', findRichText: true), findsWidgets);

      // Ahora buscar una localidad inexistente para probar allowCustomValue
      await tester.enterText(find.byType(TextField), 'Rancho Mi Esperanza');
      await tester.pumpAndSettle();

      expect(find.text('Usar "Rancho Mi Esperanza" como localidad'), findsOneWidget);

      await tester.tap(find.text('Usar "Rancho Mi Esperanza" como localidad'));
      await tester.pumpAndSettle();

      expect(localidad, equals('Rancho Mi Esperanza'));
      expect(find.text('Rancho Mi Esperanza'), findsOneWidget);
    });

    testWidgets('Navegación por teclado y selección con tecla Enter', (tester) async {
      String? municipio;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SearchableSelectFormField(
                  value: municipio,
                  items: MunicipiosData.municipios,
                  labelText: 'Municipio *',
                  searchTitle: 'Buscar Municipio',
                  onChanged: (val) {
                    setState(() => municipio = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SearchableSelectFormField));
      await tester.pumpAndSettle();

      // Escribir 'morelia'
      await tester.enterText(find.byType(TextField), 'morelia');
      await tester.pumpAndSettle();

      // Presionar Enter en el TextField
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Debe haber seleccionado Morelia zona (I) y cerrado el diálogo
      expect(find.byType(SearchableSelectDialog), findsNothing);
      expect(municipio, equals('Morelia zona (I)'));
    });

    testWidgets('Validación con FormState y botón de limpiar selección', (tester) async {
      final formKey = GlobalKey<FormState>();
      String? municipio = 'Morelia zona (I)';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return SearchableSelectFormField(
                    value: municipio,
                    items: MunicipiosData.municipios,
                    labelText: 'Municipio *',
                    hintText: 'Selecciona un municipio',
                    searchTitle: 'Buscar Municipio',
                    validator: (v) => v == null || v.isEmpty ? 'Municipio obligatorio' : null,
                    onChanged: (val) {
                      setState(() => municipio = val);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Valida inicialmente con éxito
      expect(formKey.currentState!.validate(), isTrue);

      // Limpiar selección usando el botón 'x' del campo
      await tester.tap(find.byTooltip('Limpiar selección'));
      await tester.pumpAndSettle();

      expect(municipio, isNull);

      // Ahora la validación debe fallar mostrando el error
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Municipio obligatorio'), findsOneWidget);
    });
  });
}
