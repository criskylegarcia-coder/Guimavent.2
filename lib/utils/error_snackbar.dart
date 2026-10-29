import 'package:flutter/material.dart';

import '../repositories/repository_exception.dart';

/// Awaits [future]; if it throws, shows a SnackBar with a friendly message
/// and resolves to [fallback] instead of letting the error propagate.
///
/// Used to wrap the repository calls FutureBuilder-based screens make in
/// initState, so a real network/database error surfaces to the user instead
/// of leaving the screen stuck on its loading spinner forever (which is what
/// happens if a Future backing a FutureBuilder simply throws and nothing
/// catches it).
Future<T> withErrorFallback<T>(
  BuildContext context,
  Future<T> future, {
  required T fallback,
}) async {
  try {
    return await future;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessageFor(e))));
    }
    return fallback;
  }
}

/// The same friendly-message rule [withErrorFallback] uses internally,
/// exposed for call sites that need to show an error SnackBar directly
/// (e.g. after an action's own try/catch, not a FutureBuilder's initState).
String errorMessageFor(Object error) {
  if (error is RepositoryException) return error.message;
  return 'Something went wrong. Please try again.';
}
