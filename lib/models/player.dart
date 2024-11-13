import 'package:schafkopf_rechner/models/game_types.dart';
import 'package:schafkopf_rechner/models/session.dart';

class Player {
  final String name;
  int gamesParticipated = 0;
  int gamesPlayed = 0;
  int gamesWon = 0;
  double totalEarnings = 0.0;
  Map<GameType, int> gameTypeStats = {};

  Player({required this.name});

  double get winRate => gamesPlayed > 0 ? gamesWon / gamesPlayed : 0;
  double get participationRate => gamesParticipated > 0 ? gamesPlayed / gamesParticipated : 0;
  double get averageEarningsPerGame => gamesParticipated > 0 ? totalEarnings / gamesParticipated : 0;

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

  List<PerformancePoint> getPerformanceHistory(List<Session> sessions) {
    List<PerformancePoint> history = [];
    int totalGamesPlayed = 0;
    int totalGamesWon = 0;
    
    // Sort sessions by date
    final sortedSessions = sessions.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
      
    for (final session in sortedSessions) {
      int sessionGamesPlayed = 0;
      int sessionGamesWon = 0;
      
      for (final round in session.rounds) {
        if (round.mainPlayer == name) {
          sessionGamesPlayed++;
          if (round.isWon) sessionGamesWon++;
        }
      }
      
      if (sessionGamesPlayed > 0) {
        totalGamesPlayed += sessionGamesPlayed;
        totalGamesWon += sessionGamesWon;
        
        history.add(PerformancePoint(
          date: session.date,
          winRate: totalGamesWon / totalGamesPlayed,
          gamesPlayed: totalGamesPlayed,
          gamesWon: totalGamesWon,
        ));
      }
    }
    
    return history;
  }
}

class PerformancePoint {
  final DateTime date;
  final double winRate;
  final int gamesPlayed;
  final int gamesWon;

  PerformancePoint({
    required this.date,
    required this.winRate,
    required this.gamesPlayed,
    required this.gamesWon,
  });
} 