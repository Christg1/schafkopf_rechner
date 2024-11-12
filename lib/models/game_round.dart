import 'game_types.dart';

class GameRound {
  final String mainPlayer;
  final String? partner;
  final GameType gameType;
  final CardSuit? suit;
  final bool isWon;
  final bool isSchneider;
  final bool isSchwarz;
  final List<String> knockingPlayers;
  final List<String> kontraPlayers;
  final List<String> rePlayers;
  final double value;

  GameRound({
    required this.mainPlayer,
    this.partner,
    required this.gameType,
    this.suit,
    required this.isWon,
    required this.isSchneider,
    required this.isSchwarz,
    required this.knockingPlayers,
    required this.kontraPlayers,
    required this.rePlayers,
    required this.value,
  });

  factory GameRound.fromFirestore(Map<String, dynamic> map) {
    return GameRound(
      mainPlayer: map['mainPlayer'] as String,
      partner: map['partner'] as String?,
      gameType: GameType.values.firstWhere(
        (e) => e.name == map['gameType'],
      ),
      suit: map['suit'] != null 
          ? CardSuit.values.firstWhere((e) => e.name == map['suit'])
          : null,
      isWon: map['isWon'] as bool,
      isSchneider: map['isSchneider'] as bool? ?? false,
      isSchwarz: map['isSchwarz'] as bool? ?? false,
      knockingPlayers: List<String>.from(map['knockingPlayers'] ?? []),
      kontraPlayers: List<String>.from(map['kontraPlayers'] ?? []),
      rePlayers: List<String>.from(map['rePlayers'] ?? []),
      value: (map['value'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'mainPlayer': mainPlayer,
      'partner': partner,
      'gameType': gameType.name,
      'suit': suit?.name,
      'isWon': isWon,
      'isSchneider': isSchneider,
      'isSchwarz': isSchwarz,
      'knockingPlayers': knockingPlayers,
      'kontraPlayers': kontraPlayers,
      'rePlayers': rePlayers,
      'value': value,
    };
  }
}

enum CardSuit {
  eichel,
  gras,
  herz,
  schellen,
} 