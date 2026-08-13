// lib/services/app_toast.dart
// Short, cheerful English toasts for the good moments — a sale saved, a
// payment collected, stock bought, scrap sold.
//
// Rules kept deliberately tight:
//   • short — it is a toast, not a paragraph
//   • English only
//   • uses the person's name when there is one
//   • never repeats the same line twice in a row for the same event
import 'package:flutter/material.dart';

enum ToastEvent {
  sale,
  payment,
  due,
  purchase,
  expense,
  wastageSold,
  sheetSent,
  piecesBack,
  workerPaid,
  saved,
}

class AppToast {
  AppToast._();

  /// Where each event is in its list of lines. Advancing this per call is what
  /// makes the messages rotate instead of repeating.
  static final Map<ToastEvent, int> _cursor = {};

  /// Used whenever a name is known — the name always appears, because
  /// "Sold to Kumar. Nice one!" beats "Another sale in the book!".
  static const Map<ToastEvent, List<String>> _named = {
    ToastEvent.sale: [
      'Sold to {name}. Nice one!',
      '{name} billed. Keep going!',
      'Done! {name} is served.',
      'Great sale to {name}!',
      '{name} sale saved. Super!',
      'Another one for {name}!',
    ],
    ToastEvent.payment: [
      '{name} paid up. Excellent!',
      'Collected from {name}!',
      '{name} cleared the due!',
      'Cash in from {name}. Super!',
      '{name} settled up. Great!',
    ],
    ToastEvent.due: [
      'Due recorded for {name}.',
      '{name} still owes. Noted.',
      'Noted — collect from {name}.',
      '{name} due added.',
    ],
    ToastEvent.purchase: [
      'Bought from {name}. Saved!',
      'Stock in from {name}!',
      '{name} supplied. Recorded!',
      'Sheet from {name}. Nice!',
    ],
    ToastEvent.expense: [
      'Paid {name}. Noted!',
      '{name} expense recorded.',
    ],
    ToastEvent.wastageSold: [
      'Sold to {name}. Clever!',
      'Scrap to {name}. Free money!',
      '{name} took the scrap. Nice!',
    ],
    ToastEvent.sheetSent: [
      'On its way to {name}.',
      'Sheet sent to {name}.',
      '{name} got the sheet!',
    ],
    ToastEvent.piecesBack: [
      'Back from {name}. Good!',
      '{name} delivered. Counted!',
      'Pieces in from {name}!',
    ],
    ToastEvent.workerPaid: [
      '{name} paid. Well done!',
      'Wages to {name}. Done!',
      '{name} settled. Team happy!',
    ],
    ToastEvent.saved: [
      '{name} saved!',
      'Done — {name}!',
    ],
  };

  /// Fallbacks for when there is no name to use.
  static const Map<ToastEvent, List<String>> _plain = {
    ToastEvent.sale: [
      'Sale saved. Well done!',
      'Another sale in the book!',
      'Good sale. Money moving!',
      'Sale done. Keep it up!',
    ],
    ToastEvent.payment: [
      'Payment received. Great!',
      'Cash in. Well collected!',
      'Money in the bank!',
    ],
    ToastEvent.due: [
      'Due noted. Follow it up!',
      'Noted. Collect it soon!',
    ],
    ToastEvent.purchase: [
      'Stock added. Ready to work!',
      'Purchase saved. Good stock!',
      'Sheet in. Let us make money!',
      'Stock topped up!',
    ],
    ToastEvent.expense: [
      'Expense noted.',
      'Recorded. Watch the costs!',
      'Noted. Every rupee counts!',
    ],
    ToastEvent.wastageSold: [
      'Scrap sold. Free money!',
      'Wastage cleared. Smart!',
      'Nothing wasted. Well done!',
    ],
    ToastEvent.sheetSent: [
      'Sheet sent out. Tracked!',
      'Issued. Nothing lost now!',
    ],
    ToastEvent.piecesBack: [
      'Pieces received. Counted!',
      'Received and recorded!',
    ],
    ToastEvent.workerPaid: [
      'Worker paid. Team happy!',
      'Wages settled!',
    ],
    ToastEvent.saved: [
      'Saved!',
      'Done!',
      'All set!',
    ],
  };

  /// The next line for [event]. When [name] is given the reply always uses it.
  static String message(ToastEvent event, {String? name}) {
    final clean = (name ?? '').trim();
    final named = _named[event] ?? const [];

    final usable = (clean.isNotEmpty && named.isNotEmpty)
        ? named
        : (_plain[event] ?? const ['Saved!']);
    if (usable.isEmpty) return 'Saved!';

    final i = (_cursor[event] ?? 0) % usable.length;
    _cursor[event] = i + 1;
    return usable[i].replaceAll('{name}', _firstName(clean));
  }

  /// Long names make a toast wrap onto two lines, so use the first word.
  static String _firstName(String name) {
    final first = name.split(RegExp(r'\s+')).first;
    return first.length > 14 ? first.substring(0, 14) : first;
  }

  /// Shows a small floating toast. Safe to call after an await — it simply
  /// does nothing if the widget has gone.
  static void show(
    BuildContext context,
    ToastEvent event, {
    String? name,
    String? extra,
  }) {
    if (!context.mounted) return;
    final text = message(event, name: name);
    showText(context, extra == null ? text : '$text  $extra');
  }

  /// Same toast, but driven by a messenger captured earlier.
  ///
  /// Use this when the toast follows a `Navigator.pop()`: after the pop the
  /// original context's route is gone, so looking the messenger up from it can
  /// silently find nothing and the toast never appears. Grab the messenger
  /// BEFORE popping and hand it here.
  static void showWith(
    ScaffoldMessengerState messenger,
    ToastEvent event, {
    String? name,
  }) =>
      _showOn(messenger, message(event, name: name));

  /// Shows an arbitrary short line in the same compact style.
  static void showText(BuildContext context, String text) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    _showOn(messenger, text);
  }

  static void _showOn(ScaffoldMessengerState messenger, String text) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1F4E79),
          duration: const Duration(milliseconds: 1800),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          margin: const EdgeInsets.fromLTRB(40, 0, 40, 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22)),
          dismissDirection: DismissDirection.horizontal,
        ),
      );
  }

  /// Test helper — puts the rotation back to the start.
  @visibleForTesting
  static void resetRotation() => _cursor.clear();
}
