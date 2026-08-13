import 'package:flutter_test/flutter_test.dart';
import 'package:profit_tracker/services/ai_language.dart';
import 'package:profit_tracker/services/local_answers.dart';
import 'package:profit_tracker/services/shop_facts.dart';

ShopFacts facts() => ShopFacts(
      asOf: DateTime(2026, 8, 12),
      shopNames: const ['Sri Murugan Pattarai'],
      todaySales: 3,
      todayRevenue: 8400,
      todayProfit: 1250,
      monthSales: 42,
      monthKg: 610.5,
      monthRevenue: 184000,
      monthProfit: 42000,
      monthExpenses: 9000,
      monthNetProfit: 33000,
      monthWages: 14500,
      lastMonthProfit: 38000,
      profitByProduct: const [
        NamedAmount('Kadai', 18000),
        NamedAmount('Thattu', 12000),
        NamedAmount('Tumbler', 8000),
        NamedAmount('Chombu', 2500),
        NamedAmount('Panai', 1200),
        NamedAmount('Vaali', 300),
      ],
      profitByCategory: const [NamedAmount('SS', 30000), NamedAmount('Brass', 12000)],
      profitByBuyer: const [
        NamedAmount('Kumar Stores', 15000),
        NamedAmount('Lakshmi Traders', 9000),
      ],
      expensesByHead: const [
        NamedAmount('Current bill', 4000),
        NamedAmount('Transport', 3000),
        NamedAmount('Tea', 2000),
      ],
      wagesByRole: const [
        NamedAmount('Plasma 1', 8000),
        NamedAmount('Polish 1', 6500),
      ],
      pendingByBuyer: const [
        NamedAmount('Kumar Stores', 22000),
        NamedAmount('Lakshmi Traders', 5000),
        NamedAmount('Ravi Metals', -3000), // paid in advance
      ],
      stock: const [
        NamedAmount('SS Sheet', 120.5),
        NamedAmount('Brass Sheet', -8),
      ],
      products: const [],
      workers: const [],
    );

void main() {
  group('answers the common questions without touching the AI', () {
    test('profit — Tanglish', () {
      final a = LocalAnswers.answer(
          'Intha maasam profit evvalavu?', facts(), AiLang.tanglish);
      expect(a, isNotNull);
      expect(a!.rule, 'profit');
      expect(a.text, contains('Rs 42,000'));
      expect(a.text, contains('Rs 33,000')); // net
      expect(a.text, contains('adhigam')); // up vs last month
    });

    test('profit — Tamil script question gets a Tamil answer', () {
      final a =
          LocalAnswers.answer('லாபம் எவ்வளவு?', facts(), AiLang.tamil);
      expect(a!.rule, 'profit');
      expect(hasTamilScript(a.text), isTrue);
      expect(a.text, contains('Rs 42,000'));
    });

    test('profit — English', () {
      final a = LocalAnswers.answer(
          'what is my profit this month', facts(), AiLang.english);
      expect(a!.rule, 'profit');
      expect(a.text, contains('Gross profit'));
      expect(a.text, contains('more than last month'));
    });

    test('pending lists who owes, and who paid in advance', () {
      final a = LocalAnswers.answer(
          'yaar kitta pending irruku', facts(), AiLang.tanglish);
      expect(a!.rule, 'pending');
      expect(a.text, contains('Kumar Stores'));
      expect(a.text, contains('Rs 22,000'));
      expect(a.text, contains('Rs 27,000')); // total, advance excluded
      expect(a.text, contains('Ravi Metals')); // advance noted separately
    });

    test('best product', () {
      final a = LocalAnswers.answer(
          'edhu product la profit adhigam', facts(), AiLang.tanglish);
      expect(a!.rule, 'product');
      expect(a.text, contains('Kadai'));
      expect(a.text, contains('Rs 18,000'));
    });

    test('expenses', () {
      final a =
          LocalAnswers.answer('selavu evvalavu', facts(), AiLang.tanglish);
      expect(a!.rule, 'expenses');
      expect(a.text, contains('Current bill'));
      expect(a.text, contains('Rs 9,000'));
    });

    test('stock flags a shortage', () {
      final a = LocalAnswers.answer('stock evvalavu', facts(), AiLang.english);
      expect(a!.rule, 'stock');
      expect(a.text, contains('SS Sheet'));
      expect(a.text, contains('shortage')); // Brass Sheet is negative
    });

    test('worker wages', () {
      final a = LocalAnswers.answer('kooli evvalavu', facts(), AiLang.tanglish);
      expect(a!.rule, 'worker');
      expect(a.text, contains('Plasma 1'));
    });

    test('today', () {
      final a = LocalAnswers.answer('innaiku sales', facts(), AiLang.english);
      expect(a!.rule, 'today');
      expect(a.text, contains('3 sales today'));
    });
  });

  group('keyword matching is word-bounded', () {
    test('"lower" does not trigger the pending rule via "owe"', () {
      final a = LocalAnswers.answer('profit lower?', facts(), AiLang.english);
      expect(a!.rule, 'profit');
    });

    test('"internet bill" does not trigger the profit rule via "net"', () {
      final a =
          LocalAnswers.answer('internet bill', facts(), AiLang.english);
      expect(a?.rule, isNot('profit'));
    });

    test('Tamil keys still match inside longer Tamil words', () {
      // 'பொருள்' inside 'பொருளில்'
      final a = LocalAnswers.answer(
          'எந்த பொருளில் லாபம் அதிகம்?', facts(), AiLang.tamil);
      expect(a!.rule, 'product');
    });
  });

  group('knows when NOT to answer — those questions belong to the AI', () {
    test('a long reasoning question falls through', () {
      final a = LocalAnswers.answer(
        'why is my profit lower than last month and what should i change',
        facts(),
        AiLang.english,
      );
      expect(a, isNull);
    });

    test('an unrelated question falls through', () {
      expect(LocalAnswers.answer('zzz qqq www', facts(), AiLang.english),
          isNull);
    });

    test('empty input falls through', () {
      expect(LocalAnswers.answer('   ', facts(), AiLang.english), isNull);
    });
  });

  group('lenient mode — used when the AI is unreachable', () {
    test('a long question is still answered', () {
      final a = LocalAnswers.answer(
        'why is my profit lower than last month and what should i change',
        facts(),
        AiLang.english,
        lenient: true,
      );
      expect(a, isNotNull);
      expect(a!.text, contains('Rs 42,000'));
    });

    test('an unmatched question gets the overall summary', () {
      final a = LocalAnswers.answer('zzz qqq www', facts(), AiLang.english,
          lenient: true);
      expect(a!.rule, 'summary');
      expect(a.text, contains('Best product: Kadai'));
      expect(a.text, contains('to collect'));
      expect(a.text, contains('Stock shortage: Brass Sheet'));
    });
  });

  group('empty shop does not crash or lie', () {
    test('every rule handles no data', () {
      final f = ShopFacts.empty();
      for (final q in [
        'profit',
        'pending',
        'selavu',
        'stock',
        'kooli',
        'product',
        'buyer',
        'innaiku',
      ]) {
        final a = LocalAnswers.answer(q, f, AiLang.english, lenient: true);
        expect(a, isNotNull, reason: 'no answer for "$q"');
        expect(a!.text.trim(), isNotEmpty);
      }
    });
  });
}
