import 'dart:math';

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
    final newBalances = Map<String, double>.from(currentBalances);
    
    if (round.gameType == GameType.ramsch) {
      // The loser pays the base value, others split it equally
      final loserPays = round.value;
      final winnersShare = loserPays / (players.length - 1);
      
      for (final player in players) {
        if (player == round.mainPlayer) {
          // Loser pays the full amount
          newBalances[player] = (newBalances[player] ?? 0) - loserPays;
        } else {
          // Winners split the amount equally
          newBalances[player] = (newBalances[player] ?? 0) + winnersShare;
        }
      }
    } else {
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
    // For 3-player games
    if (players.length == 3) {
      if (round.isWon) {
        balances[round.mainPlayer] = (balances[round.mainPlayer] ?? 0) + valueInEuros;
        for (String player in players) {
          if (player != round.mainPlayer) {
            balances[player] = (balances[player] ?? 0) - (valueInEuros / 2);
          }
        }
      } else {
        balances[round.mainPlayer] = (balances[round.mainPlayer] ?? 0) - valueInEuros;
        for (String player in players) {
          if (player != round.mainPlayer) {
            balances[player] = (balances[player] ?? 0) + (valueInEuros / 2);
          }
        }
      }
      return;
    }

    // For 4-player games
    // Note: valueInEuros already includes the 2x multiplier for solo games
    // so we don't multiply it again
    if (round.isWon) {
      // Solo player gets the base value from each opponent (3x total)
      balances[round.mainPlayer] = (balances[round.mainPlayer] ?? 0) + (valueInEuros * 1.5);
      
      // Each opponent pays the base value
      for (String player in players) {
        if (player != round.mainPlayer) {
          balances[player] = (balances[player] ?? 0) - (valueInEuros / 2);
        }
      }
    } else {
      // Solo player pays the base value to each opponent (3x total)
      balances[round.mainPlayer] = (balances[round.mainPlayer] ?? 0) - (valueInEuros * 1.5);
      
      // Each opponent receives the base value
      for (String player in players) {
        if (player != round.mainPlayer) {
          balances[player] = (balances[player] ?? 0) + (valueInEuros / 2);
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
    if (players.length == 3) {
      // For 3-player Ramsch, use baseValue directly
      balances[round.mainPlayer] = (balances[round.mainPlayer] ?? 0) - (valueInEuros * 2);
      for (String player in players) {
        if (player != round.mainPlayer) {
          balances[player] = (balances[player] ?? 0) + valueInEuros;
        }
      }
    } else {
      // For 4-player Ramsch, use doubled baseValue
      double adjustedValue = valueInEuros * 2;  // Double the base value for 4 players
      balances[round.mainPlayer] = (balances[round.mainPlayer] ?? 0) - (adjustedValue * 3);
      for (String player in players) {
        if (player != round.mainPlayer) {
          balances[player] = (balances[player] ?? 0) + adjustedValue;
        }
      }
    }
  }

  /// Add multiplier for game types
  static double getGameTypeMultiplier(GameType type) {
    switch (type) {
      case GameType.sauspiel:
        return 1.0;
      default:
        return 2.0; // All solo games and Ramsch are worth double
    }
  }

  /// Calculates the final settlement between players
  /// Returns a list of settlements in the format: "Player A owes Player B X€"
  static List<Settlement> calculateFinalSettlement(Map<String, double> finalBalances) {
    List<Settlement> settlements = [];
    List<MapEntry<String, double>> players = finalBalances.entries.toList();
    
    // Sort players by balance (negative to positive)
    players.sort((a, b) => a.value.compareTo(b.value));

    int i = 0;  // Index for players who owe money (negative balance)
    int j = players.length - 1;  // Index for players who receive money (positive balance)

    while (i < j) {
      String debtor = players[i].key;
      String creditor = players[j].key;
      double debtorBalance = players[i].value.abs();
      double creditorBalance = players[j].value;

      double settlementAmount = min(debtorBalance, creditorBalance);
      
      if (settlementAmount > 0) {
        settlements.add(Settlement(
          from: debtor,
          to: creditor,
          amount: settlementAmount,
        ));
      }

      // Update balances
      players[i] = MapEntry(debtor, players[i].value + settlementAmount);
      players[j] = MapEntry(creditor, players[j].value - settlementAmount);

      // Move indices if a balance has been fully settled
      if (players[i].value.abs() < 0.01) i++;
      if (players[j].value < 0.01) j--;
    }

    return settlements;
  }
}

/// Represents a single settlement between two players
class Settlement {
  final String from;
  final String to;
  final double amount;

  Settlement({
    required this.from,
    required this.to,
    required this.amount,
  });

  @override
  String toString() {
    return '$from owes $to ${amount.toStringAsFixed(2)}€';
  }
} 