import '../models/game_types.dart';

class GameCalculator {
  /// Base multipliers for game types
  static double getGameTypeMultiplier(GameType type) {
    switch (type) {
      case GameType.sauspiel:
        return 1.0;
      default:
        return 2.0; // All other games (Wenz, Solo, Ramsch, etc.) are worth double
    }
  }

  /// Calculates the value of a game round based on various factors
  static double calculateGameValue({
    required GameType gameType,
    required double baseValue,
    List<String> knockingPlayers = const [],
    List<String> kontraPlayers = const [],
    List<String> rePlayers = const [],
    bool isSchneider = false,
    bool isSchwarz = false,
  }) {
    // 1. Start with base value and game type multiplier
    double gameBaseValue = baseValue * getGameTypeMultiplier(gameType);
    double value = gameBaseValue;
    
    // 2. Apply klopfen (each klopfen doubles the value)
    for (int i = 0; i < knockingPlayers.length; i++) {
      value *= 2;
    }

    // 3. For non-Ramsch games, apply additional multipliers
    if (gameType != GameType.ramsch) {
      // Kontra doubles the value
      if (kontraPlayers.isNotEmpty) {
        value *= 2;
      }
      
      // Re doubles the value again
      if (rePlayers.isNotEmpty) {
        value *= 2;
      }
      
      // Schneider and Schwarz each add the game's base value (not the original base value)
      if (isSchneider) {
        value += gameBaseValue;  // Add the game's base value (20 for Solo, 10 for Sauspiel)
      }
      if (isSchwarz) {
        value += gameBaseValue;  // Add the game's base value (20 for Solo, 10 for Sauspiel)
      }
    }

    return value;
  }
}