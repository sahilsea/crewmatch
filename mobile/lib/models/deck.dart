import 'user.dart';

/// `GET /deck`: candidates ranked best fit first.
class Deck {
  const Deck({required this.cards, this.scoredAgainstCrew = false});

  factory Deck.fromJson(Map<String, dynamic> json) => Deck(
        cards: User.listFrom(json['deck']),
        scoredAgainstCrew: json['scoredAgainst'] == 'crew',
      );

  final List<User> cards;

  /// True when cards are scored against your whole crew rather than just you.
  final bool scoredAgainstCrew;
}

enum SwipeDirection { left, right }

/// `POST /swipe`: `{ match, user? }`. [user] (with email) is set on a match.
class SwipeResult {
  const SwipeResult({required this.match, this.user});

  factory SwipeResult.fromJson(Map<String, dynamic> json) => SwipeResult(
        match: json['match'] as bool? ?? false,
        user: json['user'] is Map<String, dynamic>
            ? User.fromJson(json['user'] as Map<String, dynamic>)
            : null,
      );

  final bool match;
  final User? user;
}
