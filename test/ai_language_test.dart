import 'package:flutter_test/flutter_test.dart';
import 'package:profit_tracker/services/ai_language.dart';

void main() {
  group('auto language detection', () {
    test('Tamil script question gets a Tamil answer', () {
      expect(resolveLang(AiLangPref.auto, 'இந்த மாதம் லாபம் எவ்வளவு?'),
          AiLang.tamil);
    });

    test('Tanglish question gets a Tanglish answer', () {
      expect(resolveLang(AiLangPref.auto, 'Intha maasam profit evvalavu?'),
          AiLang.tanglish);
      expect(resolveLang(AiLangPref.auto, 'yaar kitta baaki irruku'),
          AiLang.tanglish);
      expect(resolveLang(AiLangPref.auto, 'edhu product la profit adhigam'),
          AiLang.tanglish);
    });

    test('plain English question gets English', () {
      expect(resolveLang(AiLangPref.auto, 'What is my profit this month?'),
          AiLang.english);
      expect(resolveLang(AiLangPref.auto, 'show pending payments'),
          AiLang.english);
    });

    test('an English word that merely contains a Tanglish word is not Tanglish',
        () {
      // "important" contains "porta"-like fragments; "management" contains
      // "enna". Marker matching is word-bounded, so these stay English.
      expect(resolveLang(AiLangPref.auto, 'important management summary'),
          AiLang.english);
      expect(
          resolveLang(AiLangPref.auto, 'inventory annual report'),
          AiLang.english);
    });
  });

  group('explicit preference overrides detection', () {
    test('English preference answers a Tamil question in English', () {
      expect(resolveLang(AiLangPref.english, 'லாபம் எவ்வளவு?'), AiLang.english);
    });

    test('Tamil preference answers an English question in Tamil', () {
      expect(resolveLang(AiLangPref.tamil, 'what is my profit'), AiLang.tamil);
    });

    test('Tanglish preference wins over everything', () {
      expect(resolveLang(AiLangPref.tanglish, 'லாபம்'), AiLang.tanglish);
      expect(resolveLang(AiLangPref.tanglish, 'profit'), AiLang.tanglish);
    });
  });

  group('script helpers', () {
    test('hasTamilScript only fires on Tamil letters', () {
      expect(hasTamilScript('லாபம்'), isTrue);
      expect(hasTamilScript('laabam'), isFalse);
      expect(hasTamilScript('Rs 42,000'), isFalse);
    });

    test('every language has its own model instruction', () {
      expect(langInstruction(AiLang.tamil), contains('Tamil script'));
      expect(langInstruction(AiLang.tanglish), contains('English letters'));
      expect(langInstruction(AiLang.english), contains('English'));
    });

    test('say() picks the matching wording', () {
      String pick(AiLang l) => say(l, ta: 'தமிழ்', tg: 'tanglish', en: 'english');
      expect(pick(AiLang.tamil), 'தமிழ்');
      expect(pick(AiLang.tanglish), 'tanglish');
      expect(pick(AiLang.english), 'english');
    });
  });
}
