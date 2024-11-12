import 'dart:math';
import '../models/game_types.dart';

class GameCalculator {
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