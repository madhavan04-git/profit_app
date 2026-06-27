// lib/screens/account_screen.dart
//
// Business / Account details sub-screen — opened from Settings.
// Stores: business name, PAN, GST, address, phone, bank details,
// and a payment QR (either an uploaded image OR auto-generated from a UPI ID).
//
// ── SETUP NEEDED (one-time) ─────────────────────────────────────────────────
// 1. Add these to pubspec.yaml, under dependencies:
//      image_picker: ^1.1.2
//      qr_flutter: ^4.1.0
//    then run: flutter pub get
//
// 2. Add the BusinessProfile model from models_addition.dart into your
//    models.dart file.
//
// 3. Add the getBusinessProfile()/saveBusinessProfile()/updateSale() methods
//    from the updated firebase_service.dart into your FirebaseService class
//    (already done for you if you're using the firebase_service.dart file
//    provided alongside this one).
//
// 4. iOS only — add these two keys to ios/Runner/Info.plist so photo-library
//    access works for picking the QR image:
//      <key>NSPhotoLibraryUsageDescription</key>
//      <string>Used to pick your payment QR code image</string>
//      <key>NSCameraUsageDescription</key>
//      <string>Used to take a photo of your QR code</string>
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _svc = FirebaseService.instance;

  final _businessNameCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bankHolderCtrl = TextEditingController();
  final _bankAccountCtrl = TextEditingController();
  final _bankIfscCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String _qrImageBase64 = ''; // uploaded QR, if any

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _panCtrl.dispose();
    _gstCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _bankHolderCtrl.dispose();
    _bankAccountCtrl.dispose();
    _bankIfscCtrl.dispose();
    _bankNameCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await _svc.getBusinessProfile();
      _businessNameCtrl.text = p.businessName;
      _panCtrl.text = p.pan;
      _gstCtrl.text = p.gst;
      _addressCtrl.text = p.address;
      _phoneCtrl.text = p.phone;
      _bankHolderCtrl.text = p.bankAccountHolder;
      _bankAccountCtrl.text = p.bankAccountNumber;
      _bankIfscCtrl.text = p.bankIfsc;
      _bankNameCtrl.text = p.bankName;
      _upiCtrl.text = p.upiId;
      _qrImageBase64 = p.qrImageBase64;
    } catch (e) {
      _snack('Failed to load: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final profile = BusinessProfile(
        businessName: _businessNameCtrl.text.trim(),
        pan: _panCtrl.text.trim().toUpperCase(),
        gst: _gstCtrl.text.trim().toUpperCase(),
        address: _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        bankAccountHolder: _bankHolderCtrl.text.trim(),
        bankAccountNumber: _bankAccountCtrl.text.trim(),
        bankIfsc: _bankIfscCtrl.text.trim().toUpperCase(),
        bankName: _bankNameCtrl.text.trim(),
        upiId: _upiCtrl.text.trim(),
        qrImageBase64: _qrImageBase64,
      );
      await _svc.saveBusinessProfile(profile);
      _snack('Business details saved!');
    } catch (e) {
      _snack('Failed to save: $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickQrImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 900000) {
        _snack('Image too large — please choose a smaller one.');
        return;
      }
      setState(() => _qrImageBase64 = base64Encode(bytes));
    } catch (e) {
      _snack('Could not pick image: $e');
    }
  }

  void _removeQrImage() {
    setState(() => _qrImageBase64 = '');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Account / Business Details'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle('Business Info', Icons.storefront_outlined),
                const SizedBox(height: 10),
                _card(children: [
                  _field(
                    controller: _businessNameCtrl,
                    label: 'Business Name',
                    hint: 'e.g. Sri Murugan Pattarai',
                    icon: Icons.business_outlined,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _addressCtrl,
                    label: 'Address',
                    hint: 'Shop address',
                    icon: Icons.location_on_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _phoneCtrl,
                    label: 'Phone',
                    hint: 'e.g. 9876543210',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ]),
                const SizedBox(height: 24),

                _sectionTitle('Tax Details', Icons.receipt_long_outlined),
                const SizedBox(height: 10),
                _card(children: [
                  _field(
                    controller: _panCtrl,
                    label: 'PAN Number',
                    hint: 'e.g. ABCDE1234F',
                    icon: Icons.badge_outlined,
                    textCapitalization: TextCapitalization.characters,
                    helper: 'Shown to customers when asked',
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _gstCtrl,
                    label: 'GST Number',
                    hint: 'e.g. 33ABCDE1234F1Z5',
                    icon: Icons.confirmation_number_outlined,
                    textCapitalization: TextCapitalization.characters,
                  ),
                ]),
                const SizedBox(height: 24),

                _sectionTitle('Bank Details', Icons.account_balance_outlined),
                const SizedBox(height: 10),
                _card(children: [
                  _field(
                    controller: _bankHolderCtrl,
                    label: 'Account Holder Name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _bankAccountCtrl,
                    label: 'Account Number',
                    icon: Icons.numbers_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _bankIfscCtrl,
                    label: 'IFSC Code',
                    icon: Icons.account_tree_outlined,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _bankNameCtrl,
                    label: 'Bank Name & Branch',
                    icon: Icons.account_balance_outlined,
                  ),
                ]),
                const SizedBox(height: 24),

                _sectionTitle('Payment QR', Icons.qr_code_2_outlined),
                const SizedBox(height: 10),
                _card(children: [
                  _field(
                    controller: _upiCtrl,
                    label: 'UPI ID',
                    hint: 'e.g. yourname@upi',
                    icon: Icons.account_balance_wallet_outlined,
                    helper: 'Used to auto-generate a QR if you don\'t upload one',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 18),
                  Center(child: _buildQrPreview()),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickQrImage,
                        icon: const Icon(Icons.upload_outlined, size: 18),
                        label: const Text('Upload QR Image'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1F4E79),
                            side: const BorderSide(color: Color(0xFF1F4E79))),
                      ),
                    ),
                    if (_qrImageBase64.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: _removeQrImage,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red)),
                        child: const Icon(Icons.delete_outline, size: 18),
                      ),
                    ],
                  ]),
                  if (_qrImageBase64.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Showing your uploaded QR image.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
                      ),
                    )
                  else if (_upiCtrl.text.trim().isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Auto-generated from your UPI ID above.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
                      ),
                    ),
                ]),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F4E79),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save Business Details',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  // ── QR preview: uploaded image takes priority, else auto-generate from UPI ID ──
  Widget _buildQrPreview() {
    if (_qrImageBase64.isNotEmpty) {
      Uint8List? bytes;
      try {
        bytes = base64Decode(_qrImageBase64);
      } catch (_) {
        bytes = null;
      }
      if (bytes != null) {
        return Container(
          width: 200,
          height: 200,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEEEE))),
          child: Image.memory(bytes, fit: BoxFit.contain),
        );
      }
    }

    final upi = _upiCtrl.text.trim();
    if (upi.isEmpty) {
      return Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(12)),
        child: const Center(
          child: Text(
            'Enter a UPI ID or\nupload a QR image',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
          ),
        ),
      );
    }

    final upiUri = 'upi://pay?pa=$upi'
        '${_businessNameCtrl.text.trim().isNotEmpty ? '&pn=${Uri.encodeComponent(_businessNameCtrl.text.trim())}' : ''}';

    return Container(
      width: 200,
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE))),
      child: QrImageView(
        data: upiUri,
        version: QrVersions.auto,
        backgroundColor: Colors.white,
      ),
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────
  Widget _sectionTitle(String text, IconData icon) => Row(children: [
        Icon(icon, size: 18, color: const Color(0xFF1F4E79)),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F4E79))),
      ]);

  Widget _card({required List<Widget> children}) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      );

  Widget _field({
    TextEditingController? controller,
    required String label,
    String? hint,
    String? helper,
    IconData? icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 2,
          prefixIcon: icon != null
              ? Icon(icon, size: 20, color: const Color(0xFF1F4E79))
              : null,
          filled: true,
          fillColor: const Color(0xFFF5F6FA),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1F4E79), width: 1.5)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );
}