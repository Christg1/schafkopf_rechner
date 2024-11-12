import 'package:schafkopf_rechner/models/game_types.dart';

class Player {
  final String name;
  int gamesPlayed = 0;
  int gamesWon = 0;
  double totalEarnings = 0.0;
  Map<GameType, int> gameTypeStats = {};

  Player({required this.name});

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'totalEarnings': totalEarnings,
      'gameTypeStats': gameTypeStats.map((key, value) => MapEntry(key.name, value)),
    };
  }
} 