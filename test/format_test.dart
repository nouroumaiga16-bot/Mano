import 'package:flutter_test/flutter_test.dart';
import 'package:mano/utils/format.dart';

void main() {
  test('formatFcfa groupe les milliers', () {
    expect(formatFcfa(0), '0 FCFA');
    expect(formatFcfa(12500), '12 500 FCFA');
    expect(formatFcfa(1250000), '1 250 000 FCFA');
    expect(formatNumber(-3500), '-3 500');
  });

  test('parseNumber ignore les espaces', () {
    expect(parseNumber('12 500'), 12500);
    expect(parseNumber('1 250 000'), 1250000);
    expect(parseNumber(''), isNull);
  });

  test('ThousandsInputFormatter formate pendant la saisie', () {
    final result = ThousandsInputFormatter().formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '125000'),
    );
    expect(result.text, '125 000');
  });

  test('formatPhone affiche les numéros par paires', () {
    expect(formatPhone('60401903'), '60 40 19 03');
    expect(formatPhone('60 40 19 03'), '60 40 19 03');
    expect(formatPhone('+226 60401903'), '+226 60 40 19 03');
    expect(formatPhone('0022676363832'), '+226 76 36 38 32');
    expect(formatPhone('123'), '123');
  });
}
