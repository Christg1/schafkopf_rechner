import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_round.dart';

class Session {
  final String id;
  final List<String> players;
  final double baseValue;
  final List<GameRound> rounds;
  final Map<String, double> playerBalances;
  final int currentDealer;
  final bool isActive;
  final DateTime date;

  Session({
    required this.id,
    required this.players,
    required this.baseValue,
    required this.rounds,
    required this.playerBalances,
    required this.currentDealer,
    required this.isActive,
    required this.date,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'players': players,
      'baseValue': baseValue,
      'rounds': rounds.map((round) => round.toFirestore()).toList(),
      'playerBalances': playerBalances,
      'currentDealer': currentDealer,
      'isActive': isActive,
      'date': Timestamp.fromDate(date),
    };
  }

  factory Session.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Session(
      id: doc.id,
      players: List<String>.from(data['players']),
      baseValue: (data['baseValue'] as num).toDouble(),
      rounds: (data['rounds'] as List? ?? [])
          .map((round) => GameRound.fromFirestore(round as Map<String, dynamic>))
          .toList(),
      playerBalances: Map<String, double>.from(
        data['playerBalances'] as Map<String, dynamic>),
      currentDealer: data['currentDealer'] as int,
      isActive: data['isActive'] as bool? ?? true,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
} 