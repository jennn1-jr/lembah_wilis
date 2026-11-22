import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class KasirHomeScreen extends StatelessWidget {
  final String userName;
  const KasirHomeScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Loket Kasir - $userName'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: const Center(
        child: Text('Halaman Transaksi Tiket Kasir Siap Dibangun!'),
      ),
    );
  }
}