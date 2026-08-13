// lib/screens/ai_assistant_screen.dart
// Chat with an assistant that can see the shop's live figures, in Tamil,
// Tanglish or English — plus a one-tap "Insights" review.
//
// Simple questions are answered offline from the shop's own numbers (marked
// with a ⚡ badge), so the free AI quota is only spent where it's needed.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ai_language.dart';
import '../services/ai_service.dart';
import '../services/firebase_service.dart';
import 'settings_screen.dart';

const _kPrimary = Color(0xFF1F4E79);

class _Msg {
  final String text;
  final bool fromUser;
  final bool usedAi;
  final String? note; // why the AI was skipped, when it was
  const _Msg(this.text,
      {required this.fromUser, this.usedAi = false, this.note});
}

class AiAssistantScreen extends StatefulWidget {
  /// When true the screen runs the Insights review as soon as it opens.
  final bool startWithInsights;
  const AiAssistantScreen({super.key, this.startWithInsights = false});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _ai = AiService.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();

  final List<_Msg> _messages = [];
  bool _busy = false;
  bool? _configured;
  String _lang = AiLangPref.auto;

  /// Deliberately mixed — shows the owner that every language works.
  static const _suggestions = [
    'Intha maasam profit evvalavu?',
    'Yaar kitta pending amount irruku?',
    'இந்த மாதம் எந்த பொருளில் லாபம் அதிகம்?',
    'Expenses la edhu adhigam poguthu?',
    'What should I do to increase profit?',
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final ok = await _ai.isConfigured;
    final lang = await _ai.languagePref;
    if (!mounted) return;
    setState(() {
      _configured = ok;
      _lang = lang;
    });
    if (widget.startWithInsights) _runInsights();
  }

  Future<void> _setLang(String pref) async {
    setState(() => _lang = pref);
    try {
      final svc = FirebaseService.instance;
      final current = await svc.getAppSettings();
      await svc.saveAppSettings(current.copyWith(aiLanguage: pref));
      _ai.invalidateSettings();
    } catch (_) {
      // Not saved (offline) — the choice still applies for this session.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Answers in ${AiLangPref.label(pref)}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<AiTurn> get _history => [
        for (final m in _messages) AiTurn(m.text, fromUser: m.fromUser),
      ];

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _busy) return;

    FocusScope.of(context).unfocus();
    final history = _history;
    setState(() {
      _messages.add(_Msg(text, fromUser: true));
      _input.clear();
      _busy = true;
    });
    _scrollToEnd();

