// lib/screens/login_screen.dart
// My Pattarii — Login screen with branding

import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _loginForm = GlobalKey<FormState>();
  final _regForm   = GlobalKey<FormState>();

  final _lemail = TextEditingController();
  final _lpass  = TextEditingController();
  final _rname  = TextEditingController();
  final _remail = TextEditingController();
  final _rpass  = TextEditingController();
  final _rpass2 = TextEditingController();

  bool _loading = false;
  bool _showPass = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [_lemail, _lpass, _rname, _remail, _rpass, _rpass2]) c.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_loginForm.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseService.instance.login(_lemail.text.trim(), _lpass.text);
    } catch (e) {
      setState(() => _error = _friendlyError(e.toString()));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _register() async {
    if (!_regForm.currentState!.validate()) return;
    if (_rpass.text != _rpass2.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() { _loading = true; _error = null; });
try {
  await FirebaseService.instance.login(
    _lemail.text.trim(),
    _lpass.text,
  );

  if (!mounted) return;
} catch (e) {
  if (!mounted) return;

  setState(() {
    _error = _friendlyError(e.toString());
  });
} finally {
  if (mounted) {
    setState(() {
      _loading = false;
    });
  }
}
    if (mounted) setState(() => _loading = false);
  }

  String _friendlyError(String e) {
    if (e.contains('user-not-found'))       return 'No account found with this email.';
    if (e.contains('wrong-password'))       return 'Incorrect password.';
    if (e.contains('email-already-in-use')) return 'Email already registered.';
    if (e.contains('weak-password'))        return 'Password must be at least 6 characters.';
    if (e.contains('invalid-email'))        return 'Invalid email address.';
    if (e.contains('network-request-failed')) return 'No internet connection.';
    return 'Error. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 32),

            // ── Logo ─────────────────────────────────────────────────────
           Container(
  width: 90,
  height: 90,
  // decoration: BoxDecoration(
  //   color: const Color(0xFF1F4E79),
  //   borderRadius: BorderRadius.circular(24),
  //   // boxShadow: [
  //   //   BoxShadow(
  //   //     color: const Color(0xFF1F4E79).withOpacity(0.3),
  //   //     blurRadius: 16,
  //   //     offset: const Offset(0, 6),
  //   //   )
  //   // ],
  // ),
  child: Center(
    child: Padding(
      padding: const EdgeInsets.all(14), // 👈 controls spacing
      child: Image.asset(
        'assets/icon/logo4.png',
        fit: BoxFit.contain, // 👈 IMPORTANT
      ),
    ),
  ),
),
            const SizedBox(height: 16),

            // ── App name ──────────────────────────────────────────────────
            const Text('My Pattariii',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                    color: Color(0xFF1F4E79), letterSpacing: 0.5)),
            const SizedBox(height: 4),
            const Text('SS & Brass daily profit calculator',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
            const SizedBox(height: 32),

            // ── Card ──────────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05),
                        blurRadius: 12, offset: const Offset(0, 4))
                  ]),
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                // Tab bar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabs,
                    indicator: BoxDecoration(
                      color: const Color(0xFF1F4E79),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF888888),
                    tabs: const [Tab(text: 'Login'), Tab(text: 'Register')],
                    padding: const EdgeInsets.all(4),
                    dividerColor: Colors.transparent,
                  ),
                ),
                const SizedBox(height: 20),

                // Error
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCCCC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(color: Color(0xFFBB3333), fontSize: 13)),
                  ),

                SizedBox(
                  height: 360,
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      // ── LOGIN ─────────────────────────────────────────
                      Form(
                        key: _loginForm,
                        child: Column(children: [
                          _field(_lemail, 'Email', Icons.email_outlined,
                              type: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          _passField(_lpass, 'Password'),
                          const SizedBox(height: 24),
                          _submitBtn('Login', _login),
                        ]),
                      ),
                      // ── REGISTER ──────────────────────────────────────
                      Form(
                        key: _regForm,
                        child: Column(children: [
                          _field(_rname, 'Your name', Icons.person_outline),
                          const SizedBox(height: 12),
                          _field(_remail, 'Email', Icons.email_outlined,
                              type: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          _passField(_rpass, 'Password (min 6 chars)'),
                          const SizedBox(height: 12),
                          _passField(_rpass2, 'Confirm password'),
                          const SizedBox(height: 24),
                          _submitBtn('Create account', _register),
                        ]),
                      ),
                    ],
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 24),
            // License note
            const Text('Licensed device only — contact owner to register',
                style: TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icon, size: 20),
          filled: true, fillColor: const Color(0xFFF5F6FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
        ),
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      );

  Widget _passField(TextEditingController ctrl, String label) =>
      TextFormField(
        controller: ctrl,
        obscureText: !_showPass,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline, size: 20),
          filled: true, fillColor: const Color(0xFFF5F6FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
          suffixIcon: IconButton(
            icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, size: 20),
            onPressed: () => setState(() => _showPass = !_showPass),
          ),
        ),
        validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
      );

  Widget _submitBtn(String label, VoidCallback onTap) => SizedBox(
    width: double.infinity, height: 52,
    child: ElevatedButton(
      onPressed: _loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _loading
          ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ),
  );
}