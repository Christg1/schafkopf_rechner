import 'package:schafkopf_rechner/models/game_types.dart';

class Player {
  final String name;
  int gamesParticipated = 0;
  int gamesPlayed = 0;
  int gamesWon = 0;
  double totalEarnings = 0.0;
  Map<GameType, int> gameTypeStats = {};

  Player({required this.name});

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'gamesParticipated': gamesParticipated,
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'totalEarnings': totalEarnings,
      'gameTypeStats': gameTypeStats.map((key, value) => MapEntry(key.name, value)),
    };
  }

  factory Player.fromFirestore(Map<String, dynamic> data) {
    final player = Player(name: data['name']);
    player.gamesParticipated = data['gamesParticipated'] ?? 0;
    player.gamesPlayed = data['gamesPlayed'] ?? 0;
    player.gamesWon = data['gamesWon'] ?? 0;
    player.totalEarnings = (data['totalEarnings'] ?? 0.0).toDouble();
    
    if (data['gameTypeStats'] != null) {
      player.gameTypeStats = (data['gameTypeStats'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          GameType.values.firstWhere((e) => e.name == key),
          value as int,
        ),
      );
    }
    
    return player;
  }
} 