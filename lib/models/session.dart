import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_round.dart';

class Session {
  final String id;
  final DateTime date;
  final List<String> players;
  final int baseValue;
  final List<GameRound> rounds;
  final Map<String, double> playerBalances;
  final int currentDealer;
  final bool isActive;

  Session({
    required this.id,
    required this.date,
    required this.players,
    required this.baseValue,
    required this.rounds,
    required this.playerBalances,
    required this.currentDealer,
    required this.isActive,
  });

  Map<String, dynamic> toFirestore() => {
    'date': Timestamp.fromDate(date),
    'players': players,
    'baseValue': baseValue,
    'rounds': rounds.map((r) => r.toFirestore()).toList(),
    'playerBalances': playerBalances,
    'currentDealer': currentDealer,
    'isActive': isActive,
  };

  factory Session.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Session(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      players: List<String>.from(data['players']),
      baseValue: data['baseValue'] ?? 10,
      rounds: (data['rounds'] as List? ?? [])
          .map((r) => GameRound.fromFirestore(r))
          .toList(),
      playerBalances: Map<String, double>.from(data['playerBalances'] ?? {}),
      currentDealer: data['currentDealer'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }
} 