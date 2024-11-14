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
      _calculateRamschBalances(
        balances: newBalances,
        players: players,
        loser: round.mainPlayer,
        valueInEuros: round.value,
      );
    } else if (round.gameType == GameType.sauspiel) {
      _calculateSauspielBalances(
        balances: newBalances,
        players: players,
        mainPlayer: round.mainPlayer,
        partner: round.partner!,
        isWon: round.isWon,
        valueInEuros: round.value,
      );
    } else {
      _calculateSoloBalances(
        balances: newBalances,
        players: players,
        mainPlayer: round.mainPlayer,
        isWon: round.isWon,
        valueInEuros: round.value,
      );
    }

    return newBalances;
  }

  /// Keep all existing helper methods but make them update the balances map directly
  static void _calculateSauspielBalances({
    required Map<String, double> balances,
    required List<String> players,
    required String mainPlayer,
    required String partner,
    required bool isWon,
    required double valueInEuros,
  }) {
    final List<String> team1 = [mainPlayer, partner];
    final List<String> team2 = players.where((p) => !team1.contains(p)).toList();

    if (isWon) {
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

  static void _calculateSoloBalances({
    required Map<String, double> balances,
    required List<String> players,
    required String mainPlayer,
    required bool isWon,
    required double valueInEuros,
  }) {
    if (players.length == 3) {
      // 3-player gamea
      for (final player in players) {
        if (player == mainPlayer) {
          balances[player] = (balances[player] ?? 0) + 
              (isWon ? valueInEuros * 2 : -valueInEuros * 2);
        } else {
          balances[player] = (balances[player] ?? 0) + 
              (isWon ? -valueInEuros : valueInEuros);
        }
      }
    } else {
      // 4-player game
      for (final player in players) {
        if (player == mainPlayer) {
          balances[player] = (balances[player] ?? 0) + 
              (isWon ? valueInEuros * 3 : -valueInEuros * 3);
        } else {
          balances[player] = (balances[player] ?? 0) + 
              (isWon ? -valueInEuros : valueInEuros);
        }
      }
    }
  }

  static void _calculateRamschBalances({
    required Map<String, double> balances,
    required List<String> players,
    required String loser,
    required double valueInEuros,
  }) {
    if (players.length == 3) {
      // For 3-player Ramsch
      balances[loser] = (balances[loser] ?? 0) - (valueInEuros * 2);
      for (String player in players) {
        if (player != loser) {
          balances[player] = (balances[player] ?? 0) + valueInEuros;
        }
      }
    } else {
      // For 4-player Ramsch
      double adjustedValue = valueInEuros * 2;  // Double the base value for 4 players
      balances[loser] = (balances[loser] ?? 0) - (adjustedValue * 3);
      for (String player in players) {
        if (player != loser) {
          balances[player] = (balances[player] ?? 0) + adjustedValue;
        }
      }
    }
  }

  // Keep the existing getGameTypeMultiplier method
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