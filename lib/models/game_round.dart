import 'game_types.dart';

class GameRound {
  final GameType gameType;
  final String mainPlayer;
  final String? partner;
  final CardSuit? suit;
  final bool isWon;
  final bool isSchneider;
  final bool isSchwarz;
  final List<String> knockingPlayers;
  final List<String> kontraPlayers;
  final List<String> rePlayers;
  final double value;

  GameRound({
    required this.gameType,
    required this.mainPlayer,
    this.partner,
    this.suit,
    required this.isWon,
    required this.isSchneider,
    required this.isSchwarz,
    required this.knockingPlayers,
    required this.kontraPlayers,
    required this.rePlayers,
    required this.value,
  });

  Map<String, dynamic> toFirestore() => {
    'gameType': gameType.name,
    'mainPlayer': mainPlayer,
    'partner': partner,
    'suit': suit?.name,
    'isWon': isWon,
    'isSchneider': isSchneider,
    'isSchwarz': isSchwarz,
    'knockingPlayers': knockingPlayers,
    'kontraPlayers': kontraPlayers,
    'rePlayers': rePlayers,
    'value': value,
  };

  factory GameRound.fromFirestore(Map<String, dynamic> data) => GameRound(
    gameType: GameType.values.firstWhere((e) => e.name == data['gameType']),
    mainPlayer: data['mainPlayer'],
    partner: data['partner'],
    suit: data['suit'] != null 
        ? CardSuit.values.firstWhere((e) => e.name == data['suit'])
        : null,
    isWon: data['isWon'],
    isSchneider: data['isSchneider'] ?? false,
    isSchwarz: data['isSchwarz'] ?? false,
    knockingPlayers: List<String>.from(data['knockingPlayers'] ?? []),
    kontraPlayers: List<String>.from(data['kontraPlayers'] ?? []),
    rePlayers: List<String>.from(data['rePlayers'] ?? []),
    value: data['value']?.toDouble() ?? 0.0,
  );
} 