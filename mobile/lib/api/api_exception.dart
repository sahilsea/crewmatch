/// One entry of an error's `details`: which input was wrong and why.
class FieldError {
  const FieldError(this.field, this.message);

  factory FieldError.fromJson(Map<String, dynamic> json) => FieldError(
        json['field'] as String? ?? '',
        json['message'] as String? ?? 'Invalid value',
      );

  final String field;
  final String message;
}

/// An error from the API, which always answers `{ error, details? }`.
class ApiException implements Exception {
  const ApiException(this.status, this.message, {this.details = const []});

  /// Reads a decoded error body. Falls back to a generic message when the
  /// server sent something else (an HTML page from a proxy, say).
  factory ApiException.fromBody(int status, Object? body) {
    if (body is Map<String, dynamic> && body['error'] is String) {
      final details = body['details'];
      return ApiException(
        status,
        body['error'] as String,
        details: [
          if (details is List)
            for (final d in details.whereType<Map<String, dynamic>>())
              FieldError.fromJson(d),
        ],
      );
    }
    return ApiException(status, 'Request failed ($status)');
  }

  /// HTTP status, or 0 when the server could not be reached at all.
  final int status;
  final String message;
  final List<FieldError> details;

  bool get isOffline => status == 0;

  /// `{ field: message }` for showing errors under form inputs. Nested paths
  /// such as `interests.0` are grouped under their top-level field, and the
  /// first message for a field wins.
  Map<String, String> get fieldErrors {
    final errors = <String, String>{};
    for (final d in details) {
      errors.putIfAbsent(d.field.split('.').first, () => d.message);
    }
    return errors;
  }

  @override
  String toString() => message;
}
