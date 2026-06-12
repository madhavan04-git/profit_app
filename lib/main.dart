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
            // User is logged in, go directly to HomeScreen
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}