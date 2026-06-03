// lib/screens/login_screen.dart
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
  final _loginForm  = GlobalKey<FormState>();
  final _regForm    = GlobalKey<FormState>();

  // Login controllers
  final _lemail = TextEditingController();
  final _lpass  = TextEditingController();

  // Register controllers
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
    for (final c in [_lemail,_lpass,_rname,_remail,_rpass,_rpass2]) c.dispose();
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
    setState(() => _loading = false);
  }

  Future<void> _register() async {
    if (!_regForm.currentState!.validate()) return;
    if (_rpass.text != _rpass2.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseService.instance.register(
          _remail.text.trim(), _rpass.text, _rname.text.trim());
    } catch (e) {
      setState(() => _error = _friendlyError(e.toString()));
    }
    setState(() => _loading = false);
  }

  String _friendlyError(String e) {
    if (e.contains('user-not-found')) return 'No account found with this email.';
    if (e.contains('wrong-password')) return 'Incorrect password.';
    if (e.contains('email-already-in-use')) return 'Email already registered.';
    if (e.contains('weak-password')) return 'Password must be at least 6 characters.';
    if (e.contains('invalid-email')) return 'Invalid email address.';
    if (e.contains('network-request-failed')) return 'No internet connection.';
    return 'Error. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 32),
            // Logo area
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF1F4E79),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.trending_up, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Profit Tracker',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                    color: Color(0xFF1F4E79))),
            const Text('SS & Brass daily profit calculator',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
            const SizedBox(height: 32),

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
            const SizedBox(height: 24),

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
                  // ── LOGIN FORM ────────────────────────────────────────
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
                  // ── REGISTER FORM ─────────────────────────────────────
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
          filled: true, fillColor: Colors.white,
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
          labelText: label, prefixIcon: const Icon(Icons.lock_outline, size: 20),
          filled: true, fillColor: Colors.white,
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