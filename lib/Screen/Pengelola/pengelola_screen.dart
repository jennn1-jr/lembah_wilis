import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PengelolaHomeScreen extends StatelessWidget {
  final String userName;
  const PengelolaHomeScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard Pengelola - $userName'),
        backgroundColor: const Color(0xFF0D47A1),
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
        child: Text('Dashboard Rekap & Harga Tiket Pengelola Siap Dibangun!'),
      ),
    );
  }
}