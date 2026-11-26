import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../Services/report_export_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../shared/widgets/dashboard_widgets.dart';
import '../../shared/widgets/role_scaffold.dart';

class PengelolaHomeScreen extends StatefulWidget {
  final String userName;

  const PengelolaHomeScreen({super.key, required this.userName});

  @override
  State<PengelolaHomeScreen> createState() => _PengelolaHomeScreenState();
}

class _PengelolaHomeScreenState extends State<PengelolaHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _reportsStream =
      _firestore
          .collection('daily_reports')
          .where('status', isEqualTo: 'verified')
          .orderBy('operationalDate', descending: true)
          .snapshots();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _ticketTypesStream =
      _firestore.collection('ticket_types').orderBy('name').snapshots();

  String _selectedPeriod = 'Hari Ini';

  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isExporting = false;
  int _selectedIndex = 0;

  static const Color primaryColor = AppColors.forest;

  // =========================================
  // HELPER
  // =========================================

  DateTime? _parseOperationalDate(String? value) {
    if (value == null || value.isEmpty) return null;

    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _getReportData(Map<String, dynamic> report) {
    final verified = report['verifiedData'];

    if (verified is Map) {
      return Map<String, dynamic>.from(verified);
    }

    return Map<String, dynamic>.from(report['submittedData'] as Map? ?? {});
  }

  int _number(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _isInSelectedPeriod(String? dateString) {
    final date = _parseOperationalDate(dateString);
    if (date == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_selectedPeriod) {
      case 'Hari Ini':
        return date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;

      case 'Minggu Ini':
        final start = today.subtract(Duration(days: today.weekday - 1));
        return !date.isBefore(start) && !date.isAfter(today);

      case 'Bulan Ini':
        return date.year == now.year && date.month == now.month;

      case 'Tahun Ini':
        return date.year == now.year;

      case 'Semua':
        return true;

      case 'Rentang Tanggal':
        if (_customStartDate == null || _customEndDate == null) {
          return true;
        }

        final start = DateTime(
          _customStartDate!.year,
          _customStartDate!.month,
          _customStartDate!.day,
        );

        final end = DateTime(
          _customEndDate!.year,
          _customEndDate!.month,
          _customEndDate!.day,
          23,
          59,
          59,
        );

        return !date.isBefore(start) && !date.isAfter(end);

      default:
        return true;
    }
  }

  String _formatDate(String? value) {
    final date = _parseOperationalDate(value);
    if (date == null) return '-';

    return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
  }

  // =========================================
  // FILTER TANGGAL
  // =========================================

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();

    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );

    if (result == null || !mounted) return;

    setState(() {
      _selectedPeriod = 'Rentang Tanggal';
      _customStartDate = result.start;
      _customEndDate = result.end;
    });
  }

  List<ReportExportRow> _createExportRows(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reports,
  ) {
    return reports.map((doc) {
      final data = doc.data();
      final reportData = _getReportData(data);
      final rawSummary = reportData['ticketSummary'] as Map? ?? {};

      var paidTickets = 0;
      var freeTickets = 0;
      for (final entry in rawSummary.values) {
        if (entry is! Map) continue;
        paidTickets += _number(entry['paidCount']);
        freeTickets += _number(entry['freeCount']);
      }

      return ReportExportRow(
        operationalDate: _formatDate(data['operationalDate']?.toString()),
        loketName: data['loketName']?.toString() ?? '-',
        cashierName: data['cashierName']?.toString() ?? '-',
        totalVisitors: _number(reportData['totalVisitors']),
        paidTickets: paidTickets,
        freeTickets: freeTickets,
        cashRevenue: _number(reportData['cashRevenue']),
        qrisRevenue: _number(reportData['qrisRevenue']),
        totalRevenue: _number(reportData['totalRevenue']),
      );
    }).toList();
  }

  String _currentPeriodLabel() {
    if (_selectedPeriod == 'Rentang Tanggal' &&
        _customStartDate != null &&
        _customEndDate != null) {
      final start = DateFormat('dd/MM/yyyy').format(_customStartDate!);
      final end = DateFormat('dd/MM/yyyy').format(_customEndDate!);
      return '$start - $end';
    }

    if (_selectedPeriod == 'Tahun Ini') {
      return 'Tahun Ini (${DateTime.now().year})';
    }

    return _selectedPeriod;
  }

  Future<void> _exportReports(
    List<ReportExportRow> reports,
    String periodLabel,
    ReportExportFormat format,
  ) async {
    if (reports.isEmpty || _isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      await ReportExportService.saveReport(
        reports: reports,
        periodLabel: periodLabel,
        format: format,
      );

      if (!mounted) return;

      final formatLabel = switch (format) {
        ReportExportFormat.csv => 'CSV',
        ReportExportFormat.excel => 'Excel',
        ReportExportFormat.pdf => 'PDF',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Laporan $formatLabel berhasil diekspor.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor laporan: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  // =========================================
  // DASHBOARD LAPORAN
  // =========================================

  Widget _buildReportTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _reportsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.danger,
                    size: 45,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Gagal memuat laporan harian.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];

        final reports = allDocs.where((doc) {
          final data = doc.data();

          return _isInSelectedPeriod(data['operationalDate']?.toString());
        }).toList();
        final exportRows = _createExportRows(reports);
        final periodLabel = _currentPeriodLabel();

        int totalRevenue = 0;
        int totalVisitors = 0;
        int cashRevenue = 0;
        int qrisRevenue = 0;
        int totalPaidTickets = 0;
        int totalFreeTickets = 0;

        for (final doc in reports) {
          final data = _getReportData(doc.data());

          totalRevenue += _number(data['totalRevenue']);
          totalVisitors += _number(data['totalVisitors']);
          cashRevenue += _number(data['cashRevenue']);
          qrisRevenue += _number(data['qrisRevenue']);

          final rawSummary = data['ticketSummary'] as Map? ?? {};

          for (final entry in rawSummary.values) {
            if (entry is! Map) continue;

            totalPaidTickets += _number(entry['paidCount']);
            totalFreeTickets += _number(entry['freeCount']);
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildWelcomeCard(),

            const SizedBox(height: 18),
            const WorkflowGuideCard(
              title: 'Panduan ringkasan operasional',
              steps: [
                'Pilih periode untuk membatasi laporan terverifikasi.',
                'Bandingkan pendapatan, jumlah pengunjung, dan grafik bulanan.',
                'Buka laporan untuk detail atau ekspor sesuai periode aktif.',
              ],
            ),

            const SizedBox(height: 18),

            const Text(
              'Periode Laporan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    [
                      'Hari Ini',
                      'Minggu Ini',
                      'Bulan Ini',
                      'Tahun Ini',
                      'Semua',
                    ].map((period) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(period),
                          selected: _selectedPeriod == period,
                          onSelected: (_) {
                            setState(() {
                              _selectedPeriod = period;
                            });
                          },
                        ),
                      );
                    }).toList(),
              ),
            ),

            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _selectCustomDateRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _selectedPeriod == 'Rentang Tanggal' &&
                            _customStartDate != null &&
                            _customEndDate != null
                        ? '${DateFormat('dd/MM/yyyy').format(_customStartDate!)}'
                              ' - '
                              '${DateFormat('dd/MM/yyyy').format(_customEndDate!)}'
                        : 'Pilih Rentang Tanggal',
                  ),
                ),
                PopupMenuButton<ReportExportFormat>(
                  enabled: reports.isNotEmpty && !_isExporting,
                  tooltip: 'Ekspor laporan',
                  onSelected: (format) {
                    unawaited(_exportReports(exportRows, periodLabel, format));
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: ReportExportFormat.csv,
                      child: Text('CSV (.csv)'),
                    ),
                    PopupMenuItem(
                      value: ReportExportFormat.excel,
                      child: Text('Excel (.xlsx)'),
                    ),
                    PopupMenuItem(
                      value: ReportExportFormat.pdf,
                      child: Text('PDF (.pdf)'),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: reports.isEmpty || _isExporting
                            ? AppColors.muted
                            : primaryColor,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isExporting)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            Icons.download_outlined,
                            color: reports.isEmpty
                                ? AppColors.muted
                                : primaryColor,
                          ),
                        const SizedBox(width: 8),
                        Text(_isExporting ? 'Mengekspor...' : 'Ekspor laporan'),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            const Text(
              'Ringkasan Keuangan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            _buildMetricGrid([
              _buildSummaryCard(
                'Total Pendapatan',
                CurrencyFormatter.formatRupiah(totalRevenue),
                Icons.account_balance_wallet_outlined,
                AppColors.forest,
              ),
              _buildSummaryCard(
                'Pendapatan Tunai',
                CurrencyFormatter.formatRupiah(cashRevenue),
                Icons.payments_outlined,
                AppColors.success,
              ),
              _buildSummaryCard(
                'QRIS / Transfer',
                CurrencyFormatter.formatRupiah(qrisRevenue),
                Icons.qr_code_2,
                AppColors.qris,
              ),
              _buildSummaryCard(
                'Total Pengunjung',
                '$totalVisitors orang',
                Icons.groups_outlined,
                AppColors.visitors,
              ),
              _buildSummaryCard(
                'Tiket Berbayar',
                '$totalPaidTickets lembar',
                Icons.confirmation_number_outlined,
                AppColors.tickets,
              ),
              _buildSummaryCard(
                'Tiket Gratis',
                '$totalFreeTickets lembar',
                Icons.card_giftcard,
                AppColors.amber,
              ),
            ]),

            const SizedBox(height: 20),

            _buildRevenueChart(allDocs),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Laporan Terverifikasi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${reports.length} Laporan',
                  style: const TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (reports.isEmpty)
              const EmptyStateWidget(
                icon: Icons.inbox_outlined,
                title: 'Belum ada laporan untuk periode ini',
                message:
                    'Laporan yang sudah diverifikasi Kasir akan muncul '
                    'di sini. Coba pilih periode lain.',
              )
            else
              ...reports.map((doc) {
                final data = doc.data();
                final reportData = _getReportData(data);
                final revenue = _number(reportData['totalRevenue']);
                final visitors = _number(reportData['totalVisitors']);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showReportDetail(doc.id, data),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.verified_outlined,
                                color: primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _formatDate(
                                    data['operationalDate']?.toString(),
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _buildStatusBadge('Terverifikasi'),
                            ],
                          ),
                          const Divider(height: 24),
                          Wrap(
                            spacing: 22,
                            runSpacing: 8,
                            children: [
                              _reportFact(
                                'Petugas Loket',
                                data['loketName']?.toString() ?? '-',
                              ),
                              _reportFact(
                                'Petugas Kasir',
                                data['cashierName']?.toString() ?? '-',
                              ),
                              _reportFact('Pengunjung', '$visitors orang'),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 18,
                                color: AppColors.forest,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Total pendapatan',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  CurrencyFormatter.formatRupiah(revenue),
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    color: AppColors.forest,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  // =========================================
  // KARTU DASHBOARD
  // =========================================

  Widget _buildMetricGrid(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        const spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }

  Widget _buildRevenueChart(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
  ) {
    final year = DateTime.now().year;
    final monthlyRevenue = List<int>.filled(12, 0);

    for (final doc in allDocs) {
      final data = doc.data();
      final date = _parseOperationalDate(data['operationalDate']?.toString());
      if (date == null || date.year != year) continue;

      final reportData = _getReportData(data);
      monthlyRevenue[date.month - 1] += _number(reportData['totalRevenue']);
    }

    final maximum = monthlyRevenue.fold<int>(
      0,
      (current, value) => value > current ? value : current,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pendapatan per Bulan',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Data laporan terverifikasi • $year',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            if (maximum == 0)
              const SizedBox(
                height: 150,
                child: Center(
                  child: Text(
                    'Belum ada data pendapatan untuk tahun ini.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              )
            else
              SizedBox(
                height: 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var month = 1; month <= 12; month++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Tooltip(
                            message:
                                '${DateFormat('MMMM', 'id_ID').format(DateTime(year, month))}: '
                                '${CurrencyFormatter.formatRupiah(monthlyRevenue[month - 1])}',
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      width: double.infinity,
                                      height: monthlyRevenue[month - 1] == 0
                                          ? 3
                                          : (100 *
                                                    monthlyRevenue[month - 1] /
                                                    maximum)
                                                .clamp(8, 100)
                                                .toDouble(),
                                      decoration: BoxDecoration(
                                        color: monthlyRevenue[month - 1] == 0
                                            ? AppColors.border
                                            : AppColors.forest,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(5),
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  DateFormat(
                                    'MMM',
                                    'id_ID',
                                  ).format(DateTime(year, month)),
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _reportFact(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.forest.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.forest,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return RoleBannerCard(
      kicker: 'Dashboard Manajemen',
      title: 'Selamat datang, ${widget.userName}',
      description:
          'Pantau laporan operasional dan pendapatan Wisata Lembah Wilis.',
      icon: Icons.insights_outlined,
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return StatSummaryCard(
      title: title,
      value: value,
      icon: icon,
      accent: color,
    );
  }

  // =========================================
  // DETAIL LAPORAN
  // =========================================

  void _showReportDetail(String reportId, Map<String, dynamic> report) {
    final reportData = _getReportData(report);

    final summary = reportData['ticketSummary'] as Map? ?? {};

    final totalVisitors = _number(reportData['totalVisitors']);

    final cashRevenue = _number(reportData['cashRevenue']);

    final qrisRevenue = _number(reportData['qrisRevenue']);

    final totalRevenue = _number(reportData['totalRevenue']);

    final submittedAt = report['submittedAt'] as Timestamp?;
    final verifiedAt = report['verifiedAt'] as Timestamp?;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Detail Laporan Harian',
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close, color: AppColors.white),
                      ),
                    ],
                  ),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailRow(
                          'Tanggal Operasional',
                          _formatDate(report['operationalDate']?.toString()),
                        ),
                        _detailRow(
                          'Petugas Loket',
                          report['loketName']?.toString() ?? '-',
                        ),
                        _detailRow(
                          'Petugas Kasir',
                          report['cashierName']?.toString() ?? '-',
                        ),
                        _detailRow(
                          'Waktu Pengiriman',
                          submittedAt == null
                              ? '-'
                              : DateFormat(
                                  'dd/MM/yyyy HH:mm',
                                ).format(submittedAt.toDate()),
                        ),
                        _detailRow(
                          'Waktu Verifikasi',
                          verifiedAt == null
                              ? '-'
                              : DateFormat(
                                  'dd/MM/yyyy HH:mm',
                                ).format(verifiedAt.toDate()),
                        ),

                        const Divider(height: 24),

                        const Text(
                          'Rincian Tiket',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 10),

                        if (summary.isEmpty)
                          const Text('Tidak ada rincian tiket.')
                        else
                          ...summary.entries.map((entry) {
                            final item = Map<String, dynamic>.from(
                              entry.value as Map,
                            );

                            return Card(
                              color: AppColors.successSurface,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['ticketName']?.toString() ?? 'Tiket',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _detailRow(
                                      'Harga Tiket',
                                      CurrencyFormatter.formatRupiah(
                                        _number(item['price']),
                                      ),
                                    ),
                                    _detailRow(
                                      'Nomor Seri',
                                      '${item['serialStart']} - '
                                          '${item['serialEnd']}',
                                    ),
                                    _detailRow(
                                      'Jumlah Tiket Fisik',
                                      '${_number(item['serialCount'])}',
                                    ),
                                    _detailRow(
                                      'Tiket Gratis',
                                      '${_number(item['freeCount'])}',
                                    ),
                                    _detailRow(
                                      'Tiket Berbayar',
                                      '${_number(item['paidCount'])}',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),

                        const Divider(height: 24),

                        const Text(
                          'Rekap Keuangan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 8),

                        _detailRow('Total Pengunjung', '$totalVisitors orang'),
                        _detailRow(
                          'Pendapatan Tunai',
                          CurrencyFormatter.formatRupiah(cashRevenue),
                        ),
                        _detailRow(
                          'QRIS / Transfer',
                          CurrencyFormatter.formatRupiah(qrisRevenue),
                        ),

                        const Divider(),

                        _detailRow(
                          'Total Pendapatan',
                          CurrencyFormatter.formatRupiah(totalRevenue),
                          bold: true,
                        ),

                        const Divider(height: 24),

                        const Text(
                          'Ketidaksesuaian',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 8),

                        _buildSubcollectionList(
                          reportId: reportId,
                          collection: 'discrepancies',
                          emptyMessage: 'Tidak ada catatan ketidaksesuaian.',
                        ),

                        const Divider(height: 24),

                        const Text(
                          'Riwayat Koreksi Kasir',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 8),

                        _buildSubcollectionList(
                          reportId: reportId,
                          collection: 'corrections',
                          emptyMessage: 'Tidak ada riwayat koreksi.',
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Tutup'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================
  // SUBKOLEKSI TEMUAN DAN KOREKSI
  // =========================================

  Widget _buildSubcollectionList({
    required String reportId,
    required String collection,
    required String emptyMessage,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('daily_reports')
          .doc(reportId)
          .collection(collection)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Gagal memuat data: ${snapshot.error}',
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              emptyMessage,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();

            final description =
                data['description']?.toString() ??
                data['reason']?.toString() ??
                '-';

            final type =
                data['type']?.toString() ??
                data['fieldName']?.toString() ??
                'Catatan';

            final oldValue = data['oldValue'];
            final newValue = data['newValue'];

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Text(description),
                    if (oldValue != null || newValue != null) ...[
                      const Divider(),
                      _detailRow('Nilai Sebelum', oldValue?.toString() ?? '-'),
                      _detailRow('Nilai Sesudah', newValue?.toString() ?? '-'),
                    ],
                    if (data['serialNumber'] != null)
                      _detailRow('Nomor Seri', data['serialNumber'].toString()),
                    if (data['cashierName'] != null)
                      _detailRow('Petugas', data['cashierName'].toString()),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: bold ? primaryColor : null,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================
  // KELOLA KATEGORI TIKET
  // =========================================

  void _showTicketDialog({DocumentSnapshot<Map<String, dynamic>>? doc}) {
    final data = doc?.data();

    final nameController = TextEditingController(text: data?['name'] ?? '');

    final priceController = TextEditingController(
      text: data != null
          ? CurrencyFormatter.formatInput(_number(data['price']))
          : '',
    );

    bool isActive = data?['isActive'] ?? true;
    bool saving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                doc == null ? 'Tambah Kategori Tiket' : 'Edit Kategori Tiket',
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Tiket',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [RupiahInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Harga Tiket',
                          prefixText: 'Rp ',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Status Aktif'),
                        value: isActive,
                        onChanged: (value) {
                          setDialogState(() {
                            isActive = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameController.text.trim();

                          final price =
                              CurrencyFormatter.parseInput(
                                priceController.text,
                              ) ??
                              0;

                          if (name.isEmpty || price <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Nama dan harga tiket harus valid.',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                          });

                          try {
                            final collection = _firestore.collection(
                              'ticket_types',
                            );

                            if (doc == null) {
                              await collection.add({
                                'name': name,
                                'price': price,
                                'isActive': isActive,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                            } else {
                              await collection.doc(doc.id).update({
                                'name': name,
                                'price': price,
                                'isActive': isActive,
                              });
                            }

                            if (!mounted ||
                                !context.mounted ||
                                !dialogContext.mounted) {
                              return;
                            }

                            Navigator.pop(dialogContext);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Kategori tiket berhasil disimpan.',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted || !dialogContext.mounted) {
                              return;
                            }

                            setDialogState(() {
                              saving = false;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Gagal menyimpan kategori tiket: $e',
                                ),
                              ),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      nameController.dispose();
      priceController.dispose();
    });
  }

  Widget _buildTicketManagementTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ticketTypesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Gagal memuat kategori tiket: ${snapshot.error}'),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final activeCount = docs
            .where((doc) => (doc.data()['isActive'] as bool?) ?? true)
            .length;
        final inactiveCount = docs.length - activeCount;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            const RoleBannerCard(
              kicker: 'Pengaturan operasional',
              title: 'Kategori tiket',
              description:
                  'Kelola nama, harga, dan status kategori yang digunakan '
                  'Petugas Loket.',
              icon: Icons.confirmation_number_outlined,
            ),
            const SizedBox(height: 14),
            const WorkflowGuideCard(
              title: 'Panduan kategori',
              steps: [
                'Tambahkan nama dan harga sesuai ketentuan operasional.',
                'Nonaktifkan kategori yang tidak digunakan tanpa menghapusnya.',
                'Pastikan kategori aktif tersedia untuk input Petugas Loket.',
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 420
                    ? 2
                    : 1;
                const spacing = 10.0;
                final width =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    SizedBox(
                      width: width,
                      child: StatSummaryCard(
                        title: 'Total kategori',
                        value: '${docs.length}',
                        icon: Icons.category_outlined,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: StatSummaryCard(
                        title: 'Kategori aktif',
                        value: '$activeCount',
                        icon: Icons.check_circle_outline_rounded,
                        accent: AppColors.forest,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: StatSummaryCard(
                        title: 'Kategori nonaktif',
                        value: '$inactiveCount',
                        icon: Icons.pause_circle_outline_rounded,
                        accent: AppColors.muted,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            if (docs.isEmpty)
              EmptyStateWidget(
                icon: Icons.confirmation_number_outlined,
                title: 'Belum ada kategori tiket',
                message:
                    'Tambahkan kategori agar Petugas Loket dapat '
                    'menyusun laporan harian.',
                actionLabel: 'Tambah kategori',
                onAction: _showTicketDialog,
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                final isActive = (data['isActive'] as bool?) ?? true;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: isActive
                          ? AppColors.sage.withValues(alpha: 0.18)
                          : AppColors.canvas,
                      child: Icon(
                        Icons.confirmation_number_outlined,
                        color: isActive ? primaryColor : AppColors.muted,
                      ),
                    ),
                    title: Text(
                      data['name']?.toString() ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: isActive
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        '${CurrencyFormatter.formatRupiah(_number(data['price']))}'
                        ' • ${isActive ? 'Aktif' : 'Nonaktif'}',
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: 'Edit kategori',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showTicketDialog(doc: doc),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  // =========================================
  // BUILD
  // =========================================

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'Manajemen Operasional',
      userName: widget.userName,
      roleLabel: 'PENGELOLA',
      destinations: const [
        RoleNavigationDestination(
          label: 'Dashboard',
          icon: Icons.analytics_outlined,
        ),
        RoleNavigationDestination(
          label: 'Kategori tiket',
          icon: Icons.confirmation_number_outlined,
        ),
      ],
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded),
          tooltip: 'Keluar',
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
          },
        ),
      ],
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () => _showTicketDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Tiket'),
            )
          : null,
      body: _selectedIndex == 0
          ? _buildReportTab()
          : _buildTicketManagementTab(),
    );
  }
}
