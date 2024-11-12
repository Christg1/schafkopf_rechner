import '../models/game_round.dart';
import '../models/game_types.dart';

class BalanceCalculator {
  /// Calculates new balances for all players after a game round
  /// Returns a map of player names to their new balances
  static Map<String, double> calculateNewBalances({
    required Map<String, double> currentBalances,
    required GameRound round,
    required List<String> players,
  }) {
    Map<String, double> newBalances = Map.from(currentBalances);

    switch (round.gameType) {
      case GameType.sauspiel:
        _calculateSauspielBalances(newBalances, round, players);
        break;
      case GameType.ramsch:
        _calculateRamschBalances(newBalances, round, players);
        break;
      default:
        _calculateSoloBalances(newBalances, round, players);
        break;
    }

    return newBalances;
  }

  /// Calculates balances for Sauspiel games
  static void _calculateSauspielBalances(
    Map<String, double> balances,
    GameRound round,
    List<String> players,
  ) {
    if (round.partner == null) {
      throw ArgumentError('Partner cannot be null for Sauspiel');
    }

    final List<String> team1 = [round.mainPlayer, round.partner!];
    final List<String> team2 = players.where((p) => !team1.contains(p)).toList();

    if (round.isWon) {
      // Team 1 wins
      for (final winner in team1) {
        balances[winner] = (balances[winner] ?? 0) + round.value;
      }
      for (final loser in team2) {
        balances[loser] = (balances[loser] ?? 0) - round.value;
      }
    } else {
      // Team 2 wins
      for (final loser in team1) {
        balances[loser] = (balances[loser] ?? 0) - round.value;
      }
      for (final winner in team2) {
        balances[winner] = (balances[winner] ?? 0) + round.value;
      }
    }
  }

  /// Calculates balances for Solo games (including Wenz, Geier, etc.)
  static void _calculateSoloBalances(
    Map<String, double> balances,
    GameRound round,
    List<String> players,
  ) {
    if (round.isWon) {
      // Solo player gets 3x the value (one from each opponent)
      balances[round.mainPlayer] = (balances[round.mainPlayer] ?? 0) + (round.value * 3);
      
      // Each opponent pays the base value
      for (String player in players) {
        if (player != round.mainPlayer) {
          balances[player] = (balances[player] ?? 0) - round.value;
        }
      }
    } else {
      // Solo player pays 3x the value (one to each opponent)
      balances[round.mainPlayer] = (balances[round.mainPlayer] ?? 0) - (round.value * 3);
      
      // Each opponent receives the base value
      for (String player in players) {
        if (player != round.mainPlayer) {
          balances[player] = (balances[player] ?? 0) + round.value;
        }
      }
    }
  }

  /// Calculates balances for Ramsch games
  static void _calculateRamschBalances(
    Map<String, double> balances,
    GameRound round,
    List<String> players,
  ) {
    // In Ramsch, the main player is the loser
    balances[round.mainPlayer] = (balances[round.mainPlayer] ?? 0) - (round.value * 3);
    
    // Other players split the winnings
    for (String player in players) {
      if (player != round.mainPlayer) {
        balances[player] = (balances[player] ?? 0) + round.value;
      }
    }
  }
} 