import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum ReportExportFormat { csv, excel, pdf }

class ReportExportRow {
  const ReportExportRow({
    required this.operationalDate,
    required this.loketName,
    required this.cashierName,
    required this.totalVisitors,
    required this.paidTickets,
    required this.freeTickets,
    required this.cashRevenue,
    required this.qrisRevenue,
    required this.totalRevenue,
  });

  final String operationalDate;
  final String loketName;
  final String cashierName;
  final int totalVisitors;
  final int paidTickets;
  final int freeTickets;
  final int cashRevenue;
  final int qrisRevenue;
  final int totalRevenue;
}

class ReportExportService {
  static const _headers = [
    'Tanggal Operasional',
    'Petugas Loket',
    'Petugas Kasir',
    'Total Pengunjung',
    'Tiket Berbayar',
    'Tiket Gratis',
    'Pendapatan Tunai (Rp)',
    'QRIS / Transfer (Rp)',
    'Total Pendapatan (Rp)',
  ];

  static Future<void> saveReport({
    required List<ReportExportRow> reports,
    required String periodLabel,
    required ReportExportFormat format,
  }) async {
    late final Uint8List bytes;
    late final String extension;
    late final MimeType mimeType;

    switch (format) {
      case ReportExportFormat.csv:
        bytes = createCsvBytes(reports, periodLabel);
        extension = 'csv';
        mimeType = MimeType.csv;
      case ReportExportFormat.excel:
        bytes = createExcelBytes(reports, periodLabel);
        extension = 'xlsx';
        mimeType = MimeType.microsoftExcel;
      case ReportExportFormat.pdf:
        bytes = await createPdfBytes(reports, periodLabel);
        extension = 'pdf';
        mimeType = MimeType.pdf;
    }

    final result = await FileSaver.instance.saveFile(
      name: _fileName(periodLabel),
      bytes: bytes,
      fileExtension: extension,
      mimeType: mimeType,
    );

    if (result.startsWith('Something went wrong')) {
      throw StateError(result);
    }
  }

  static Uint8List createCsvBytes(
    List<ReportExportRow> reports,
    String periodLabel,
  ) {
    final rows = <List<dynamic>>[
      ['Laporan Harian Wisata Lembah Wilis'],
      ['Periode', periodLabel],
      [],
      _headers,
      for (final report in reports) _spreadsheetRow(report),
      [],
      _totalRow(reports),
    ];

    final csv = ListToCsvConverter().convert(rows);
    return Uint8List.fromList(utf8.encode('\uFEFF$csv'));
  }

