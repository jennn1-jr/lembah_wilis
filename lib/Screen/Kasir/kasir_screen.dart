import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../Models/daily_report_model.dart';
import '../../Services/daily_report_service.dart';

class KasirScreen extends StatefulWidget {
  final String userName;

  const KasirScreen({super.key, required this.userName});

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> {
  final DailyReportService _service = DailyReportService();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  String _selectedFilter = 'Semua';

  String _filterStatus(String value) {
    switch (value) {
      case 'Menunggu':
        return 'submitted';
      case 'Diperiksa':
        return 'under_review';
      case 'Koreksi':
        return 'needs_correction';
      case 'Terverifikasi':
        return 'verified';
      default:
        return 'all';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'submitted':
        return 'Menunggu Pemeriksaan';
      case 'under_review':
        return 'Sedang Diperiksa';
      case 'needs_correction':
        return 'Perlu Koreksi';
      case 'verified':
        return 'Terverifikasi';
      case 'draft':
        return 'Draft';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'submitted':
        return Colors.orange;
      case 'under_review':
        return Colors.blue;
      case 'needs_correction':
        return Colors.red;
      case 'verified':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _openReport(DailyReport report) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      if (report.status == 'submitted') {
        await _service.startReview(
          operationalDate: report.operationalDate,
          cashierId: user.uid,
          cashierName: widget.userName,
        );
      }

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => KasirReportDetailScreen(
            operationalDate: report.operationalDate,
            userName: widget.userName,
          ),
        ),
      );
    } catch (e) {
      _showMessage('Gagal membuka laporan: $e', isError: true);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Petugas Kasir'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilter(),
          Expanded(child: _buildReportList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: const Color(0xFFE8F5E9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selamat datang, ${widget.userName}',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Periksa laporan penutupan harian dari Petugas Loket.',
            style: TextStyle(color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildFilter() {
    const filters = [
      'Semua',
      'Menunggu',
      'Diperiksa',
      'Koreksi',
      'Terverifikasi',
    ];

    return SizedBox(
      height: 65,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        children: filters.map((filter) {
          final selected = _selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              selectedColor: const Color(0xFFC8E6C9),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReportList() {
    return StreamBuilder<List<DailyReport>>(
      stream: _service.streamAllReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Gagal memuat laporan: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final reports = (snapshot.data ?? []).where((report) {
          // Draft tidak ditampilkan kepada Kasir.
          if (report.status == 'draft') return false;

          if (_selectedFilter == 'Semua') return true;

          return report.status == _filterStatus(_selectedFilter);
        }).toList();

        reports.sort((a, b) => b.operationalDate.compareTo(a.operationalDate));

        if (reports.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada laporan.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Laporan dari Petugas Loket akan muncul di sini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              return _buildReportCard(reports[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildReportCard(DailyReport report) {
    final data = report.submittedData;

    final statusColor = _statusColor(report.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openReport(report),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month, color: Color(0xFF1B5E20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      DateFormat(
                        'dd MMMM yyyy',
                        'id_ID',
                      ).format(DateTime.parse(report.operationalDate)),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(report.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(height: 22),

              Text('Petugas Loket: ${report.loketName}'),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Pengunjung'),
                  Text(
                    '${data.totalVisitors} orang',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Pendapatan'),
                  Text(
                    _currencyFormat.format(data.totalRevenue),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openReport(report),
                  icon: const Icon(Icons.fact_check),
                  label: const Text('Periksa Laporan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// HALAMAN DETAIL PEMERIKSAAN LAPORAN
// =====================================================

class KasirReportDetailScreen extends StatefulWidget {
  final String operationalDate;
  final String userName;

  const KasirReportDetailScreen({
    super.key,
    required this.operationalDate,
    required this.userName,
  });

  @override
  State<KasirReportDetailScreen> createState() =>
      _KasirReportDetailScreenState();
}

class _KasirReportDetailScreenState extends State<KasirReportDetailScreen> {
  final DailyReportService _service = DailyReportService();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  final TextEditingController _cashController = TextEditingController();

  final TextEditingController _qrisController = TextEditingController();

  final TextEditingController _discrepancyController = TextEditingController();

  final TextEditingController _correctionReasonController =
      TextEditingController();

  final Map<String, TextEditingController> _startControllers = {};
  final Map<String, TextEditingController> _endControllers = {};
  final Map<String, TextEditingController> _freeControllers = {};

  DailyReport? _report;

  bool _isLoading = true;
  bool _isProcessing = false;
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      final report = await _service.getReport(widget.operationalDate);

      if (!mounted) return;

      setState(() {
        _report = report;
      });

      if (report != null && !_controllersInitialized) {
        _initializeControllers(report);
      }
    } catch (e) {
      _showMessage('Gagal memuat detail laporan: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _initializeControllers(DailyReport report) {
    final data = report.submittedData;

    _cashController.text = data.cashRevenue.toString();
    _qrisController.text = data.qrisRevenue.toString();

    for (final entry in data.ticketSummary.entries) {
      final id = entry.key;
      final ticket = entry.value;

      _startControllers[id] = TextEditingController(text: ticket.serialStart);

      _endControllers[id] = TextEditingController(text: ticket.serialEnd);

      _freeControllers[id] = TextEditingController(
        text: ticket.freeCount.toString(),
      );
    }

    _controllersInitialized = true;
  }

  bool get _isVerified => _report?.status == 'verified';

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  ReportData _buildVerifiedData() {
    final report = _report!;

    final Map<String, TicketSummary> summaries = {};

    for (final entry in report.submittedData.ticketSummary.entries) {
      final id = entry.key;
      final original = entry.value;

      final start = _startControllers[id]!.text.trim();
      final end = _endControllers[id]!.text.trim();

      final free = int.tryParse(_freeControllers[id]!.text.trim());

      if (start.isEmpty || end.isEmpty || free == null) {
        throw Exception('Data tiket ${original.ticketName} belum lengkap.');
      }

      summaries[id] = TicketSummary.fromInput(
        ticketTypeId: id,
        ticketName: original.ticketName,
        price: original.price,
        serialStart: start,
        serialEnd: end,
        freeCount: free,
      );
    }

    final cash = int.tryParse(_cashController.text.trim());
    final qris = int.tryParse(_qrisController.text.trim());

    if (cash == null || qris == null || cash < 0 || qris < 0) {
      throw Exception('Nominal pembayaran tidak valid.');
    }

    return ReportData.fromTickets(
      ticketSummary: summaries,
      cashRevenue: cash,
      qrisRevenue: qris,
    );
  }

  Future<void> _addDiscrepancy() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || _report == null) return;

    final controller = TextEditingController();

    final description = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Catat Ketidaksesuaian'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Deskripsi temuan',
              hintText: 'Contoh: Nomor seri fisik tidak sesuai dengan laporan.',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('Simpan Temuan'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (description == null || description.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      await _service.addDiscrepancy(
        operationalDate: widget.operationalDate,
        cashierId: user.uid,
        type: 'general',
        description: description,
      );

      await _loadReport();

      _showMessage('Ketidaksesuaian berhasil dicatat.');
    } catch (e) {
      _showMessage('Gagal mencatat ketidaksesuaian: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _verifyReport() async {
    final report = _report;
    final user = FirebaseAuth.instance.currentUser;

    if (report == null || user == null) return;

    if (report.status != 'under_review' &&
        report.status != 'needs_correction') {
      _showMessage(
        'Status laporan belum memungkinkan untuk diverifikasi.',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verifikasi Laporan'),
        content: const Text(
          'Pastikan data sudah dicocokkan dengan tiket fisik, '
          'bukti pembayaran, dan hasil pemeriksaan bersama '
          'Petugas Loket. Setelah diverifikasi, laporan akan '
          'diteruskan kepada Pengelola.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Periksa Lagi'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Verifikasi'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final verifiedData = _buildVerifiedData();

      final original = report.submittedData;

      // Mencatat perubahan data tiket ke riwayat koreksi.
      for (final entry in original.ticketSummary.entries) {
        final id = entry.key;
        final oldTicket = entry.value;
        final newTicket = verifiedData.ticketSummary[id]!;

        await _saveCorrectionIfChanged(
          user.uid,
          'ticketSummary.$id.serialStart',
          oldTicket.serialStart,
          newTicket.serialStart,
        );

        await _saveCorrectionIfChanged(
          user.uid,
          'ticketSummary.$id.serialEnd',
          oldTicket.serialEnd,
          newTicket.serialEnd,
        );

        await _saveCorrectionIfChanged(
          user.uid,
          'ticketSummary.$id.freeCount',
          oldTicket.freeCount,
          newTicket.freeCount,
        );
      }

      await _saveCorrectionIfChanged(
        user.uid,
        'cashRevenue',
        original.cashRevenue,
        verifiedData.cashRevenue,
      );

      await _saveCorrectionIfChanged(
        user.uid,
        'qrisRevenue',
        original.qrisRevenue,
        verifiedData.qrisRevenue,
      );

      await _service.verifyReport(
        operationalDate: widget.operationalDate,
        cashierId: user.uid,
        cashierName: widget.userName,
        verifiedData: verifiedData,
      );

      await _loadReport();

      _showMessage(
        'Laporan berhasil diverifikasi dan diteruskan kepada Pengelola.',
      );
    } catch (e) {
      _showMessage('Gagal memverifikasi laporan: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _saveCorrectionIfChanged(
    String cashierId,
    String fieldName,
    dynamic oldValue,
    dynamic newValue,
  ) async {
    if (oldValue == newValue) return;

    await _service.addCorrection(
      operationalDate: widget.operationalDate,
      cashierId: cashierId,
      fieldName: fieldName,
      oldValue: oldValue,
      newValue: newValue,
      reason: 'Hasil pemeriksaan dan pencocokan oleh Petugas Kasir.',
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildReadOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketReview(String id, TicketSummary ticket) {
    final editable = !_isVerified;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ticket.ticketName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            _buildReadOnlyRow(
              'Harga tiket',
              _currencyFormat.format(ticket.price),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startControllers[id],
                    enabled: editable,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nomor awal',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _endControllers[id],
                    enabled: editable,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nomor akhir',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            TextField(
              controller: _freeControllers[id],
              enabled: editable,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Jumlah tiket gratis',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),

            const SizedBox(height: 10),

            _buildReadOnlyRow(
              'Jumlah tiket menurut laporan Loket',
              '${ticket.serialCount}',
            ),

            _buildReadOnlyRow(
              'Tiket berbayar menurut laporan Loket',
              '${ticket.paidCount}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentReview(ReportData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: _cashController,
              enabled: !_isVerified,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total Tunai (Rp)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _qrisController,
              enabled: !_isVerified,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total QRIS/Transfer (Rp)',
                border: OutlineInputBorder(),
              ),
            ),

            const Divider(height: 25),

            _buildReadOnlyRow(
              'Total pembayaran menurut laporan Loket',
              _currencyFormat.format(data.totalRevenue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(String collectionName) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('daily_reports')
          .doc(widget.operationalDate)
          .collection(collectionName)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Gagal memuat riwayat: ${snapshot.error}',
            style: const TextStyle(color: Colors.red),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Text(
            'Belum ada catatan.',
            style: TextStyle(color: Colors.grey),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();

            if (collectionName == 'discrepancies') {
              return Card(
                color: Colors.red.shade50,
                child: ListTile(
                  leading: const Icon(Icons.warning_amber, color: Colors.red),
                  title: Text(data['description'] ?? 'Ketidaksesuaian'),
                  subtitle: Text('Jenis: ${data['type'] ?? '-'}'),
                ),
              );
            }

            return Card(
              child: ListTile(
                leading: const Icon(Icons.edit_note, color: Colors.blue),
                title: Text(data['fieldName'] ?? 'Perubahan data'),
                subtitle: Text(
                  'Sebelum: ${data['oldValue'] ?? '-'}\n'
                  'Sesudah: ${data['newValue'] ?? '-'}\n'
                  'Alasan: ${data['reason'] ?? '-'}',
                ),
                isThreeLine: true,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildReportDetail(DailyReport report) {
    final data = report.submittedData;

    final canVerify =
        report.status == 'under_review' || report.status == 'needs_correction';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Laporan ${DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.parse(report.operationalDate))}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        Text('Petugas Loket: ${report.loketName}'),

        Text(
          'Status: ${report.status}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: report.status == 'verified' ? Colors.green : Colors.orange,
          ),
        ),

        _buildSectionTitle('1. Pemeriksaan Data Tiket'),

        ...data.ticketSummary.entries.map(
          (entry) => _buildTicketReview(entry.key, entry.value),
        ),

        _buildSectionTitle('2. Pemeriksaan Pembayaran'),

        _buildPaymentReview(data),

        _buildSectionTitle('3. Rekap Laporan'),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildReadOnlyRow(
                  'Total pengunjung',
                  '${data.totalVisitors} orang',
                ),
                _buildReadOnlyRow(
                  'Total tiket gratis',
                  '${data.ticketSummary.values.fold<int>(0, (total, ticket) => total + ticket.freeCount)} tiket',
                ),
                _buildReadOnlyRow(
                  'Total tiket berbayar',
                  '${data.ticketSummary.values.fold<int>(0, (total, ticket) => total + ticket.paidCount)} tiket',
                ),
                const Divider(),
                _buildReadOnlyRow(
                  'Total pendapatan',
                  _currencyFormat.format(data.totalRevenue),
                ),
              ],
            ),
          ),
        ),

        _buildSectionTitle('4. Catatan Ketidaksesuaian'),

        _buildHistorySection('discrepancies'),

        if (!_isVerified && canVerify) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isProcessing ? null : _addDiscrepancy,
            icon: const Icon(Icons.add_alert),
            label: const Text('Tambah Ketidaksesuaian'),
          ),
        ],

        _buildSectionTitle('5. Riwayat Koreksi'),

        _buildHistorySection('corrections'),

        const SizedBox(height: 20),

        if (_isVerified)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified, color: Colors.green),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Laporan telah diverifikasi dan diteruskan '
                    'kepada Pengelola.',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (canVerify)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _verifyReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(15),
              ),
              icon: const Icon(Icons.verified),
              label: const Text('Verifikasi dan Kirim ke Pengelola'),
            ),
          ),

        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),

        const SizedBox(height: 30),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pemeriksaan Laporan'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
          ? const Center(child: Text('Laporan tidak ditemukan.'))
          : _buildReportDetail(_report!),
    );
  }

  @override
  void dispose() {
    _cashController.dispose();
    _qrisController.dispose();
    _discrepancyController.dispose();
    _correctionReasonController.dispose();

    for (final controller in _startControllers.values) {
      controller.dispose();
    }

    for (final controller in _endControllers.values) {
      controller.dispose();
    }

    for (final controller in _freeControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }
}
