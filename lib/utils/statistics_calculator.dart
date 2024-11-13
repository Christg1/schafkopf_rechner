import '../models/game_round.dart';
import '../models/game_types.dart';
import '../models/statistics_data.dart';

class StatisticsCalculator {
  static PlayerStatistics calculateGameTypeStats(
    List<GameRound> rounds,
    String playerName,
  ) {
    final stats = PlayerStatistics(
      name: playerName,
      gamesPlayed: 0,
      gamesWon: 0,
      gamesParticipated: 0,
      totalEarnings: 0,
      gameTypeStats: {},
    );

    for (final round in rounds) {
      if (round.mainPlayer == playerName) {
        stats.gamesPlayed++;
        if (round.isWon) stats.gamesWon++;
        
        // Update game type stats
        final currentCount = stats.gameTypeStats[round.gameType] ?? 0;
        stats.gameTypeStats[round.gameType] = currentCount + 1;
        
        stats.totalEarnings += round.isWon ? round.value : -round.value;
      }
      stats.gamesParticipated++;
    }

    return stats;
  }

  static double _calculateTeamEarnings(List<GameRound> rounds) {
    return 0;
  }
} 