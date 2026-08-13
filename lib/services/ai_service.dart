// lib/services/ai_service.dart
// The assistant. Two layers, on purpose:
//
//   1. LocalAnswers  — routine lookups ("profit evvalavu?") are answered from
//      the shop's own numbers. No internet, no key, no quota, instant.
//   2. Google Gemini — free tier, used only for questions that need real
//      reasoning, and as such the daily quota lasts a very long time.
//
// If the AI is unreachable, out of quota or has no key, layer 1 answers anyway,
// so the feature never becomes dead weight.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'ai_language.dart';
import 'firebase_service.dart';
import 'local_answers.dart';
import 'shop_facts.dart';

/// A single chat turn. [fromUser] false means the assistant wrote it.
class AiTurn {
  final String text;
  final bool fromUser;
  const AiTurn(this.text, {required this.fromUser});
}

/// What came back, and whether the free AI quota was spent on it.
class AiReply {
  final String text;
  final bool usedAi;

  /// Set when the AI was tried and failed, and a local answer was used instead.
  final String? fallbackReason;

  const AiReply(this.text, {required this.usedAi, this.fallbackReason});
}

/// Friendly, already-translated failure. [message] is safe to show as-is.
class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => message;
}

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  // Resolved lazily, not in a field: touching FirebaseService before
  // Firebase.initializeApp() throws, and that would take the whole screen
  // down instead of showing the "add your key" card.
  FirebaseService get _svc => FirebaseService.instance;

  // ── API key ────────────────────────────────────────────────────────────────
  // Paste your free Gemini key here and it ships with the app. Get one at
  // https://aistudio.google.com/apikey — free tier, no card needed.
  // A key entered in Settings always wins over this one.
  static const String hardcodedApiKey = '';

  /// Tried in order. Each model has its own free quota, so when one is
  /// exhausted (429) the next still answers — and a retired model name just
  /// falls through instead of breaking the feature.
  static const List<String> _fallbackModels = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-2.5-flash-lite',
    'gemini-flash-latest',
  ];

  static const _endpoint = 'https://generativelanguage.googleapis.com/v1beta/models';

  AppSettings? _settings;
  ShopFacts? _facts;
  DateTime? _factsAt;

  /// Counts how many AI calls this app run has made — shown in the UI so the
  /// owner can see the free quota is barely being touched.
  int aiCallsThisSession = 0;
  int localAnswersThisSession = 0;

  /// Call after the key or language changes in Settings.
  void invalidateSettings() => _settings = null;

  /// Call after saving a sale/expense so the next answer sees fresh numbers.
  void invalidateSnapshot() {
    _facts = null;
    _factsAt = null;
  }

  /// Never throws — an unreachable Firestore just means "no saved key", and
  /// the hardcoded key (if any) still works.
  Future<AppSettings> _loadSettings() async {
    if (_settings != null) return _settings!;
    try {
      return _settings = await _svc.getAppSettings();
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<String> _apiKey() async {
    final s = await _loadSettings();
    return s.geminiApiKey.trim().isNotEmpty
        ? s.geminiApiKey.trim()
        : hardcodedApiKey.trim();
  }

  Future<bool> get isConfigured async => (await _apiKey()).isNotEmpty;

  Future<String> get languagePref async =>
      (await _loadSettings()).aiLanguage.isEmpty
          ? AiLangPref.auto
          : (await _loadSettings()).aiLanguage;

  /// Shop numbers, cached for 2 minutes so a back-and-forth chat doesn't
  /// re-read Firestore on every message.
  Future<ShopFacts> facts({bool force = false}) async {
    final fresh = _factsAt != null &&
        DateTime.now().difference(_factsAt!) < const Duration(minutes: 2);
    if (!force && _facts != null && fresh) return _facts!;
    _facts = await ShopFacts.load();
    _factsAt = DateTime.now();
    return _facts!;
  }

  /// Text snapshot handed to the model as context.
  Future<String> businessSnapshot({bool force = false}) async =>
      (await facts(force: force)).toPromptText();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Phrases that ask the assistant to CHANGE the records. It cannot — it has
  /// no write path at all — so these are answered directly instead of being
  /// sent to the model, which could otherwise reply "done, I deleted it" and
  /// leave the owner believing something happened.
  static final _writeIntent = RegExp(
    r'\b(delete|remove|erase|clear|wipe|drop|reset|'
    r'add|record|enter|save|create|insert|update|edit|change|modify|correct|'
    r'azhi|neekku|maathu|serthu|pathivu)\b',
    caseSensitive: false,
  );

  /// Words that make a "change" phrasing harmless — "how do I add a sale?"
  /// is a question, not an instruction.
  static final _questionShape = RegExp(
    r'\b(how|where|why|can i|should i|what|which|when|epdi|eppadi|enga|edhu|ethu)\b',
    caseSensitive: false,
  );

  @visibleForTesting
  static bool looksLikeWriteRequest(String q) =>
      _writeIntent.hasMatch(q) && !_questionShape.hasMatch(q);

  static String _cannotWrite(AiLang lang) => say(lang,
        ta: 'நான் கணக்கைப் பார்த்து சொல்ல மட்டுமே முடியும். எதையும் சேர்க்கவோ, '
            'மாற்றவோ, அழிக்கவோ முடியாது — அது நீங்கள்தான் அந்தந்த திரையில் '
            'செய்ய வேண்டும். உங்கள் பதிவுகள் பாதுகாப்பாக இருக்கும்.',
        tg: 'Naan kanakku paathu solla mattum thaan mudiyum. Ethaiyum add, '
            'change, delete panna mudiyaathu — atha neenga antha screen la '
            'thaan panna vendum. Unga data safe ah irukkum.',
        en: 'I can only read your records and answer questions. I cannot add, '
            'change or delete anything — you do that on the relevant screen. '
            'Your data stays safe.',
      );

  /// Answers a question about the shop.
  ///
  /// Simple lookups are answered offline. Everything else goes to the AI, and
  /// if that fails for any reason the offline engine answers instead.
  ///
  /// The assistant is READ-ONLY by construction: this class only ever calls
  /// read methods on FirebaseService, so no answer can alter or delete a
  /// record. Requests to change data are refused before they reach the model.
  Future<AiReply> ask(String question, {List<AiTurn> history = const []}) async {
    final pref = await languagePref;
    final lang = resolveLang(pref, question);

    if (looksLikeWriteRequest(question)) {
      return AiReply(_cannotWrite(lang), usedAi: false);
    }

    final f = await facts();

    // 1. Free, instant, offline — only for short lookup-style questions.
    final local = LocalAnswers.answer(question, f, lang);
    if (local != null && history.isEmpty) {
      localAnswersThisSession++;
      return AiReply(local.text, usedAi: false);
    }

    // 2. Real reasoning — spend one free AI call.
    try {
      final text = await _generate(
        system: _systemPrompt(lang, f.toPromptText()),
        // Only the last 3 exchanges: enough for follow-ups, cheap on tokens.
        turns: [
          ...history.length > 6 ? history.sublist(history.length - 6) : history,
          AiTurn(question, fromUser: true),
        ],
        maxOutputTokens: 900,
      );
      aiCallsThisSession++;
      return AiReply(text, usedAi: true);
    } on AiException catch (e) {
      // 3. AI unavailable — answer from the numbers anyway.
      final rescue = LocalAnswers.answer(question, f, lang, lenient: true);
      if (rescue != null) {
        localAnswersThisSession++;
        return AiReply(rescue.text, usedAi: false, fallbackReason: e.message);
      }
      rethrow;
    }
  }

  /// A short, ready-to-read review of how the shop is doing.
  Future<AiReply> insights() async {
    final pref = await languagePref;
    final f = await facts(force: true);
    // For insights, 'auto' means the owner's everyday language.
    final lang = pref == AiLangPref.auto
        ? AiLang.tanglish
        : resolveLang(pref, '');

    try {
      final text = await _generate(
        system: _systemPrompt(lang, f.toPromptText()),
        turns: const [
          AiTurn(
            'Give a short business review. Exactly four sections, each with a '
            'bold heading and 2 short lines under it:\n'
            '1. How the shop is doing now (this month vs last month)\n'
            '2. What is going well (best product, best buyer)\n'
            '3. What to watch (losses, shortages, big pending dues, high expenses)\n'
            '4. What to do next — 2 specific actions with numbers\n'
            'Every line under 20 words. Use the real figures from the data.',
            fromUser: true,
          ),
        ],
        maxOutputTokens: 1200,
      );
      aiCallsThisSession++;
      return AiReply(text, usedAi: true);
    } on AiException catch (e) {
      localAnswersThisSession++;
      return AiReply(
        LocalAnswers.answer('summary', f, lang, lenient: true)!.text,
        usedAi: false,
        fallbackReason: e.message,
      );
    }
  }

  /// One-line headline for the home screen card. Answered offline — the home
  /// screen must never cost a free AI call.
  Future<AiReply> headline() async {
    final pref = await languagePref;
    final lang =
        pref == AiLangPref.auto ? AiLang.tanglish : resolveLang(pref, '');
    final f = await facts(force: true);

    final diff = f.profitChange;
    final up = diff >= 0;
    final parts = <String>[];

    parts.add(say(lang,
      ta: 'இந்த மாத லாபம் ${rs(f.monthProfit)}',
      tg: 'Intha maasam profit ${rs(f.monthProfit)}',
      en: 'Profit this month ${rs(f.monthProfit)}',
    ));

    if (f.lastMonthProfit > 0) {
      parts.add(say(lang,
        ta: up ? 'போன மாதத்தை விட ${rs(diff.abs())} அதிகம்' : 'போன மாதத்தை விட ${rs(diff.abs())} குறைவு',
        tg: up ? 'pona maasathai vida ${rs(diff.abs())} adhigam' : 'pona maasathai vida ${rs(diff.abs())} kammi',
        en: up ? '${rs(diff.abs())} more than last month' : '${rs(diff.abs())} less than last month',
      ));
    }
    if (f.totalPending > 0) {
      parts.add(say(lang,
        ta: 'வசூலிக்க ${rs(f.totalPending)}',
        tg: 'vasool panna ${rs(f.totalPending)}',
        en: '${rs(f.totalPending)} to collect',
      ));
    }
    localAnswersThisSession++;
    return AiReply('${parts.join(', ')}.', usedAi: false);
  }

  // ── Prompt ─────────────────────────────────────────────────────────────────

  String _systemPrompt(AiLang lang, String data) => '''
You are the business assistant inside "My Pattarii", an app used by the owner of
a small stainless steel and brass vessel workshop (pattarai) in Tamil Nadu, India.

LANGUAGE — this is the most important rule:
${langInstruction(lang)}
Never mix two scripts in one reply.

WHAT YOU CAN DO — read only:
- You can read the DATA below and answer questions about it. That is all.
- You CANNOT add, edit, delete or save anything. Nothing you write changes the
  app. If asked to record or remove something, say so plainly and name the
  screen where the owner can do it. Never claim you have done it.

ACCURACY — this matters more than sounding good:
- Every figure you give must come from the DATA below. Never estimate, never
  guess, never carry a number over from an earlier message.
- If a figure is not in the DATA, say exactly which one is missing and which
  screen shows it. Do not substitute a similar number.
- You may add, subtract and compare the given figures. When you do arithmetic,
  keep it simple and show it, e.g. "42,000 - 9,000 = 33,000".
- Percentages: state what they are a share of.
- Never mix periods in one comparison. Today with today, month with month.
- If the question is ambiguous, answer the most likely reading in one line,
  then say what else it could have meant.

STYLE:
- Talk like a practical shop accountant, not a chatbot. Short lines, no preamble,
  no "As an AI", never repeat the question back.
- Money is Indian rupees, written as Rs 12,500. Weight in kg, pieces as pcs.
- Always say which period a number is from (today / this month / last month).
- Round sensibly — Rs 1,240 not Rs 1,239.87.
- Under 120 words unless a list is genuinely needed.

DATA — live figures from the owner's own records, in Indian rupees:
$data''';

  // ── Gemini call ────────────────────────────────────────────────────────────

  Future<String> _generate({
    required String system,
    required List<AiTurn> turns,
    int maxOutputTokens = 900,
  }) async {
    final key = await _apiKey();
    if (key.isEmpty) {
      throw const AiException(
        'No AI key yet.\n\nGo to Settings → AI Assistant and paste a free '
        'Gemini API key. Get one in 30 seconds at aistudio.google.com/apikey '
        '— no credit card needed.',
      );
    }

    final settings = await _loadSettings();
    final models = <String>[
      if (settings.aiModel.trim().isNotEmpty) settings.aiModel.trim(),
      ..._fallbackModels,
    ];

    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': system}
        ]
      },
      'contents': [
        for (final t in turns)
          {
            'role': t.fromUser ? 'user' : 'model',
            'parts': [
              {'text': t.text}
            ]
          }
      ],
      'generationConfig': {
        // Low: these are factual questions about real money, not creative ones.
        'temperature': 0.15,
        'topP': 0.8,
        'maxOutputTokens': maxOutputTokens,
      },
    });

    AiException? quotaError;
    Object? lastError;

    for (final model in models) {
      try {
        final res = await http
            .post(
              Uri.parse('$_endpoint/$model:generateContent'),
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': key,
              },
              body: body,
            )
            .timeout(const Duration(seconds: 60));

        // A retired model name, or one this key can't use — try the next.
        if (res.statusCode == 404) {
          lastError = 'model $model not available';
          continue;
        }
        // Per-model quota is separate, so the next model may still answer.
        if (res.statusCode == 429) {
          quotaError = AiException(httpMessage(429, res.body));
          lastError = 'quota exhausted on $model';
          continue;
        }
        if (res.statusCode != 200) {
          throw AiException(httpMessage(res.statusCode, res.body));
        }

        final text = extractText(res.body);
        if (text.isEmpty) {
          throw const AiException(
            'The AI sent an empty reply. Try asking again in a shorter way.',
          );
        }
        return text;
      } on AiException {
        rethrow;
      } on TimeoutException {
        throw const AiException(
          'The AI took too long to answer. Check your internet and try again.',
        );
      } catch (e) {
        lastError = e;
      }
    }

    if (quotaError != null) throw quotaError;
    throw AiException(
      'Could not reach the AI. Check your internet connection.\n\n($lastError)',
    );
  }

  /// Pulls the answer out of a Gemini response body.
  @visibleForTesting
  static String extractText(String responseBody) {
    final json = jsonDecode(responseBody) as Map<String, dynamic>;

    final blocked = json['promptFeedback']?['blockReason'];
    if (blocked != null) {
      throw AiException('The AI refused to answer that ($blocked). '
          'Try wording the question differently.');
    }

    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return '';

    final first = candidates.first as Map<String, dynamic>;
    final parts = first['content']?['parts'] as List?;
    final text = (parts ?? [])
        .map((p) => (p as Map<String, dynamic>)['text'] ?? '')
        .join()
        .trim();

    if (text.isEmpty && first['finishReason'] == 'MAX_TOKENS') {
      throw const AiException(
        'The answer was too long to finish. Ask for a shorter answer.',
      );
    }
    return text;
  }

  /// Turns an HTTP failure into something a shop owner can act on.
  @visibleForTesting
  static String httpMessage(int status, String body) {
    String detail = '';
    try {
      detail = (jsonDecode(body)['error']?['message'] ?? '').toString();
    } catch (_) {}

    switch (status) {
      case 400:
        return 'The AI key looks wrong or expired.\n\nOpen Settings → AI '
            'Assistant and paste the key again from aistudio.google.com/apikey.'
            '${detail.isEmpty ? '' : '\n\n($detail)'}';
      case 401:
      case 403:
        return 'The AI key was rejected.\n\nMake sure the Gemini API is enabled '
            'for that key at aistudio.google.com/apikey.';
      case 429:
        return 'Free AI limit reached for now.\n\nWait a minute and try again — '
            'the free quota refills automatically.';
      case 500:
      case 503:
        return 'Google\'s AI server is busy right now. Try again in a moment.';
      default:
        return 'AI error $status.${detail.isEmpty ? '' : '\n\n$detail'}';
    }
  }
}
