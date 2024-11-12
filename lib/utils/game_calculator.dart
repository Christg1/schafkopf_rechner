import 'dart:math';
import '../models/game_types.dart';

class GameCalculator {
  /// Calculates the value of a game round based on various factors
  /// 
  /// [baseValue] is the basic point value for the game
  /// [knockingPlayers] list of players who knocked (each doubles the value)
  /// [kontraPlayers] list of players who called Kontra (doubles the value)
  /// [rePlayers] list of players who called Re (doubles the value)
  /// [isSchneider] adds baseValue if true
  /// [isSchwarz] adds baseValue if true
  static double calculateGameValue({
    required GameType gameType,
    required int baseValue,
    required List<String> knockingPlayers,
    required List<String> kontraPlayers,
    required List<String> rePlayers,
    required bool isSchneider,
    required bool isSchwarz,
  }) {
    // Start with base value
    double value = baseValue.toDouble();
    
    // Double the base value for solo games and ramsch
    if (gameType != GameType.sauspiel) {
      value = baseValue * 2;
    }

    // Apply knocks (each knock doubles)
    if (knockingPlayers.isNotEmpty) {
      value *= pow(2, knockingPlayers.length);
    }

    // Apply Kontra (doubles)
    if (kontraPlayers.isNotEmpty) {
      value *= 2;
    }

    // Apply Re (doubles)
    if (rePlayers.isNotEmpty) {
      value *= 2;
    }

    // Add Schneider bonus (adds base value)
    if (isSchneider) {
      value += baseValue;
    }

    // Add Schwarz bonus (adds base value)
    if (isSchwarz) {
      value += baseValue;
    }

    return value;
  }
} 