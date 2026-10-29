import 'dart:async';

/// Runs two requests at the same time and returns both results.
///
/// If either fails, rethrows that failure itself rather than a
/// [ParallelWaitError], so callers can keep catching `ApiException`.
Future<(A, B)> waitBoth<A, B>(Future<A> a, Future<B> b) async {
  try {
    return await (a, b).wait;
  } on ParallelWaitError<(A?, B?), (AsyncError?, AsyncError?)> catch (e) {
    final failure = (e.errors.$1 ?? e.errors.$2)!;
    Error.throwWithStackTrace(failure.error, failure.stackTrace);
  }
}
