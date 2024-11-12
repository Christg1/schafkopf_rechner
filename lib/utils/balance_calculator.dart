import '../models/game_round.dart';
import '../models/game_types.dart';

class BalanceCalculator {
  /// Calculates new balances for all players after a game round
  /// Returns a map of player names to their new balances (in euros)
  static Map<String, double> calculateNewBalances({
    required Map<String, double> currentBalances,
    required GameRound round,
    required List<String> players,
  }) {
    Map<String, double> newBalances = Map.from(currentBalances);
    double typeMultiplier = getGameTypeMultiplier(round.gameType);
    double adjustedValue = round.value * typeMultiplier;

    switch (round.gameType) {
      case GameType.sauspiel:
        _calculateSauspielBalances(newBalances, adjustedValue, round, players);
        break;
      case GameType.ramsch:
        _calculateRamschBalances(newBalances, adjustedValue, round, players);
        break;
      default:
        _calculateSoloBalances(newBalances, adjustedValue, round, players);
        break;
    }

    return newBalances;
  }

  /// Calculates balances for Sauspiel games
  static void _calculateSauspielBalances(
    Map<String, double> balances,
    double valueInEuros,
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
        balances[winner] = (balances[winner] ?? 0) + valueInEuros;
      }
      for (final loser in team2) {
        balances[loser] = (balances[loser] ?? 0) - valueInEuros;
      }
    } else {
      // Team 2 wins
      for (final loser in team1) {
        balances[loser] = (balances[loser] ?? 0) - valueInEuros;
      }
      for (final winner in team2) {
        balances[winner] = (balances[winner] ?? 0) + valueInEuros;
      }
    }
  }

  /// Calculates balances for Solo games (including Wenz, Geier, etc.)
  static void _calculateSoloBalances(
    Map<String, double> balances,
    double valueInEuros,
    GameRound round,
    List<String> players,
  ) {
    if (round.isWon) {
      // Solo player gets 3x the value (one from each opponent)
      balances[round.mainPlayer] = (balances[round.mainPlayer] ?? 0) + (valueInEuros * 3);
      
      // Each opponent pays the base value
      for (String player in players) {
        if (player != round.mainPlayer) {
          balances[player] = (balances[player] ?? 0) - valueInEuros;
        }
      }
    } else {
      // Solo player pays 3x the value (one to each opponent)
      balances[round.mainPlayer] = (balances[round.mainPlayer] ?? 0) - (valueInEuros * 3);
      
      // Each opponent receives the base value
      for (String player in players) {
        if (player != round.mainPlayer) {
          balances[player] = (balances[player] ?? 0) + valueInEuros;
        }
      }
    }
  }

  /// Calculates balances for Ramsch games
  static void _calculateRamschBalances(
    Map<String, double> balances,
    double valueInEuros,
    GameRound round,
    List<String> players,
  ) {
    // In Ramsch, the main player is the loser
    balances[round.mainPlayer] = (balances[round.mainPlayer] ?? 0) - (valueInEuros * 3);
    
    // Other players split the winnings
    for (String player in players) {
      if (player != round.mainPlayer) {
        balances[player] = (balances[player] ?? 0) + valueInEuros;
      }
    }
  }

  /// Add multiplier for game types
  static double getGameTypeMultiplier(GameType type) {
    switch (type) {
      case GameType.sauspiel:
        return 1.0;
      case GameType.ramsch:
        return 2.0;
      default:
        return 2.0; // All solo games are worth double
    }
  }
} 