  static Uint8List createExcelBytes(
    List<ReportExportRow> reports,
    String periodLabel,
  ) {
    final workbook = xlsx.Excel.createExcel();
    workbook.rename('Sheet1', 'Laporan');
    final sheet = workbook['Laporan'];

    sheet.appendRow([xlsx.TextCellValue('Laporan Harian Wisata Lembah Wilis')]);
    sheet.appendRow([
      xlsx.TextCellValue('Periode'),
      xlsx.TextCellValue(periodLabel),
    ]);
    sheet.appendRow([null]);
    sheet.appendRow(_headers.map(xlsx.TextCellValue.new).toList());

    for (final report in reports) {
      sheet.appendRow([
        xlsx.TextCellValue(report.operationalDate),
        xlsx.TextCellValue(report.loketName),
        xlsx.TextCellValue(report.cashierName),
        xlsx.IntCellValue(report.totalVisitors),
        xlsx.IntCellValue(report.paidTickets),
        xlsx.IntCellValue(report.freeTickets),
        xlsx.IntCellValue(report.cashRevenue),
        xlsx.IntCellValue(report.qrisRevenue),
        xlsx.IntCellValue(report.totalRevenue),
      ]);
    }

    sheet.appendRow([null]);
    sheet.appendRow(
      _totalRow(reports).map((value) => _cellValue(value)).toList(),
    );

    final headerStyle = xlsx.CellStyle(
      backgroundColorHex: xlsx.ExcelColor.fromHexString('FF1B5E20'),
      fontColorHex: xlsx.ExcelColor.fromHexString('FFFFFFFF'),
      bold: true,
      horizontalAlign: xlsx.HorizontalAlign.Center,
    );

    for (var column = 0; column < _headers.length; column++) {
      sheet
              .cell(
                xlsx.CellIndex.indexByColumnRow(
                  columnIndex: column,
                  rowIndex: 3,
                ),
              )
              .cellStyle =
          headerStyle;
    }

    final bytes = workbook.encode();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Gagal membuat file Excel laporan.');
    }

    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List> createPdfBytes(
    List<ReportExportRow> reports,
    String periodLabel,
  ) async {
    final document = pw.Document();
    final totals = _totals(reports);
    final formatter = NumberFormat.decimalPattern('id_ID');
    final tableRows = reports
        .map(
          (report) => <dynamic>[
            report.operationalDate,
            report.loketName,
            report.cashierName,
            '${report.totalVisitors}',
            '${report.paidTickets}',
            '${report.freeTickets}',
            formatter.format(report.cashRevenue),
            formatter.format(report.qrisRevenue),
            formatter.format(report.totalRevenue),
          ],
        )
        .toList();

    tableRows.add([
      'TOTAL',
      '',
      '',
      '${totals.totalVisitors}',
      '${totals.paidTickets}',
      '${totals.freeTickets}',
      formatter.format(totals.cashRevenue),
      formatter.format(totals.qrisRevenue),
      formatter.format(totals.totalRevenue),
    ]);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'Laporan Harian Wisata Lembah Wilis',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Periode: $periodLabel'),
          pw.SizedBox(height: 6),
          pw.Text(
            'Jumlah laporan: ${reports.length}  |  '
            'Total pengunjung: ${totals.totalVisitors}  |  '
            'Total pendapatan: Rp ${formatter.format(totals.totalRevenue)}',
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            context: context,
            headers: _headers,
            data: tableRows,
            cellStyle: const pw.TextStyle(fontSize: 6.5),
            headerStyle: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 4,
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.3),
              1: pw.FlexColumnWidth(1.4),
              2: pw.FlexColumnWidth(1.4),
              3: pw.FlexColumnWidth(0.8),
              4: pw.FlexColumnWidth(0.8),
              5: pw.FlexColumnWidth(0.8),
              6: pw.FlexColumnWidth(1.1),
              7: pw.FlexColumnWidth(1.1),
              8: pw.FlexColumnWidth(1.1),
            },
          ),
        ],
      ),
    );

    return document.save();
  }

  static List<dynamic> _spreadsheetRow(ReportExportRow report) => [
    _spreadsheetSafeText(report.operationalDate),
    _spreadsheetSafeText(report.loketName),
    _spreadsheetSafeText(report.cashierName),
    report.totalVisitors,
    report.paidTickets,
    report.freeTickets,
    report.cashRevenue,
    report.qrisRevenue,
    report.totalRevenue,
  ];

  static List<dynamic> _totalRow(List<ReportExportRow> reports) {
    final totals = _totals(reports);
    return [
      'TOTAL',
      '',
      '',
      totals.totalVisitors,
      totals.paidTickets,
      totals.freeTickets,
      totals.cashRevenue,
      totals.qrisRevenue,
      totals.totalRevenue,
    ];
  }

  static xlsx.CellValue _cellValue(dynamic value) {
    if (value is int) return xlsx.IntCellValue(value);
    return xlsx.TextCellValue(value?.toString() ?? '');
  }

  static String _spreadsheetSafeText(String value) {
    if (RegExp(r'^[\t\r\n ]*[=+\-@]').hasMatch(value)) {
      return "'$value";
    }
    return value;
  }

  static _ReportTotals _totals(List<ReportExportRow> reports) {
    return reports.fold(
      _ReportTotals.zero,
      (totals, report) => _ReportTotals(
        totalVisitors: totals.totalVisitors + report.totalVisitors,
        paidTickets: totals.paidTickets + report.paidTickets,
        freeTickets: totals.freeTickets + report.freeTickets,
        cashRevenue: totals.cashRevenue + report.cashRevenue,
        qrisRevenue: totals.qrisRevenue + report.qrisRevenue,
        totalRevenue: totals.totalRevenue + report.totalRevenue,
      ),
    );
  }

  static String _fileName(String periodLabel) {
    final period = periodLabel
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return period.isEmpty ? 'laporan' : 'laporan_$period';
  }
}

class _ReportTotals {
  const _ReportTotals({
    required this.totalVisitors,
    required this.paidTickets,
    required this.freeTickets,
    required this.cashRevenue,
    required this.qrisRevenue,
    required this.totalRevenue,
  });

  static const zero = _ReportTotals(
    totalVisitors: 0,
    paidTickets: 0,
    freeTickets: 0,
    cashRevenue: 0,
    qrisRevenue: 0,
    totalRevenue: 0,
  );

  final int totalVisitors;
  final int paidTickets;
  final int freeTickets;
  final int cashRevenue;
  final int qrisRevenue;
  final int totalRevenue;
}
