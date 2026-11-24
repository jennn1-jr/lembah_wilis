import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PengelolaHomeScreen extends StatefulWidget {
  final String userName;
  const PengelolaHomeScreen({super.key, required this.userName});

  @override
  State<PengelolaHomeScreen> createState() => _PengelolaHomeScreenState();
}

class _PengelolaHomeScreenState extends State<PengelolaHomeScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _transactionsStream =
      FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .snapshots();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _ticketTypesStream =
      FirebaseFirestore.instance
          .collection('ticket_types')
          .orderBy('name')
          .snapshots();

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );
  String _selectedPeriod = 'Hari Ini';

  void _showTicketDialog({DocumentSnapshot<Map<String, dynamic>>? doc}) {
    final data = doc?.data();
    final nameController = TextEditingController(text: data?['name'] ?? '');
    final priceController = TextEditingController(
      text: data != null ? '${data['price']}' : '',
    );
    bool isActive = data?['isActive'] ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(doc == null ? 'Tambah Kategori Tiket' : 'Edit Tiket'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Tiket (misal: Tiket Masuk)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga (Rp)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Status Aktif'),
                value: isActive,
                onChanged: (val) => setDialogState(() => isActive = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final price = int.tryParse(priceController.text.trim()) ?? 0;
                if (name.isEmpty || price <= 0) return;

                final collection = FirebaseFirestore.instance.collection(
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
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Pengelola • ${widget.userName}'),
          backgroundColor: const Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Keluar',
              onPressed: () => FirebaseAuth.instance.signOut(),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.amber,
            tabs: [
              Tab(icon: Icon(Icons.analytics_outlined), text: 'Laporan'),
              Tab(
                icon: Icon(Icons.confirmation_number_outlined),
                text: 'Harga Tiket',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildReportTab(), _buildTicketManagementTab()],
        ),
      ),
    );
  }

  Widget _buildReportTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _transactionsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Gagal memuat laporan transaksi: ${snapshot.error}'),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final now = DateTime.now();
        final periodStart = switch (_selectedPeriod) {
          'Hari Ini' => DateTime(now.year, now.month, now.day),
          'Bulan Ini' => DateTime(now.year, now.month),
          _ => null,
        };
        final filteredDocs = periodStart == null
            ? docs
            : docs.where((doc) {
                final createdAt = doc.data()['createdAt'] as Timestamp?;
                return createdAt != null &&
                    !createdAt.toDate().isBefore(periodStart);
              }).toList();

        var totalRevenue = 0;
        var totalTickets = 0;
        var cashRevenue = 0;
        var qrisRevenue = 0;
        for (final doc in filteredDocs) {
          final data = doc.data();
          final amount = (data['totalAmount'] as num? ?? 0).toInt();
          totalRevenue += amount;
          totalTickets += (data['totalQty'] as num? ?? 0).toInt();
          if (data['paymentMethod'] == 'Tunai') {
            cashRevenue += amount;
          } else if (data['paymentMethod'] == 'QRIS') {
            qrisRevenue += amount;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: ['Hari Ini', 'Bulan Ini', 'Semua']
                  .map(
                    (period) => ChoiceChip(
                      label: Text(period),
                      selected: _selectedPeriod == period,
                      onSelected: (_) =>
                          setState(() => _selectedPeriod = period),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    'Total Pendapatan',
                    _currencyFormat.format(totalRevenue),
                    Icons.payments_outlined,
                    Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryCard(
                    'Tiket Terjual',
                    '$totalTickets Lembar',
                    Icons.local_activity_outlined,
                    Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    'Pendapatan Tunai',
                    _currencyFormat.format(cashRevenue),
                    Icons.money_outlined,
                    Colors.teal.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryCard(
                    'Pendapatan QRIS',
                    _currencyFormat.format(qrisRevenue),
                    Icons.qr_code_2,
                    Colors.deepPurple.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Riwayat Transaksi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (filteredDocs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('Belum ada transaksi penjualan tiket.'),
                ),
              )
            else
              ...filteredDocs.map((doc) {
                final data = doc.data();
                final ts = data['createdAt'] as Timestamp?;
                final timeStr = ts != null
                    ? DateFormat('dd MMM yyyy, HH:mm').format(ts.toDate())
                    : '-';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: const Icon(
                        Icons.receipt_long,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    title: Text(
                      data['invoiceNumber'] ?? doc.id,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${data['cashierName']} • ${data['paymentMethod']} • $timeStr',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      _currencyFormat.format(data['totalAmount'] ?? 0),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    onTap: () => _showTransactionDetails(data, doc.id),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  
void _showTransactionDetails(Map<String, dynamic> data, String docId) {
  final timestamp = data['createdAt'] as Timestamp?;
  final transactionTime = timestamp?.toDate();
  final invoiceNumber = data['invoiceNumber'] as String? ?? docId;
  final cashierName = data['cashierName'] as String? ?? '-';
  final paymentMethod = data['paymentMethod'] as String? ?? '-';

  final items = (data['items'] as List<dynamic>? ?? [])
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();

  final totalAmount = (data['totalAmount'] as num? ?? 0).toInt();
  final cashReceived = (data['cashReceived'] as num? ?? 0).toInt();
  final changeAmount = (data['changeAmount'] as num? ?? 0).toInt();

  // Mengambil nomor seri dari data transaksi.
  String getSerial(Map<String, dynamic> item, String field, String numberField) {
    final serial = item[field];

    if (serial != null && serial.toString().isNotEmpty) {
      return serial.toString();
    }

    final number = item[numberField];
    if (number is num) {
      return number.toInt().toString().padLeft(4, '0');
    }

    return '';
  }

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.receipt_long, color: Color(0xFF0D47A1)),
          SizedBox(width: 8),
          Text('Detail Transaksi'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Invoice', invoiceNumber),
            _detailRow(
              'Waktu',
              transactionTime == null
                  ? '-'
                  : DateFormat('dd MMM yyyy, HH:mm')
                      .format(transactionTime),
            ),
            _detailRow('Kasir', cashierName),
            _detailRow('Metode Pembayaran', paymentMethod),

            const Divider(height: 24),

            const Text(
              'Rincian Tiket',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),

            ...items.map((item) {
              final name = item['name']?.toString() ?? '-';
              final visitorCount =
                  (item['visitorCount'] as num? ?? 0).toInt();
              final discountCount =
                  (item['discountCount'] as num? ?? 0).toInt();
              final qty = (item['qty'] as num? ?? 0).toInt();
              final subtotal =
                  (item['subtotal'] as num? ?? 0).toInt();

              final serialStart = getSerial(
                item,
                'serialStart',
                'serialStartNumber',
              );

              final serialEnd = getSerial(
                item,
                'serialEnd',
                'serialEndNumber',
              );

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _detailRow('Jumlah Pengunjung', '$visitorCount orang'),
                    _detailRow('Tiket Gratis/Potongan', '$discountCount'),
                    _detailRow('Tiket Dibayar', '$qty lembar'),

                    const Divider(),

                    if (qty > 0 && serialStart.isNotEmpty && serialEnd.isNotEmpty)
                      _detailRow(
                        'Nomor Seri',
                        serialStart == serialEnd
                            ? serialStart
                            : '$serialStart - $serialEnd',
                      )
                    else if (qty == 0)
                      _detailRow('Nomor Seri', 'Tidak ada tiket berbayar')
                    else
                      _detailRow('Nomor Seri', 'Tidak tersedia'),

                    const SizedBox(height: 4),

                    _detailRow(
                      'Subtotal',
                      _currencyFormat.format(subtotal),
                    ),
                  ],
                ),
              );
            }),

            const Divider(height: 24),

            _detailRow(
              'Total Pembayaran',
              _currencyFormat.format(totalAmount),
            ),

            if (paymentMethod == 'Tunai') ...[
              _detailRow(
                'Uang Diterima',
                _currencyFormat.format(cashReceived),
              ),
              _detailRow(
                'Kembalian',
                _currencyFormat.format(changeAmount),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );
}


  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketManagementTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTicketDialog(),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Tiket'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
          if (docs.isEmpty) {
            return const Center(
              child: Text('Belum ada kategori tiket. Tekan "+ Tambah Tiket".'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final isActive = data['isActive'] ?? true;

              return Card(
                child: ListTile(
                  title: Text(
                    data['name'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: isActive ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text(
                    '${_currencyFormat.format(data['price'] ?? 0)} • ${isActive ? "Aktif" : "Nonaktif"}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _showTicketDialog(doc: doc),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
