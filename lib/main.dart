import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'Screen/auth/login_screen.dart';
import 'Screen/Kasir/kasir_screen.dart';
import 'Screen/Pengelola/pengelola_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const LembahWilisApp());
}

class LembahWilisApp extends StatelessWidget {
  const LembahWilisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lembah Wilis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
        useMaterial3: true,
      ),
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = authSnapshot.data;
        if (user == null || user.email == null) {
          return const LoginScreen();
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.email!.toLowerCase())
              .get(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!roleSnapshot.hasData || !roleSnapshot.data!.exists) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Data peran untuk ${user.email} tidak ditemukan.'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text('Kembali ke Login'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = roleSnapshot.data!.data() as Map<String, dynamic>;
            final role = data['role'] ?? 'kasir';
            final name = data['name'] ?? user.email!;

            if (role == 'pengelola') {
              return PengelolaHomeScreen(userName: name);
            }
            return KasirHomeScreen(userName: name);
          },
        );
      },
    );
  }
}