// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/ai_language.dart';
import '../services/ai_service.dart';
import '../services/firebase_service.dart';
import 'account_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _svc = FirebaseService.instance;
  final _auth = FirebaseAuth.instance;

  // ── Personal Info ──────────────────────────────────────────────────────────
  final _shopNameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  bool _savingInfo = false;
  String _avatarLetter = 'U';
  String _profileName = 'User';
  String _profileEmail = '';

  // ── Change Password ────────────────────────────────────────────────────────
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _savingPass = false;
  bool _showCurrentPass = false;
  bool _showNewPass = false;
  bool _showConfirmPass = false;

  // ── Inventory Settings ─────────────────────────────────────────────────────
  AppSettings _settings = const AppSettings();
  bool _loadingSettings = true;
  bool _savingSettings = false;
  final _thresholdCtrl = TextEditingController();
  final Map<RawMaterialType, TextEditingController> _rateCtrls = {
    for (final m in RawMaterialType.values) m: TextEditingController(),
  };

  // ── AI Assistant ───────────────────────────────────────────────────────────
  final _aiKeyCtrl = TextEditingController();
  bool _savingAiKey = false;
  bool _showAiKey = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _displayNameCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _thresholdCtrl.dispose();
    _aiKeyCtrl.dispose();
    for (final c in _rateCtrls.values) c.dispose();
    super.dispose();
  }

  // FIXED: Get user info directly from Firebase Auth, not from PigUser
  void _refreshUserDisplay() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Use the displayName directly from Firebase Auth
    final name = user.displayName ?? '';
    final email = user.email ?? '';

    setState(() {
      _profileName = name.isNotEmpty ? name : 'User';
      _profileEmail = email;
      _avatarLetter =
          (name.isNotEmpty ? name[0] : (email.isNotEmpty ? email[0] : 'U'))
              .toUpperCase();
    });
  }

  Future<void> _loadAll() async {
    // Get fresh user data directly from Firebase Auth
    _refreshUserDisplay();

    final user = _auth.currentUser;
    _displayNameCtrl.text = user?.displayName ?? '';

    // Load pattarai / shop name
    try {
      final pattarais = await _svc.getPattarais();
      if (pattarais.isNotEmpty) {
        _shopNameCtrl.text = pattarais.first.name;
      }
    } catch (e) {
      debugPrint('Load pattarais error: $e');
    }

    // Load app settings
    try {
      final settings = await _svc.getAppSettings();
      _thresholdCtrl.text = settings.lowStockThresholdKg > 0
          ? settings.lowStockThresholdKg.toStringAsFixed(0)
          : '';
      for (final m in RawMaterialType.values) {
        final v = settings.defaultRatesPerKg[m.displayName];
        _rateCtrls[m]!.text = (v != null && v > 0) ? v.toStringAsFixed(0) : '';
      }
      _aiKeyCtrl.text = settings.geminiApiKey;
      setState(() {
        _settings = settings;
        _loadingSettings = false;
      });
    } catch (e) {
      debugPrint('Load settings error: $e');
      setState(() => _loadingSettings = false);
    }
  }

  // ── Save personal info (FIXED) ────────────────────────────────────────────
  Future<void> _savePersonalInfo() async {
    final shopName = _shopNameCtrl.text.trim();
    final displayName = _displayNameCtrl.text.trim();

    if (shopName.isEmpty) {
      _snack('Please enter your shop / Pattarai name');
      return;
    }
    setState(() => _savingInfo = true);
    try {
      // 1. Update Firebase Auth display name
      final user = _auth.currentUser;
      if (user != null &&
          displayName.isNotEmpty &&
          displayName != user.displayName) {
        await user.updateDisplayName(displayName);
        // IMPORTANT: Reload to get fresh data
        await user.reload();
        // Force refresh the display
        _refreshUserDisplay();
      }

      // 2. Rename the main pattarai (the one shown in the greeting).
      //
      // This used to delete every other pattarai to "clean up duplicates".
      // It must not: pattarais now carry their own sheet/wastage ledger, so
      // deleting one here would silently destroy that history. Extra
      // pattarais are managed in Inventory → Sheet / Wastage.
      final existing = await _svc.getPattarais();
      if (existing.isNotEmpty && existing.first.id != null) {
        await _svc.savePattarai(Pattarai(
          id: existing.first.id,
          name: shopName,
          isActive: true,
          sortOrder: existing.first.sortOrder,
        ));
      } else {
        // First time — create the single entry
        await _svc.savePattarai(
            Pattarai(name: shopName, isActive: true, sortOrder: 0));
      }

      // 3. Force refresh the UI
      _refreshUserDisplay();
      _snack('Shop name saved!');

      // Update the home screen greeting by reloading the pattarai name
      // This ensures the change is visible immediately
      final updatedPattarais = await _svc.getPattarais();
      if (updatedPattarais.isNotEmpty) {
        // The home screen will reload when we navigate back
      }
    } catch (e) {
      _snack('Failed to save: ${e.toString().replaceAll('Exception: ', '')}');
    }
    setState(() => _savingInfo = false);
  }

  // ── Change password ────────────────────────────────────────────────────────
  Future<void> _changePassword() async {
    final current = _currentPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _snack('Please fill in all password fields');
      return;
    }
    if (newPass.length < 6) {
      _snack('New password must be at least 6 characters');
      return;
    }
    if (newPass != confirm) {
      _snack('New passwords do not match');
      return;
    }

    setState(() => _savingPass = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      final email = user.email;
      if (email == null || email.isEmpty)
        throw Exception('No email on account');

      // Re-authenticate with current password
      final cred =
          EmailAuthProvider.credential(email: email, password: current);
      await user.reauthenticateWithCredential(cred);

      // Now update password
      await user.updatePassword(newPass);

      // Reload so the session stays valid
      await user.reload();

      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      _snack('Password changed successfully!');
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-password':
          _snack('Current password is incorrect. Please try again.');
          break;
        case 'too-many-requests':
          _snack('Too many attempts. Please wait and try again.');
          break;
        case 'requires-recent-login':
          _snack('Session expired. Please log out and log back in.');
          break;
        case 'weak-password':
          _snack('New password is too weak. Use at least 6 characters.');
          break;
        default:
          _snack('Error: ${e.message ?? e.code}');
      }
    } catch (e) {
      _snack('Error: ${e.toString().replaceAll('Exception: ', '')}');
    }
    setState(() => _savingPass = false);
  }

  // ── Save inventory settings ────────────────────────────────────────────────
  Future<void> _saveAdvancedSettings() async {
    setState(() => _savingSettings = true);
    try {
      final threshold = double.tryParse(_thresholdCtrl.text) ?? 0;
      final rates = <String, double>{};
      for (final m in RawMaterialType.values) {
        final v = double.tryParse(_rateCtrls[m]!.text) ?? 0;
        if (v > 0) rates[m.displayName] = v;
      }
      // copyWith, not a fresh AppSettings — a plain constructor here would
      // silently wipe the saved AI key.
      final newSettings = _settings.copyWith(
        lowStockThresholdKg: threshold,
        defaultRatesPerKg: rates,
      );
      await _svc.saveAppSettings(newSettings);
      setState(() => _settings = newSettings);
      _snack('Settings saved');
    } catch (e) {
      _snack('Error saving settings: $e');
    }
    setState(() => _savingSettings = false);
  }

  // ── Save the Gemini API key ────────────────────────────────────────────────
  Future<void> _saveAiKey() async {
    setState(() => _savingAiKey = true);
    try {
      final newSettings =
          _settings.copyWith(geminiApiKey: _aiKeyCtrl.text.trim());
      await _svc.saveAppSettings(newSettings);
      AiService.instance.invalidateSettings();
      setState(() => _settings = newSettings);
      _snack(_aiKeyCtrl.text.trim().isEmpty
          ? 'AI key cleared'
          : 'AI key saved — assistant is ready');
    } catch (e) {
      _snack('Error saving AI key: $e');
    }
    setState(() => _savingAiKey = false);
  }

  // ── Save the answer language ───────────────────────────────────────────────
  Future<void> _saveAiLanguage(String pref) async {
    final previous = _settings;
    setState(() => _settings = _settings.copyWith(aiLanguage: pref));
    try {
      await _svc.saveAppSettings(_settings);
      AiService.instance.invalidateSettings();
      _snack('Answers in ${AiLangPref.label(pref)}');
    } catch (e) {
      setState(() => _settings = previous); // put the chip back
      _snack('Could not save language: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profile avatar banner ─────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F4E79), Color(0xFF2E6FA8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  _avatarLetter,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              Text(_profileName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(_profileEmail,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.75), fontSize: 12)),
            ]),
          ),

          // ── Account (business details: PAN, GST, bank, QR) ─────────────────
          _sectionTitle('Account', Icons.account_circle_outlined),
          const SizedBox(height: 10),
          _card(children: [
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              ),
              borderRadius: BorderRadius.circular(10),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE6F1FB),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.storefront_outlined,
                      size: 18, color: Color(0xFF1F4E79)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Business Details',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      SizedBox(height: 2),
                      Text('PAN, GST, address, bank details & payment QR',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF888888))),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF888888)),
              ]),
            ),
          ]),
          const SizedBox(height: 24),

          // ── Personal Info ─────────────────────────────────────────────────
          _sectionTitle('Personal Info', Icons.person_outline),
          const SizedBox(height: 10),
          _card(children: [
            _field(
              controller: _shopNameCtrl,
              label: 'Shop / Pattarai Name',
              hint: 'e.g. Sri Murugan Pattarai',
              icon: Icons.storefront_outlined,
              helper: 'Shows as the greeting on the home screen',
            ),
            const SizedBox(height: 14),
            _field(
              controller: _displayNameCtrl,
              label: 'Your Name',
              hint: 'e.g. Mathavan',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 14),
            _field(
              label: 'Email',
              hint: _profileEmail,
              icon: Icons.email_outlined,
              enabled: false,
            ),
            const SizedBox(height: 18),
            _saveBtn(
              label: 'Save Info',
              loading: _savingInfo,
              onPressed: _savePersonalInfo,
            ),
          ]),
          const SizedBox(height: 24),

          // ── Change Password ───────────────────────────────────────────────
          _sectionTitle('Change Password', Icons.lock_outline),
          const SizedBox(height: 10),
          _card(children: [
            _passField(
              controller: _currentPassCtrl,
              label: 'Current Password',
              show: _showCurrentPass,
              onToggle: () =>
                  setState(() => _showCurrentPass = !_showCurrentPass),
            ),
            const SizedBox(height: 14),
            _passField(
              controller: _newPassCtrl,
              label: 'New Password',
              show: _showNewPass,
              onToggle: () => setState(() => _showNewPass = !_showNewPass),
            ),
            const SizedBox(height: 14),
            _passField(
              controller: _confirmPassCtrl,
              label: 'Confirm New Password',
              show: _showConfirmPass,
              onToggle: () =>
                  setState(() => _showConfirmPass = !_showConfirmPass),
            ),
            const SizedBox(height: 18),
            _saveBtn(
              label: 'Change Password',
              loading: _savingPass,
              onPressed: _changePassword,
              color: const Color(0xFF1A6B2A),
            ),
          ]),
          const SizedBox(height: 24),

          // ── Inventory Settings ────────────────────────────────────────────
          _sectionTitle('Inventory Settings', Icons.tune_outlined),
          const SizedBox(height: 10),
          _card(children: [
            if (_loadingSettings)
              const Center(child: CircularProgressIndicator())
            else ...[
              const Text('Low stock alert threshold',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              const Text(
                'Highlight a material in red when stock falls below this kg. Leave blank to disable.',
                style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 8),
              _field(
                controller: _thresholdCtrl,
                label: 'Threshold (kg)',
                icon: Icons.warning_amber_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              const Text('Default raw material rates (₹/kg)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              const Text(
                'Pre-fills the rate when adding a purchase. Leave blank to enter manually.',
                style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 10),
              ...RawMaterialType.values.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _field(
                      controller: _rateCtrls[m],
                      label: '${m.displayName} rate (₹/kg)',
                      icon: Icons.price_change_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  )),
              _saveBtn(
                label: 'Save Settings',
                loading: _savingSettings,
                onPressed: _saveAdvancedSettings,
                color: const Color(0xFF7B4F06),
              ),
            ],
          ]),
          const SizedBox(height: 24),

          // ── AI Assistant ──────────────────────────────────────────────────
          _sectionTitle('AI Assistant', Icons.auto_awesome),
          const SizedBox(height: 10),
          _card(children: [
            const Text('Google Gemini API key',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            const Text(
              'The assistant reads your sales, expenses, buyers and stock, then '
              'answers your questions in Tamil, Tanglish or English.\n\n'
              'Get a FREE key at aistudio.google.com/apikey — sign in, tap '
              '"Create API key", copy and paste it below. No credit card needed.',
              style: TextStyle(fontSize: 11, color: Color(0xFF888888), height: 1.45),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _aiKeyCtrl,
              obscureText: !_showAiKey,
              decoration: InputDecoration(
                labelText: 'Gemini API key',
                hintText: 'AIza...',
                prefixIcon: const Icon(Icons.key_outlined, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                      _showAiKey ? Icons.visibility_off : Icons.visibility,
                      size: 20),
                  onPressed: () => setState(() => _showAiKey = !_showAiKey),
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _settings.geminiApiKey.isNotEmpty
                  ? 'A key is saved. Leave the box empty and save to remove it.'
                  : 'No key saved yet — the assistant will use the key built '
                      'into the app, if one was added.',
              style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 18),
            const Text('Answer language',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            const Text(
              'Auto follows the language you type in — Tamil question gets a '
              'Tamil answer, Tanglish gets Tanglish.',
              style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final p in AiLangPref.all)
                  ChoiceChip(
                    label: Text(AiLangPref.label(p)),
                    selected: _settings.aiLanguage == p,
                    onSelected: (_) => _saveAiLanguage(p),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Simple questions (profit, pending, stock, expenses) are answered '
              'straight from your own records — instantly, with no internet and '
              'without using any AI quota. Only questions that need real thinking '
              'go to the AI, so the free limit lasts a long time.',
              style: TextStyle(fontSize: 11, color: Color(0xFF1A6B2A), height: 1.45),
            ),
            const SizedBox(height: 14),
            _saveBtn(
              label: 'Save AI Key',
              loading: _savingAiKey,
              onPressed: _saveAiKey,
              color: const Color(0xFF4A2B7B),
            ),
          ]),
          const SizedBox(height: 24),

          // ── Help ──────────────────────────────────────────────────────────
          // ── Help & Info ──────────────────────────────────────────────────────────
          _sectionTitle('Help & Info', Icons.help_outline),
          const SizedBox(height: 10),
          _card(children: [
            _helpTile(Icons.storefront_outlined, '🏪 Your Shop Identity',
                'Set your shop name above — it\'s the first thing you\'ll see every day on the home screen. This name travels with every sale you make, every receipt you generate. Think of it as your digital storefront, always open, always welcoming. Make it something you\'re proud of — because this is your business, your legacy, your everyday story.'),
            const Divider(height: 16),
            _helpTile(Icons.inventory_2_outlined, '📦 Smart Stock Management',
                'Every purchase you add in the Investment screen becomes part of your living inventory. When you record a sale, sheet is automatically deducted — no math, no mistakes. Running low? The system highlights it in red, so you\'ll never be caught off guard. It\'s like having a silent partner who always remembers. Simple. Reliable. Always watching out for you.'),
            const Divider(height: 16),
            _helpTile(Icons.people_outline, '👥 Buyers & Fair Balances',
                'Record every person who buys from you. If someone gives you sheet instead of cash, mark it as a Party purchase in Investment — their balance gets used first in their next sale. This keeps everything transparent and fair. Because business isn\'t just about numbers — it\'s about relationships, trust, and keeping your word. And that matters.'),
            const Divider(height: 16),
            _helpTile(Icons.family_restroom_outlined, '❤️ Made for Our People',
                'This app carries the spirit of everyone who made it possible. Ram, who taught us that hard work never goes unnoticed. Vicky, who showed us that care makes everything better. Deepi, who believes in keeping things organized and right. Maddy, who turned ideas into reality. And Jaan, who reminds us daily that joy is the real reward. This one\'s for all of you — always.'),
            const Divider(height: 16),
            _helpTile(Icons.lock_outline, '🔑 Password Help Made Easy',
                'Change your password anytime using the section above — you\'ll need your current one. If you\'ve completely forgotten it (happens to the best of us!), just log out and tap "Forgot password" on the login screen. We\'ll send a reset link to your email. Simple. Secure. You\'ll be back in seconds. No stress, no hassle.'),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────

  Widget _sectionTitle(String text, IconData icon) => Row(children: [
        Icon(icon, size: 18, color: const Color(0xFF1F4E79)),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F4E79))),
      ]);

  Widget _card({required List<Widget> children}) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      );

  Widget _field({
    TextEditingController? controller,
    required String label,
    String? hint,
    IconData? icon,
    String? helper,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) =>
      TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 2,
          prefixIcon: icon != null
              ? Icon(icon, size: 20, color: const Color(0xFF1F4E79))
              : null,
          filled: true,
          fillColor: enabled ? const Color(0xFFF5F6FA) : Colors.grey.shade100,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF1F4E79), width: 1.5)),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );

  Widget _passField({
    required TextEditingController controller,
    required String label,
    required bool show,
    required VoidCallback onToggle,
  }) =>
      TextField(
        controller: controller,
        obscureText: !show,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline,
              size: 20, color: Color(0xFF1F4E79)),
          suffixIcon: IconButton(
            icon: Icon(
                show
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: Colors.grey),
            onPressed: onToggle,
          ),
          filled: true,
          fillColor: const Color(0xFFF5F6FA),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF1F4E79), width: 1.5)),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );

  Widget _saveBtn({
    required String label,
    required bool loading,
    required VoidCallback onPressed,
    Color color = const Color(0xFF1F4E79),
  }) =>
      SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      );

  Widget _helpTile(IconData icon, String title, String body) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFFE6F1FB),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: const Color(0xFF1F4E79)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              Text(body,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF666666), height: 1.4)),
            ]),
          ),
        ],
      );
}