    try {
      final reply = await _ai.ask(text, history: history);
      if (!mounted) return;
      setState(() => _messages.add(_Msg(reply.text,
          fromUser: false,
          usedAi: reply.usedAi,
          note: reply.fallbackReason)));
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_Msg(e.message, fromUser: false)));
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _messages.add(_Msg('Something went wrong: $e', fromUser: false)));
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  Future<void> _runInsights() async {
    if (_busy) return;
    setState(() {
      _messages.add(const _Msg('Business insights', fromUser: true));
      _busy = true;
    });
    _scrollToEnd();

    try {
      final reply = await _ai.insights();
      if (!mounted) return;
      setState(() => _messages.add(_Msg(reply.text,
          fromUser: false,
          usedAi: reply.usedAi,
          note: reply.fallbackReason)));
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_Msg(e.message, fromUser: false)));
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _messages.add(_Msg('Something went wrong: $e', fromUser: false)));
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Answer language',
            onSelected: _setLang,
            itemBuilder: (_) => [
              for (final p in AiLangPref.all)
                PopupMenuItem(
                  value: p,
                  child: Row(children: [
                    Icon(
                      p == _lang
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 18,
                      color: _kPrimary,
                    ),
                    const SizedBox(width: 10),
                    Text(AiLangPref.label(p)),
                  ]),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                const Icon(Icons.translate, size: 18),
                const SizedBox(width: 4),
                Text(AiLangPref.label(_lang),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'Clear chat',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _busy ? null : () => setState(_messages.clear),
            ),
        ],
      ),
      body: _chatBody(),
    );
  }

  Widget _chatBody() {
    return Column(children: [
      if (_configured == false) _noKeyBanner(),
      Expanded(child: _messages.isEmpty ? _emptyState() : _messageList()),
      if (_busy) const _ThinkingBar(),
      _inputBar(),
    ]);
  }

  // ── No key: a banner, not a wall. The offline answers still work. ──────────
  Widget _noKeyBanner() {
    return Material(
      color: const Color(0xFFFFF4E0),
      child: InkWell(
        onTap: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()));
          _ai.invalidateSettings();
          _init();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(children: [
            Icon(Icons.info_outline, size: 18, color: Colors.orange.shade800),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No AI key yet — basic questions still work offline. '
                'Add a free key in Settings for full answers.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: Colors.orange.shade800),
          ]),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      children: [
        const Icon(Icons.auto_awesome, size: 42, color: _kPrimary),
        const SizedBox(height: 12),
        const Text('Ungaloda kanakku pathi kelunga',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: _kPrimary)),
        const SizedBox(height: 6),
        const Text(
          'தமிழ் · Tanglish · English — எதுவும் நல்லது.\n'
          'The assistant reads your own sales, expenses, buyers and stock.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: Colors.black45, height: 1.5),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 46,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _kPrimary,
              side: const BorderSide(color: _kPrimary),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.insights),
            label: const Text('Business insights kaatu'),
            onPressed: _runInsights,
          ),
        ),
        const SizedBox(height: 20),
        const Text('Or ask:',
            style: TextStyle(fontSize: 12, color: Colors.black38)),
        const SizedBox(height: 8),
        for (final s in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _send(s),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE3E7EF)),
                ),
                child: Row(children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 16, color: _kPrimary),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(s, style: const TextStyle(fontSize: 13.5))),
                ]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _messageList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final m = _messages[i];
        return Align(
          alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment:
                m.fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: m.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Copied'),
                        duration: Duration(seconds: 1)),
                  );
                },
                child: Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: m.fromUser ? _kPrimary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(m.fromUser ? 14 : 4),
                      bottomRight: Radius.circular(m.fromUser ? 4 : 14),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: _AiText(
                    text: m.text,
                    color: m.fromUser ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (!m.fromUser) _badge(m),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _badge(_Msg m) {
    if (m.usedAi) {
      return const Padding(
        padding: EdgeInsets.only(left: 6, top: 3),
        child: Text('AI answer',
            style: TextStyle(fontSize: 10.5, color: Colors.black26)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 6, top: 3),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.bolt, size: 12, color: Color(0xFF1A6B2A)),
        const SizedBox(width: 3),
        Text(
          m.note == null
              ? 'Instant — no AI used'
              : 'From your records (AI unavailable)',
          style: const TextStyle(fontSize: 10.5, color: Color(0xFF1A6B2A)),
        ),
      ]),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, -2))
          ],
        ),
        child: Row(children: [
          IconButton(
            tooltip: 'Business insights',
            icon: const Icon(Icons.insights, color: _kPrimary),
            onPressed: _busy ? null : _runInsights,
          ),
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Kelvi kelunga...',
                filled: true,
                fillColor: const Color(0xFFF2F4F8),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: _busy ? Colors.grey.shade300 : _kPrimary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _busy ? null : () => _send(),
              child: const Padding(
                padding: EdgeInsets.all(11),
                child: Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ThinkingBar extends StatelessWidget {
  const _ThinkingBar();
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        color: const Color(0xFFE6F1FB),
        child: const Row(children: [
          SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Yosikuthu...', style: TextStyle(fontSize: 13, color: _kPrimary)),
        ]),
      );
}

/// Renders the light markdown the model produces: `**bold**` and `- ` bullets.
class _AiText extends StatelessWidget {
  final String text;
  final Color color;
  const _AiText({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: 14.5, height: 1.45, color: color);
    final spans = <TextSpan>[];

    for (final rawLine in text.split('\n')) {
      var line = rawLine;
      if (line.trimLeft().startsWith('- ') || line.trimLeft().startsWith('* ')) {
        line = '  •${line.trimLeft().substring(1)}';
      }
      for (final part in _splitBold(line)) {
        spans.add(TextSpan(
          text: part.text,
          style: part.bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
        ));
      }
      spans.add(const TextSpan(text: '\n'));
    }
    if (spans.isNotEmpty) spans.removeLast();

    return SelectableText.rich(TextSpan(style: base, children: spans));
  }

  static List<_Part> _splitBold(String line) {
    final out = <_Part>[];
    var rest = line;
    while (true) {
      final open = rest.indexOf('**');
      if (open < 0) break;
      final close = rest.indexOf('**', open + 2);
      if (close < 0) break;
      if (open > 0) out.add(_Part(rest.substring(0, open), false));
      out.add(_Part(rest.substring(open + 2, close), true));
      rest = rest.substring(close + 2);
    }
    if (rest.isNotEmpty) out.add(_Part(rest, false));
    return out.isEmpty ? [_Part(line, false)] : out;
  }
}

class _Part {
  final String text;
  final bool bold;
  const _Part(this.text, this.bold);
}
