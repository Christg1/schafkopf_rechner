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

extension GameTypeDisplay on GameType {
  String get displayName {
    switch (this) {
      case GameType.sauspiel:
        return 'Sauspiel';
      case GameType.wenz:
        return 'Wenz';
      case GameType.farbwenz:
        return 'Farbwenz';
      case GameType.geier:
        return 'Geier';
      case GameType.farbgeier:
        return 'Farbgeier';
      case GameType.farbspiel:
        return 'Farbsolo';
      case GameType.ramsch:
        return 'Ramsch';
    }
  }

  bool get isSolo {
    switch (this) {
      case GameType.wenz:
      case GameType.farbwenz:
      case GameType.geier:
      case GameType.farbgeier:
      case GameType.farbspiel:
        return true;
      case GameType.sauspiel:
      case GameType.ramsch:
        return false;
    }
  }
} 