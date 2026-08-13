// lib/screens/calculator_screen.dart
// Plain calculator — + − × ÷ with % (100+10% = 110), live result and history.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

const _kPrimary = Color(0xFF1F4E79);

/// The calculation tape. Kept outside the widget so it survives leaving the
/// calculator and coming back during the same app session.
class CalcHistory {
  static final List<String> entries = [];
  static void clear() => entries.clear();
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _expr = '';

  /// True right after '='. The next digit starts a fresh sum, while an
  /// operator carries on from the answer — otherwise typing the next number
  /// glues it onto the previous answer (20 then '50' became '2050').
  bool _justEvaluated = false;

  List<String> get _history => CalcHistory.entries;

  static final _fmt = NumberFormat('#,##0.####', 'en_IN');

  // ── Expression evaluation ──────────────────────────────────────────────────
  double? get _value => _eval(_expr);

  String get _resultText {
    final v = _value;
    if (v == null) return '';
    if (v.isNaN || v.isInfinite) return 'Error';
    return _fmt.format(v);
  }

  static double? _eval(String s) {
    if (s.trim().isEmpty) return null;

    // ── Tokenize ────────────────────────────────────────────────────────────
    final nums = <_Num>[];
    final ops = <String>[];
    var buf = StringBuffer();
    var pct = false;

    void flush() {
      final t = buf.toString();
      final v = double.tryParse(t == '-' || t.isEmpty ? '0' : t);
      nums.add(_Num(v ?? 0, pct));
      buf = StringBuffer();
      pct = false;
    }

    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '+' || c == '-' || c == '×' || c == '÷') {
        final atStart = buf.isEmpty && nums.isEmpty && ops.isEmpty;
        final afterOp = buf.isEmpty && nums.length == ops.length;
        if (c == '-' && (atStart || afterOp) && !pct) {
          buf.write('-'); // unary minus
          continue;
        }
        if (buf.isEmpty && nums.isEmpty) continue; // stray leading operator
        if (buf.isNotEmpty) flush();
        if (nums.isEmpty) continue;
        if (ops.length == nums.length) {
          ops[ops.length - 1] = c; // operator typed twice — replace
        } else {
          ops.add(c);
        }
      } else if (c == '%') {
        pct = true;
      } else {
        buf.write(c);
      }
    }
    if (buf.isNotEmpty || pct) flush();
    if (nums.isEmpty) return null;
    while (ops.length >= nums.length) {
      ops.removeLast(); // trailing operator — ignore it for the live preview
    }

    // ── × ÷ first ───────────────────────────────────────────────────────────
    final n2 = <_Num>[nums.first];
    final o2 = <String>[];
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final rhs = nums[i + 1];
      if (op == '×' || op == '÷') {
        final lhs = n2.removeLast();
        final l = lhs.pct ? lhs.value / 100 : lhs.value;
        final r = rhs.pct ? rhs.value / 100 : rhs.value;
        n2.add(_Num(op == '×' ? l * r : l / r, false));
      } else {
        o2.add(op);
        n2.add(rhs);
      }
    }

    // ── then + − (a % term reads as "percent of the running total") ─────────
    var total = n2.first.pct ? n2.first.value / 100 : n2.first.value;
    for (var i = 0; i < o2.length; i++) {
      final t = n2[i + 1];
      final v = t.pct ? total * t.value / 100 : t.value;
      total = o2[i] == '+' ? total + v : total - v;
    }
    return total;
  }

  // ── Key handling ───────────────────────────────────────────────────────────
  void _tap(String k) {
    setState(() {
      switch (k) {
        case 'C':
          _expr = '';
          _justEvaluated = false;
          break;
        case '⌫':
          if (_expr.isNotEmpty) {
            _expr = _expr.substring(0, _expr.length - 1);
          }
          _justEvaluated = false;
          break;
        case '=':
          final v = _value;
          if (v == null || v.isNaN || v.isInfinite) return;
          // Only a real calculation goes on the tape — '150 =' is not one.
          final line = '$_expr = ${_fmt.format(v)}';
          if (_hasOperator(_expr) && (_history.isEmpty || _history.first != line)) {
            _history.insert(0, line);
            if (_history.length > 50) _history.removeLast();
          }
          _expr = _plain(v);
          _justEvaluated = true;
          break;
        default:
          if (_justEvaluated) {
            // A digit starts a new sum; an operator continues from the answer.
            if (!_isOperator(k)) _expr = '';
            _justEvaluated = false;
          }
          _expr += k;
      }
    });
  }

  static bool _isOperator(String k) => k == '+' || k == '-' || k == '×' || k == '÷';

  static bool _hasOperator(String s) {
    // Skip a leading minus — that is a sign, not an operation.
    for (var i = 1; i < s.length; i++) {
      if (_isOperator(s[i])) return true;
    }
    return s.contains('%');
  }

  /// Machine-readable form so the answer can keep being calculated with.
  static String _plain(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) {
      return v.toStringAsFixed(0);
    }
    return v.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  /// Tapping a tape line brings its answer back — appended when the current
  /// expression is waiting for a number, otherwise it replaces what is there.
  void _reuse(String line) {
    final answer = line.split(' = ').last.replaceAll(',', '');
    setState(() {
      final waiting = _expr.isNotEmpty && _isOperator(_expr[_expr.length - 1]);
      _expr = waiting && !_justEvaluated ? _expr + answer : answer;
      _justEvaluated = false;
    });
  }

  void _copy() {
    final t = _resultText;
    if (t.isEmpty || t == 'Error') return;
    Clipboard.setData(ClipboardData(text: t.replaceAll(',', '')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Calculator'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              icon: const Icon(Icons.history_toggle_off),
              onPressed: () => setState(_history.clear),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
        // ── History ───────────────────────────────────────────────────────
        Expanded(
          flex: 2,
          child: _history.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Press  =  to keep a calculation here.\n'
                      'Tap any line to use it again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black26),
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _history.length,
                  itemBuilder: (_, i) {
                    final h = _history[i];
                    return InkWell(
                      onTap: () => _reuse(h),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(h,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black45)),
                      ),
                    );
                  },
                ),
        ),

        // ── Display ───────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Text(
                _expr.isEmpty ? '0' : _expr,
                style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onLongPress: _copy,
              child: Text(
                _resultText.isEmpty ? '' : '= $_resultText',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: _kPrimary),
              ),
            ),
          ]),
        ),
        const Divider(height: 1),

        // ── Keypad ────────────────────────────────────────────────────────
        // Expanded (not a bare Column) — the key rows below use Expanded
        // themselves and need a bounded height to lay out.
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              _row(['C', '⌫', '%', '÷']),
              _row(['7', '8', '9', '×']),
              _row(['4', '5', '6', '-']),
              _row(['1', '2', '3', '+']),
              _row(['00', '0', '.', '=']),
            ]),
          ),
        ),
      ]),
      ),
    );
  }

  Widget _row(List<String> keys) => Expanded(
        child: Row(
          children: [
            for (final k in keys)
              Expanded(child: _key(k)),
          ],
        ),
      );

  Widget _key(String k) {
    final isOp = ['÷', '×', '-', '+'].contains(k);
    final isEq = k == '=';
    final isFn = k == 'C' || k == '⌫' || k == '%';

    Color bg = const Color(0xFFF2F4F8);
    Color fg = Colors.black87;
    if (isOp) {
      bg = const Color(0xFFE6F1FB);
      fg = _kPrimary;
    } else if (isFn) {
      bg = const Color(0xFFF7EDED);
      fg = k == 'C' ? Colors.red.shade600 : Colors.black54;
    } else if (isEq) {
      bg = _kPrimary;
      fg = Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.all(5),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _tap(k),
          onLongPress: k == '⌫' ? () => _tap('C') : null,
          child: Center(
            child: Text(k,
                style: TextStyle(
                    fontSize: isOp || isEq ? 26 : 22,
                    fontWeight: FontWeight.w600,
                    color: fg)),
          ),
        ),
      ),
    );
  }
}

class _Num {
  final double value;
  final bool pct;
  const _Num(this.value, this.pct);
}
