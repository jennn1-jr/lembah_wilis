import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembah_wilis/core/utils/currency_formatter.dart';

void main() {
  test('formats Rupiah with Indonesian grouping', () {
    expect(CurrencyFormatter.formatRupiah(5000), 'Rp 5.000');
    expect(CurrencyFormatter.formatInput(150000), '150.000');
  });

  test('parses formatted amounts without changing their value', () {
    expect(CurrencyFormatter.parseInput('1.250.000'), 1250000);
    expect(CurrencyFormatter.parseInput('invalid'), isNull);
  });

  test('input formatter groups digits and keeps a parseable value', () {
    final formatter = RupiahInputFormatter();
    final formatted = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(
        text: '5000',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );

    expect(formatted.text, '5.000');
    expect(CurrencyFormatter.parseInput(formatted.text), 5000);
  });
}
