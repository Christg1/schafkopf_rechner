import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_round.dart';

class Game {
  final String id;
  final DateTime date;
  final List<String> players;
  final List<GameRound> rounds;
  final int baseValue;
  final int currentDealer;

  Game({
    required this.id,
    required this.date,
    required this.players,
    required this.rounds,
    required this.baseValue,
    required this.currentDealer,
  });

  Map<String, dynamic> toFirestore() => {
    'date': Timestamp.fromDate(date),
    'players': players,
    'rounds': rounds.map((round) => round.toFirestore()).toList(),
    'baseValue': baseValue,
    'currentDealer': currentDealer,
  };

  factory Game.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Game(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      players: List<String>.from(data['players']),
      rounds: (data['rounds'] as List)
          .map((round) => GameRound.fromFirestore(round))
          .toList(),
      baseValue: data['baseValue'] ?? 10,
      currentDealer: data['currentDealer'] ?? 0,
    );
  }
} 