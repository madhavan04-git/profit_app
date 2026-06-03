// lib/screens/settings_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper.instance;
  bool _backingUp = false;
  bool _restoring = false;
  List<FileSystemEntity> _backupFiles = [];

  @override
  void initState() { super.initState(); _loadBackups(); }

  Future<void> _loadBackups() async {
    final files = await _listBackups();
    setState(() => _backupFiles = files);
  }

  Future<List<FileSystemEntity>> _listBackups() async {
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      if (!await dir.exists()) return [];
      return dir.listSync()
          .where((f) => f.path.contains('profit_backup'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
    } catch (_) { return []; }
  }

  Future<void> _backup() async {
    setState(() => _backingUp = true);
    try {
      final path = await _db.backupDatabase();
      final file = File(path);
      // Share the file
      await Share.shareXFiles([XFile(path)],
          text: 'Profit Tracker Backup — ${DateFormat('dd MMM yyyy').format(DateTime.now())}');
      await _loadBackups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Backup saved: ${path.split('/').last}'),
          backgroundColor: const Color(0xFF1A6B2A),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red));
    }
    setState(() => _backingUp = false);
  }

  Future<void> _restoreFromFile(String path) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore backup?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
          const SizedBox(height: 12),
          const Text('This will REPLACE all current data with the backup.\n\n'
              'Your current sales and products will be overwritten.\n\n'
              'This cannot be undone.',
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(path.split('/').last,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restore', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _restoring = true);
    final success = await _db.restoreDatabase(path);
    setState(() => _restoring = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? 'Restore successful! Restart the app.'
            : 'Restore failed. File may be corrupted.'),
        backgroundColor: success ? const Color(0xFF1A6B2A) : Colors.red,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  Future<void> _pickAndRestore() async {
    // Show available backup files
    if (_backupFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No backup files found in Downloads folder.')));
      return;
    }
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Select backup to restore',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._backupFiles.map((f) {
            final name = f.path.split('/').last;
            final date = _extractDateFromFilename(name);
            return ListTile(
              leading: const Icon(Icons.storage, color: Color(0xFF1F4E79)),
              title: Text(date, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(name, style: const TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _restoreFromFile(f.path);
              },
            );
          }),
        ]),
      ),
    );
  }

  String _extractDateFromFilename(String name) {
    // profit_backup_2025-01-15_10-30.db
    try {
      final parts = name.replaceAll('profit_backup_', '').replaceAll('.db', '');
      return parts.replaceAll('_', ' ').replaceAll('-', '/');
    } catch (_) { return name; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Backup & Restore ───────────────────────────────────────────
          _SectionHeader('Backup & Restore'),
          _SettingCard(children: [
            _SettingRow(
              icon: Icons.backup_outlined,
              iconColor: const Color(0xFF1F4E79),
              title: 'Backup data',
              subtitle: 'Save all sales data to Downloads folder.\nShare via WhatsApp, Drive, Email etc.',
              trailing: _backingUp
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : ElevatedButton.icon(
                      onPressed: _backup,
                      icon: const Icon(Icons.upload, size: 16),
                      label: const Text('Backup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F4E79),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
            ),
            const Divider(height: 1),
            _SettingRow(
              icon: Icons.restore_outlined,
              iconColor: Colors.orange,
              title: 'Restore from backup',
              subtitle: 'Restore data from a previous backup file.\n⚠ Warning: replaces all current data.',
              trailing: _restoring
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          color: Colors.orange))
                  : OutlinedButton.icon(
                      onPressed: _pickAndRestore,
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Restore'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
            ),
          ]),

          // ── Backup files found ────────────────────────────────────────
          if (_backupFiles.isNotEmpty) ...[
            const SizedBox(height: 6),
            _SettingCard(children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_backupFiles.length} backup file(s) found in Downloads',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1A6B2A),
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  ..._backupFiles.take(3).map((f) {
                    final name = f.path.split('/').last;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        const Icon(Icons.check_circle, size: 14, color: Color(0xFF1A6B2A)),
                        const SizedBox(width: 6),
                        Text(name, style: const TextStyle(fontSize: 11,
                            color: Color(0xFF555555))),
                      ]),
                    );
                  }),
                ]),
              ),
            ]),
          ],

          // ── How backup works ──────────────────────────────────────────
          const SizedBox(height: 8),
          _SettingCard(children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF1F4E79)),
                  SizedBox(width: 8),
                  Text('How backup works',
                      style: TextStyle(fontWeight: FontWeight.w600,
                          color: Color(0xFF1F4E79))),
                ]),
                const SizedBox(height: 8),
                _infoLine('Tap Backup → file saved to Downloads folder'),
                _infoLine('Share it via WhatsApp, Google Drive, Email, etc.'),
                _infoLine('If you reinstall the app, tap Restore'),
                _infoLine('Select the backup file → all data is recovered'),
                _infoLine('Backup file name: profit_backup_DATE.db'),
              ]),
            ),
          ]),

          // ── About ─────────────────────────────────────────────────────
          const SizedBox(height: 16),
          _SectionHeader('About'),
          _SettingCard(children: [
            _SettingRow(
              icon: Icons.app_shortcut,
              iconColor: const Color(0xFF1F4E79),
              title: 'Profit Tracker',
              subtitle: 'Version 2.0 — Personal Use\nSS & Brass daily profit calculator',
              trailing: const SizedBox.shrink(),
            ),
          ]),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _infoLine(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('• ', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
      Expanded(child: Text(text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF555555)))),
    ]),
  );
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4, left: 4),
    child: Text(text, style: const TextStyle(fontSize: 13,
        fontWeight: FontWeight.bold, color: Color(0xFF888888),
        letterSpacing: 0.5)),
  );
}

class _SettingCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFEEEEEE)),
    ),
    child: Column(children: children),
  );
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final Widget trailing;
  const _SettingRow({required this.icon, required this.iconColor,
      required this.title, required this.subtitle, required this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
      ])),
      const SizedBox(width: 12),
      trailing,
    ]),
  );
}