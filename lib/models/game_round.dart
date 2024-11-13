import 'game_types.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GameRound {
  final GameType gameType;
  final String mainPlayer;
  final String? partner;
  final bool isWon;
  final double value;
  final DateTime timestamp;

  GameRound({
    required this.gameType,
    required this.mainPlayer,
    this.partner,
    required this.isWon,
    required this.value,
    required this.timestamp,
  });

  factory GameRound.fromFirestore(Map<String, dynamic> map) {
    return GameRound(
      gameType: GameType.values.firstWhere(
        (e) => e.name == map['gameType'],
      ),
      mainPlayer: map['mainPlayer'] as String,
      partner: map['partner'] as String?,
      isWon: map['isWon'] as bool,
      value: (map['value'] as num).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'gameType': gameType.name,
      'mainPlayer': mainPlayer,
      'partner': partner,
      'isWon': isWon,
      'value': value,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

enum CardSuit {
  eichel,
  gras,
  herz,
  schellen,
} 