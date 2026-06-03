// lib/main.dart
// My Pattarii — SS & Brass Profit Tracker

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyPattariiApp());
}

class MyPattariiApp extends StatelessWidget {
  const MyPattariiApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Pattarii',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F4E79)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Color(0xFF1F4E79),
          titleTextStyle: TextStyle(
            color: Color(0xFF1F4E79),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasData && snap.data != null) {
            return const _DeviceLicenseGate();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

// ── Device License Gate ───────────────────────────────────────────────────────
// After login, check if this device is licensed before showing HomeScreen.
// If not licensed, show a locked screen.
class _DeviceLicenseGate extends StatefulWidget {
  const _DeviceLicenseGate();
  @override State<_DeviceLicenseGate> createState() => _DeviceLicenseGateState();
}
class _DeviceLicenseGateState extends State<_DeviceLicenseGate> {
  bool _checking = true;
  bool _licensed = false;

  @override
  void initState() { super.initState(); _check(); }

  Future<void> _check() async {
    final ok = await FirebaseService.instance.isDeviceLicensed();
    setState(() { _licensed = ok; _checking = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_licensed) return const HomeScreen();
    return _UnlicensedScreen();
  }
}

// ── Unlicensed device screen ──────────────────────────────────────────────────
class _UnlicensedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 80, height: 80,
              decoration: BoxDecoration(color: const Color(0xFFFFCCCC),
                  borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.lock_outline, size: 44, color: Colors.red)),
            const SizedBox(height: 24),
            const Text('Device Not Licensed',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                    color: Color(0xFFCC3333))),
            const SizedBox(height: 12),
            const Text(
              'This account is registered on a different device.\n\n'
              'My Pattarii is licensed per device. Contact the app owner to register this device.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF555555), height: 1.6),
            ),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: () => FirebaseService.instance.logout(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F4E79),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}