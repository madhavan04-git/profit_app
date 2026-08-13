import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:profit_tracker/services/ai_service.dart';

String body(Object json) => jsonEncode(json);

void main() {
  group('extractText', () {
    test('joins every text part of the first candidate', () {
      final text = AiService.extractText(body({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Intha maasam profit '},
                {'text': 'Rs 42,000.'},
              ],
            },
            'finishReason': 'STOP',
          }
        ],
      }));
      expect(text, 'Intha maasam profit Rs 42,000.');
    });

    test('returns empty string when there are no candidates', () {
      expect(AiService.extractText(body({'candidates': []})), '');
      expect(AiService.extractText(body({})), '');
    });

    test('a blocked prompt raises a readable error, not a crash', () {
      expect(
        () => AiService.extractText(body({
          'promptFeedback': {'blockReason': 'SAFETY'}
        })),
        throwsA(isA<AiException>().having(
            (e) => e.message, 'message', contains('refused'))),
      );
    });

    test('a truncated answer explains itself instead of returning blank', () {
      expect(
        () => AiService.extractText(body({
          'candidates': [
            {
              'content': {'parts': []},
              'finishReason': 'MAX_TOKENS',
            }
          ],
        })),
        throwsA(isA<AiException>()
            .having((e) => e.message, 'message', contains('too long'))),
      );
    });

    test('tolerates a candidate with no content block', () {
      expect(
        AiService.extractText(body({
          'candidates': [
            {'finishReason': 'STOP'}
          ],
        })),
        '',
      );
    });
  });

  group('the assistant is read-only', () {
    test('asking it to delete something is treated as a write request', () {
      for (final q in [
        'delete my sales',
        'remove Kumar from buyers',
        'clear all expenses',
        'erase last month data',
        'reset the stock',
      ]) {
        expect(AiService.looksLikeWriteRequest(q), isTrue, reason: q);
      }
    });

    test('asking it to add or change something is caught too', () {
      for (final q in [
        'add a sale of 10 kg',
        'record payment from Kumar',
        'update the rate to 250',
        'change my profit',
        'save this as an expense',
      ]) {
        expect(AiService.looksLikeWriteRequest(q), isTrue, reason: q);
      }
    });

    test('Tamil and Tanglish instructions are caught', () {
      expect(AiService.looksLikeWriteRequest('sales ah delete pannu'), isTrue);
      expect(AiService.looksLikeWriteRequest('idha neekku'), isTrue);
    });

    test('genuine questions are NOT blocked', () {
      for (final q in [
        'how do I add a sale?',
        'where can I delete a transaction?',
        'what is my profit this month',
        'which product gives more profit',
        'intha maasam profit evvalavu',
        'yaar kitta pending irruku',
        'why is my profit down',
        'epdi profit koodum',
      ]) {
        expect(AiService.looksLikeWriteRequest(q), isFalse, reason: q);
      }
    });

    test('a plain report request is not mistaken for a write', () {
      expect(AiService.looksLikeWriteRequest('show me the monthly summary'),
          isFalse);
      expect(AiService.looksLikeWriteRequest('business insights'), isFalse);
    });
  });

  group('httpMessage', () {
    test('429 tells the owner the free quota refills', () {
      final msg = AiService.httpMessage(429, '{}');
      expect(msg.toLowerCase(), contains('free'));
      expect(msg.toLowerCase(), contains('wait'));
    });

    test('400 points at the API key in Settings', () {
      final msg = AiService.httpMessage(400, '{}');
      expect(msg, contains('Settings'));
      expect(msg.toLowerCase(), contains('key'));
    });

    test('403 explains the key was rejected', () {
      expect(AiService.httpMessage(403, '{}').toLowerCase(),
          contains('rejected'));
    });

    test('503 blames the server, not the user', () {
      expect(AiService.httpMessage(503, '{}').toLowerCase(), contains('busy'));
    });

    test('includes Google\'s own detail when it sends one', () {
      final msg = AiService.httpMessage(
        400,
        body({
          'error': {'message': 'API key not valid'}
        }),
      );
      expect(msg, contains('API key not valid'));
    });

    test('an unparseable body still produces a message', () {
      final msg = AiService.httpMessage(418, 'not json at all');
      expect(msg, contains('418'));
    });
  });
}
