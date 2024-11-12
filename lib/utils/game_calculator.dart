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
    required bool isSchneider,
    required bool isSchwarz,
  }) {
    // Start with base value
    double value = double.parse(baseValue.toStringAsFixed(2));
    double multiplier = 1.0;

    // Add multiplier for knocking players (x2 for each)
    multiplier *= pow(2, knockingPlayers.length).toDouble();

    // Add multiplier for kontra/re (x2 each)
    if (kontraPlayers.isNotEmpty) multiplier *= 2;
    if (rePlayers.isNotEmpty) multiplier *= 2;

    // Calculate base game value with multipliers
    double finalValue = value * multiplier;

    // Add baseValue for Schneider and Schwarz (not multiplied)
    if (isSchneider) finalValue += baseValue;
    if (isSchwarz) finalValue += baseValue;

    // Apply game type multiplier
    switch (gameType) {
      case GameType.sauspiel:
        return double.parse(finalValue.toStringAsFixed(2));
      case GameType.wenz:
      case GameType.farbwenz:
      case GameType.geier:
      case GameType.farbgeier:
      case GameType.farbspiel:
        return double.parse((finalValue * 2).toStringAsFixed(2));  // Solo games are worth double
      case GameType.ramsch:
        return double.parse(finalValue.toStringAsFixed(2));
    }
  }
} 