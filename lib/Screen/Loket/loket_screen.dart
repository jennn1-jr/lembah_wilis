
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../Models/daily_report_model.dart';
import '../../Services/daily_report_service.dart';

class LoketScreen extends StatefulWidget {
  final String userName;

  const LoketScreen({
    super.key,
    required this.userName,
  });

  @override
  State<LoketScreen> createState() => _LoketScreenState();
}

class _LoketScreenState extends State<LoketScreen> {
  final DailyReportService _reportService = DailyReportService();

  final Map<String, TextEditingController> _startControllers = {};
  final Map<String, TextEditingController> _endControllers = {};
  final Map<String, TextEditingController> _freeControllers = {};

  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _qrisController = TextEditingController();

  List<Map<String, dynamic>> _ticketTypes = [];

  DateTime _selectedDate = DateTime.now();

  bool _isLoading = true;
  bool _isSaving = false;

  DailyReport? _existingReport;

  String get _operationalDate =>
      DateFormat('yyyy-MM-dd').format(_selectedDate);

  bool get _isLocked =>
      _existingReport != null &&
      _existingReport!.status != 'draft';

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    try {
      await _loadTicketTypes();
      await _loadReport();
    } catch (e) {
      _showMessage('Gagal memuat halaman: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadTicketTypes() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('ticket_types')
        .where('isActive', isEqualTo: true)
        .get();

    _ticketTypes = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        'name': data['name'] ?? '',
        'price': (data['price'] as num).toInt(),
      };
    }).toList();

    for (final ticket in _ticketTypes) {
      final id = ticket['id'] as String;

      _startControllers[id] = TextEditingController();
      _endControllers[id] = TextEditingController();
      _freeControllers[id] = TextEditingController(text: '0');
    }
  }

  Future<void> _loadReport() async {
    final report = await _reportService.getReport(_operationalDate);

    if (!mounted) return;

    setState(() {
      _existingReport = report;
    });

    if (report == null) return;

    final data = report.submittedData;

    if (data.ticketSummary.isNotEmpty) {
      for (final entry in data.ticketSummary.entries) {
        final id = entry.key;
        final ticket = entry.value;

        if (_startControllers.containsKey(id)) {
          _startControllers[id]!.text = ticket.serialStart;
          _endControllers[id]!.text = ticket.serialEnd;
          _freeControllers[id]!.text = ticket.freeCount.toString();
        }
      }

      _cashController.text = data.cashRevenue.toString();
      _qrisController.text = data.qrisRevenue.toString();
    }
  }

  Future<void> _selectDate() async {
    if (_isSaving) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Pilih tanggal operasional',
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
      _existingReport = null;

      for (final controller in _startControllers.values) {
        controller.clear();
      }

      for (final controller in _endControllers.values) {
        controller.clear();
      }

      for (final controller in _freeControllers.values) {
        controller.text = '0';
      }

      _cashController.clear();
      _qrisController.clear();
      _isLoading = true;
    });

    try {
      await _loadReport();
    } catch (e) {
      _showMessage('Gagal memuat laporan: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  ReportData _buildReportData() {
    final Map<String, TicketSummary> summaries = {};

    for (final ticket in _ticketTypes) {
      final id = ticket['id'] as String;

      final start = _startControllers[id]!.text.trim();
      final end = _endControllers[id]!.text.trim();
      final free = int.tryParse(_freeControllers[id]!.text.trim());

      if (start.isEmpty || end.isEmpty) {
        throw Exception(
          'Rentang nomor seri ${ticket['name']} belum lengkap.',
        );
      }

      if (free == null) {
        throw Exception(
          'Jumlah tiket gratis ${ticket['name']} tidak valid.',
        );
      }

      summaries[id] = TicketSummary.fromInput(
        ticketTypeId: id,
        ticketName: ticket['name'] as String,
        price: ticket['price'] as int,
        serialStart: start,
        serialEnd: end,
        freeCount: free,
      );
    }

    final cash = int.tryParse(_cashController.text.trim()) ?? 0;
    final qris = int.tryParse(_qrisController.text.trim()) ?? 0;

    if (cash < 0 || qris < 0) {
      throw Exception('Nominal pembayaran tidak boleh negatif.');
    }

    return ReportData.fromTickets(
      ticketSummary: summaries,
      cashRevenue: cash,
      qrisRevenue: qris,
    );
  }

  Future<void> _ensureDraftExists() async {
    if (_existingReport != null) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Sesi login tidak ditemukan.');
    }

    await _reportService.createDraft(
      operationalDate: _operationalDate,
      loketId: user.uid,
      loketName: widget.userName,
    );

    _existingReport = await _reportService.getReport(_operationalDate);
  }

  Future<void> _saveDraft() async {
    await _processReport(isSubmit: false);
  }

  Future<void> _submitReport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kirim Laporan?'),
        content: const Text(
          'Setelah dikirim, laporan tidak dapat diubah langsung oleh '
          'Petugas Loket. Pastikan rentang nomor seri dan nominal '
          'pembayaran sudah benar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Periksa Lagi'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kirim Laporan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _processReport(isSubmit: true);
  }

  Future<void> _processReport({required bool isSubmit}) async {
    if (_isSaving || _isLocked) return;

    setState(() => _isSaving = true);

    try {
      final reportData = _buildReportData();

      await _ensureDraftExists();

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Sesi login tidak ditemukan.');
      }

      if (isSubmit) {
        await _reportService.submitReport(
          operationalDate: _operationalDate,
          loketId: user.uid,
          reportData: reportData,
        );
      } else {
        await _reportService.saveDraft(
          operationalDate: _operationalDate,
          loketId: user.uid,
          reportData: reportData,
        );
      }

      _existingReport = await _reportService.getReport(_operationalDate);

      if (!mounted) return;

      setState(() {});

      _showMessage(
        isSubmit
            ? 'Laporan berhasil dikirim kepada Petugas Kasir.'
            : 'Draft laporan berhasil disimpan.',
      );
    } catch (e) {
      _showMessage(
        'Gagal memproses laporan: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isLocked && !_isSaving,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final id = ticket['id'] as String;
    final name = ticket['name'] as String;
    final price = ticket['price'] as int;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Harga tiket: ${NumberFormat.currency(
                locale: 'id_ID',
                symbol: 'Rp',
                decimalDigits: 0,
              ).format(price)}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            const Text(
              'Rentang Nomor Seri',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    label: 'Nomor Awal',
                    controller: _startControllers[id]!,
                    hint: 'Contoh: 0001',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberField(
                    label: 'Nomor Akhir',
                    controller: _endControllers[id]!,
                    hint: 'Contoh: 0050',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildNumberField(
              label: 'Jumlah Tiket Gratis',
              controller: _freeControllers[id]!,
              hint: 'Masukkan jumlah tiket gratis',
            ),

            const SizedBox(height: 8),

            const Text(
              'Jumlah tiket dan tiket berbayar akan dihitung otomatis '
              'berdasarkan rentang nomor seri.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rekap Pembayaran Harian',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _buildNumberField(
              label: 'Total Tunai (Rp)',
              controller: _cashController,
              hint: 'Contoh: 250000',
            ),

            const SizedBox(height: 12),

            _buildNumberField(
              label: 'Total QRIS/Transfer (Rp)',
              controller: _qrisController,
              hint: 'Contoh: 150000',
            ),

            const SizedBox(height: 8),

            const Text(
              'Masukkan total pembayaran untuk kedua kategori tiket '
              'secara gabungan, bukan per kategori.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus() {
    final status = _existingReport?.status ?? 'Belum dibuat';

    String label;

    switch (status) {
      case 'draft':
        label = 'Draft - Belum Dikirim';
        break;
      case 'submitted':
        label = 'Terkirim - Menunggu Kasir';
        break;
      case 'under_review':
        label = 'Sedang Diperiksa Kasir';
        break;
      case 'needs_correction':
        label = 'Memerlukan Pemeriksaan/Koreksi';
        break;
      case 'verified':
        label = 'Terverifikasi';
        break;
      default:
        label = status;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Status laporan: $label',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _startControllers.values) {
      controller.dispose();
    }

    for (final controller in _endControllers.values) {
      controller.dispose();
    }

    for (final controller in _freeControllers.values) {
      controller.dispose();
    }

    _cashController.dispose();
    _qrisController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Petugas Loket'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ticketTypes.isEmpty
              ? const Center(
                  child: Text('Tidak ada kategori tiket aktif.'),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selamat datang, ${widget.userName}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Buat laporan penutupan operasional harian.',
                      ),
                      const SizedBox(height: 20),

                      InkWell(
                        onTap: _selectDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Tanggal Operasional',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_month),
                          ),
                          child: Text(
                            DateFormat(
                              'dd MMMM yyyy',
                              'id_ID',
                            ).format(_selectedDate),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      _buildStatus(),

                      const SizedBox(height: 20),

                      const Text(
                        'Data Tiket',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      ..._ticketTypes.map(_buildTicketCard),

                      const SizedBox(height: 8),

                      _buildPaymentSection(),

                      const SizedBox(height: 20),

                      if (_isLocked)
                        const Text(
                          'Laporan sudah dikirim. Perubahan selanjutnya '
                          'hanya dapat dilakukan melalui proses pemeriksaan '
                          'oleh Petugas Kasir.',
                          style: TextStyle(color: Colors.orange),
                        )
                      else
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed:
                                    _isSaving ? null : _saveDraft,
                                icon: const Icon(Icons.save),
                                label: const Text('Simpan Draft'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isSaving ? null : _submitReport,
                                icon: const Icon(Icons.send),
                                label: const Text('Kirim Laporan ke Kasir'),
                              ),
                            ),
                          ],
                        ),

                      if (_isSaving)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
