/// Utilidad para convertir valores numéricos a su representación en letras en español,
/// con paridad al Helper NumeroALetras de la versión web de CASART.
class NumeroALetras {
  static const List<String> _unidades = [
    '',
    'un',
    'dos',
    'tres',
    'cuatro',
    'cinco',
    'seis',
    'siete',
    'ocho',
    'nueve',
  ];

  static const List<String> _decenas = [
    'diez',
    'once',
    'doce',
    'trece',
    'catorce',
    'quince',
    'dieciséis',
    'diecisiete',
    'dieciocho',
    'diecinueve',
    'veinte',
    'treinta',
    'cuarenta',
    'cincuenta',
    'sesenta',
    'setenta',
    'ochenta',
    'noventa',
  ];

  static const Map<int, String> _decenasCompuestas = {
    2: 'veinti',
    3: 'treinta y ',
    4: 'cuarenta y ',
    5: 'cincuenta y ',
    6: 'sesenta y ',
    7: 'setenta y ',
    8: 'ochenta y ',
    9: 'noventa y ',
  };

  static const List<String> _centenas = [
    '',
    'ciento',
    'doscientos',
    'trescientos',
    'cuatrocientos',
    'quinientos',
    'seiscientos',
    'setecientos',
    'ochocientos',
    'novecientos',
  ];

  /// Convierte un entero a su representación en letras.
  /// Soporta hasta 999,999,999.
  static String convertirEnteroALetras(int numero) {
    if (numero == 0) return 'cero';

    String letras = '';

    // Millones
    if (numero >= 1000000) {
      final int millones = numero ~/ 1000000;
      if (millones == 1) {
        letras += 'un millón ';
      } else {
        letras += '${convertirEnteroALetras(millones)} millones ';
      }
      numero %= 1000000;
    }

    // Miles
    if (numero >= 1000) {
      final int miles = numero ~/ 1000;
      if (miles == 1) {
        letras += 'mil ';
      } else {
        letras += '${convertirEnteroALetras(miles)} mil ';
      }
      numero %= 1000;
    }

    // Cientos
    if (numero >= 100) {
      final int cientos = numero ~/ 100;
      if (cientos == 1 && numero != 100) {
        letras += 'ciento ';
      } else if (cientos == 1 && numero == 100) {
        letras += 'cien ';
      } else {
        letras += '${_centenas[cientos]} ';
      }
      numero %= 100;
    }

    // Decenas y unidades
    if (numero > 0) {
      if (numero < 10) {
        letras += _unidades[numero];
      } else if (numero < 20) {
        letras += _decenas[numero - 10];
      } else {
        final int decena = numero ~/ 10;
        final int unidad = numero % 10;

        if (unidad == 0) {
          // Decena cerrada: 20, 30, 40, etc.
          letras += _decenas[decena + 8];
        } else {
          // Con unidades: 21-29, 31-99
          letras += '${_decenasCompuestas[decena]}${_unidades[unidad]}';
        }
      }
    }

    return letras.trim();
  }

  /// Convierte un monto numérico a formato monetario en letras
  /// Ejemplo: 25000 -> "Veinticinco mil pesos 00/100 M.N."
  static String numeroAMonedaLetras(
    num numero, {
    String moneda = 'pesos',
    String abreviaturaMoneda = 'M.N.',
  }) {
    final fixed = numero.toStringAsFixed(2);
    final parts = fixed.split('.');
    final int enteros = int.tryParse(parts[0]) ?? 0;
    final String decimales = parts.length > 1 ? parts[1].padRight(2, '0') : '00';

    String letrasEnteros = convertirEnteroALetras(enteros);

    if (enteros == 1) {
      letrasEnteros = 'un';
      moneda = 'peso';
    } else if (moneda == 'peso') {
      moneda = 'pesos';
    }

    final resultado = '$letrasEnteros $moneda $decimales/100 $abreviaturaMoneda';
    if (resultado.isEmpty) return '';
    return resultado[0].toUpperCase() + resultado.substring(1);
  }
}
