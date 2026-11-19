import 'json.dart';

/// `GET /options`: the allowed values for every profile chip, so web and
/// mobile never drift apart.
class ProfileOptions {
  const ProfileOptions(this.values, {this.maxSuperpowers = 2});

  factory ProfileOptions.fromJson(Map<String, dynamic> json) => ProfileOptions(
        {
          for (final entry in json.entries)
            if (entry.value is List) entry.key: stringList(entry.value),
        },
        maxSuperpowers: intOr(json['maxSuperpowers'], 2),
      );

  /// Field name (`role`, `interests`...) to its allowed values.
  final Map<String, List<String>> values;
  final int maxSuperpowers;

  List<String> operator [](String field) => values[field] ?? const [];
}
