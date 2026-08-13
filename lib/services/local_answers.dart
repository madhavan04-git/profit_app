// lib/services/local_answers.dart
// Answers the common questions straight from the shop's own numbers — no
// internet, no API key, no quota. Three reasons this exists:
//   1. Free forever: the daily AI quota is never spent on "profit evvalavu?".
//   2. Instant: no network round trip.
//   3. Still works when the AI is down, out of quota, or the phone is offline.
// Anything it can't answer falls through to the real AI.
import 'ai_language.dart';
import 'shop_facts.dart';

class LocalAnswer {
  final String text;

  /// Which rule matched — handy for tests and for the UI badge.
  final String rule;
  const LocalAnswer(this.text, this.rule);
}

typedef _Build = String Function(ShopFacts f, AiLang l);

class _Rule {
  final String name;
  final List<String> keys;
  final _Build build;
  const _Rule(this.name, this.keys, this.build);

  /// Latin keys must match whole words — a plain `contains` makes 'owe' fire
  /// on "l**owe**r" and 'net' on "inter**net**", sending a profit question to
  /// the pending answer.
  ///
  /// Tamil keys are matched as substrings instead, because Tamil agglutinates:
  /// 'பொருள்' must also match 'பொருளில்'. The trailing pulli (virama) is
  /// dropped first — when a suffix is added the pure consonant ள் becomes ளி,
  /// so the key with its pulli would never be found inside the longer word.
  bool matches(String q) {
    for (final k in keys) {
      if (hasTamilScript(k)) {
        final stem = k.endsWith('்') ? k.substring(0, k.length - 1) : k;
        if (q.contains(stem)) return true;
      } else if (RegExp('(?<![a-z])${RegExp.escape(k)}(?![a-z])').hasMatch(q)) {
        return true;
      }
    }
    return false;
  }
}

class LocalAnswers {
  /// Tries to answer without the AI.
  ///
  /// [lenient] is used when the AI is unavailable: it drops the
  /// short-question requirement and always returns something useful.
  static LocalAnswer? answer(
    String question,
    ShopFacts f,
    AiLang lang, {
    bool lenient = false,
  }) {
    final q = _normalise(question);
    if (q.isEmpty) return null;

    // A long question usually wants reasoning ("why is profit down and what
    // should I do") — that belongs to the AI, not a canned lookup.
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final simple = words <= 7;

    for (final rule in _rules) {
      if (rule.matches(q)) {
        if (!simple && !lenient) return null;
        return LocalAnswer(rule.build(f, lang), rule.name);
      }
    }

    // Nothing matched. When the AI can't be reached, still give the overview
    // rather than an error.
    if (lenient) return LocalAnswer(_summary(f, lang), 'summary');
    return null;
  }

