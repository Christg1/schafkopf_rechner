import 'dart:math';
import '../models/game_types.dart';

class GameCalculator {
  /// Calculates the value of a game round based on various factors
  static double calculateGameValue({
    required GameType gameType,
    required double baseValue,
    required List<String> knockingPlayers,
    required List<String> kontraPlayers,
    required List<String> rePlayers,
    bool isSchneider = false,
    bool isSchwarz = false,
  }) {
    double value = baseValue;
    
    // Special handling for Ramsch
    if (gameType == GameType.ramsch) {
      // No need to modify the base value for Ramsch
      // The value distribution will be handled in BalanceCalculator
      return baseValue;
    }

    // For non-Ramsch games, apply multipliers
    value *= (1 + knockingPlayers.length * 0.5);
    
    if (kontraPlayers.isNotEmpty) value *= 2;
    if (isSchneider) value *= 2;
    if (isSchwarz) value *= 2;

    return value;
  }

  static Map<String, double> calculateBalances({
    required GameType gameType,
    required List<String> players,
    required String mainPlayer,
    String? partner,
    required bool isWon,
    required double value,
  }) {
    final balances = <String, double>{};
    
    if (players.length == 3) {
      if (gameType == GameType.sauspiel) {
        throw Exception('Sauspiel nicht möglich mit 3 Spielern');
      }
      
      for (final player in players) {
        if (player == mainPlayer) {
          balances[player] = isWon ? value : -value;
        } else {
          balances[player] = isWon ? -value/2 : value/2;
        }
      }
    } else {
      // 4-player game logic
      for (final player in players) {
        if (player == mainPlayer) {
          balances[player] = isWon ? value * 3 : -value * 3;
        } else if (player == partner && gameType == GameType.sauspiel) {
          balances[player] = isWon ? value : -value;
        } else {
          balances[player] = isWon ? -value : value;
        }
      }
    }

    return balances;
  }
} 