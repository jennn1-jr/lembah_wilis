
import 'package:flutter/material.dart';

class LoketScreen extends StatelessWidget {
  final String userName;

  const LoketScreen({
    super.key,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Petugas Loket'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () {
              // Fitur logout akan ditambahkan.
            },
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Selamat datang, $userName',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
