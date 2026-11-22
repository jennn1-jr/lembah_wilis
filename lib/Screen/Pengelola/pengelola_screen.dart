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
  final _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  void _showTicketDialog({DocumentSnapshot? doc}) {
    final data = doc?.data() as Map<String, dynamic>?;
    final nameController = TextEditingController(text: data?['name'] ?? '');
    final priceController =
        TextEditingController(text: data != null ? '${data['price']}' : '');
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

                final collection =
                    FirebaseFirestore.instance.collection('ticket_types');
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
              Tab(icon: Icon(Icons.confirmation_number_outlined), text: 'Harga Tiket'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildReportTab(),
            _buildTicketManagementTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTab() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        int todayRevenue = 0;
        int todayTickets = 0;

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = data['createdAt'] as Timestamp?;
          if (ts != null && ts.toDate().isAfter(startOfDay)) {
            todayRevenue += (data['totalAmount'] as num? ?? 0).toInt();
            todayTickets += (data['totalQty'] as num? ?? 0).toInt();
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    'Pendapatan Hari Ini',
                    _currencyFormat.format(todayRevenue),
                    Icons.payments_outlined,
                    Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryCard(
                    'Tiket Terjual Hari Ini',
                    '$todayTickets Lembar',
                    Icons.local_activity_outlined,
                    Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Riwayat Transaksi Terbaru',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (docs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('Belum ada transaksi penjualan tiket.'),
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final ts = data['createdAt'] as Timestamp?;
                final timeStr = ts != null
                    ? DateFormat('dd MMM yyyy, HH:mm').format(ts.toDate())
                    : '-';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: const Icon(Icons.receipt_long, color: Color(0xFF0D47A1)),
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
                  ),
                );
              }),
          ],
        );
      },
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
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ticket_types')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
              final data = doc.data() as Map<String, dynamic>;
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