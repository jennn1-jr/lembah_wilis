import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class KasirScreen extends StatefulWidget {
  final String userName;
  const KasirScreen({super.key, required this.userName});

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _ticketsStream =
      FirebaseFirestore.instance
          .collection('ticket_types')
          .where('isActive', isEqualTo: true)
          .snapshots();

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  // _cart menyimpan jumlah pengunjung, bukan jumlah tiket berbayar.
  final Map<String, int> _cart = {};
  final Map<String, int> _discounts = {};

  String _paymentMethod = 'Tunai';
  final _cashReceivedController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _cashReceivedController.dispose();
    super.dispose();
  }

  void _updateVisitors(String docId, int delta) {
    setState(() {
      final current = _cart[docId] ?? 0;
      final next = current + delta;

      if (next <= 0) {
        _cart.remove(docId);
        _discounts.remove(docId);
      } else {
        _cart[docId] = next;
        // Potongan tidak boleh melebihi jumlah pengunjung.
        if ((_discounts[docId] ?? 0) > next) {
          _discounts[docId] = next;
        }
      }
    });
  }

  void _updateDiscount(String docId, int delta) {
    setState(() {
      final visitors = _cart[docId] ?? 0;
      final current = _discounts[docId] ?? 0;
      final next = (current + delta).clamp(0, visitors).toInt();
      if (next == 0) {
        _discounts.remove(docId);
      } else {
        _discounts[docId] = next;
      }
    });
  }

  void _setQuickCash(int amount) {
    _cashReceivedController.text = amount.toString();
  }

  Future<void> _processCheckout(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> activeTickets,
  ) async {
    final items = <Map<String, dynamic>>[];
    int totalAmount = 0;
    int totalQty = 0;
    int totalVisitors = 0;
    int totalDiscount = 0;

    for (final doc in activeTickets) {
      final visitorCount = _cart[doc.id] ?? 0;
      final discountCount = _discounts[doc.id] ?? 0;
      final qty = visitorCount - discountCount;
      if (visitorCount > 0) {
        final data = doc.data();
        final price = (data['price'] as num? ?? 0).toInt();
        final subtotal = price * qty;
        items.add({
          'ticketId': doc.id,
          'name': data['name'] as String? ?? '',
          'price': price,
          'visitorCount': visitorCount,
          'discountCount': discountCount,
          'qty': qty,
          'ticketCount': qty,
          'subtotal': subtotal,
        });
        totalAmount += subtotal;
        totalQty += qty;
        totalVisitors += visitorCount;
        totalDiscount += discountCount;
      }
    }

    if (items.isEmpty || totalQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah tiket berbayar harus lebih dari 0.')),
      );
      return;
    }

    final usedPaymentMethod = _paymentMethod;
    int cashReceived = totalAmount;
    int changeAmount = 0;

    if (usedPaymentMethod == 'Tunai') {
      cashReceived = int.tryParse(_cashReceivedController.text.trim()) ?? 0;
      if (cashReceived < totalAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nominal uang tunai kurang dari total tagihan!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      changeAmount = cashReceived - totalAmount;
    }

    setState(() => _isProcessing = true);

    try {
      final now = DateTime.now();
      final user = FirebaseAuth.instance.currentUser;
      final transactionRef = FirebaseFirestore.instance
          .collection('transactions')
          .doc();
      final invoiceNumber =
          'LW-${DateFormat('yyyyMMdd-HHmmss').format(now)}-${transactionRef.id.substring(0, 6).toUpperCase()}';

      await transactionRef.set({
        'invoiceNumber': invoiceNumber,
        'items': items,
        'totalQty': totalQty,
        'totalVisitors': totalVisitors,
        'totalDiscount': totalDiscount,
        'totalAmount': totalAmount,
        'paymentMethod': usedPaymentMethod,
        'cashReceived': cashReceived,
        'changeAmount': changeAmount,
        'cashierId': user?.uid ?? '',
        'cashierName': widget.userName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _cart.clear();
        _discounts.clear();
        _cashReceivedController.clear();
        _paymentMethod = 'Tunai';
      });

      _showReceiptDialog(
        invoiceNumber: invoiceNumber,
        items: items,
        totalAmount: totalAmount,
        paymentMethod: usedPaymentMethod,
        cashReceived: cashReceived,
        changeAmount: changeAmount,
        time: now,
        isReprint: false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan transaksi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showReceiptDialog({
    required String invoiceNumber,
    required List<Map<String, dynamic>> items,
    required int totalAmount,
    required String paymentMethod,
    required int cashReceived,
    required int changeAmount,
    required DateTime time,
    bool isReprint = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: isReprint,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isReprint ? Icons.receipt_long : Icons.check_circle,
              color: const Color(0xFF1B5E20),
            ),
            const SizedBox(width: 8),
            Text(isReprint ? 'Salinan Struk' : 'Transaksi Berhasil'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'WISATA LEMBAH WILIS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Center(
                child: Text(
                  '$invoiceNumber\n${DateFormat('dd MMM yyyy, HH:mm').format(time)}\nKasir: ${widget.userName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              const Divider(height: 20),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item['name']} • ${item['qty']} bayar'
                          '${(item['discountCount'] as num? ?? 0) > 0 ? ' (${item['visitorCount']} pengunjung, ${item['discountCount']} gratis)' : ''}',
                        ),
                      ),
                      Text(_currencyFormat.format(item['subtotal'])),
                    ],
                  ),
                ),
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _currencyFormat.format(totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bayar ($paymentMethod)'),
                  Text(_currencyFormat.format(cashReceived)),
                ],
              ),
              if (paymentMethod == 'Tunai') ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kembalian'),
                    Text(
                      _currencyFormat.format(changeAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
            ),
            child: Text(isReprint ? 'Tutup' : 'Transaksi Baru'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Kasir • ${widget.userName}'),
          backgroundColor: const Color(0xFF1B5E20),
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
              Tab(icon: Icon(Icons.point_of_sale), text: 'Loket Tiket'),
              Tab(icon: Icon(Icons.history), text: 'Riwayat Shift'),
            ],
          ),
        ),
        body: TabBarView(children: [_buildPosTab(), _buildShiftHistoryTab()]),
      ),
    );
  }

  Widget _buildPosTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ticketsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Gagal memuat daftar tiket: ${snapshot.error}'),
          );
        }

        final activeTickets = snapshot.data?.docs ?? [];
        if (activeTickets.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Belum ada tiket aktif. Minta Pengelola menambahkan kategori tiket terlebih dahulu.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        int totalAmount = 0;
        int totalQty = 0;
        int totalVisitors = 0;
        int totalDiscount = 0;
        for (final doc in activeTickets) {
          final visitors = _cart[doc.id] ?? 0;
          final discount = _discounts[doc.id] ?? 0;
          final paidQty = visitors - discount;
          if (visitors > 0) {
            final data = doc.data();
            final price = (data['price'] as num? ?? 0).toInt();
            totalAmount += price * paidQty;
            totalQty += paidQty;
            totalVisitors += visitors;
            totalDiscount += discount;
          }
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activeTickets.length,
                itemBuilder: (context, index) {
                  final doc = activeTickets[index];
                  final data = doc.data();
                  final visitors = _cart[doc.id] ?? 0;
                  final discount = _discounts[doc.id] ?? 0;
                  final paidQty = visitors - discount;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: visitors > 0
                            ? const Color(0xFF1B5E20)
                            : Colors.grey.shade300,
                        width: visitors > 0 ? 1.5 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['name'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currencyFormat.format(data['price'] ?? 0),
                                  style: const TextStyle(
                                    color: Color(0xFF1B5E20),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Pengunjung', style: TextStyle(fontSize: 11)),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton.outlined(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: visitors > 0
                                        ? () => _updateVisitors(doc.id, -1)
                                        : null,
                                    icon: const Icon(Icons.remove, size: 18),
                                  ),
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '$visitors',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton.filled(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _updateVisitors(doc.id, 1),
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xFF1B5E20),
                                    ),
                                    icon: const Icon(Icons.add, size: 18),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Gratis', style: TextStyle(fontSize: 11)),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: discount > 0
                                        ? () => _updateDiscount(doc.id, -1)
                                        : null,
                                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                                  ),
                                  Text('$discount', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: discount < visitors
                                        ? () => _updateDiscount(doc.id, 1)
                                        : null,
                                    icon: const Icon(Icons.add_circle_outline, size: 18),
                                  ),
                                ],
                              ),
                              Text(
                                '$paidQty tiket dibayar',
                                style: const TextStyle(
                                  color: Color(0xFF1B5E20),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (totalVisitors > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Metode Bayar:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('Tunai'),
                          selected: _paymentMethod == 'Tunai',
                          onSelected: (_) =>
                              setState(() => _paymentMethod = 'Tunai'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('QRIS'),
                          selected: _paymentMethod == 'QRIS',
                          onSelected: (_) =>
                              setState(() => _paymentMethod = 'QRIS'),
                        ),
                      ],
                    ),
                    if (_paymentMethod == 'Tunai') ...[
                      const SizedBox(height: 10),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _cashReceivedController,
                        builder: (context, value, _) {
                          final cashInput =
                              int.tryParse(value.text.trim()) ?? 0;
                          final previewChange = cashInput - totalAmount;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _cashReceivedController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Uang Diterima (Rp)',
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  suffixText: cashInput >= totalAmount
                                      ? 'Kembali: ${_currencyFormat.format(previewChange)}'
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    ActionChip(
                                      label: const Text('Uang Pas'),
                                      onPressed: () =>
                                          _setQuickCash(totalAmount),
                                    ),
                                    const SizedBox(width: 6),
                                    ActionChip(
                                      label: const Text('Rp20.000'),
                                      onPressed: () => _setQuickCash(20000),
                                    ),
                                    const SizedBox(width: 6),
                                    ActionChip(
                                      label: const Text('Rp50.000'),
                                      onPressed: () => _setQuickCash(50000),
                                    ),
                                    const SizedBox(width: 6),
                                    ActionChip(
                                      label: const Text('Rp100.000'),
                                      onPressed: () => _setQuickCash(100000),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total ($totalQty Tiket dibayar)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              '$totalVisitors pengunjung • $totalDiscount gratis',
                              style: const TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                            Text(
                              _currencyFormat.format(totalAmount),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: (_isProcessing || totalQty <= 0)
                              ? null
                              : () => _processCheckout(activeTickets),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.point_of_sale),
                          label: const Text(
                            'Bayar & Cetak',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildShiftHistoryTab() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Gagal memuat riwayat shift: ${snapshot.error}'),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        final todayMyDocs = allDocs.where((doc) {
          final data = doc.data();
          final ts = data['createdAt'] as Timestamp?;
          final isToday = ts != null && ts.toDate().isAfter(startOfDay);
          final isMyTx = data['cashierId'] == currentUid;
          return isToday && isMyTx;
        }).toList();

        int cashTotal = 0;
        int qrisTotal = 0;
        for (final doc in todayMyDocs) {
          final data = doc.data();
          final amount = (data['totalAmount'] as num? ?? 0).toInt();
          if (data['paymentMethod'] == 'QRIS') {
            qrisTotal += amount;
          } else {
            cashTotal += amount;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: const Color(0xFFE8F5E9),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Setoran Shift Hari Ini',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Uang Tunai di Laci:'),
                        Text(
                          _currencyFormat.format(cashTotal),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Pembayaran QRIS:'),
                        Text(
                          _currencyFormat.format(qrisTotal),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total (${todayMyDocs.length} Transaksi):',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _currencyFormat.format(cashTotal + qrisTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Daftar Transaksi Shift Ini (Ketuk untuk Struk)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (todayMyDocs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('Belum ada transaksi pada shift hari ini.'),
                ),
              )
            else
              ...todayMyDocs.map((doc) {
                final data = doc.data();
                final ts = data['createdAt'] as Timestamp?;
                final dt = ts?.toDate() ?? DateTime.now();
                final rawItems = (data['items'] as List<dynamic>? ?? [])
                    .map(
                      (e) =>
                          Map<String, dynamic>.from(e as Map<String, dynamic>),
                    )
                    .toList();

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade50,
                      child: const Icon(
                        Icons.receipt,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    title: Text(
                      data['invoiceNumber'] ?? doc.id,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${DateFormat('HH:mm').format(dt)} • ${data['paymentMethod']} • ${data['totalQty']} Tiket',
                    ),
                    trailing: Text(
                      _currencyFormat.format(data['totalAmount'] ?? 0),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    onTap: () => _showReceiptDialog(
                      invoiceNumber: data['invoiceNumber'] ?? doc.id,
                      items: rawItems,
                      totalAmount: (data['totalAmount'] as num? ?? 0).toInt(),
                      paymentMethod: data['paymentMethod'] ?? 'Tunai',
                      cashReceived: (data['cashReceived'] as num? ?? 0).toInt(),
                      changeAmount: (data['changeAmount'] as num? ?? 0).toInt(),
                      time: dt,
                      isReprint: true,
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
