import 'package:cloud_firestore/cloud_firestore.dart';
import '../Models/daily_report_model.dart';

class DailyReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('daily_reports');

  /// Memastikan format tanggal adalah YYYY-MM-DD.
  void _validateDate(String date) {
    final pattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

    if (!pattern.hasMatch(date)) {
      throw ArgumentError('Format tanggal harus YYYY-MM-DD.');
    }

    final parsed = DateTime.tryParse(date);

    if (parsed == null ||
        '${parsed.year.toString().padLeft(4, '0')}-'
                '${parsed.month.toString().padLeft(2, '0')}-'
                '${parsed.day.toString().padLeft(2, '0')}' !=
            date) {
      throw ArgumentError('Tanggal operasional tidak valid.');
    }
  }

  /// Membuat satu draft laporan untuk satu tanggal.
  ///
  /// Jika laporan pada tanggal tersebut sudah ada,
  /// sistem tidak membuat laporan kedua.
  Future<void> createDraft({
    required String operationalDate,
    required String loketId,
    required String loketName,
  }) async {
    _validateDate(operationalDate);

    if (loketId.trim().isEmpty || loketName.trim().isEmpty) {
      throw ArgumentError('Identitas Petugas Loket tidak boleh kosong.');
    }

    final reportRef = _reports.doc(operationalDate);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reportRef);

      if (snapshot.exists) {
        throw StateError(
          'Laporan tanggal $operationalDate sudah pernah dibuat.',
        );
      }

      transaction.set(reportRef, {
        'operationalDate': operationalDate,
        'status': 'draft',
        'createdBy': loketId,
        'loketName': loketName,
        'submittedData': {
          'ticketSummary': <String, dynamic>{},
          'totalVisitors': 0,
          'cashRevenue': 0,
          'qrisRevenue': 0,
          'totalRevenue': 0,
        },
        'verifiedData': null,
        'cashierId': null,
        'cashierName': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'submittedAt': null,
        'verifiedAt': null,
      });
    });
  }

  /// Menyimpan perubahan draft dari Petugas Loket.
  /// Draft hanya boleh diubah oleh pembuatnya.
  Future<void> saveDraft({
    required String operationalDate,
    required String loketId,
    required ReportData reportData,
  }) async {
    _validateDate(operationalDate);

    final reportRef = _reports.doc(operationalDate);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reportRef);

      if (!snapshot.exists) {
        throw StateError('Laporan belum dibuat.');
      }

      final data = snapshot.data()!;

      if (data['status'] != 'draft') {
        throw StateError(
          'Laporan sudah dikirim dan tidak dapat diubah oleh Loket.',
        );
      }

      if (data['createdBy'] != loketId) {
        throw StateError(
          'Kamu tidak memiliki akses untuk mengubah laporan ini.',
        );
      }

      transaction.update(reportRef, {
        'submittedData': reportData.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Mengirim laporan dari Loket kepada Kasir.
  Future<void> submitReport({
    required String operationalDate,
    required String loketId,
    required ReportData reportData,
  }) async {
    _validateDate(operationalDate);

    final reportRef = _reports.doc(operationalDate);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reportRef);

      if (!snapshot.exists) {
        throw StateError('Laporan belum dibuat.');
      }

      final data = snapshot.data()!;

      if (data['status'] != 'draft') {
        throw StateError('Laporan sudah pernah dikirim.');
      }

      if (data['createdBy'] != loketId) {
        throw StateError(
          'Kamu tidak memiliki akses untuk mengirim laporan ini.',
        );
      }

      _validateReportData(reportData);

      transaction.update(reportRef, {
        'submittedData': reportData.toMap(),
        'status': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Validasi dasar sebelum laporan dikirim atau diverifikasi.
  void _validateReportData(ReportData data) {
    if (data.ticketSummary.isEmpty) {
      throw ArgumentError('Rincian tiket belum diisi.');
    }

    if (data.cashRevenue < 0 || data.qrisRevenue < 0) {
      throw ArgumentError('Pemasukan tidak boleh negatif.');
    }

    for (final ticket in data.ticketSummary.values) {
      if (ticket.serialCount <= 0 ||
          ticket.freeCount < 0 ||
          ticket.paidCount < 0 ||
          ticket.freeCount + ticket.paidCount != ticket.serialCount ||
          ticket.price <= 0) {
        throw ArgumentError('Rincian tiket tidak valid.');
      }
    }

    final expectedVisitors = data.ticketSummary.values.fold<int>(
      0,
      (total, ticket) => total + ticket.serialCount,
    );

    if (data.totalVisitors != expectedVisitors) {
      throw ArgumentError('Jumlah pengunjung tidak sesuai rincian tiket.');
    }

    if (data.totalRevenue != data.cashRevenue + data.qrisRevenue) {
      throw ArgumentError('Total pemasukan tidak sesuai.');
    }
  }

  /// Mengambil satu laporan berdasarkan tanggal.
  Future<DailyReport?> getReport(String operationalDate) async {
    _validateDate(operationalDate);

    final snapshot = await _reports.doc(operationalDate).get();

    if (!snapshot.exists) return null;

    return DailyReport.fromFirestore(snapshot.data()!);
  }

  /// Memantau seluruh laporan, terbaru lebih dahulu.
  Stream<List<DailyReport>> streamAllReports() {
    return _reports
        .orderBy('operationalDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return DailyReport.fromFirestore(doc.data());
          }).toList();
        });
  }

  /// Memantau laporan berdasarkan status.
  Stream<List<DailyReport>> streamReportsByStatus(String status) {
    return _reports
        .where('status', isEqualTo: status)
        .orderBy('operationalDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return DailyReport.fromFirestore(doc.data());
          }).toList();
        });
  }

  /// Kasir mulai memeriksa laporan.
  Future<void> startReview({
    required String operationalDate,
    required String cashierId,
    required String cashierName,
  }) async {
    _validateDate(operationalDate);

    final reportRef = _reports.doc(operationalDate);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reportRef);

      if (!snapshot.exists) {
        throw StateError('Laporan tidak ditemukan.');
      }

      final data = snapshot.data()!;

      if (data['status'] != 'submitted') {
        throw StateError('Laporan tidak tersedia untuk diperiksa.');
      }

      transaction.update(reportRef, {
        'status': 'under_review',
        'cashierId': cashierId,
        'cashierName': cashierName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Kasir mencatat ketidaksesuaian.
  Future<String> addDiscrepancy({
    required String operationalDate,
    required String cashierId,
    required String type,
    required String description,
    String? ticketTypeId,
    String? serialNumber,
  }) async {
    _validateDate(operationalDate);

    final reportRef = _reports.doc(operationalDate);
    final discrepancyRef = reportRef.collection('discrepancies').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reportRef);

      if (!snapshot.exists) {
        throw StateError('Laporan tidak ditemukan.');
      }

      final data = snapshot.data()!;
      final status = data['status'];

      if (status != 'under_review' && status != 'needs_correction') {
        throw StateError('Laporan tidak sedang dalam proses pemeriksaan.');
      }

      transaction.set(discrepancyRef, {
        'type': type,
        'description': description,
        'ticketTypeId': ticketTypeId,
        'serialNumber': serialNumber,
        'createdBy': cashierId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(reportRef, {
        'status': 'needs_correction',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return discrepancyRef.id;
  }

  /// Kasir menyimpan catatan koreksi tanpa menghapus data asli.
  Future<String> addCorrection({
    required String operationalDate,
    required String cashierId,
    required String fieldName,
    required dynamic oldValue,
    required dynamic newValue,
    required String reason,
    String? discrepancyId,
  }) async {
    _validateDate(operationalDate);

    if (reason.trim().isEmpty) {
      throw ArgumentError('Alasan koreksi wajib diisi.');
    }

    final reportRef = _reports.doc(operationalDate);
    final correctionRef = reportRef.collection('corrections').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reportRef);

      if (!snapshot.exists) {
        throw StateError('Laporan tidak ditemukan.');
      }

      final status = snapshot.data()!['status'];

      if (status != 'under_review' && status != 'needs_correction') {
        throw StateError('Laporan tidak dapat dikoreksi pada tahap ini.');
      }

      transaction.set(correctionRef, {
        'fieldName': fieldName,
        'oldValue': oldValue,
        'newValue': newValue,
        'reason': reason.trim(),
        'discrepancyId': discrepancyId,
        'correctedBy': cashierId,
        'correctedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(reportRef, {
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return correctionRef.id;
  }

  /// Kasir menyimpan data final setelah pemeriksaan selesai.
  Future<void> verifyReport({
    required String operationalDate,
    required String cashierId,
    required String cashierName,
    required ReportData verifiedData,
  }) async {
    _validateDate(operationalDate);
    _validateReportData(verifiedData);

    final reportRef = _reports.doc(operationalDate);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reportRef);

      if (!snapshot.exists) {
        throw StateError('Laporan tidak ditemukan.');
      }

      final data = snapshot.data()!;
      final status = data['status'];

      if (status != 'under_review' && status != 'needs_correction') {
        throw StateError('Laporan belum siap diverifikasi.');
      }

      if (data['cashierId'] != cashierId) {
        throw StateError(
          'Hanya Kasir yang menangani laporan ini yang dapat memverifikasi.',
        );
      }

      transaction.update(reportRef, {
        'verifiedData': verifiedData.toMap(),
        'status': 'verified',
        'cashierId': cashierId,
        'cashierName': cashierName,
        'verifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
