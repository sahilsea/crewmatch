// Small, forgiving readers for decoded JSON values.

List<String> stringList(Object? value) =>
    value is List ? [for (final v in value) if (v is String) v] : const [];

int intOr(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;

int? intOrNull(Object? value) => value is num ? value.toInt() : null;

/// Parses an ISO 8601 timestamp into local time.
DateTime? dateOrNull(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

List<Map<String, dynamic>> objectList(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : const [];

/// Looks an enum value up by its `name`, with a fallback for unknown values.
T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.asNameMap()[name] ?? fallback;
