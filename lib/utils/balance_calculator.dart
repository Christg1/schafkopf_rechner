import 'dart:math';

import '../models/game_round.dart';
import '../models/game_types.dart';

class BalanceCalculator {
  /// Calculates new balances for all players after a game round
  static Map<String, double> calculateNewBalances({
    required Map<String, double> currentBalances,
    required GameRound round,
    required List<String> players,
  }) {
    final newBalances = Map<String, double>.from(currentBalances);
    
    switch (round.gameType) {
      case GameType.sauspiel:
        _calculateSauspielBalances(
          balances: newBalances,
          players: players,
          mainPlayer: round.mainPlayer,
          partner: round.partner!,
          isWon: round.isWon,
          value: round.value,
        );
        break;
      
      case GameType.ramsch:
        _calculateRamschBalances(
          balances: newBalances,
          players: players,
          loser: round.mainPlayer,
          value: round.value,
        );
        break;
      
      default:
        _calculateSoloBalances(
          balances: newBalances,
          players: players,
          mainPlayer: round.mainPlayer,
          isWon: round.isWon,
          value: round.value,
        );
    }

    return newBalances;
  }

  static void _calculateSauspielBalances({
    required Map<String, double> balances,
    required List<String> players,
    required String mainPlayer,
    required String partner,
    required bool isWon,
    required double value,
  }) {
    final team1 = [mainPlayer, partner];
    final team2 = players.where((p) => !team1.contains(p)).toList();

    if (isWon) {
      for (final winner in team1) {
        balances[winner] = (balances[winner] ?? 0) + value;
      }
      for (final loser in team2) {
        balances[loser] = (balances[loser] ?? 0) - value;
      }
    } else {
      for (final loser in team1) {
        balances[loser] = (balances[loser] ?? 0) - value;
      }
      for (final winner in team2) {
        balances[winner] = (balances[winner] ?? 0) + value;
      }
    }
  }

  static void _calculateSoloBalances({
    required Map<String, double> balances,
    required List<String> players,
    required String mainPlayer,
    required bool isWon,
    required double value,
  }) {
    final multiplier = players.length - 1; // 2 for 3 players, 3 for 4 players
    
    if (isWon) {
      balances[mainPlayer] = (balances[mainPlayer] ?? 0) + (value * multiplier);
      for (final player in players.where((p) => p != mainPlayer)) {
        balances[player] = (balances[player] ?? 0) - value;
      }
    } else {
      balances[mainPlayer] = (balances[mainPlayer] ?? 0) - (value * multiplier);
      for (final player in players.where((p) => p != mainPlayer)) {
        balances[player] = (balances[player] ?? 0) + value;
      }
    }
  }

  static void _calculateRamschBalances({
    required Map<String, double> balances,
    required List<String> players,
    required String loser,
    required double value,
  }) {
    final multiplier = players.length - 1; // 2 for 3 players, 3 for 4 players
    balances[loser] = (balances[loser] ?? 0) - (value * multiplier);
    
    for (final player in players.where((p) => p != loser)) {
      balances[player] = (balances[player] ?? 0) + value;
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