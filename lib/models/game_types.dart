enum GameType {
  sauspiel,
  wenz,
  farbwenz,
  geier,
  farbgeier,
  farbspiel,
  ramsch
}

enum CardSuit {
  eichel,
  gras,
  herz,
  schellen
}

extension GameTypeEmoji on GameType {
  String get emoji {
    switch (this) {
      case GameType.sauspiel:
        return '🐷';
      case GameType.farbspiel:
        return '👑';
      case GameType.wenz:
        return '🃏';
      case GameType.farbwenz:
        return '🎨';
      case GameType.geier:
        return '🦅';
      case GameType.farbgeier:
        return '🎯';
      case GameType.ramsch:
        return '💥';
      default:
        return '🎮';
    }
  }

  bool get allowedInThreePlayerGame {
    return this != GameType.sauspiel;  // Sauspiel requires 4 players
  }
} 