// lib/services/ai_language.dart
// Which language the assistant answers in: Tamil script, Tanglish (Tamil words
// written in English letters), or English.

enum AiLang { tamil, tanglish, english }

/// Stored in AppSettings.aiLanguage. 'auto' follows the language of the question.
class AiLangPref {
  static const auto = 'auto';
  static const tamil = 'ta';
  static const tanglish = 'tanglish';
  static const english = 'en';

  static const all = [auto, tamil, tanglish, english];

  static String label(String pref) {
    switch (pref) {
      case tamil:
        return 'தமிழ்';
      case tanglish:
        return 'Tanglish';
      case english:
        return 'English';
      default:
        return 'Auto';
    }
  }
}

/// Tamil letters occupy U+0B80–U+0BFF.
final _tamilScript = RegExp(r'[஀-௿]');

/// Everyday Tamil words people type in English letters. Presence of any of
/// these means the owner is writing Tanglish, not English.
const _tanglishMarkers = <String>[
  'evvalavu', 'evlo', 'epdi', 'eppadi', 'enna', 'yaar', 'yaaru', 'edhu', 'ethu',
  'irruku', 'iruku', 'irukku', 'poguthu', 'pogudhu', 'kaatu', 'kaattu', 'sollu',
  'panna', 'pannunga', 'pannu', 'venum', 'vennum', 'kadan', 'baaki', 'baki',
  'laabam', 'labam', 'selavu', 'coolie', 'kooli', 'sambalam', 'vitha', 'vitten',
  'intha', 'antha', 'ippo', 'innaiku', 'innikku', 'nethu', 'naalaikku',
  'maasam', 'maasa', 'kanakku', 'kettu', 'kelvi', 'romba', 'konjam', 'adhigam',
  'kammi', 'nalla', 'mudiyuma', 'mudiyum', 'sari', 'seri', 'ungaloda', 'enakku',
];

bool hasTamilScript(String s) => _tamilScript.hasMatch(s);

bool looksTanglish(String s) {
  final lower = s.toLowerCase();
  for (final m in _tanglishMarkers) {
    if (RegExp('\\b$m\\b').hasMatch(lower)) return true;
  }
  return false;
}

/// Turns the saved preference plus the question into one concrete language.
AiLang resolveLang(String pref, String question) {
  switch (pref) {
    case AiLangPref.tamil:
      return AiLang.tamil;
    case AiLangPref.tanglish:
      return AiLang.tanglish;
    case AiLangPref.english:
      return AiLang.english;
  }
  // Auto — follow the owner.
  if (hasTamilScript(question)) return AiLang.tamil;
  if (looksTanglish(question)) return AiLang.tanglish;
  return AiLang.english;
}

/// Picks one of three wordings.
String say(AiLang l, {required String ta, required String tg, required String en}) {
  switch (l) {
    case AiLang.tamil:
      return ta;
    case AiLang.tanglish:
      return tg;
    case AiLang.english:
      return en;
  }
}

/// The instruction handed to the model so it never guesses the language.
String langInstruction(AiLang l) {
  switch (l) {
    case AiLang.tamil:
      return 'Answer ONLY in Tamil script (தமிழ்). Do not use English words '
          'except for numbers, product names and Rs amounts.';
    case AiLang.tanglish:
      return 'Answer ONLY in Tanglish — Tamil words written in English letters, '
          'the way shop owners text each other (example: "Intha maasam profit '
          'Rs 42,000. Pona maasathai vida konjam kammi."). Never use Tamil '
          'script. Keep it natural, not formal.';
    case AiLang.english:
      return 'Answer ONLY in simple English. Short sentences, no jargon.';
  }
}
