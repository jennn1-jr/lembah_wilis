import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

abstract final class CurrencyFormatter {
  static final NumberFormat _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  static final NumberFormat _input = NumberFormat.decimalPattern('id_ID');

  static String formatRupiah(num amount) => _rupiah.format(amount);

  static String formatInput(num amount) => _input.format(amount);

  static int? parseInput(String value) {
    final normalized = value
        .replaceAll('Rp', '')
        .replaceAll('.', '')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
    return int.tryParse(normalized);
  }
}

class RupiahInputFormatter extends TextInputFormatter {
  RupiahInputFormatter() : _numberFormat = NumberFormat.decimalPattern('id_ID');

  final NumberFormat _numberFormat;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();

    final parsed = int.tryParse(digits);
    if (parsed == null) return oldValue;

    final formatted = _numberFormat.format(parsed);
    final cursorOffset = newValue.selection.extentOffset
        .clamp(0, newValue.text.length)
        .toInt();
    final digitsBeforeCursor = newValue.text
        .substring(0, cursorOffset)
        .replaceAll(RegExp(r'[^0-9]'), '');
    final cursorValue = digitsBeforeCursor.isEmpty
        ? 0
        : _numberFormat.format(int.parse(digitsBeforeCursor)).length;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: cursorValue.clamp(0, formatted.length).toInt(),
      ),
      composing: TextRange.empty,
    );
  }
}