  static String _normalise(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[?!.,;:\-_/()]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // ── Rules, most specific first ─────────────────────────────────────────────
  static const List<_Rule> _rules = [
    _Rule('pending', [
      'pending', 'kadan', 'கடன்', 'baaki', 'baki', 'பாக்கி', 'balance',
      'owe', 'collect', 'vasool', 'வசூல்', 'due', 'dues', 'vaanga venum',
    ], _pending),

    _Rule('expenses', [
      'expense', 'expenses', 'selavu', 'செலவு', 'kharch', 'cost la',
      'spending', 'செலவுகள்',
    ], _expenses),

    _Rule('stock', [
      'stock', 'ஸ்டாக்', 'sheet', 'material', 'மூலப்பொருள்', 'raw',
      'inventory', 'irupu',
    ], _stock),

    _Rule('worker', [
      'worker', 'workers', 'coolie', 'kooli', 'கூலி', 'salary', 'sambalam',
      'சம்பளம்', 'aal', 'ஆள்', 'wage', 'wages',
    ], _workers),

    _Rule('product', [
      'product', 'பொருள்', 'item', 'best', 'adhigam profit', 'edhu la',
      'ethu la', 'which product', 'top product', 'category',
    ], _products),

    _Rule('buyer', [
      'buyer', 'customer', 'வாடிக்கையாளர்', 'party', 'yaar vaangi',
      'top buyer', 'best buyer',
    ], _buyers),

    _Rule('today', [
      'today', 'innaiku', 'innikku', 'இன்று', 'இன்றைக்கு', 'ivvalavu naal',
      'daily',
    ], _today),

    _Rule('profit', [
      'profit', 'laabam', 'labam', 'லாபம்', 'earning', 'income', 'varumanam',
      'வருமானம்', 'net', 'revenue', 'vithanai', 'விற்பனை', 'sales',
    ], _profit),

    _Rule('summary', [
      'summary', 'epdi', 'eppadi', 'எப்படி', 'business', 'nilamai', 'நிலைமை',
      'overall', 'report', 'how is',
    ], _summary),
  ];

  // ── Answer builders ────────────────────────────────────────────────────────

  static String _profit(ShopFacts f, AiLang l) {
    final diff = f.profitChange;
    final up = diff >= 0;
    final lines = <String>[];

    lines.add(say(l,
        ta: 'இந்த மாதம் மொத்த லாபம் ${rs(f.monthProfit)}.',
        tg: 'Intha maasam gross profit ${rs(f.monthProfit)}.',
        en: 'Gross profit this month is ${rs(f.monthProfit)}.'));

    lines.add(say(l,
        ta: 'செலவு ${rs(f.monthExpenses)} போக நிகர லாபம் ${rs(f.monthNetProfit)}.',
        tg: 'Selavu ${rs(f.monthExpenses)} poga net profit ${rs(f.monthNetProfit)}.',
        en: 'After ${rs(f.monthExpenses)} expenses, net profit is ${rs(f.monthNetProfit)}.'));

    if (f.lastMonthProfit > 0) {
      lines.add(say(l,
          ta: up
              ? 'போன மாதத்தை விட ${rs(diff.abs())} அதிகம்.'
              : 'போன மாதத்தை விட ${rs(diff.abs())} குறைவு.',
          tg: up
              ? 'Pona maasathai vida ${rs(diff.abs())} adhigam.'
              : 'Pona maasathai vida ${rs(diff.abs())} kammi.',
          en: up
              ? '${rs(diff.abs())} more than last month.'
              : '${rs(diff.abs())} less than last month.'));
    }

    lines.add(say(l,
        ta: '${f.monthSales} விற்பனை, ${kgs(f.monthKg)}, வரவு ${rs(f.monthRevenue)}.',
        tg: '${f.monthSales} sales, ${kgs(f.monthKg)}, revenue ${rs(f.monthRevenue)}.',
        en: '${f.monthSales} sales, ${kgs(f.monthKg)}, revenue ${rs(f.monthRevenue)}.'));

    return lines.join('\n');
  }

  static String _today(ShopFacts f, AiLang l) {
    if (f.todaySales == 0) {
      return say(l,
          ta: 'இன்று இதுவரை விற்பனை இல்லை.',
          tg: 'Innaiku ipovarai sales illa.',
          en: 'No sales recorded today yet.');
    }
    return say(l,
      ta: 'இன்று ${f.todaySales} விற்பனை. வரவு ${rs(f.todayRevenue)}, '
          'லாபம் ${rs(f.todayProfit)}.',
      tg: 'Innaiku ${f.todaySales} sales. Revenue ${rs(f.todayRevenue)}, '
          'profit ${rs(f.todayProfit)}.',
      en: '${f.todaySales} sales today. Revenue ${rs(f.todayRevenue)}, '
          'profit ${rs(f.todayProfit)}.',
    );
  }

  static String _products(ShopFacts f, AiLang l) {
    if (f.profitByProduct.isEmpty) {
      return say(l,
          ta: 'இந்த மாதம் விற்பனை பதிவு இல்லை.',
          tg: 'Intha maasam sales entry ille.',
          en: 'No sales recorded this month.');
    }
    final b = StringBuffer(say(l,
        ta: 'இந்த மாதம் லாபம் அதிகம் தரும் பொருட்கள்:',
        tg: 'Intha maasam profit adhigam kudukura products:',
        en: 'Best profit products this month:'));
    for (final p in f.profitByProduct.take(5)) {
      b.write('\n• ${p.name} — ${rs(p.value)}');
    }
    final worst = f.profitByProduct.last;
    if (f.profitByProduct.length > 5) {
      b.write('\n');
      b.write(say(l,
          ta: 'கடைசி: ${worst.name} — ${rs(worst.value)}.',
          tg: 'Kadaisi: ${worst.name} — ${rs(worst.value)}.',
          en: 'Lowest: ${worst.name} — ${rs(worst.value)}.'));
    }
    return b.toString();
  }

  static String _buyers(ShopFacts f, AiLang l) {
    if (f.profitByBuyer.isEmpty) {
      return say(l,
          ta: 'இந்த மாதம் வாடிக்கையாளர் விற்பனை இல்லை.',
          tg: 'Intha maasam buyer sales ille.',
          en: 'No buyer sales this month.');
    }
    final b = StringBuffer(say(l,
        ta: 'இந்த மாதம் சிறந்த வாடிக்கையாளர்கள்:',
        tg: 'Intha maasam top buyers:',
        en: 'Top buyers this month:'));
    for (final e in f.profitByBuyer.take(5)) {
      b.write('\n• ${e.name} — ${rs(e.value)}');
    }
    return b.toString();
  }

  static String _pending(ShopFacts f, AiLang l) {
    final owing = f.pendingByBuyer.where((e) => e.value > 0).toList();
    if (owing.isEmpty) {
      return say(l,
          ta: 'யாரிடமும் பாக்கி இல்லை. எல்லாம் வசூல் ஆகிவிட்டது.',
          tg: 'Yaar kitteyum baaki ille. Ellame vasool aagiduchu.',
          en: 'Nothing pending — everything has been collected.');
    }
    final b = StringBuffer(say(l,
      ta: 'மொத்த பாக்கி ${rs(f.totalPending)}:',
      tg: 'Mothham pending ${rs(f.totalPending)}:',
      en: 'Total pending ${rs(f.totalPending)}:',
    ));
    for (final e in owing.take(8)) {
      b.write('\n• ${e.name} — ${rs(e.value)}');
    }
    final advance = f.pendingByBuyer.where((e) => e.value < 0).toList();
    if (advance.isNotEmpty) {
      b.write('\n');
      b.write(say(l,
        ta: 'முன்பணம் தந்தவர்: ${advance.map((e) => '${e.name} ${rs(e.value.abs())}').join(', ')}.',
        tg: 'Advance kuduthavanga: ${advance.map((e) => '${e.name} ${rs(e.value.abs())}').join(', ')}.',
        en: 'Paid in advance: ${advance.map((e) => '${e.name} ${rs(e.value.abs())}').join(', ')}.',
      ));
    }
    return b.toString();
  }

  static String _expenses(ShopFacts f, AiLang l) {
    if (f.expensesByHead.isEmpty) {
      return say(l,
          ta: 'இந்த மாதம் செலவு பதிவு இல்லை.',
          tg: 'Intha maasam selavu entry ille.',
          en: 'No expenses recorded this month.');
    }
    final b = StringBuffer(say(l,
      ta: 'இந்த மாதம் மொத்த செலவு ${rs(f.monthExpenses)}:',
      tg: 'Intha maasam mothham selavu ${rs(f.monthExpenses)}:',
      en: 'Total expenses this month ${rs(f.monthExpenses)}:',
    ));
    for (final e in f.expensesByHead.take(6)) {
      b.write('\n• ${e.name} — ${rs(e.value)}');
    }
    return b.toString();
  }

  static String _workers(ShopFacts f, AiLang l) {
    if (f.wagesByRole.isEmpty) {
      return say(l,
          ta: 'இந்த மாதம் கூலி கணக்கு இல்லை.',
          tg: 'Intha maasam kooli kanakku ille.',
          en: 'No worker earnings recorded this month.');
    }
    final b = StringBuffer(say(l,
      ta: 'இந்த மாதம் கூலி மொத்தம் ${rs(f.monthWages)}:',
      tg: 'Intha maasam kooli mothham ${rs(f.monthWages)}:',
      en: 'Worker wages this month ${rs(f.monthWages)}:',
    ));
    for (final e in f.wagesByRole.take(8)) {
      b.write('\n• ${e.name} — ${rs(e.value)}');
    }
    return b.toString();
  }

  static String _stock(ShopFacts f, AiLang l) {
    if (f.stock.isEmpty) {
      return say(l,
          ta: 'ஸ்டாக் பதிவு இல்லை.',
          tg: 'Stock entry ille.',
          en: 'No stock recorded.');
    }
    final b = StringBuffer(say(l,
      ta: 'இப்போதைய ஸ்டாக்:',
      tg: 'Ippo irukkura stock:',
      en: 'Current stock:',
    ));
    for (final e in f.stock) {
      final short = e.value < 0
          ? say(l, ta: ' (பற்றாக்குறை)', tg: ' (kammi)', en: ' (shortage)')
          : '';
      b.write('\n• ${e.name} — ${kgs(e.value)}$short');
    }
    return b.toString();
  }

  static String _summary(ShopFacts f, AiLang l) {
    final lines = <String>[_profit(f, l)];

    if (f.profitByProduct.isNotEmpty) {
      final top = f.profitByProduct.first;
      lines.add(say(l,
        ta: 'அதிக லாபம்: ${top.name} (${rs(top.value)}).',
        tg: 'Adhigam profit: ${top.name} (${rs(top.value)}).',
        en: 'Best product: ${top.name} (${rs(top.value)}).',
      ));
    }
    if (f.totalPending > 0) {
      lines.add(say(l,
        ta: 'வசூலிக்க வேண்டியது ${rs(f.totalPending)}.',
        tg: 'Vasool panna venumnu ${rs(f.totalPending)} irruku.',
        en: '${rs(f.totalPending)} still to collect.',
      ));
    }
    final short = f.stock.where((e) => e.value < 0).toList();
    if (short.isNotEmpty) {
      lines.add(say(l,
        ta: 'ஸ்டாக் பற்றாக்குறை: ${short.map((e) => e.name).join(', ')}.',
        tg: 'Stock kammi: ${short.map((e) => e.name).join(', ')}.',
        en: 'Stock shortage: ${short.map((e) => e.name).join(', ')}.',
      ));
    }
    return lines.join('\n');
  }
}
