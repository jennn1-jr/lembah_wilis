import 'dart:convert';

import 'package:excel/excel.dart' as xlsx;
import 'package:flutter_test/flutter_test.dart';
import 'package:lembah_wilis/Services/report_export_service.dart';

void main() {
  const report = ReportExportRow(
    operationalDate: '2026-11-26',
    loketName: '=1+1',
    cashierName: 'Kasir, Satu',
    totalVisitors: 5,
    paidTickets: 3,
    freeTickets: 2,
    cashRevenue: 10000,
    qrisRevenue: 5000,
    totalRevenue: 15000,
  );

  test(
    'CSV export contains report totals and protects spreadsheet formulas',
    () {
      final bytes = ReportExportService.createCsvBytes(const [report], 'Semua');
      final csv = utf8.decode(bytes);

      expect(bytes.take(3).toList(), [0xef, 0xbb, 0xbf]);
      expect(csv, contains("'=1+1"));
      expect(csv, contains('"Kasir, Satu"'));
      expect(csv, contains('TOTAL'));
      expect(csv, contains('15000'));
    },
  );

  test('Excel export creates an XLSX workbook', () {
    final bytes = ReportExportService.createExcelBytes(const [report], 'Semua');

    expect(bytes.take(2).toList(), [0x50, 0x4b]);

    final workbook = xlsx.Excel.decodeBytes(bytes);
    final rows = workbook.tables['Laporan']!.rows;
    expect((rows[4][8]!.value as xlsx.IntCellValue).value, 15000);
    expect((rows[6][8]!.value as xlsx.IntCellValue).value, 15000);
  });

  test('PDF export creates a PDF document', () async {
    final bytes = await ReportExportService.createPdfBytes(const [
      report,
    ], 'Semua');

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
