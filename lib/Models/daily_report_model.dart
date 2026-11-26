import 'package:cloud_firestore/cloud_firestore.dart';

/// Model untuk satu jenis tiket dalam laporan harian.
class TicketSummary {
  final String ticketTypeId;
  final String ticketName;
  final int price;

  /// Disimpan sebagai String agar angka nol di depan tetap terjaga.
  /// Contoh: "0001" sampai "0050".
  final String serialStart;
  final String serialEnd;

  final int serialCount;
  final int freeCount;
  final int paidCount;

  const TicketSummary({
    required this.ticketTypeId,
    required this.ticketName,
    required this.price,
    required this.serialStart,
    required this.serialEnd,
    required this.serialCount,
    required this.freeCount,
    required this.paidCount,
  });

  /// Membuat data tiket berdasarkan input Petugas Loket.
  factory TicketSummary.fromInput({
    required String ticketTypeId,
    required String ticketName,
    required int price,
    required String serialStart,
    required String serialEnd,
    required int freeCount,
  }) {
    final start = int.tryParse(serialStart.trim());
    final end = int.tryParse(serialEnd.trim());

    if (start == null || end == null) {
      throw ArgumentError('Nomor seri harus berupa angka.');
    }

    if (start <= 0 || end < start) {
      throw ArgumentError('Rentang nomor seri tidak valid.');
    }

    final count = end - start + 1;

    if (freeCount < 0 || freeCount > count) {
      throw ArgumentError(
        'Jumlah tiket gratis tidak boleh melebihi jumlah tiket.',
      );
    }

    return TicketSummary(
      ticketTypeId: ticketTypeId,
      ticketName: ticketName,
      price: price,
      serialStart: serialStart.trim(),
      serialEnd: serialEnd.trim(),
      serialCount: count,
      freeCount: freeCount,
      paidCount: count - freeCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ticketTypeId': ticketTypeId,
      'ticketName': ticketName,
      'price': price,
      'serialStart': serialStart,
      'serialEnd': serialEnd,
      'serialCount': serialCount,
      'freeCount': freeCount,
      'paidCount': paidCount,
    };
  }

  factory TicketSummary.fromMap(Map<String, dynamic> map) {
    return TicketSummary(
      ticketTypeId: map['ticketTypeId'] as String? ?? '',
      ticketName: map['ticketName'] as String? ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      serialStart: map['serialStart']?.toString() ?? '',
      serialEnd: map['serialEnd']?.toString() ?? '',
      serialCount: (map['serialCount'] as num?)?.toInt() ?? 0,
      freeCount: (map['freeCount'] as num?)?.toInt() ?? 0,
      paidCount: (map['paidCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Data rekap yang dikirim Loket atau hasil verifikasi Kasir.
class ReportData {
  final Map<String, TicketSummary> ticketSummary;
  final int totalVisitors;
  final int cashRevenue;
  final int qrisRevenue;
  final int totalRevenue;

  const ReportData({
    required this.ticketSummary,
    required this.totalVisitors,
    required this.cashRevenue,
    required this.qrisRevenue,
    required this.totalRevenue,
  });

  factory ReportData.fromTickets({
    required Map<String, TicketSummary> ticketSummary,
    required int cashRevenue,
    required int qrisRevenue,
  }) {
    final visitors = ticketSummary.values.fold<int>(
      0,
      (total, ticket) => total + ticket.serialCount,
    );

    return ReportData(
      ticketSummary: ticketSummary,
      totalVisitors: visitors,
      cashRevenue: cashRevenue,
      qrisRevenue: qrisRevenue,
      totalRevenue: cashRevenue + qrisRevenue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ticketSummary': ticketSummary.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'totalVisitors': totalVisitors,
      'cashRevenue': cashRevenue,
      'qrisRevenue': qrisRevenue,
      'totalRevenue': totalRevenue,
    };
  }

  factory ReportData.fromMap(Map<String, dynamic> map) {
    final rawSummary = map['ticketSummary'] as Map? ?? {};

    final summary = rawSummary.map(
      (key, value) => MapEntry(
        key.toString(),
        TicketSummary.fromMap(Map<String, dynamic>.from(value as Map)),
      ),
    );

    return ReportData(
      ticketSummary: Map<String, TicketSummary>.from(summary),
      totalVisitors: (map['totalVisitors'] as num?)?.toInt() ?? 0,
      cashRevenue: (map['cashRevenue'] as num?)?.toInt() ?? 0,
      qrisRevenue: (map['qrisRevenue'] as num?)?.toInt() ?? 0,
      totalRevenue: (map['totalRevenue'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Model utama laporan penutupan harian.
class DailyReport {
  final String operationalDate;
  final String status;

  final String createdBy;
  final String loketName;

  /// Data asli yang dikirim oleh Petugas Loket.
  final ReportData submittedData;

  /// Data setelah pemeriksaan dan koreksi oleh Kasir.
  /// Bernilai null sebelum proses verifikasi selesai.
  final ReportData? verifiedData;

  final String? cashierId;
  final String? cashierName;

  final DateTime? submittedAt;
  final DateTime? verifiedAt;

  const DailyReport({
    required this.operationalDate,
    required this.status,
    required this.createdBy,
    required this.loketName,
    required this.submittedData,
    this.verifiedData,
    this.cashierId,
    this.cashierName,
    this.submittedAt,
    this.verifiedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'operationalDate': operationalDate,
      'status': status,
      'createdBy': createdBy,
      'loketName': loketName,
      'submittedData': submittedData.toMap(),
      'verifiedData': verifiedData?.toMap(),
      'cashierId': cashierId,
      'cashierName': cashierName,
      'submittedAt': submittedAt == null
          ? null
          : Timestamp.fromDate(submittedAt!),
      'verifiedAt': verifiedAt == null ? null : Timestamp.fromDate(verifiedAt!),
    };
  }

  factory DailyReport.fromFirestore(Map<String, dynamic> map) {
    final submittedMap = Map<String, dynamic>.from(map['submittedData'] as Map);

    final verifiedRaw = map['verifiedData'];

    DateTime? readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return DailyReport(
      operationalDate: map['operationalDate'] as String? ?? '',
      status: map['status'] as String? ?? 'draft',
      createdBy: map['createdBy'] as String? ?? '',
      loketName: map['loketName'] as String? ?? '',
      submittedData: ReportData.fromMap(submittedMap),
      verifiedData: verifiedRaw is Map
          ? ReportData.fromMap(Map<String, dynamic>.from(verifiedRaw))
          : null,
      cashierId: map['cashierId'] as String?,
      cashierName: map['cashierName'] as String?,
      submittedAt: readDate(map['submittedAt']),
      verifiedAt: readDate(map['verifiedAt']),
    );
  }
}
