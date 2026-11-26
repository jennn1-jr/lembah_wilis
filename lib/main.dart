import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'Screen/Auth/login_screen.dart';
import 'Screen/Loket/loket_screen.dart';
import 'Screen/Kasir/kasir_screen.dart';
import 'Screen/Pengelola/pengelola_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID', null);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const LembahWilisApp());
}

class LembahWilisApp extends StatelessWidget {
  const LembahWilisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wisata Lembah Wilis',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        final user = authSnapshot.data;

        if (user == null || user.email == null) {
          return const LoginScreen();
        }

        final email = user.email!.toLowerCase();

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(email)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingScreen();
            }

            if (userSnapshot.hasError) {
              return AccessErrorScreen(
                message:
                    'Gagal mengambil data akun. Periksa koneksi '
                    'internet dan izin Firestore.',
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const AccessErrorScreen(
                message:
                    'Data akun tidak ditemukan di Firestore. '
                    'Hubungi Pengelola.',
              );
            }

            final userData = userSnapshot.data!.data()!;

            final role = userData['role'] as String? ?? '';
            final name = userData['name'] as String? ?? email;

            switch (role) {
              case 'loket':
                return LoketScreen(userName: name);

              case 'kasir':
                return KasirScreen(userName: name);

              case 'pengelola':
                return PengelolaHomeScreen(userName: name);

              default:
                return const AccessErrorScreen(
                  message:
                      'Role akun tidak dikenali. '
                      'Hubungi Pengelola untuk memperbaiki '
                      'hak akses akun.',
                );
            }
          },
        );
      },
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class AccessErrorScreen extends StatelessWidget {
  final String message;

  const AccessErrorScreen({super.key, required this.message});

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Akses Tidak Tersedia',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Keluar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
